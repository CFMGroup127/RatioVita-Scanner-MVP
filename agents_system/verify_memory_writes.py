"""
Verify that agents actually wrote to their memory documents.
This script reads the memory documents directly to check for recent content.
"""
import os
from config import Config
from main import get_agent_metadata

# Google Docs API imports
try:
    from google.oauth2.credentials import Credentials
    from google_auth_oauthlib.flow import InstalledAppFlow
    from google.auth.transport.requests import Request
    from googleapiclient.discovery import build
    from googleapiclient.errors import HttpError
    GOOGLE_DOCS_AVAILABLE = True
except ImportError:
    GOOGLE_DOCS_AVAILABLE = False
    print("❌ Google Docs API not available")

def read_memory_document(doc_id):
    """Read a memory document and return its content."""
    if not GOOGLE_DOCS_AVAILABLE:
        return "Error: Google Docs API not available"
    
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
                return "Error: Need to authenticate"
        
        # Build service
        service = build('docs', 'v1', credentials=creds)
        
        # Get document
        doc = service.documents().get(documentId=doc_id).execute()
        
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
    
    except Exception as e:
        return f"Error reading document: {str(e)}"

def verify_memory_writes():
    """Verify that all agents wrote to their memory documents."""
    print("\n" + "="*80)
    print("🔍 VERIFYING MEMORY DOCUMENT WRITES")
    print("="*80)
    
    # Get memory document IDs for key agents
    agents_to_check = {
        "Alice Kim": "Documentation and Knowledge Archivist",
        "Samuel Reed": "Competitive Intelligence Specialist",
        "Arthur Jensen": "Legal Compliance and Risk Assessor",
        "Megan Parker": "Market Strategist and Voice of the Customer",
        "Ash Roy": "Technical and Product Visionary",
        "David Chen": "Process Architect and Schedule Publisher",
        "Dana Flores": "Admin Assistant & Workflow Funnel"
    }
    
    print("\n📋 Checking memory documents for recent content...\n")
    
    for agent_name, role in agents_to_check.items():
        try:
            metadata = get_agent_metadata(role)
            memory_id = metadata.get('memory_doc_id', '')
            
            if not memory_id:
                print(f"❌ {agent_name}: No memory_doc_id found")
                continue
            
            print(f"📄 {agent_name} (ID: {memory_id[:20]}...)")
            print("-" * 80)
            
            content = read_memory_document(memory_id)
            
            if "Error" in content:
                print(f"   ❌ {content}")
            else:
                # Check for recent content indicators
                content_lower = content.lower()
                recent_indicators = [
                    'block p', 'market and competitive', 'design token', 'branding',
                    'v2 technical baseline', 'quarantine', 'coordination',
                    '2025-11-15', 'november 15', 'completed', 'status'
                ]
                
                found_indicators = [ind for ind in recent_indicators if ind in content_lower]
                
                if found_indicators:
                    print(f"   ✅ Document contains recent content indicators: {', '.join(found_indicators[:3])}")
                    # Show last 200 characters
                    last_chars = content[-200:] if len(content) > 200 else content
                    print(f"   📝 Last 200 chars: ...{last_chars}")
                else:
                    print(f"   ⚠️  No recent content indicators found")
                    # Show last 200 characters anyway
                    last_chars = content[-200:] if len(content) > 200 else content
                    print(f"   📝 Last 200 chars: ...{last_chars}")
            
            print()
        
        except Exception as e:
            print(f"❌ {agent_name}: Error checking - {str(e)}\n")
    
    print("="*80)

if __name__ == "__main__":
    verify_memory_writes()



