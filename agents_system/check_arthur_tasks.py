"""
Check Arthur Jensen's TASKS Section
Verifies that P3 protocol successfully logged task to memory document.
"""
import os
import sys
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
import yaml

SCOPES = ['https://www.googleapis.com/auth/documents.readonly']

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

def extract_text_from_document(doc):
    """Extract all text from a Google Doc"""
    text_content = []
    for element in doc.get('body', {}).get('content', []):
        if 'paragraph' in element:
            para = element['paragraph']
            if 'elements' in para:
                for elem in para['elements']:
                    if 'textRun' in elem:
                        text_content.append(elem['textRun'].get('content', ''))
    return ''.join(text_content)

def find_tasks_section(doc_content, date_subsection):
    """Find the TASKS section and specific date subsection"""
    lines = doc_content.split('\n')
    in_tasks_section = False
    in_date_subsection = False
    tasks_content = []
    
    for i, line in enumerate(lines):
        line_upper = line.upper()
        
        # Check for TASKS section header
        if '##' in line and 'TASKS' in line_upper:
            in_tasks_section = True
            in_date_subsection = False
            continue
        
        # Check if we've left TASKS section
        if in_tasks_section and '##' in line and 'TASKS' not in line_upper:
            break
        
        # Check for date subsection
        if in_tasks_section and '###' in line and date_subsection.upper() in line_upper:
            in_date_subsection = True
            continue
        
        # Check if we've left date subsection
        if in_date_subsection and '###' in line and date_subsection.upper() not in line_upper:
            break
        
        # Collect content from date subsection
        if in_date_subsection:
            tasks_content.append(line)
    
    return '\n'.join(tasks_content)

def check_arthur_tasks():
    """Check Arthur Jensen's TASKS section"""
    print("🔍 CHECKING ARTHUR JENSEN'S TASKS SECTION")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
    
    # Load agents.yaml to get Arthur's memory doc ID
    with open('agents.yaml', 'r') as f:
        data = yaml.safe_load(f)
    
    arthur_data = None
    for agent_data in data.get('agents', []):
        if "Legal Compliance" in agent_data.get('role', '') or "Risk Assessor" in agent_data.get('role', ''):
            arthur_data = agent_data
            break
    
    if not arthur_data:
        print("❌ Error: Arthur Jensen not found in agents.yaml")
        return False
    
    memory_doc_id = arthur_data.get('memory_doc_id', '')
    if not memory_doc_id:
        print("❌ Error: Arthur Jensen memory_doc_id not found")
        return False
    
    print(f"📄 Memory Doc ID: {memory_doc_id}")
    print(f"📅 Checking TASKS section for: November 21, 2025\n")
    
    # Get credentials
    creds = get_credentials()
    if not creds:
        print("❌ Error: Could not get credentials")
        return False
    
    # Get document
    try:
        service = build('docs', 'v1', credentials=creds)
        doc = service.documents().get(documentId=memory_doc_id).execute()
        
        # Extract full text
        full_text = extract_text_from_document(doc)
        
        # Find TASKS section for November 21, 2025
        tasks_content = find_tasks_section(full_text, 'November 21, 2025')
        
        print("="*80)
        print("📋 ARTHUR JENSEN'S TASKS SECTION (November 21, 2025)")
        print("="*80)
        
        if tasks_content.strip():
            print(tasks_content)
            print("\n" + "="*80)
            
            # Check for the specific task
            if "legal risk assessment" in tasks_content.lower():
                print("✅ SUCCESS: Task found in TASKS section!")
                print("   ✅ P3 PART A (Memory Document) is WORKING")
                return True
            else:
                print("⚠️  TASKS section exists but specific task not found")
                print("   Task should contain: 'legal risk assessment'")
                return False
        else:
            print("⚠️  TASKS section for November 21, 2025 is empty or not found")
            print("   This suggests P3 PART A may not have executed successfully")
            return False
            
    except Exception as e:
        print(f"❌ Error reading document: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    from datetime import datetime
    success = check_arthur_tasks()
    sys.exit(0 if success else 1)

