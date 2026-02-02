"""
Sort Memory Documents by Timestamp
Re-sorts all dated subsections in agent memory documents to ensure chronological order.
This fixes any existing chronological issues and ensures perfect timestamp ordering.
"""
import os
import sys
import re
from datetime import datetime
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from main import load_agents_from_yaml, get_agent_metadata
import re
from tools import sort_subsection_content_by_timestamp, extract_timestamp_from_entry

SCOPES = ['https://www.googleapis.com/auth/documents']

def get_credentials():
    """Get valid user credentials"""
    creds = None
    if os.path.exists('token.json'):
        try:
            creds = Credentials.from_authorized_user_file('token.json', SCOPES)
        except:
            try:
                creds = Credentials.from_authorized_user_file('token.json', None)
                if creds.scopes:
                    has_docs = any('documents' in s for s in creds.scopes)
                    if not has_docs:
                        return None
            except:
                return None
    
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            try:
                creds.refresh(Request())
            except:
                return None
    
    return creds

def extract_text_from_document(doc):
    """Extract all text content from a Google Docs document"""
    content = ''
    if 'body' in doc and 'content' in doc['body']:
        for element in doc['body']['content']:
            if 'paragraph' in element:
                para = element['paragraph']
                if 'elements' in para:
                    for elem in para['elements']:
                        if 'textRun' in elem:
                            content += elem['textRun'].get('content', '')
    return content

def find_subsection_bounds(doc, section_name, subsection_name):
    """Find the start and end indices of a subsection"""
    section_upper = section_name.upper()
    subsection_upper = subsection_name.upper() if subsection_name else None
    
    subsection_start = None
    subsection_end = None
    
    for i, element in enumerate(doc['body']['content']):
        if 'paragraph' in element:
            para = element['paragraph']
            if 'elements' in para:
                for elem in para['elements']:
                    if 'textRun' in elem:
                        text = elem['textRun'].get('content', '').upper()
                        
                        # Find section
                        if section_upper in text and ('##' in text or '#' in text):
                            # Found section, look for subsection
                            if subsection_upper:
                                for j in range(i + 1, min(i + 100, len(doc['body']['content']))):
                                    next_elem = doc['body']['content'][j]
                                    if 'paragraph' in next_elem:
                                        next_para = next_elem['paragraph']
                                        if 'elements' in next_para:
                                            for next_elem in next_para['elements']:
                                                if 'textRun' in next_elem:
                                                    next_text = next_elem['textRun'].get('content', '').upper()
                                                    if subsection_upper in next_text and '###' in next_text:
                                                        subsection_start = next_elem.get('startIndex', None)
                                                        # Find end of subsection
                                                        for k in range(j + 1, min(j + 200, len(doc['body']['content']))):
                                                            check_elem = doc['body']['content'][k]
                                                            if 'paragraph' in check_elem:
                                                                check_para = check_elem['paragraph']
                                                                if 'elements' in check_para:
                                                                    for check_elem in check_para['elements']:
                                                                        if 'textRun' in check_elem:
                                                                            check_text = check_elem['textRun'].get('content', '').upper()
                                                                            if ('###' in check_text and subsection_upper not in check_text) or ('##' in check_text and section_upper not in check_text):
                                                                                subsection_end = check_elem.get('startIndex', None)
                                                                                return subsection_start, subsection_end
                                                        # If no end found, use end of document
                                                        subsection_end = doc['body']['content'][-1]['endIndex'] - 1
                                                        return subsection_start, subsection_end
                            break
    
    return subsection_start, subsection_end

def sort_agent_subsection(agent_name, memory_doc_id, section_name, subsection_name, docs_service):
    """Sort a specific subsection for an agent"""
    try:
        # Get document
        doc = docs_service.documents().get(documentId=memory_doc_id).execute()
        
        # Find subsection bounds
        subsection_start, subsection_end = find_subsection_bounds(doc, section_name, subsection_name)
        
        if not subsection_start or not subsection_end:
            return {'status': 'not_found', 'message': f'Subsection not found: {section_name}/{subsection_name}'}
        
        # Extract subsection content
        subsection_content = ""
        for element in doc['body']['content']:
            if 'paragraph' in element:
                para = element['paragraph']
                if 'elements' in para:
                    for elem in para['elements']:
                        if 'textRun' in elem:
                            elem_start = elem.get('startIndex', 0)
                            elem_end = elem.get('endIndex', 0)
                            if subsection_start <= elem_start < subsection_end:
                                subsection_content += elem['textRun'].get('content', '')
        
        # Remove subsection header from content
        lines = subsection_content.split('\n')
        content_lines = []
        skip_header = True
        for line in lines:
            if skip_header and (subsection_name.upper() in line.upper() or '###' in line):
                skip_header = False
                continue
            if not skip_header:
                content_lines.append(line)
        
        existing_content = '\n'.join(content_lines).strip()
        
        # Sort the content (pass empty new entry since we're just sorting existing)
        sorted_content = sort_subsection_content_by_timestamp(existing_content, "")
        
        if sorted_content == existing_content:
            return {'status': 'no_change', 'message': 'Content already sorted'}
        
        # Replace subsection content
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
                    'text': f"### {subsection_name}\n\n{sorted_content}\n\n"
                }
            }
        ]
        
        docs_service.documents().batchUpdate(documentId=memory_doc_id, body={'requests': requests}).execute()
        
        return {'status': 'success', 'message': f'Sorted {section_name}/{subsection_name}'}
        
    except Exception as e:
        return {'status': 'error', 'message': str(e)}

def sort_all_agent_documents():
    """Sort all dated subsections in all agent memory documents"""
    print("🔄 SORTING MEMORY DOCUMENTS BY TIMESTAMP")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
    
    creds = get_credentials()
    if not creds:
        print("❌ Error: Could not get credentials")
        return False
    
    docs_service = build('docs', 'v1', credentials=creds)
    agents = load_agents_from_yaml('agents.yaml')
    
    # Sections that should be sorted by timestamp
    sortable_sections = ['PROTOCOLS', 'MEETINGS', 'TRANSCRIPTS', 'REPORTS']
    
    # Get today's date for subsection
    today = datetime.now().strftime('%B %d, %Y')
    
    results = []
    
    for agent in agents:
        role = agent.role
        meta = get_agent_metadata(role)
        
        agent_name = meta.get('email_address', '').split('@')[0].replace('.', ' ').title()
        if not agent_name:
            agent_name = role.split()[0] if role else 'Unknown'
        
        memory_doc_id = meta.get('memory_doc_id', '')
        
        if not memory_doc_id:
            print(f"⚠️  Skipping {agent_name}: No memory_doc_id")
            continue
        
        print(f"🔄 Sorting: {agent_name} ({role})")
        
        for section in sortable_sections:
            result = sort_agent_subsection(agent_name, memory_doc_id, section, today, docs_service)
            if result['status'] == 'success':
                print(f"   ✅ {section}/{today}: Sorted")
            elif result['status'] == 'no_change':
                print(f"   ✓ {section}/{today}: Already sorted")
            elif result['status'] == 'not_found':
                print(f"   ⚠️  {section}/{today}: Subsection not found (may not exist yet)")
            else:
                print(f"   ❌ {section}/{today}: {result['message']}")
        
        results.append({'agent': agent_name, 'status': 'processed'})
        print()
    
    print("="*80)
    print("✅ TIMESTAMP SORTING COMPLETE")
    print("="*80)
    print(f"Total Agents Processed: {len(results)}")
    
    return True

if __name__ == "__main__":
    success = sort_all_agent_documents()
    sys.exit(0 if success else 1)

