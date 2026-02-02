"""
De-duplicate Memory Documents
Removes redundant meeting minutes and transcripts from agent memory documents.
This fixes the bloat issue caused by multiple runs of retroactive logging.
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
                    creds = creds.with_scopes(SCOPES)
            except:
                pass
    
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            try:
                creds.refresh(Request())
            except:
                return None
        else:
            return None
    
    return creds

def find_subsection_bounds(doc, section_name, subsection_name):
    """Find the start and end indices of a subsection"""
    subsection_start = None
    subsection_end = None
    section_upper = section_name.upper()
    subsection_upper = subsection_name.upper()
    
    for i, element in enumerate(doc['body']['content']):
        if 'paragraph' in element:
            para = element['paragraph']
            if 'elements' in para:
                for elem in para['elements']:
                    if 'textRun' in elem:
                        text = elem['textRun'].get('content', '').upper()
                        # Check for section header
                        if section_upper in text and '##' in text and '###' not in text:
                            # Found section, now look for subsection
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
                                                    if not subsection_end:
                                                        subsection_end = doc['body']['content'][-1]['endIndex'] - 1
                                                    return subsection_start, subsection_end
                            break
    
    return subsection_start, subsection_end

def deduplicate_subsection(agent_name, memory_doc_id, section_name, subsection_name, docs_service):
    """Remove duplicate content from a subsection"""
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
        
        # De-duplicate: Split by major blocks (MEETING MINUTES, MEETING TRANSCRIPT, etc.)
        # Look for repeated patterns
        deduplicated = existing_content  # Default: no changes
        
        if section_name.upper() == 'MEETINGS':
            # Look for duplicate MEETING MINUTES blocks
            minutes_pattern = r'(MEETING MINUTES:.*?)(?=MEETING MINUTES:|$)'
            matches = re.findall(minutes_pattern, existing_content, re.DOTALL)
            if len(matches) > 1:
                # Keep only the first (most recent) one
                deduplicated = matches[0]
                # Add any non-duplicate content before the first match
                first_match_pos = existing_content.find(matches[0])
                if first_match_pos > 0:
                    deduplicated = existing_content[:first_match_pos] + deduplicated
        elif section_name.upper() == 'TRANSCRIPTS':
            # Look for duplicate MEETING TRANSCRIPT blocks
            transcript_pattern = r'(MEETING TRANSCRIPT ARCHIVE.*?)(?=MEETING TRANSCRIPT ARCHIVE|$)'
            matches = re.findall(transcript_pattern, existing_content, re.DOTALL)
            if len(matches) > 1:
                # Keep only the first one
                deduplicated = matches[0]
                first_match_pos = existing_content.find(matches[0])
                if first_match_pos > 0:
                    deduplicated = existing_content[:first_match_pos] + deduplicated
        else:
            # For other sections, use simple line-based deduplication
            lines = existing_content.split('\n')
            seen = set()
            deduplicated_lines = []
            for line in lines:
                line_stripped = line.strip()
                # Skip empty lines and very short lines
                if not line_stripped or len(line_stripped) < 10:
                    deduplicated_lines.append(line)
                    continue
                # Create a signature for the line (first 50 chars)
                signature = line_stripped[:50]
                if signature not in seen:
                    seen.add(signature)
                    deduplicated_lines.append(line)
                # If we see a duplicate, check if it's part of a larger block
                elif line_stripped.startswith('**') or line_stripped.startswith('#'):
                    # Headers are okay to repeat
                    deduplicated_lines.append(line)
            
            deduplicated = '\n'.join(deduplicated_lines)
        
        # Check if deduplication made a change
        if deduplicated.strip() == existing_content.strip():
            return {'status': 'no_change', 'message': 'No duplicates found'}
        
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
                    'text': f"### {subsection_name}\n\n{deduplicated.strip()}\n\n"
                }
            }
        ]
        
        docs_service.documents().batchUpdate(documentId=memory_doc_id, body={'requests': requests}).execute()
        
        original_length = len(existing_content)
        new_length = len(deduplicated)
        reduction = original_length - new_length
        
        return {
            'status': 'success',
            'message': f'Deduplicated {section_name}/{subsection_name}',
            'reduction': reduction,
            'original_length': original_length,
            'new_length': new_length
        }
        
    except Exception as e:
        return {'status': 'error', 'message': str(e)}

def deduplicate_all_agent_documents():
    """De-duplicate all dated subsections in all agent memory documents"""
    print("🔄 DE-DUPLICATING MEMORY DOCUMENTS")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
    
    creds = get_credentials()
    if not creds:
        print("❌ Error: Could not get credentials")
        return False
    
    docs_service = build('docs', 'v1', credentials=creds)
    agents = load_agents_from_yaml('agents.yaml')
    
    # Sections that might have duplicates
    deduplicate_sections = ['MEETINGS', 'TRANSCRIPTS', 'PROTOCOLS', 'REPORTS']
    
    # Get today's date for subsection
    today = datetime.now().strftime('%B %d, %Y')
    
    total_reduction = 0
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
        
        print(f"🔄 De-duplicating: {agent_name} ({role})")
        
        for section in deduplicate_sections:
            result = deduplicate_subsection(agent_name, memory_doc_id, section, today, docs_service)
            if result['status'] == 'success':
                reduction = result.get('reduction', 0)
                total_reduction += reduction
                print(f"   ✅ {section}/{today}: Removed {reduction} characters")
            elif result['status'] == 'no_change':
                print(f"   ✓ {section}/{today}: No duplicates found")
            elif result['status'] == 'not_found':
                print(f"   ⚠️  {section}/{today}: Subsection not found")
            else:
                print(f"   ❌ {section}/{today}: {result['message']}")
        
        results.append({'agent': agent_name, 'status': 'processed'})
        print()
    
    print("="*80)
    print("✅ DE-DUPLICATION COMPLETE")
    print("="*80)
    print(f"Total Reduction: {total_reduction} characters removed")
    print(f"Total Agents Processed: {len(results)}")
    
    return True

if __name__ == "__main__":
    success = deduplicate_all_agent_documents()
    sys.exit(0 if success else 1)

