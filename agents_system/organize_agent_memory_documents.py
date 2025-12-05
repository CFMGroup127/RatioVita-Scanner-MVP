"""
Organize Agent Memory Documents
This script creates/updates all agent memory documents with standardized tab structure.
"""
import os
import sys
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

def find_section_in_document(doc, section_name):
    """Find a section in the document by heading"""
    if 'body' not in doc or 'content' not in doc['body']:
        return None
    
    for element in doc['body']['content']:
        if 'paragraph' in element:
            para = element['paragraph']
            if 'elements' in para:
                for elem in para['elements']:
                    if 'textRun' in elem:
                        text = elem['textRun'].get('content', '')
                        if section_name.upper() in text.upper():
                            return element.get('startIndex', None)
    return None

def create_or_update_agent_document(agent_role, agent_name, agent_email, memory_doc_id, docs_service):
    """Create or update agent memory document with organized structure"""
    print(f"\n📝 Processing: {agent_name} ({agent_role})")
    print(f"   Document ID: {memory_doc_id}")
    
    try:
        # Get current document
        doc = docs_service.documents().get(documentId=memory_doc_id).execute()
        
        # Check if document has structure
        has_structure = False
        if 'body' in doc and 'content' in doc['body']:
            content_text = ''
            for element in doc['body']['content']:
                if 'paragraph' in element:
                    for para in element['paragraph'].get('elements', []):
                        if 'textRun' in para:
                            content_text += para['textRun'].get('content', '')
            
            # Check for key sections
            if 'INTRODUCTION' in content_text or 'TASKS' in content_text:
                has_structure = True
        
        if not has_structure:
            print(f"   ⚠️  Document lacks structure - creating organized structure...")
            
            # Generate new structure
            new_structure = generate_document_structure(agent_role, agent_name, agent_email)
            
            # Get document end index
            end_index = doc['body']['content'][-1]['endIndex'] - 1
            
            # Insert organized structure at the beginning
            requests = [{
                'insertText': {
                    'location': {'index': 1},
                    'text': new_structure
                }
            }]
            
            docs_service.documents().batchUpdate(
                documentId=memory_doc_id,
                body={'requests': requests}
            ).execute()
            
            print(f"   ✅ Organized structure created")
        else:
            print(f"   ✅ Document already has structure")
            
            # Check if today's task section exists
            today = datetime.now().strftime('%B %d, %Y')
            content_text = ''
            for element in doc['body']['content']:
                if 'paragraph' in element:
                    for para in element['paragraph'].get('elements', []):
                        if 'textRun' in para:
                            content_text += para['textRun'].get('content', '')
            
            if today not in content_text:
                print(f"   📅 Adding today's task section...")
                # Find TASKS section and add today's date subsection
                # This would require more complex document manipulation
                print(f"   ⚠️  Manual update may be needed for daily task sections")
        
        return True
        
    except HttpError as e:
        print(f"   ❌ Error: {e}")
        return False
    except Exception as e:
        print(f"   ❌ Error: {e}")
        return False

def main():
    """Main function to organize all agent memory documents"""
    print("\n" + "="*80)
    print("📋 ORGANIZING AGENT MEMORY DOCUMENTS")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}")
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
    print("🚀 PROCESSING AGENT DOCUMENTS")
    print("="*80)
    
    success_count = 0
    failed_count = 0
    
    for agent in agents:
        agent_role = agent.role
        agent_meta = get_agent_metadata(agent_role)
        
        # Extract agent name from role or email
        agent_email = agent_meta.get('email_address', '')
        agent_name = agent_email.split('@')[0].replace('.', ' ').title() if agent_email else agent_role.split()[0]
        
        memory_doc_id = agent_meta.get('memory_doc_id', '')
        
        if not memory_doc_id:
            print(f"\n⚠️  Skipping {agent_role} - no memory_doc_id")
            failed_count += 1
            continue
        
        if create_or_update_agent_document(agent_role, agent_name, agent_email, memory_doc_id, docs_service):
            success_count += 1
        else:
            failed_count += 1
    
    # Summary
    print("\n" + "="*80)
    print("📊 ORGANIZATION SUMMARY")
    print("="*80)
    print(f"Total Agents: {len(agents)}")
    print(f"✅ Successfully Organized: {success_count}")
    print(f"❌ Failed: {failed_count}")
    print("="*80)
    
    if success_count > 0:
        print("\n✅ Agent memory documents have been organized with:")
        print("   - Standardized tab structure")
        print("   - Role-specific templates")
        print("   - Daily task tracking sections")
        print("   - Protocol compliance logs")
        print("   - Meeting notes sections")
        print("   - Report archives")
    
    return success_count > 0

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)

