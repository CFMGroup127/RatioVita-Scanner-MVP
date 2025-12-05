"""
Enhanced Google Docs Memory Tool
This enhanced version writes to specific sections/tabs instead of just appending to the end.
"""
import os
import json
from datetime import datetime
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

def find_section_index(doc, section_name, subsection_name=None):
    """
    Find the index of a section in the document.
    
    Args:
        doc: Google Docs document object
        section_name: Main section name (e.g., "TASKS", "MEETINGS")
        subsection_name: Optional subsection (e.g., date)
        
    Returns:
        Index where to insert content, or None if section not found
    """
    if 'body' not in doc or 'content' not in doc['body']:
        return None
    
    target_text = section_name.upper()
    subsection_text = subsection_name.upper() if subsection_name else None
    
    for i, element in enumerate(doc['body']['content']):
        if 'paragraph' in element:
            para = element['paragraph']
            if 'elements' in para:
                for elem in para['elements']:
                    if 'textRun' in elem:
                        text = elem['textRun'].get('content', '').upper()
                        
                        # Check for main section
                        if target_text in text and ('##' in text or '#' in text):
                            # If looking for subsection, continue searching
                            if subsection_text:
                                # Look ahead for subsection
                                for j in range(i+1, min(i+10, len(doc['body']['content']))):
                                    next_elem = doc['body']['content'][j]
                                    if 'paragraph' in next_elem:
                                        next_para = next_elem['paragraph']
                                        if 'elements' in next_para:
                                            for next_elem in next_para['elements']:
                                                if 'textRun' in next_elem:
                                                    next_text = next_elem['textRun'].get('content', '').upper()
                                                    if subsection_text in next_text:
                                                        return next_elem.get('endIndex', None)
                                # Subsection not found, return after main section
                                return element.get('endIndex', None)
                            else:
                                # Found main section, return index after it
                                return element.get('endIndex', None)
    
    return None

def enhanced_google_docs_memory_tool(
    doc_id: str,
    content: str,
    section: str = None,
    subsection: str = None,
    append: bool = True,
    template: str = None
) -> str:
    """
    Enhanced Google Docs Memory Tool that writes to specific sections.
    
    Args:
        doc_id: The Google Docs document ID
        content: The content to write
        section: Target section name (e.g., "TASKS", "MEETINGS", "PROTOCOLS")
        subsection: Optional subsection (e.g., date "2025-11-20")
        append: If True, append to section; if False, replace section
        template: Template name for formatting
        
    Returns:
        Success message or error message
    """
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
                    return "Error: credentials.json not found."
                flow = InstalledAppFlow.from_client_secrets_file('credentials.json', SCOPES)
                creds = flow.run_local_server(port=0)
                with open('token.json', 'w') as token:
                    token.write(creds.to_json())
        
        docs_service = build('docs', 'v1', credentials=creds)
        
        # Get document
        doc = docs_service.documents().get(documentId=doc_id).execute()
        
        # Format content based on template
        if template == "Task Tracker" and subsection:
            formatted_content = f"\n#### {subsection}\n**Date:** {datetime.now().strftime('%B %d, %Y')}\n\n{content}\n"
        elif template == "Meeting Notes":
            formatted_content = f"\n### {content.split(' - ')[0] if ' - ' in content else 'Meeting'}\n**Date:** {datetime.now().strftime('%B %d, %Y')}\n**Time:** {datetime.now().strftime('%I:%M %p EST')}\n\n{content}\n"
        elif template == "Compliance Log":
            formatted_content = f"\n**{datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}** - {content}\n"
        else:
            formatted_content = f"\n{content}\n"
        
        # Find insertion point
        if section:
            insert_index = find_section_index(doc, section, subsection)
            
            if insert_index:
                # Insert at specific section
                requests = [{
                    'insertText': {
                        'location': {'index': insert_index},
                        'text': formatted_content
                    }
                }]
            else:
                # Section not found, append to end (fallback)
                end_index = doc['body']['content'][-1]['endIndex'] - 1
                requests = [{
                    'insertText': {
                        'location': {'index': end_index},
                        'text': f"\n\n## {section.upper()}\n{formatted_content}"
                    }
                }]
        else:
            # No section specified, append to end (original behavior)
            end_index = doc['body']['content'][-1]['endIndex'] - 1
            requests = [{
                'insertText': {
                    'location': {'index': end_index},
                    'text': formatted_content
                }
            }]
        
        # Execute update
        docs_service.documents().batchUpdate(
            documentId=doc_id,
            body={'requests': requests}
        ).execute()
        
        location = f"section '{section}'" if section else "end of document"
        if subsection:
            location += f", subsection '{subsection}'"
        
        return f"SUCCESS: Content written to {location} in Google Doc (ID: {doc_id})."
    
    except HttpError as e:
        error_details = json.loads(e.content.decode('utf-8'))
        error_message = error_details.get('error', {}).get('message', str(e))
        return f"Error: Google Docs API error - {error_message}"
    except Exception as e:
        return f"Error: Failed to update Google Doc - {str(e)}"

# Example usage functions for agents
def write_task(doc_id: str, task_content: str, date: str = None):
    """Write a task to the Tasks section"""
    if not date:
        date = datetime.now().strftime('%B %d, %Y')
    return enhanced_google_docs_memory_tool(
        doc_id=doc_id,
        content=task_content,
        section="TASKS",
        subsection=date,
        template="Task Tracker"
    )

def write_meeting_note(doc_id: str, meeting_content: str):
    """Write a meeting note to the Meetings section"""
    return enhanced_google_docs_memory_tool(
        doc_id=doc_id,
        content=meeting_content,
        section="MEETINGS",
        template="Meeting Notes"
    )

def write_protocol_log(doc_id: str, protocol_content: str):
    """Write a protocol compliance entry"""
    return enhanced_google_docs_memory_tool(
        doc_id=doc_id,
        content=protocol_content,
        section="PROTOCOLS",
        template="Compliance Log"
    )

if __name__ == "__main__":
    print("Enhanced Google Docs Memory Tool")
    print("="*80)
    print("\nThis tool allows writing to specific sections/tabs in memory documents.")
    print("\nUsage examples:")
    print("  - write_task(doc_id, 'Complete report', 'November 20, 2025')")
    print("  - write_meeting_note(doc_id, 'Meeting acceptance logged')")
    print("  - write_protocol_log(doc_id, 'P8: Meeting accepted')")

