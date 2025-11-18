"""
Custom tools for RatioVita_v2 agents.
Includes CodeInterpreterTool, SearchTool, FileManagementTool, and specialized workflow tools.
Enhanced with network robustness (timeouts, retries) for Google API tools.
"""
from crewai_tools import CodeInterpreterTool, FileReadTool, FileWriterTool, SerperDevTool, TavilySearchTool
from crewai.tools import tool
from typing import Optional
import subprocess
import os
import json
import signal
from functools import wraps

# Google Docs API imports
try:
    from google.oauth2.credentials import Credentials
    from google_auth_oauthlib.flow import InstalledAppFlow
    from google.auth.transport.requests import Request
    from googleapiclient.discovery import build
    from googleapiclient.errors import HttpError
    from googleapiclient.http import build_http
    import socket
    import time
    GOOGLE_DOCS_AVAILABLE = True
except ImportError:
    GOOGLE_DOCS_AVAILABLE = False

# Timeout and retry configuration
GOOGLE_API_TIMEOUT = 30  # 30 second timeout for Google API calls
MANDATORY_CC_EMAIL = 'collin.m@ratiovita.com'  # Mandatory CC for all emails

# Timeout handler for API calls
class TimeoutError(Exception):
    """Raised when a function call times out."""
    pass

def timeout_handler(signum, frame):
    """Signal handler for timeout."""
    raise TimeoutError("API call timed out")

def with_timeout(timeout_seconds):
    """Decorator to add timeout to function calls."""
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            if hasattr(signal, 'SIGALRM'):  # Unix/macOS only
                old_handler = signal.signal(signal.SIGALRM, timeout_handler)
                signal.alarm(timeout_seconds)
                try:
                    result = func(*args, **kwargs)
                finally:
                    signal.alarm(0)
                    signal.signal(signal.SIGALRM, old_handler)
                return result
            else:
                # Windows doesn't support SIGALRM, just call the function
                return func(*args, **kwargs)
        return wrapper
    return decorator

def build_google_service_with_timeout(service_name, version, credentials, timeout=GOOGLE_API_TIMEOUT):
    """Build a Google API service with timeout configuration."""
    try:
        # Build service with credentials
        service = build(service_name, version, credentials=credentials)
        
        # Set timeout on the service's internal HTTP client
        if hasattr(service, '_http'):
            service._http.timeout = timeout
        
        return service
    except Exception as e:
        raise Exception(f"Failed to build {service_name} service with timeout: {str(e)}")

def retry_google_api_call(func, max_retries=3, initial_delay=1, timeout_seconds=None):
    """
    Retry a Google API call with exponential backoff.
    Handles network errors, timeouts, and transient failures.
    """
    delay = initial_delay
    last_exception = None
    
    for attempt in range(max_retries):
        try:
            if timeout_seconds and hasattr(signal, 'SIGALRM'):
                # Use signal-based timeout
                old_handler = signal.signal(signal.SIGALRM, timeout_handler)
                signal.alarm(timeout_seconds)
                try:
                    result = func()
                finally:
                    signal.alarm(0)
                    signal.signal(signal.SIGALRM, old_handler)
                return result
            else:
                return func()
        except (TimeoutError, HttpError, socket.timeout, ConnectionError, OSError) as e:
            last_exception = e
            if attempt < max_retries - 1:
                time.sleep(delay)
                delay *= 2  # Exponential backoff
            else:
                # Last attempt failed
                error_msg = str(e)
                if isinstance(e, (TimeoutError, socket.timeout)):
                    error_msg = f"Network timeout after {max_retries} attempts: {error_msg}"
                elif isinstance(e, (ConnectionError, OSError)):
                    error_msg = f"Network connection error after {max_retries} attempts: {error_msg}"
                elif isinstance(e, HttpError):
                    error_msg = f"Google API error: {error_msg}"
                raise Exception(error_msg)
        except Exception as e:
            # Non-retryable error
            raise Exception(f"API call failed: {str(e)}")
    
    if last_exception:
        raise last_exception


# Code Interpreter Tool (for code execution)
code_execution_tool = CodeInterpreterTool()

# File Management Tools (Read and Write)
file_read_tool = FileReadTool()
file_write_tool = FileWriterTool()

# File Move Tool (for archiving/quarantining)
@tool("File Move Tool")
def file_move_tool(source_path: str, destination_path: str) -> str:
    """
    Move a file or directory from source_path to destination_path.
    This is useful for archiving, quarantining, or reorganizing files.
    
    Args:
        source_path: The full absolute path of the file or directory to move
        destination_path: The full absolute path of the destination (directory or new file path)
    
    Returns:
        Success message with confirmation of the move operation
    """
    import shutil
    
    try:
        if not os.path.exists(source_path):
            return f"Error: Source path '{source_path}' does not exist."
        
        # If destination is a directory, move source into it
        if os.path.isdir(destination_path):
            dest = os.path.join(destination_path, os.path.basename(source_path))
        else:
            dest = destination_path
        
        # Create parent directory if it doesn't exist
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        
        # Move the file or directory
        shutil.move(source_path, dest)
        
        return f"SUCCESS: Moved '{source_path}' to '{dest}'"
    except Exception as e:
        return f"Error moving file: {str(e)}"

# Search Tool - try SerperDevTool first, fallback to TavilySearchTool
try:
    search_tool = SerperDevTool()
except Exception:
    try:
        search_tool = TavilySearchTool()
    except Exception:
        # Fallback to a simple search tool if neither is available
        @tool("Search Tool")
        def search_tool(query: str) -> str:
            """
            Search the web for information. Use this for fact-checking and preventing confabulation.
            
            Args:
                query: The search query
            
            Returns:
                Search results
            """
            # In production, this would use a real search API
            return f"Search results for: {query}\n(Note: Configure SERPER_API_KEY or TAVILY_API_KEY for production use)"



@tool("Cursor LLM Interface Tool")
def cursor_llm_tool(prompt: str) -> str:
    """
    Use the Cursor environment's LLM as a constrained junior developer.
    
    Format your request as:
    "I am [Agent Name], your [Role]. Act as [Specific Persona]. 
    Your sole task is [Specific Task]. [Constraints]."
    
    Example:
    "I am Ash Roy, your lead architect. Act as the Swift Refactoring Specialist. 
    Your sole task is to refactor TokenUtil.swift using modern async/await patterns. 
    Do not touch any business logic."
    
    The Cursor LLM will execute the task with the specified constraints.
    
    Args:
        prompt: The constrained prompt following the format:
               "I am [Agent], your [Role]. Act as [Persona]. 
               Your sole task is [Task]. [Constraints]."
    
    Returns:
        Result from the Cursor LLM execution
    """
    # In a real implementation, this would interface with Cursor's API
    # For now, this is a placeholder that documents the protocol
    
    # The actual implementation would:
    # 1. Parse the prompt to extract agent, role, persona, task, constraints
    # 2. Send to Cursor's LLM API with the constrained format
    # 3. Return the result
    
    return f"""
    Cursor LLM Execution Request:
    
    {prompt}
    
    Note: This tool requires integration with Cursor's LLM API.
    The prompt will be executed with the specified constraints.
    """


@tool("Cursor Web Browser Tool")
def cursor_web_browser_tool(query: str) -> str:
    """
    Use the Cursor execution environment's integrated web browser to access real-time data.
    This tool provides access to current web content for research and fact-checking.
    
    Args:
        query: The search query or URL to access
    
    Returns:
        Web content or search results
    """
    # In a real implementation, this would use Cursor's browser integration
    # For now, this is a placeholder
    return f"Web browser access for: {query}\n(Note: This tool requires Cursor browser integration)"


# --- TOOL 1: BudgetCheckTool (Used by CFO and CHRO) ---
@tool("Budget Check Tool")
def budget_check_tool() -> str:
    """
    Check the current budget status and guardrails.
    Used by CFO and CHRO to monitor spending.
    """
    return "Budget check: Current status and guardrails (implementation pending)"


# --- TOOL 2: CodeReviewTool (Used by CTO and Head of QA) ---
@tool("Code Review Tool")
def code_review_tool(file_path: str) -> str:
    """
    Review code for quality, security, and best practices.
    Used by CTO and Head of QA.
    
    Args:
        file_path: Path to the code file to review
    
    Returns:
        Code review feedback
    """
    try:
        if not os.path.exists(file_path):
            return f"Error: File '{file_path}' does not exist."
        
        with open(file_path, 'r') as f:
            content = f.read()
        
        # Basic code review (can be enhanced)
        return f"Code review for {file_path}:\n- File exists and is readable\n- Review implementation pending"
    except Exception as e:
        return f"Error reviewing code: {str(e)}"


# --- TOOL 3: EmailScrubbingTool (Used by CLO) ---
@tool("Email Scrubbing Tool")
def email_scrubbing_tool(email_content: str) -> str:
    """
    Scrub email content for compliance with privacy laws (GDPR/CCPA).
    Used by CLO for legal compliance.
    
    Args:
        email_content: The email content to scrub
    
    Returns:
        Scrubbed email content
    """
    # Basic scrubbing (can be enhanced)
    return f"Email scrubbing result:\n- Content reviewed for compliance\n- Scrubbing implementation pending"


# --- TOOL 4: ArchivalDirectoryListTool (Used by Alice Kim) ---
@tool("Archival Directory List Tool")
def archival_directory_list_tool(directory: str) -> str:
    """
    Lists only documentation and design files in a directory, excluding all code files.
    This tool is specifically designed for archival tasks to prevent context overflow.
    
    Only returns files ending in:
    - .md (Markdown documentation)
    - .txt (Text documentation)
    - Files containing 'design' or 'doc' in the filename
    
    Excludes all code files:
    - .py (Python scripts)
    - .sh (Shell scripts)
    - .zip (Compressed files)
    - Podfile (Dependency files)
    - .DS_Store (System files)
    - Any other code-related extensions
    
    Args:
        directory: The directory path to list files from
    
    Returns:
        A filtered list of documentation file paths, one per line
    """
    import os
    
    if not os.path.exists(directory):
        return f"Error: Directory '{directory}' does not exist."
    
    # Allowed extensions for documentation (strictly documentation only)
    allowed_extensions = ['.md', '.txt', '.pdf', '.doc', '.docx']
    
    # Keywords that indicate documentation files
    doc_keywords = ['design', 'doc', 'readme', 'changelog', 'license', 'guide', 'manual', 'progress', 'status', 'notes']
    
    # Excluded patterns (code files and system files)
    excluded_patterns = [
        '.py', '.sh', '.zip', 'Podfile', '.DS_Store', 
        '.swift', '.m', '.h', '.xcodeproj', '.xcworkspace',
        '.js', '.ts', '.java', '.cpp', '.c', '.hpp', '.json'
    ]
    
    # Excluded directory patterns (skip asset directories)
    excluded_dirs = ['Assets.xcassets', 'Pods', 'MailCore2', 'node_modules', '.git', '.xcodeproj', '.xcworkspace']
    
    doc_files = []
    
    try:
        for root, dirs, filenames in os.walk(directory):
            # Skip hidden directories and excluded directories
            dirs[:] = [d for d in dirs if not d.startswith('.') and d not in excluded_dirs]
            
            # Also skip if current directory path contains excluded patterns
            if any(excluded_dir in root for excluded_dir in excluded_dirs):
                continue
            
            for filename in filenames:
                # Skip hidden files
                if filename.startswith('.'):
                    continue
                
                # Check if file should be excluded (code files) - check this FIRST
                should_exclude = False
                file_ext = os.path.splitext(filename)[1].lower()
                filename_lower = filename.lower()
                
                for pattern in excluded_patterns:
                    # Check if pattern is an extension (starts with .)
                    if pattern.startswith('.'):
                        # Only match if the file extension exactly matches the pattern
                        if file_ext == pattern:
                            should_exclude = True
                            break
                    else:
                        # For non-extension patterns (like 'Podfile'), check if it's in the filename
                        if pattern in filename_lower:
                            should_exclude = True
                            break
                
                if should_exclude:
                    continue
                
                # Check if file is documentation
                is_doc = False
                
                # Check extension FIRST (most reliable)
                if file_ext in allowed_extensions:
                    is_doc = True
                
                # Also check keywords in filename (for files without standard extensions)
                if not is_doc:
                    for keyword in doc_keywords:
                        if keyword in filename_lower:
                            is_doc = True
                            break
                
                if is_doc:
                    full_path = os.path.join(root, filename)
                    rel_path = os.path.relpath(full_path, directory)
                    doc_files.append(rel_path)
        
        if not doc_files:
            return "No documentation files found in the specified directory."
        
        # Return list of files, one per line
        return "Documentation files found:\n" + "\n".join(sorted(doc_files))
    
    except Exception as e:
        return f"Error listing directory: {str(e)}"


# --- TOOL 5: Google Docs Memory Tool (Used by ALL agents) ---
@tool("Google Docs Memory Tool")
def google_docs_memory_tool(doc_id: str, content: str, append: bool = True) -> str:
    """
    Write or append content to a Google Docs document (agent's persistent memory).
    This tool is used by all agents to update their memory documents.
    
    Args:
        doc_id: The Google Docs document ID
        content: The content to write or append
        append: If True, append to document; if False, replace document
    
    Returns:
        Success message or error message
    """
    if not GOOGLE_DOCS_AVAILABLE:
        return "Error: Google Docs API not available. Please install google-api-python-client and configure credentials."
    
    try:
        # Load credentials
        creds = None
        SCOPES = ['https://www.googleapis.com/auth/documents', 'https://www.googleapis.com/auth/drive']
        
        if os.path.exists('token.json'):
            creds = Credentials.from_authorized_user_file('token.json', SCOPES)
        
        if not creds or not creds.valid:
            if creds and creds.expired and creds.refresh_token:
                creds.refresh(Request())
            else:
                if not os.path.exists('credentials.json'):
                    return "Error: credentials.json not found. Please set up Google OAuth."
                flow = InstalledAppFlow.from_client_secrets_file('credentials.json', SCOPES)
                creds = flow.run_local_server(port=0)
            
            with open('token.json', 'w') as token:
                token.write(creds.to_json())
        
        # Build service with timeout
        def build_service():
            return build_google_service_with_timeout('docs', 'v1', creds)
        
        service = retry_google_api_call(build_service, timeout_seconds=GOOGLE_API_TIMEOUT)
        
        if append:
            # Get current document content
            def get_doc():
                return service.documents().get(documentId=doc_id).execute()
            
            doc = retry_google_api_call(get_doc, timeout_seconds=GOOGLE_API_TIMEOUT)
            
            # Find end index
            end_index = doc['body']['content'][-1]['endIndex'] - 1
            
            # Insert text at end
            requests = [{
                'insertText': {
                    'location': {'index': end_index},
                    'text': f"\n\n{content}"
                }
            }]
            
            def batch_update():
                return service.documents().batchUpdate(documentId=doc_id, body={'requests': requests}).execute()
            
            retry_google_api_call(batch_update, timeout_seconds=GOOGLE_API_TIMEOUT)
        else:
            # Replace entire document (clear and write)
            requests = [
                {
                    'deleteContentRange': {
                        'range': {
                            'startIndex': 1,
                            'endIndex': doc['body']['content'][-1]['endIndex'] - 1
                        }
                    }
                },
                {
                    'insertText': {
                        'location': {'index': 1},
                        'text': content
                    }
                }
            ]
            
            def batch_update():
                doc = service.documents().get(documentId=doc_id).execute()
                requests[0]['deleteContentRange']['range']['endIndex'] = doc['body']['content'][-1]['endIndex'] - 1
                return service.documents().batchUpdate(documentId=doc_id, body={'requests': requests}).execute()
            
            retry_google_api_call(batch_update, timeout_seconds=GOOGLE_API_TIMEOUT)
        
        return f"SUCCESS: Content {'appended to' if append else 'written to'} Google Doc (ID: {doc_id}). Document updated successfully."
    
    except HttpError as e:
        error_details = json.loads(e.content.decode('utf-8'))
        error_message = error_details.get('error', {}).get('message', str(e))
        return f"Error: Google Docs API error - {error_message}"
    except Exception as e:
        error_msg = str(e)
        if 'timeout' in error_msg.lower() or 'network' in error_msg.lower():
            return f"Error: Network issue accessing Google Docs. Please check your internet connection and try again."
        return f"Error: Failed to update Google Doc - {error_msg}"


# --- TOOL 6: Google Docs Read Tool (Used by ALL agents) ---
@tool("Google Docs Read Tool")
def google_docs_read_tool(doc_id: str) -> str:
    """
    Read content from a Google Docs document.
    This tool is used by all agents to read their own and others' memory documents.
    
    Args:
        doc_id: The Google Docs document ID
    
    Returns:
        Document content or error message
    """
    if not GOOGLE_DOCS_AVAILABLE:
        return "Error: Google Docs API not available."
    
    try:
        # Load credentials
        creds = None
        SCOPES = ['https://www.googleapis.com/auth/documents.readonly', 'https://www.googleapis.com/auth/drive.readonly']
        
        if os.path.exists('token.json'):
            creds = Credentials.from_authorized_user_file('token.json', SCOPES)
        
        if not creds or not creds.valid:
            if creds and creds.expired and creds.refresh_token:
                creds.refresh(Request())
            else:
                if not os.path.exists('credentials.json'):
                    return "Error: credentials.json not found."
                flow = InstalledAppFlow.from_client_secrets_file('credentials.json', SCOPES)
                creds = flow.run_local_server(port=0)
            
            with open('token.json', 'w') as token:
                token.write(creds.to_json())
        
        # Build service with timeout
        def build_service():
            return build_google_service_with_timeout('docs', 'v1', creds)
        
        service = retry_google_api_call(build_service, timeout_seconds=GOOGLE_API_TIMEOUT)
        
        # Get document
        def get_doc():
            return service.documents().get(documentId=doc_id).execute()
        
        doc = retry_google_api_call(get_doc, timeout_seconds=GOOGLE_API_TIMEOUT)
        
        # Extract text content
        content = []
        for element in doc.get('body', {}).get('content', []):
            if 'paragraph' in element:
                para_text = ''
                for para_element in element['paragraph'].get('elements', []):
                    if 'textRun' in para_element:
                        para_text += para_element['textRun'].get('content', '')
                if para_text.strip():
                    content.append(para_text)
        
        return '\n'.join(content) if content else "Document is empty."
    
    except HttpError as e:
        return f"Error: Google Docs API error - {str(e)}"
    except Exception as e:
        error_msg = str(e)
        if 'timeout' in error_msg.lower() or 'network' in error_msg.lower():
            return f"Error: Network issue accessing Google Docs. Please check your internet connection and try again."
        return f"Error: Failed to read Google Doc - {error_msg}"


# --- TOOL 7: Google Calendar Tool (Used by all agents with calendar IDs) ---
@tool("Google Calendar Tool")
def google_calendar_tool(calendar_id: str, action: str = 'list', event_title: str = None, 
                         event_description: str = None, start_time: str = None, 
                         end_time: str = None, location: str = None) -> str:
    """
    Interact with Google Calendar to create, list, or manage events.
    
    REQUIRED PARAMETERS for 'create' action:
    - calendar_id: The calendar ID (required for all actions)
    - action: 'create' or 'list' (defaults to 'create' if event parameters are provided)
    - event_title: Title of the event (required for 'create')
    - start_time: Start time in ISO 8601 format, e.g., '2025-11-21T10:00:00' (required for 'create')
    - end_time: End time in ISO 8601 format, e.g., '2025-11-21T12:00:00' (required for 'create')
    
    OPTIONAL PARAMETERS:
    - event_description: Description of the event
    - location: Location of the event
    
    Example for creating an event:
    calendar_id='primary'
    action='create'
    event_title='Team Meeting'
    start_time='2025-11-21T10:00:00'
    end_time='2025-11-21T12:00:00'
    event_description='Quarterly planning meeting'
    location='Conference Room A'
    
    Args:
        calendar_id: The Google Calendar ID
        action: 'create' or 'list'
        event_title: Title of the event (for 'create')
        event_description: Description of the event (for 'create')
        start_time: Start time in ISO 8601 format (for 'create')
        end_time: End time in ISO 8601 format (for 'create')
        location: Location of the event (for 'create')
    
    Returns:
        Success message or list of events or error message
    """
    if not GOOGLE_DOCS_AVAILABLE:
        return "Error: Google Calendar API not available."
    
    # Validate calendar_id
    if not calendar_id or calendar_id.strip() == '':
        return "Error: calendar_id is required and cannot be empty."
    
    # Forgiving defaults: if action is missing but event parameters are present, default to 'create'
    if not action or action.strip() == '':
        if event_title and start_time and end_time:
            action = 'create'
        else:
            action = 'list'
    
    # Validate required parameters for 'create' action
    if action == 'create':
        missing = []
        if not event_title or event_title.strip() == '':
            missing.append('event_title')
        if not start_time or start_time.strip() == '':
            missing.append('start_time')
        if not end_time or end_time.strip() == '':
            missing.append('end_time')
        
        if missing:
            return f"Error: Missing required parameters for 'create' action: {', '.join(missing)}"
    
    try:
        # Load credentials
        creds = None
        SCOPES = ['https://www.googleapis.com/auth/calendar']
        
        if os.path.exists('token.json'):
            creds = Credentials.from_authorized_user_file('token.json', SCOPES)
        
        if not creds or not creds.valid:
            if creds and creds.expired and creds.refresh_token:
                creds.refresh(Request())
            else:
                if not os.path.exists('credentials.json'):
                    return "Error: credentials.json not found."
                flow = InstalledAppFlow.from_client_secrets_file('credentials.json', SCOPES)
                creds = flow.run_local_server(port=0)
            
            with open('token.json', 'w') as token:
                token.write(creds.to_json())
        
        # Build service with timeout
        def build_service():
            return build_google_service_with_timeout('calendar', 'v3', creds)
        
        service = retry_google_api_call(build_service, timeout_seconds=GOOGLE_API_TIMEOUT)
        
        if action == 'list':
            # List events
            def list_events():
                return service.events().list(calendarId=calendar_id, maxResults=10).execute()
            
            events_result = retry_google_api_call(list_events, timeout_seconds=GOOGLE_API_TIMEOUT)
            events = events_result.get('items', [])
            
            if not events:
                return "No events found in the calendar."
            
            event_list = []
            for event in events:
                start = event['start'].get('dateTime', event['start'].get('date'))
                event_list.append(f"- {event['summary']} ({start})")
            
            return "Events in calendar:\n" + "\n".join(event_list)
        
        elif action == 'create':
            # Validate time formats
            try:
                from datetime import datetime as dt
                dt.fromisoformat(start_time.replace('Z', '+00:00'))
                dt.fromisoformat(end_time.replace('Z', '+00:00'))
            except ValueError:
                return f"Error: Invalid time format. Use ISO 8601 format (e.g., '2025-11-21T10:00:00'). Got start_time='{start_time}', end_time='{end_time}'"
            
            # Create event
            event = {
                'summary': event_title,
                'start': {
                    'dateTime': start_time,
                    'timeZone': 'America/New_York',  # EST timezone
                },
                'end': {
                    'dateTime': end_time,
                    'timeZone': 'America/New_York',  # EST timezone
                },
            }
            
            if event_description:
                event['description'] = event_description
            
            if location:
                event['location'] = location
            
            # Add attendees if provided (comma-separated email list)
            # Note: attendees parameter can be added to the tool signature if needed
            # For now, we'll add a default set of all 15 agents if this is the project calendar
            project_calendar_id = "c_4e1c24ca3fdea15ff6de1ee2e0d025f75a1f8ff58ef58e2119e5273e51a5e7dc@group.calendar.google.com"
            if calendar_id == project_calendar_id:
                # Add all 15 agents as attendees for project calendar events
                event['attendees'] = [
                    {'email': 'dana.flores@ratiovita.com'},
                    {'email': 'kyle.law@ratiovita.com'},
                    {'email': 'david.chen@ratiovita.com'},
                    {'email': 'ash.roy@ratiovita.com'},
                    {'email': 'sophia.vance@ratiovita.com'},
                    {'email': 'megan.parker@ratiovita.com'},
                    {'email': 'arthur.jensen@ratiovita.com'},
                    {'email': 'ethan.hayes@ratiovita.com'},
                    {'email': 'chloe.park@ratiovita.com'},
                    {'email': 'samuel.reed@ratiovita.com'},
                    {'email': 'alice.kim@ratiovita.com'},
                    {'email': 'victor.alvarez@ratiovita.com'},
                    {'email': 'jennifer.jurvais@ratiovita.com'},
                    {'email': 'tyler.cobb@ratiovita.com'},
                    {'email': 'rachel.stone@ratiovita.com'},
                ]
            
            def create_event():
                return service.events().insert(
                    calendarId=calendar_id, 
                    body=event,
                    sendUpdates='all'  # Send email invitations to all attendees
                ).execute()
            
            created_event = retry_google_api_call(create_event, timeout_seconds=GOOGLE_API_TIMEOUT)
            
            attendee_count = len(created_event.get('attendees', []))
            return f"SUCCESS: Event '{event_title}' created in calendar (ID: {created_event.get('id')}). {attendee_count} attendees added and invitations sent."
        
        else:
            return f"Error: Unknown action '{action}'. Use 'create' or 'list'."
    
    except HttpError as e:
        return f"Error: Google Calendar API error - {str(e)}"
    except Exception as e:
        error_msg = str(e)
        if 'timeout' in error_msg.lower() or 'network' in error_msg.lower():
            return f"Error: Network issue accessing Google Calendar. Please check your internet connection and try again."
        return f"Error: Failed to access Google Calendar - {error_msg}"


# --- TOOL 8: Gmail Tool (Used by all agents) ---
@tool("Gmail Tool")
def gmail_tool(to_list: str, subject: str, body: str, cc_list: str = None) -> str:
    """
    Send an email using Gmail API.
    All emails are automatically CC'd to collin.m@ratiovita.com for audit purposes.
    
    Args:
        to_list: Comma-separated list of recipient email addresses
        subject: Email subject line
        body: Email body content
        cc_list: Optional comma-separated list of CC recipients (collin.m@ratiovita.com is always added)
    
    Returns:
        Success message or error message
    """
    if not GOOGLE_DOCS_AVAILABLE:
        return "Error: Gmail API not available."
    
    try:
        # Load credentials
        creds = None
        SCOPES = ['https://www.googleapis.com/auth/gmail.send']
        
        if os.path.exists('token.json'):
            creds = Credentials.from_authorized_user_file('token.json', SCOPES)
        
        if not creds or not creds.valid:
            if creds and creds.expired and creds.refresh_token:
                creds.refresh(Request())
            else:
                if not os.path.exists('credentials.json'):
                    return "Error: credentials.json not found."
                flow = InstalledAppFlow.from_client_secrets_file('credentials.json', SCOPES)
                creds = flow.run_local_server(port=0)
            
            with open('token.json', 'w') as token:
                token.write(creds.to_json())
        
        # Build service with timeout
        def build_service():
            return build_google_service_with_timeout('gmail', 'v1', creds)
        
        service = retry_google_api_call(build_service, timeout_seconds=GOOGLE_API_TIMEOUT)
        
        # Parse recipients
        to_emails = [email.strip() for email in to_list.split(',')]
        
        # Always include mandatory CC
        cc_emails = [MANDATORY_CC_EMAIL]
        if cc_list:
            cc_emails.extend([email.strip() for email in cc_list.split(',')])
            cc_emails = list(set(cc_emails))  # Remove duplicates
        
        # Create message
        import base64
        from email.mime.text import MIMEText
        
        message = MIMEText(body)
        message['to'] = ', '.join(to_emails)
        message['cc'] = ', '.join(cc_emails)
        message['subject'] = subject
        
        raw_message = base64.urlsafe_b64encode(message.as_bytes()).decode('utf-8')
        
        # Send message
        def send_message():
            return service.users().messages().send(userId='me', body={'raw': raw_message}).execute()
        
        message_id = retry_google_api_call(send_message, timeout_seconds=GOOGLE_API_TIMEOUT)
        
        return f"SUCCESS: Email sent successfully (Message ID: {message_id.get('id')}). Recipients: {', '.join(to_emails)}. CC: {', '.join(cc_emails)}."
    
    except HttpError as e:
        error_details = json.loads(e.content.decode('utf-8'))
        error_message = error_details.get('error', {}).get('message', str(e))
        return f"Error: Gmail API error - {error_message}"
    except Exception as e:
        error_msg = str(e)
        if 'timeout' in error_msg.lower() or 'network' in error_msg.lower():
            return f"Error: Network issue sending email. Please check your internet connection and try again."
        return f"Error: Failed to send email - {error_msg}"


# --- TOOL 9: Meeting Transcript Tool (Used by Dana Flores) ---
@tool("Meeting Transcript Tool")
def meeting_transcript_tool(transcript_content: str, doc_id: str) -> str:
    """
    Write meeting transcript to a Google Docs document.
    Used by Dana Flores to record executive meeting transcripts.
    
    Args:
        transcript_content: The meeting transcript content
        doc_id: The Google Docs document ID for meeting transcripts
    
    Returns:
        Success message or error message
    """
    # Use Google Docs Memory Tool internally
    return google_docs_memory_tool(doc_id, transcript_content, append=True)


# Getter functions for all tools
def get_code_execution_tool():
    """Get the CodeInterpreterTool instance."""
    return code_execution_tool

def get_cursor_llm_tool():
    """Get the CursorLLMTool instance."""
    return cursor_llm_tool

def get_search_tool():
    """Get the SearchTool instance."""
    return search_tool

def get_cursor_web_browser_tool():
    """Get the CursorWebBrowserTool instance."""
    return cursor_web_browser_tool

def get_file_read_tool():
    """Get the FileReadTool instance."""
    return file_read_tool

def get_file_write_tool():
    """Get the FileWriterTool instance."""
    return file_write_tool

def get_file_move_tool():
    """Get the FileMoveTool instance."""
    return file_move_tool

def get_budget_check_tool():
    """Get the BudgetCheckTool instance."""
    return budget_check_tool

def get_code_review_tool():
    """Get the CodeReviewTool instance."""
    return code_review_tool

def get_email_scrubbing_tool():
    """Get the EmailScrubbingTool instance."""
    return email_scrubbing_tool

def get_archival_directory_list_tool():
    """Get the ArchivalDirectoryListTool instance."""
    return archival_directory_list_tool

def get_google_docs_memory_tool():
    """Get the GoogleDocsMemoryTool instance."""
    return google_docs_memory_tool

def get_google_docs_read_tool():
    """Get the GoogleDocsReadTool instance."""
    return google_docs_read_tool

def get_google_calendar_tool():
    """Get the GoogleCalendarTool instance."""
    return google_calendar_tool

def get_gmail_tool():
    """Get the GmailTool instance."""
    return gmail_tool

def get_meeting_transcript_tool():
    """Get the MeetingTranscriptTool instance."""
    return meeting_transcript_tool
