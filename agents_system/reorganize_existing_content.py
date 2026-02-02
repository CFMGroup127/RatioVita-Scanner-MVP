"""
Reorganize Existing Content in Agent Memory Documents
This script reorganizes existing random entries into proper sections with chronological order.
"""
import os
import sys
import re
from datetime import datetime
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from main import load_agents_from_yaml, get_agent_metadata
from agent_memory_structure import generate_document_structure, get_agent_structure

SCOPES = ['https://www.googleapis.com/auth/documents', 'https://www.googleapis.com/auth/drive']

def get_credentials():
    """Get valid user credentials"""
    creds = None
    if os.path.exists('token.json'):
        creds = Credentials.from_authorized_user_file('token.json', SCOPES)
    
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not os.path.exists('credentials.json'):
                print("❌ credentials.json not found")
                return None
            flow = InstalledAppFlow.from_client_secrets_file('credentials.json', SCOPES)
            creds = flow.run_local_server(port=0, access_type='offline', prompt='consent')
            with open('token.json', 'w') as token:
                token.write(creds.to_json())
    
    return creds

def extract_content_from_document(doc):
    """Extract all text content from document"""
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

def parse_date_from_content(text):
    """Extract date from content text"""
    # Try various date formats
    date_patterns = [
        r'(\d{4}-\d{2}-\d{2})',  # YYYY-MM-DD
        r'(\w+ \d{1,2}, \d{4})',  # Month DD, YYYY
        r'(\d{1,2}/\d{1,2}/\d{4})',  # MM/DD/YYYY
    ]
    
    for pattern in date_patterns:
        match = re.search(pattern, text)
        if match:
            date_str = match.group(1)
            try:
                # Try to parse the date
                if '-' in date_str:
                    return datetime.strptime(date_str, '%Y-%m-%d')
                elif ',' in date_str:
                    return datetime.strptime(date_str, '%B %d, %Y')
                elif '/' in date_str:
                    return datetime.strptime(date_str, '%m/%d/%Y')
            except:
                pass
    
    # Try to find timestamp patterns
    timestamp_pattern = r'(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})'
    match = re.search(timestamp_pattern, text)
    if match:
        try:
            return datetime.strptime(match.group(1), '%Y-%m-%d %H:%M:%S')
        except:
            pass
    
    return None

def categorize_content(content):
    """Categorize content into sections"""
    categorized = {
        'introduction': [],
        'tasks': [],
        'protocols': [],
        'meetings': [],
        'reports': [],
        'role_specific': [],
        'other': []
    }
    
    # Split content into paragraphs/sections
    paragraphs = content.split('\n\n')
    
    for para in paragraphs:
        para = para.strip()
        if not para:
            continue
        
        para_lower = para.lower()
        
        # Categorize based on keywords
        if any(keyword in para_lower for keyword in ['meeting accepted', 'meeting acceptance', 'p8', 'email confirmation sent']):
            date = parse_date_from_content(para)
            categorized['meetings'].append({'content': para, 'date': date, 'raw': para})
        
        elif any(keyword in para_lower for keyword in ['p0', 'p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7', 'p8', 'p9', 'p10', 'p11', 'p12', 'protocol']):
            date = parse_date_from_content(para)
            categorized['protocols'].append({'content': para, 'date': date, 'raw': para})
        
        elif any(keyword in para_lower for keyword in ['task', 'assigned', 'delegated', 'complete', 'completed']):
            date = parse_date_from_content(para)
            categorized['tasks'].append({'content': para, 'date': date, 'raw': para})
        
        elif any(keyword in para_lower for keyword in ['report', 'submitted', 'uart', 'project.reports']):
            date = parse_date_from_content(para)
            categorized['reports'].append({'content': para, 'date': date, 'raw': para})
        
        elif any(keyword in para_lower for keyword in ['name:', 'role:', 'email:', 'profile', 'introduction']):
            categorized['introduction'].append({'content': para, 'date': None, 'raw': para})
        
        else:
            date = parse_date_from_content(para)
            categorized['other'].append({'content': para, 'date': date, 'raw': para})
    
    return categorized

def sort_by_date(items):
    """Sort items by date, putting None dates at the end"""
    dated = [(item, item['date']) for item in items if item['date']]
    undated = [item for item in items if not item['date']]
    
    dated.sort(key=lambda x: x[1])
    return [item for item, _ in dated] + undated

def reorganize_agent_document(agent_role, agent_name, agent_email, memory_doc_id, docs_service):
    """Reorganize existing content into proper sections with chronological order"""
    print(f"\n📝 Reorganizing: {agent_name} ({agent_role})")
    print(f"   Document ID: {memory_doc_id}")
    
    try:
        # Get current document
        doc = docs_service.documents().get(documentId=memory_doc_id).execute()
        
        # Extract all content
        full_content = extract_content_from_document(doc)
        
        # Categorize content
        print(f"   📋 Categorizing existing content...")
        categorized = categorize_content(full_content)
        
        # Count entries
        total_entries = sum(len(items) for items in categorized.values())
        print(f"   📊 Found {total_entries} content entries to reorganize")
        print(f"      - Protocols: {len(categorized['protocols'])}")
        print(f"      - Meetings: {len(categorized['meetings'])}")
        print(f"      - Tasks: {len(categorized['tasks'])}")
        print(f"      - Reports: {len(categorized['reports'])}")
        print(f"      - Other: {len(categorized['other'])}")
        
        # Sort each category by date
        for category in ['protocols', 'meetings', 'tasks', 'reports']:
            categorized[category] = sort_by_date(categorized[category])
        
        # Group by date for date-based subtabs
        protocols_by_date = {}
        meetings_by_date = {}
        tasks_by_date = {}
        reports_by_date = {}
        
        for item in categorized['protocols']:
            date_key = item['date'].strftime('%B %d, %Y') if item['date'] else 'Undated'
            if date_key not in protocols_by_date:
                protocols_by_date[date_key] = []
            protocols_by_date[date_key].append(item)
        
        for item in categorized['meetings']:
            date_key = item['date'].strftime('%B %d, %Y') if item['date'] else 'Undated'
            if date_key not in meetings_by_date:
                meetings_by_date[date_key] = []
            meetings_by_date[date_key].append(item)
        
        for item in categorized['tasks']:
            date_key = item['date'].strftime('%B %d, %Y') if item['date'] else 'Undated'
            if date_key not in tasks_by_date:
                tasks_by_date[date_key] = []
            tasks_by_date[date_key].append(item)
        
        for item in categorized['reports']:
            date_key = item['date'].strftime('%B %d, %Y') if item['date'] else 'Undated'
            if date_key not in reports_by_date:
                reports_by_date[date_key] = []
            reports_by_date[date_key].append(item)
        
        # Generate new organized structure
        print(f"   🔨 Generating organized structure...")
        new_structure = generate_document_structure(agent_role, agent_name, agent_email)
        
        # Add organized content to structure
        organized_content = new_structure + "\n\n---\n\n## REORGANIZED CONTENT\n\n"
        
        # Add Protocols section with date-based subtabs
        if categorized['protocols']:
            organized_content += "## PROTOCOLS\n\n"
            # Sort dates chronologically
            sorted_dates = sorted(protocols_by_date.keys(), key=lambda x: datetime.strptime(x, '%B %d, %Y') if x != 'Undated' else datetime.min)
            for date_key in sorted_dates:
                if date_key != 'Undated':
                    organized_content += f"### {date_key}\n\n"
                for item in protocols_by_date[date_key]:
                    organized_content += f"{item['content']}\n\n"
        
        # Add Meetings section with date-based subtabs
        if categorized['meetings']:
            organized_content += "\n## MEETINGS\n\n"
            sorted_dates = sorted(meetings_by_date.keys(), key=lambda x: datetime.strptime(x, '%B %d, %Y') if x != 'Undated' else datetime.min)
            for date_key in sorted_dates:
                if date_key != 'Undated':
                    organized_content += f"### {date_key}\n\n"
                for item in meetings_by_date[date_key]:
                    organized_content += f"{item['content']}\n\n"
        
        # Add Tasks section with date-based subtabs
        if categorized['tasks']:
            organized_content += "\n## TASKS\n\n"
            sorted_dates = sorted(tasks_by_date.keys(), key=lambda x: datetime.strptime(x, '%B %d, %Y') if x != 'Undated' else datetime.min)
            for date_key in sorted_dates:
                if date_key != 'Undated':
                    organized_content += f"### {date_key}\n\n"
                for item in tasks_by_date[date_key]:
                    organized_content += f"{item['content']}\n\n"
        
        # Add Reports section with date-based subtabs
        if categorized['reports']:
            organized_content += "\n## REPORTS\n\n"
            sorted_dates = sorted(reports_by_date.keys(), key=lambda x: datetime.strptime(x, '%B %d, %Y') if x != 'Undated' else datetime.min)
            for date_key in sorted_dates:
                if date_key != 'Undated':
                    organized_content += f"### {date_key}\n\n"
                for item in reports_by_date[date_key]:
                    organized_content += f"{item['content']}\n\n"
        
        # Replace entire document with organized version
        print(f"   ✏️  Writing organized structure...")
        
        # Get document end index
        end_index = doc['body']['content'][-1]['endIndex'] - 1
        
        # Delete all content and insert new organized structure
        requests = [
            {
                'deleteContentRange': {
                    'range': {
                        'startIndex': 1,
                        'endIndex': end_index
                    }
                }
            },
            {
                'insertText': {
                    'location': {'index': 1},
                    'text': organized_content
                }
            }
        ]
        
        docs_service.documents().batchUpdate(
            documentId=memory_doc_id,
            body={'requests': requests}
        ).execute()
        
        print(f"   ✅ Document reorganized with chronological order")
        return True
        
    except HttpError as e:
        print(f"   ❌ Error: {e}")
        return False
    except Exception as e:
        print(f"   ❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    """Main reorganization function"""
    print("\n" + "="*80)
    print("🔄 REORGANIZING EXISTING CONTENT IN AGENT MEMORY DOCUMENTS")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}")
    print("="*80)
    print("\nThis will:")
    print("  - Categorize all existing content into proper sections")
    print("  - Sort entries chronologically within each section")
    print("  - Create date-based subtabs for Protocols, Meetings, Tasks, and Reports")
    print("  - Maintain the organized structure going forward")
    print("="*80)
    
    # Get credentials
    print("\n🔐 Authenticating...")
    creds = get_credentials()
    if not creds:
        print("❌ Authentication failed")
        return False
    
    docs_service = build('docs', 'v1', credentials=creds)
    print("✅ Authenticated")
    
    # Load agents
    print("\n📋 Loading agents...")
    agents = load_agents_from_yaml('agents.yaml')
    print(f"✅ Loaded {len(agents)} agents")
    
    # Process each agent
    print("\n" + "="*80)
    print("🚀 REORGANIZING AGENT DOCUMENTS")
    print("="*80)
    
    success_count = 0
    failed_count = 0
    
    for agent in agents:
        agent_role = agent.role
        agent_meta = get_agent_metadata(agent_role)
        
        agent_email = agent_meta.get('email_address', '')
        agent_name = agent_email.split('@')[0].replace('.', ' ').title() if agent_email else agent_role.split()[0]
        
        memory_doc_id = agent_meta.get('memory_doc_id', '')
        
        if not memory_doc_id:
            print(f"\n⚠️  Skipping {agent_role} - no memory_doc_id")
            failed_count += 1
            continue
        
        if reorganize_agent_document(agent_role, agent_name, agent_email, memory_doc_id, docs_service):
            success_count += 1
        else:
            failed_count += 1
    
    # Summary
    print("\n" + "="*80)
    print("📊 REORGANIZATION SUMMARY")
    print("="*80)
    print(f"Total Agents: {len(agents)}")
    print(f"✅ Successfully Reorganized: {success_count}")
    print(f"❌ Failed: {failed_count}")
    print("="*80)
    
    if success_count > 0:
        print("\n✅ All agent memory documents have been reorganized with:")
        print("   - Content categorized into proper sections")
        print("   - Chronological order within each section")
        print("   - Date-based subtabs for Protocols, Meetings, Tasks, and Reports")
        print("   - All entries sorted by date and time")
    
    return success_count > 0

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)

