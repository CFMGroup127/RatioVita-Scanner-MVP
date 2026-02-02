"""
Direct verification of memory documents using known document IDs.
"""
import os

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

# Known memory document IDs from agents.yaml
MEMORY_DOCS = {
    "Alice Kim": "1flDFYht_YAdcVsTcInDdgV5KPZH1Hua6cGiVXMjwdKI",
    "Samuel Reed": "1qSLYiD280jK8-T1wn2RAIMle6Y8CeJ80I6ZYkPS9xXQ",
    "Arthur Jensen": "1I-9DE02e0ECkaa7WceP-93KG9NVfTKVUbpHhj8Ou5WQ",
    "Megan Parker": "1Gg6rP0bbtxj31snJgzAjcfFVJ-8GRVelMZ4Z7YOuQBc",
    "Ash Roy": "1tObaPs12zVYpUUMrsJMPN7JUqxUaR_MSvcxZ7D36tYs",
    "David Chen": "1oRSQMOvK2lfv3MhfLD-O0fMbAJE-JQmQ0dg8DqeO_XY",
    "Dana Flores": "17yHhn9sTmLTR7zUwX0s37khkv6cMPdHNXYBUNPVuQdo"
}

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
        
        full_text = '\n'.join(content) if content else "Document is empty."
        return full_text
    
    except HttpError as e:
        return f"Error: Google Docs API error - {str(e)}"
    except Exception as e:
        return f"Error reading document: {str(e)}"

def verify_memory_writes():
    """Verify that all agents wrote to their memory documents."""
    print("\n" + "="*80)
    print("🔍 DIRECT MEMORY DOCUMENT VERIFICATION")
    print("="*80)
    print("Checking memory documents for recent content from BLOCK P, Ash Roy, and Dana\n")
    
    # Check for recent content indicators
    recent_keywords = {
        "BLOCK P": ["market and competitive", "design token", "branding", "value proposition", "block p"],
        "Ash Roy": ["v2 technical baseline", "quarantine", "archived_v1", "dependencies", "baseline"],
        "Dana": ["coordination", "block p", "ash roy", "david chen", "workflow"]
    }
    
    results = {}
    
    for agent_name, doc_id in MEMORY_DOCS.items():
        print(f"📄 {agent_name}")
        print(f"   Doc ID: {doc_id}")
        print("-" * 80)
        
        content = read_memory_document(doc_id)
        
        if "Error" in content:
            print(f"   ❌ {content}\n")
            results[agent_name] = {"status": "error", "content": content}
        else:
            content_lower = content.lower()
            content_length = len(content)
            
            # Check for recent content
            found_keywords = []
            for category, keywords in recent_keywords.items():
                for keyword in keywords:
                    if keyword in content_lower:
                        found_keywords.append(f"{category}:{keyword}")
            
            # Show last 500 characters
            last_500 = content[-500:] if content_length > 500 else content
            
            if found_keywords:
                print(f"   ✅ Found recent content indicators: {', '.join(found_keywords[:5])}")
                print(f"   📊 Document length: {content_length} characters")
                print(f"   📝 Last 500 characters:")
                print(f"   {last_500}")
                results[agent_name] = {"status": "has_content", "length": content_length, "keywords": found_keywords}
            else:
                print(f"   ⚠️  No recent content indicators found")
                print(f"   📊 Document length: {content_length} characters")
                print(f"   📝 Last 500 characters:")
                print(f"   {last_500}")
                results[agent_name] = {"status": "no_recent_content", "length": content_length}
        
        print()
    
    # Summary
    print("="*80)
    print("📊 VERIFICATION SUMMARY")
    print("="*80)
    
    for agent_name, result in results.items():
        status = result.get("status", "unknown")
        if status == "has_content":
            print(f"✅ {agent_name}: Has recent content ({result.get('length', 0)} chars)")
        elif status == "no_recent_content":
            print(f"⚠️  {agent_name}: Document exists but no recent content indicators ({result.get('length', 0)} chars)")
        else:
            print(f"❌ {agent_name}: Error - {result.get('content', 'Unknown error')}")
    
    print("="*80)

if __name__ == "__main__":
    verify_memory_writes()



