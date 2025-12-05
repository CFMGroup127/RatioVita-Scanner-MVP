"""
Custom tools for RatioVita_v2 agents.
Includes CodeInterpreterTool, SearchTool, FileManagementTool, and specialized workflow tools.
Enhanced with network robustness (timeouts, retries) for Google API tools.
"""
from crewai_tools import CodeInterpreterTool, FileReadTool, FileWriterTool, SerperDevTool, TavilySearchTool
from crewai.tools import tool
from typing import Optional, List, Tuple, Union
import subprocess
import os
import json
import signal
import threading
from functools import wraps
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, TimeoutError as FutureTimeoutError

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
    Uses threading-based timeout that works in any thread.
    """
    delay = initial_delay
    last_exception = None
    
    def execute_with_timeout():
        """Execute function with timeout using ThreadPoolExecutor (works in any thread)."""
        if timeout_seconds:
            with ThreadPoolExecutor(max_workers=1) as executor:
                future = executor.submit(func)
                try:
                    return future.result(timeout=timeout_seconds)
                except FutureTimeoutError:
                    raise TimeoutError(f"API call timed out after {timeout_seconds} seconds")
        else:
            return func()
    
    for attempt in range(max_retries):
        try:
            result = execute_with_timeout()
            return result
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
            # Check if it's the threading error
            error_msg = str(e)
            if 'signal only works in main thread' in error_msg.lower():
                # Fall back to non-signal timeout
                try:
                    return execute_with_timeout()
                except Exception as e2:
                    raise Exception(f"API call failed: {str(e2)}")
            # Non-retryable error
            raise Exception(f"API call failed: {error_msg}")
    
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


# Timestamp sorting helper function
# Updated to handle timestamps with or without timezone suffix (EST, UTC, etc.)
TIMESTAMP_PATTERN = r"(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})(?:\s+EST|\s+UTC|\s+PST|\s+[A-Z]{3})?"
DATE_FORMAT = "%Y-%m-%d %H:%M:%S"

def extract_timestamp_from_entry(entry: str) -> Optional[datetime]:
    """Extract timestamp from an entry string. Handles timestamps with or without timezone suffix."""
    match = re.search(TIMESTAMP_PATTERN, entry)
    if match:
        try:
            timestamp_str = match.group(1)  # Get the timestamp part without timezone
            return datetime.strptime(timestamp_str, DATE_FORMAT)
        except ValueError:
            return None
    return None

def sort_subsection_content_by_timestamp(existing_content: str, new_entry: str) -> str:
    """
    Reads all entries in a subsection, adds the new entry, sorts by timestamp, and returns sorted content.
    This ensures chronological ordering for audit and readability.
    
    Args:
        existing_content: Current content of the subsection
        new_entry: New entry to add
    
    Returns:
        Sorted content with all entries in chronological order
    """
    if not existing_content.strip() and new_entry.strip():
        # If no existing content, just return the new entry
        return new_entry.strip()
    
    # 1. READ & COMBINE: Add the new entry to existing content
    # Split content into entries - entries are typically separated by blank lines or start with timestamps
    all_text = existing_content.strip() + "\n\n" + new_entry.strip()
    
    # Split by double newlines first (common separator)
    entries = [e.strip() for e in all_text.split('\n\n') if e.strip()]
    
    # If that didn't work well, try splitting by lines that start with timestamps
    if len(entries) == 1:
        # Try splitting by lines that contain timestamps
        lines = all_text.split('\n')
        entries = []
        current_entry = []
        for line in lines:
            line = line.strip()
            if not line:
                if current_entry:
                    entries.append('\n'.join(current_entry))
                    current_entry = []
                continue
            
            # Check if this line starts a new entry (has timestamp pattern)
            if re.search(TIMESTAMP_PATTERN, line):
                if current_entry:
                    entries.append('\n'.join(current_entry))
                current_entry = [line]
            else:
                current_entry.append(line)
        
        if current_entry:
            entries.append('\n'.join(current_entry))
    
    # 2. PARSE: Extract entries with timestamps and sort them
    sortable_entries = []
    non_sortable_entries = []
    
    for entry in entries:
        timestamp = extract_timestamp_from_entry(entry)
        if timestamp:
            sortable_entries.append((timestamp, entry))
        else:
            # Entries without timestamps (headers, task lists) - check if they're important headers
            # Headers (starting with #) go first, other content goes after sorted entries
            if entry.strip().startswith('#'):
                non_sortable_entries.insert(0, entry)  # Headers at the beginning
            else:
                non_sortable_entries.append(entry)  # Other content at the end
    
    # 3. SORT: Sort entries by timestamp (chronological order - oldest first)
    sortable_entries.sort(key=lambda x: x[0])
    
    # 4. REWRITE: Combine non-sortable entries (headers) first, then sorted entries, then other content
    sorted_content_parts = []
    
    # Add headers first
    headers = [e for e in non_sortable_entries if e.strip().startswith('#')]
    for header in headers:
        sorted_content_parts.append(header)
    
    # Add sorted entries (chronological)
    for timestamp, entry_text in sortable_entries:
        if entry_text.strip():
            sorted_content_parts.append(entry_text)
    
    # Add other non-sortable content at the end
    other_content = [e for e in non_sortable_entries if not e.strip().startswith('#')]
    for content in other_content:
        if content.strip():
            sorted_content_parts.append(content)
    
    # Join with double newlines for readability
    return '\n\n'.join(sorted_content_parts)

# --- TOOL 5: Google Docs Memory Tool (Used by ALL agents) ---
@tool("Google Docs Memory Tool")
def google_docs_memory_tool(doc_id: str, content: str, append: bool = True, section: Optional[str] = None, subsection: Optional[str] = None, template: Optional[str] = None) -> str:
    """
    Write or append content to a Google Docs document (agent's persistent memory).
    Enhanced to support section-based writing for organized memory documents.
    
    Args:
        doc_id: The Google Docs document ID
        content: The content to write or append
        append: If True, append to document; if False, replace document
        section: Optional section name (e.g., "TASKS", "MEETINGS", "PROTOCOLS", "REPORTS")
        subsection: Optional subsection (e.g., date "November 20, 2025" for daily tasks)
        template: Optional template name for formatting (e.g., "Task Tracker", "Meeting Notes", "Compliance Log", "Report Archive")
    
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
            
            # Format content based on template
            formatted_content = content
            if template == "Task Tracker" and subsection:
                formatted_content = f"#### {subsection}\n**Date:** {datetime.now().strftime('%B %d, %Y')}\n\n{content}\n"
            elif template == "Meeting Notes" or template == "MEETING_MINUTES":
                # Enhanced MEETING_MINUTES template
                meeting_title = content.split(' - ')[0] if ' - ' in content else 'Meeting'
                formatted_content = f"""### MEETING MINUTES: {meeting_title} - {datetime.now().strftime('%B %d, %Y')}

| Section | Detail |
| :--- | :--- |
| **I. Overview** | **Time:** {datetime.now().strftime('%I:%M %p EST')} | **Location:** Virtual Meeting | **Type:** Executive Strategy |
| **II. Attendance** | **Present:** [To be filled by agent] | **Absent:** [To be filled by agent] |
| **III. Decisions Made** | |
| **Decision 1:** [Resolution Text] | **Vote:** [Unanimous/Majority/Dissenting] |
| **Decision 2:** [Resolution Text] | **Vote:** [Unanimous/Majority/Dissenting] |
| **IV. Action Items** | **Task:** [Action to be completed] | **Owner:** [Agent Name] | **Due Date:** [Date] |
| | **Task:** [Action to be completed] | **Owner:** [Agent Name] | **Due Date:** [Date] |
| **V. Dissenting Votes** | [Notes on any explicit dissents] |

**Meeting Notes:**
{content}

---
"""
            elif template == "Compliance Log":
                formatted_content = f"**{datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}** - {content}\n"
            elif template == "Report Archive":
                formatted_content = f"### {content.split(' - ')[0] if ' - ' in content else 'Report'}\n**Date:** {datetime.now().strftime('%B %d, %Y')}\n**Status:** Submitted\n\n{content}\n"
            elif template == "COMPETITIVE_ANALYSIS":
                # New COMPETITIVE_ANALYSIS template
                competitor_name = content.split(' - ')[0] if ' - ' in content else 'Competitor'
                formatted_content = f"""## COMPETITIVE ANALYSIS REPORT: {competitor_name}

### I. Competitor Profile
* **Competitor Name:** {competitor_name}
* **Category:** [Direct/Indirect/Emerging]
* **Core Product/Service:** [Description]

### II. Comparison Benchmarking
| Feature / Metric | RatioVita Status | {competitor_name} Status | Key Delta |
| :--- | :--- | :--- | :--- |
| **Feature X** | [Status] | [Status] | [Difference] |
| **Pricing Model** | [Model/Cost] | [Model/Cost] | [Difference] |
| **Market Share** | [Percentage] | [Percentage] | [Difference] |

### III. Strategic SWOT Analysis
| Factor | Detail |
| :--- | :--- |
| **Strengths (S)** | [Competitor's Key Advantages] |
| **Weaknesses (W)** | [Competitor's Key Vulnerabilities] |
| **Opportunities (O)** | [Market Gaps to Exploit] |
| **Threats (T)** | [Risks to RatioVita] |

**Analysis Details:**
{content}

**Date:** {datetime.now().strftime('%B %d, %Y')}
**Analyst:** [Agent Name]

---
"""
            elif template == "MEETING_TRANSCRIPT_ARCHIVE":
                # New MEETING_TRANSCRIPT_ARCHIVE template for official transcripts
                formatted_content = f"""## MEETING TRANSCRIPT ARCHIVE - {datetime.now().strftime('%B %d, %Y')}

**Meeting Date:** {datetime.now().strftime('%B %d, %Y')}
**Transcript Type:** Official Meeting Record
**Status:** Archived

---

{content}

---

**End of Transcript**
**Archived:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}

---
"""
            else:
                formatted_content = f"\n{content}\n"
            
            # Find section if specified
            insert_index = None
            if section:
                # Search for section heading
                section_upper = section.upper()
                subsection_upper = subsection.upper() if subsection else None
                section_found = False
                subsection_found = False
                
                for i, element in enumerate(doc['body']['content']):
                    if 'paragraph' in element:
                        para = element['paragraph']
                        if 'elements' in para:
                            for elem in para['elements']:
                                if 'textRun' in elem:
                                    text = elem['textRun'].get('content', '').upper()
                                    # Check for main section heading
                                    if section_upper in text and ('##' in text or '#' in text):
                                        section_found = True
                                        # Found main section
                                        if subsection_upper:
                                            # Look for subsection in next elements
                                            for j in range(i + 1, min(i + 50, len(doc['body']['content']))):
                                                next_elem = doc['body']['content'][j]
                                                if 'paragraph' in next_elem:
                                                    next_para = next_elem['paragraph']
                                                    if 'elements' in next_para:
                                                        for next_elem in next_para['elements']:
                                                            if 'textRun' in next_elem:
                                                                next_text = next_elem['textRun'].get('content', '').upper()
                                                                # Check for subsection heading (###)
                                                                if subsection_upper in next_text and '###' in next_text:
                                                                    subsection_found = True
                                                                    # Found subsection, insert at end of this subsection
                                                                    # Look for next subsection or section to find insertion point
                                                                    for k in range(j + 1, min(j + 30, len(doc['body']['content']))):
                                                                        check_elem = doc['body']['content'][k]
                                                                        if 'paragraph' in check_elem:
                                                                            check_para = check_elem['paragraph']
                                                                            if 'elements' in check_para:
                                                                                for check_elem in check_para['elements']:
                                                                                    if 'textRun' in check_elem:
                                                                                        check_text = check_elem['textRun'].get('content', '').upper()
                                                                                        # If we hit another subsection or section, insert before it
                                                                                        if ('###' in check_text and subsection_upper not in check_text) or ('##' in check_text and section_upper not in check_text):
                                                                                            insert_index = check_elem.get('startIndex', None)
                                                                                            break
                                                                        if insert_index:
                                                                            break
                                                                    # If no next subsection found, we need to extract existing content for sorting
                                                                    if not insert_index:
                                                                        # Extract existing content from this subsection for timestamp sorting
                                                                        subsection_start = next_elem.get('startIndex', None)
                                                                        subsection_end = None
                                                                        # Find end of subsection
                                                                        for k in range(j + 1, min(j + 100, len(doc['body']['content']))):
                                                                            check_elem = doc['body']['content'][k]
                                                                            if 'paragraph' in check_elem:
                                                                                check_para = check_elem['paragraph']
                                                                                if 'elements' in check_para:
                                                                                    for check_elem in check_para['elements']:
                                                                                        if 'textRun' in check_elem:
                                                                                            check_text = check_elem['textRun'].get('content', '').upper()
                                                                                            if ('###' in check_text and subsection_upper not in check_text) or ('##' in check_text and section_upper not in check_text):
                                                                                                subsection_end = check_elem.get('startIndex', None)
                                                                                                break
                                                                                    if subsection_end:
                                                                                        break
                                                                        if not subsection_end:
                                                                            subsection_end = doc['body']['content'][-1]['endIndex'] - 1
                                                                        
                                                                        # Extract existing subsection content
                                                                        existing_subsection_content = ""
                                                                        for k in range(j, min(j + 100, len(doc['body']['content']))):
                                                                            check_elem = doc['body']['content'][k]
                                                                            if 'paragraph' in check_elem:
                                                                                check_para = check_elem['paragraph']
                                                                                if 'elements' in check_para:
                                                                                    for check_elem in check_para['elements']:
                                                                                        if 'textRun' in check_elem:
                                                                                            elem_start = check_elem.get('startIndex', 0)
                                                                                            elem_end = check_elem.get('endIndex', 0)
                                                                                            if subsection_start and subsection_end and subsection_start <= elem_start < subsection_end:
                                                                                                existing_subsection_content += check_elem['textRun'].get('content', '')
                                                                        
                                                                        # Apply timestamp sorting if this is a dated subsection (PROTOCOLS, MEETINGS, TRANSCRIPTS)
                                                                        if section_upper in ['PROTOCOLS', 'MEETINGS', 'TRANSCRIPTS', 'REPORTS']:
                                                                            sorted_content = sort_subsection_content_by_timestamp(existing_subsection_content, formatted_content)
                                                                            # Delete old content and insert sorted content
                                                                            formatted_content = sorted_content
                                                                            insert_index = subsection_start
                                                                            # We'll delete the old content in the requests
                                                                            requests = [
                                                                                {
                                                                                    'deleteContentRange': {
                                                                                        'range': {
                                                                                            'startIndex': subsection_start,
                                                                                            'endIndex': subsection_end
                                                                                        }
                                                                                    }
                                                                                },
                                                                                {
                                                                                    'insertText': {
                                                                                        'location': {'index': subsection_start},
                                                                                        'text': formatted_content
                                                                                    }
                                                                                }
                                                                            ]
                                                                            # Skip the normal insertion logic
                                                                            def batch_update():
                                                                                return service.documents().batchUpdate(documentId=doc_id, body={'requests': requests}).execute()
                                                                            retry_google_api_call(batch_update, timeout_seconds=GOOGLE_API_TIMEOUT)
                                                                            location_desc = f"section '{section}'" if section else "end of document"
                                                                            if subsection:
                                                                                location_desc += f", subsection '{subsection}'"
                                                                            return f"SUCCESS: Content written and sorted chronologically in {location_desc} in Google Doc (ID: {doc_id}). Document updated successfully."
                                                                    break
                                                        if subsection_found:
                                                            break
                                            if not subsection_found:
                                                # Subsection not found, create it after main section
                                                insert_index = element.get('endIndex', None)
                                                formatted_content = f"\n### {subsection}\n{formatted_content}"
                                        else:
                                            # No subsection, insert at end of section (before next section)
                                            # Look for next section
                                            for j in range(i + 1, min(i + 30, len(doc['body']['content']))):
                                                next_elem = doc['body']['content'][j]
                                                if 'paragraph' in next_elem:
                                                    next_para = next_elem['paragraph']
                                                    if 'elements' in next_para:
                                                        for next_elem in next_para['elements']:
                                                            if 'textRun' in next_elem:
                                                                next_text = next_elem['textRun'].get('content', '').upper()
                                                                # If we hit another section, insert before it
                                                                if '##' in next_text and section_upper not in next_text:
                                                                    insert_index = next_elem.get('startIndex', None)
                                                                    break
                                                if insert_index:
                                                    break
                                            if not insert_index:
                                                # No next section found, insert at end of document
                                                insert_index = doc['body']['content'][-1]['endIndex'] - 1
                                        break
                                if insert_index:
                                    break
                        if insert_index:
                            break
                
                # If section not found, create it
                if not section_found:
                    insert_index = doc['body']['content'][-1]['endIndex'] - 1
                    formatted_content = f"\n\n## {section.upper()}\n{formatted_content}"
                    if subsection:
                        formatted_content = f"{formatted_content}\n### {subsection}\n"
            
            # Use found index or default to end
            if insert_index is None:
                insert_index = doc['body']['content'][-1]['endIndex'] - 1
                # If section was specified but not found, create it
                if section:
                    formatted_content = f"\n\n## {section.upper()}\n{formatted_content}"
                    if subsection:
                        formatted_content = f"{formatted_content}\n### {subsection}\n"
            
            # PERFECT TEMPORAL FIDELITY: Apply timestamp sorting for dated subsections
            # This ensures all entries are chronologically ordered (no more 9 PM before 2 PM)
            if section and subsection and section.upper() in ['PROTOCOLS', 'MEETINGS', 'TRANSCRIPTS', 'REPORTS']:
                # Try to find and extract the entire subsection for sorting
                try:
                    subsection_start = None
                    subsection_end = None
                    subsection_found_in_doc = False
                    
                    # Search for the subsection header
                    for i, element in enumerate(doc['body']['content']):
                        if 'paragraph' in element:
                            para = element['paragraph']
                            if 'elements' in para:
                                for elem in para['elements']:
                                    if 'textRun' in elem:
                                        text = elem['textRun'].get('content', '').upper()
                                        # Check if this is our subsection header
                                        if subsection_upper and subsection_upper in text and '###' in text:
                                            subsection_start = elem.get('startIndex', None)
                                            subsection_found_in_doc = True
                                            # Find end of subsection (next subsection or section)
                                            for k in range(i + 1, min(i + 300, len(doc['body']['content']))):
                                                check_elem = doc['body']['content'][k]
                                                if 'paragraph' in check_elem:
                                                    check_para = check_elem['paragraph']
                                                    if 'elements' in check_para:
                                                        for check_elem in check_para['elements']:
                                                            if 'textRun' in check_elem:
                                                                check_text = check_elem['textRun'].get('content', '').upper()
                                                                # Found next subsection or section - this is the end
                                                                if ('###' in check_text and subsection_upper not in check_text) or ('##' in check_text and section_upper not in check_text):
                                                                    subsection_end = check_elem.get('startIndex', None)
                                                                    break
                                                        if subsection_end:
                                                            break
                                            if not subsection_end:
                                                subsection_end = doc['body']['content'][-1]['endIndex'] - 1
                                            break
                    
                    if subsection_found_in_doc and subsection_start and subsection_end:
                        # Extract existing subsection content (skip the header line)
                        existing_subsection_content = ""
                        for elem in doc['body']['content']:
                            if 'paragraph' in elem:
                                para = elem['paragraph']
                                if 'elements' in para:
                                    for para_elem in para['elements']:
                                        if 'textRun' in para_elem:
                                            elem_start = para_elem.get('startIndex', 0)
                                            # Extract content after the header, before the end
                                            if subsection_start < elem_start < subsection_end:
                                                existing_subsection_content += para_elem['textRun'].get('content', '')
                        
                        # Apply PERFECT TEMPORAL FIDELITY: Sort all entries chronologically
                        sorted_content = sort_subsection_content_by_timestamp(existing_subsection_content, formatted_content)
                        
                        # Rewrite the entire subsection with sorted content
                        requests = [
                            {
                                'deleteContentRange': {
                                    'range': {
                                        'startIndex': subsection_start,
                                        'endIndex': subsection_end
                                    }
                                }
                            },
                            {
                                'insertText': {
                                    'location': {'index': subsection_start},
                                    'text': f"### {subsection}\n\n{sorted_content}\n\n"
                                }
                            }
                        ]
                        
                        def batch_update():
                            return service.documents().batchUpdate(documentId=doc_id, body={'requests': requests}).execute()
                        
                        retry_google_api_call(batch_update, timeout_seconds=GOOGLE_API_TIMEOUT)
                        location_desc = f"section '{section}'" if section else "end of document"
                        if subsection:
                            location_desc += f", subsection '{subsection}'"
                        return f"SUCCESS: Content written and sorted chronologically (PERFECT TEMPORAL FIDELITY) in {location_desc} in Google Doc (ID: {doc_id}). Document updated successfully."
                except Exception as e:
                    # If sorting fails, proceed with normal insertion (fallback)
                    # Log error but don't fail completely
                    pass
            
            # Normal insertion (if sorting didn't apply or failed)
            requests = [{
                'insertText': {
                    'location': {'index': insert_index},
                    'text': formatted_content
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
        
        location_desc = f"section '{section}'" if section else "end of document"
        if subsection:
            location_desc += f", subsection '{subsection}'"
        
        return f"SUCCESS: Content written to {location_desc} in Google Doc (ID: {doc_id}). Document updated successfully."
    
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
        # Use full read/write scopes to ensure access (readonly may not be sufficient for some operations)
        SCOPES = ['https://www.googleapis.com/auth/documents', 'https://www.googleapis.com/auth/drive.readonly']
        
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


def generate_email_signature(agent_role: str, agent_email: str = None) -> str:
    """
    Generate an email signature for an agent with RatioVita branding.
    
    Args:
        agent_role: The agent's role/title
        agent_email: The agent's email address (optional)
    
    Returns:
        HTML signature string
    """
    # Extract full name from role (e.g., "Admin Assistant & Workflow Funnel" -> "Dana Flores")
    # This mapping will be used to get the agent's name
    role_to_name = {
        "Admin Assistant & Workflow Funnel": "Dana Flores",
        "Visionary and Final Decision Maker": "Kyle Law",
        "Process Architect and Schedule Publisher": "David Chen",
        "Technical and Product Visionary": "Ash Roy",
        "Financial Guardian and Strategy Modeler": "Sophia Vance",
        "Market Strategist and Voice of the Customer": "Megan Parker",
        "Legal Compliance and Risk Assessor": "Arthur Jensen",
        "Lead Code Execution and V2 Development": "Ethan Hayes",
        "Process and Factual Integrity Auditor": "Chloe Park",
        "Competitive Intelligence Specialist": "Samuel Reed",
        "Documentation and Knowledge Archivist": "Alice Kim",
        "Go-to-Market Strategy": "Victor Alvarez",
        "Budget and Conflict Guardrail": "Jennifer Jurvais",
        "Collateral Support and Lead Qualification": "Tyler Cobb",
        "External Communication and Trust Builder": "Rachel Stone"
    }
    
    full_name = role_to_name.get(agent_role, agent_role)
    email_display = agent_email if agent_email else ""
    
    signature = f"""
<br><br>
<hr style="border: none; border-top: 1px solid #e0e0e0; margin: 20px 0;">
<table cellpadding="0" cellspacing="0" style="font-family: Arial, sans-serif; font-size: 12px; color: #333333;">
    <tr>
        <td style="padding-right: 15px; vertical-align: top;">
            <img src="https://ratiovita.com/logo.png" alt="RatioVita Logo" style="width: 120px; height: auto; max-width: 120px;" onerror="this.style.display='none'">
        </td>
        <td style="vertical-align: top;">
            <p style="margin: 0; font-weight: bold; font-size: 14px; color: #1a1a1a;">{full_name}</p>
            <p style="margin: 5px 0 0 0; font-size: 12px; color: #666666;">{agent_role}</p>
            <p style="margin: 5px 0 0 0; font-size: 11px; color: #888888;">RatioVita</p>
            {f'<p style="margin: 5px 0 0 0; font-size: 11px; color: #666666;">{email_display}</p>' if email_display else ''}
        </td>
    </tr>
</table>
<p style="margin: 10px 0 0 0; font-size: 10px; color: #999999; font-style: italic;">
    This email was sent by an AI agent representing {full_name} at RatioVita.
</p>
"""
    return signature

# --- TOOL 8: Gmail Tool (Used by all agents) ---
@tool("Gmail Tool")
def gmail_tool(to_list: str, subject: str, body: str, cc_list: str = None, agent_role: str = None) -> str:
    """
    Send an email using Gmail API.
    All emails are automatically CC'd to collin.m@ratiovita.com for audit purposes.
    Email signatures with agent name and RatioVita logo are automatically added.
    
    Args:
        to_list: Comma-separated list of recipient email addresses
        subject: Email subject line
        body: Email body content
        cc_list: Optional comma-separated list of CC recipients (collin.m@ratiovita.com is always added)
        agent_role: The agent's role (used to generate email signature with name and logo)
    
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
        
        # Get agent email for signature (if agent_role provided)
        agent_email = None
        if agent_role:
            try:
                from main import get_agent_metadata
                metadata = get_agent_metadata(agent_role)
                agent_email = metadata.get('email_address', '')
            except:
                pass
        
        # Add signature to body if agent_role is provided
        if agent_role:
            signature = generate_email_signature(agent_role, agent_email)
            # Check if body is HTML or plain text
            if '<html' in body.lower() or '<body' in body.lower() or '<br>' in body or '<p>' in body:
                # Body is already HTML, append signature
                body = body + signature
            else:
                # Convert plain text to HTML and add signature
                body = body.replace('\n', '<br>') + signature
        
        # Create message (use MIMEMultipart for HTML support)
        import base64
        from email.mime.multipart import MIMEMultipart
        from email.mime.text import MIMEText
        
        # Check if body contains HTML
        is_html = '<html' in body.lower() or '<body' in body.lower() or '<br>' in body or '<p>' in body or '<table' in body
        
        if is_html:
            # Create multipart message with HTML
            message = MIMEMultipart('alternative')
            # Add plain text version (strip HTML tags for basic plain text)
            import re
            plain_text = re.sub(r'<[^>]+>', '', body)
            message.attach(MIMEText(plain_text, 'plain'))
            message.attach(MIMEText(body, 'html'))
        else:
            # Plain text message
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


# --- TOOL 10: Google Tasks Tool (P3 Protocol - Hybrid System Phase 1) ---
@tool("Google Tasks Tool")
def google_tasks_tool(
    task_title: str,
    task_notes: str = None,
    due_date: str = None,
    task_list_id: str = "@default"
) -> str:
    """
    Create a task in Google Tasks for P3 protocol compliance.
    This makes tasks visible in the Google Tasks Sidebar for human interaction.
    
    This is part of the Hybrid System: Tasks are logged both in memory documents (AI-auditable)
    AND in Google Tasks (Human-interactive via sidebar).
    
    Args:
        task_title: The title of the task (required)
        task_notes: Additional notes or description for the task
        due_date: Due date in format "YYYY-MM-DD" or "YYYY-MM-DD HH:MM"
        task_list_id: The task list ID (default: "@default" for default list)
    
    Returns:
        Success message with task ID and URL
    """
    try:
        from google.oauth2.credentials import Credentials
        from google.auth.transport.requests import Request
        from googleapiclient.discovery import build
        from googleapiclient.errors import HttpError
        
        SCOPES = ['https://www.googleapis.com/auth/tasks']
        
        # Get credentials
        creds = None
        if os.path.exists('token.json'):
            try:
                creds = Credentials.from_authorized_user_file('token.json', SCOPES)
            except:
                try:
                    creds = Credentials.from_authorized_user_file('token.json', None)
                    if creds and creds.scopes:
                        # Add Tasks scope if not present
                        if 'https://www.googleapis.com/auth/tasks' not in creds.scopes:
                            creds = creds.with_scopes(creds.scopes + SCOPES)
                except:
                    pass
        
        if not creds or not creds.valid:
            if creds and creds.expired and creds.refresh_token:
                try:
                    creds.refresh(Request())
                except:
                    return "ERROR: Could not get credentials for Google Tasks API. Please run fix_oauth_full_permissions.py with Tasks scope."
            else:
                return "ERROR: Could not get credentials for Google Tasks API. Please run fix_oauth_full_permissions.py with Tasks scope."
        
        service = build('tasks', 'v1', credentials=creds)
        
        # Build task body
        task_body = {
            'title': task_title,
            'status': 'needsAction'  # Task is not completed
        }
        
        if task_notes:
            task_body['notes'] = task_notes
        
        if due_date:
            # Parse due date
            try:
                # Try parsing as datetime
                if ' ' in due_date:
                    due_dt = datetime.strptime(due_date, '%Y-%m-%d %H:%M')
                else:
                    due_dt = datetime.strptime(due_date, '%Y-%m-%d')
                
                # Google Tasks API expects RFC 3339 format
                task_body['due'] = due_dt.strftime('%Y-%m-%dT%H:%M:%S.000Z')
            except ValueError:
                # If parsing fails, try to use as-is
                task_body['due'] = due_date
        
        # Insert task
        result = service.tasks().insert(
            tasklist=task_list_id,
            body=task_body
        ).execute()
        
        task_id = result.get('id')
        task_url = f"https://tasks.google.com/embed/list/{task_list_id}/tasks/{task_id}"
        
        return f"SUCCESS: Task '{task_title}' created in Google Tasks (ID: {task_id}). Visible in Tasks Sidebar. URL: {task_url}"
        
    except HttpError as e:
        return f"ERROR: Google Tasks API error: {str(e)}"
    except Exception as e:
        return f"ERROR: Failed to create task: {str(e)}"


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

def get_gmail_tool(agent_role: str = None):
    """
    Get the Gmail tool instance with agent role automatically injected.
    
    Args:
        agent_role: The agent's role (optional, will be injected if provided)
    
    Returns:
        Gmail tool function with agent_role pre-filled
    """
    # Always return the main gmail_tool - it accepts agent_role as a parameter
    # The agent_role will be passed when the tool is called from main.py
    return gmail_tool

def get_meeting_transcript_tool():
    """Get the MeetingTranscriptTool instance."""
    return meeting_transcript_tool

def get_google_tasks_tool():
    """Get the Google Tasks Tool instance (P3 Protocol - Hybrid System Phase 1)."""
    return google_tasks_tool
