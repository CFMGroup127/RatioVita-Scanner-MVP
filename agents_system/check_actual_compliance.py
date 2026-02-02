"""
Check Actual Compliance
Directly reads agent memory documents to verify what was actually created.
"""
import os
import sys
from datetime import datetime
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from main import load_agents_from_yaml, get_agent_metadata

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

def check_agent_memory(agent_role, agent_name, memory_doc_id):
    """Check what's actually in an agent's memory document"""
    results = {
        'agent': agent_name,
        'role': agent_role,
        'p8_log': False,
        'p5_notes': False,
        'transcript': False,
        'meeting_minutes': False,
        'content_preview': ''
    }
    
    try:
        creds = get_credentials()
        if not creds:
            results['content_preview'] = "❌ No credentials"
            return results
        
        docs_service = build('docs', 'v1', credentials=creds)
        
        # Get document
        doc = docs_service.documents().get(documentId=memory_doc_id).execute()
        content = extract_text_from_document(doc)
        results['content_preview'] = content[:500] + "..." if len(content) > 500 else content
        
        content_upper = content.upper()
        
        # Check for P8 log
        if 'RETROACTIVE P8' in content_upper or 'MEETING ACCEPTED' in content_upper or ('P8' in content_upper and 'MEETING' in content_upper):
            results['p8_log'] = True
        
        # Check for P5 notes / MEETING_MINUTES
        if 'MEETING MINUTES' in content_upper or ('MEETING' in content_upper and 'NOTES' in content_upper and 'NOVEMBER 20' in content_upper):
            results['p5_notes'] = True
            results['meeting_minutes'] = True
        
        # Check for transcript
        if 'TRANSCRIPT' in content_upper and 'NOVEMBER 20' in content_upper:
            results['transcript'] = True
        
    except Exception as e:
        results['content_preview'] = f"❌ Error: {str(e)}"
    
    return results

def check_all_agents():
    """Check all agents' memory documents"""
    print("🔍 CHECKING ACTUAL AGENT MEMORY DOCUMENTS")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
    
    agents = load_agents_from_yaml('agents.yaml')
    all_results = []
    
    for agent in agents:
        role = agent.role
        meta = get_agent_metadata(role)
        
        agent_name = meta.get('email_address', '').split('@')[0].replace('.', ' ').title()
        if not agent_name:
            agent_name = role.split()[0] if role else 'Unknown'
        
        memory_doc_id = meta.get('memory_doc_id', '')
        
        if not memory_doc_id:
            print(f"⚠️  {agent_name}: No memory_doc_id")
            continue
        
        print(f"🔍 Checking: {agent_name} ({role})")
        results = check_agent_memory(role, agent_name, memory_doc_id)
        all_results.append(results)
        
        # Print status
        status_p8 = "✅" if results['p8_log'] else "❌"
        status_p5 = "✅" if results['p5_notes'] else "❌"
        status_transcript = "✅" if results['transcript'] else "❌"
        
        print(f"   {status_p8} P8 Log: {results['p8_log']}")
        print(f"   {status_p5} P5 Notes/MEETING_MINUTES: {results['p5_notes']}")
        print(f"   {status_transcript} Transcript: {results['transcript']}")
        
        if not results['p8_log'] and not results['p5_notes']:
            print(f"   ⚠️  Content preview: {results['content_preview'][:100]}...")
        print()
    
    # Summary
    print("="*80)
    print("📊 ACTUAL COMPLIANCE SUMMARY")
    print("="*80)
    
    total = len(all_results)
    p8_count = sum(1 for r in all_results if r['p8_log'])
    p5_count = sum(1 for r in all_results if r['p5_notes'])
    transcript_count = sum(1 for r in all_results if r['transcript'])
    
    print(f"Total Agents Checked: {total}")
    print(f"P8 Logs Found: {p8_count}/{total} ({p5_count*100//total if total > 0 else 0}%)")
    print(f"P5 Notes/MEETING_MINUTES Found: {p5_count}/{total} ({p5_count*100//total if total > 0 else 0}%)")
    print(f"Transcripts Found: {transcript_count}/{total} ({transcript_count*100//total if total > 0 else 0}%)")
    
    if p8_count < total or p5_count < total:
        print("\n❌ ISSUE DETECTED:")
        print("   Some agents did not complete retroactive logging.")
        print("   The retroactive logging script may have failed or timed out.")
        print("\n💡 RECOMMENDATION:")
        print("   Re-run: python3 force_meeting_retroactive_logging.py")
        print("   Or check if agents encountered errors during execution.")
    
    return all_results

if __name__ == "__main__":
    results = check_all_agents()
    sys.exit(0 if all(r['p8_log'] and r['p5_notes'] for r in results) else 1)

