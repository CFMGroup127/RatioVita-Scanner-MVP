"""Quick Meeting Status Check"""
from datetime import datetime
from main import get_agent_metadata
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
import os

now = datetime.now()
meeting_start = now.replace(hour=14, minute=30, second=0)
meeting_end = now.replace(hour=16, minute=30, second=0)

print("\n" + "="*80)
print("📊 MEETING STATUS")
print("="*80)
print(f"Current Time: {now.strftime('%B %d, %Y %I:%M:%S %p EST')}")
print(f"Meeting Time: 2:30 PM - 4:30 PM EST")
print("="*80)

if now < meeting_start:
    print("⏳ Status: NOT STARTED YET")
elif now >= meeting_start and now < meeting_end:
    elapsed = now - meeting_start
    remaining = meeting_end - now
    print(f"✅ Status: IN PROGRESS")
    print(f"   Elapsed: {int(elapsed.total_seconds()//60)} minutes")
    print(f"   Remaining: {int(remaining.total_seconds()//60)} minutes")
else:
    print("✅ Status: ENDED")

# Check transcript
print(f"\n📝 MEETING TRANSCRIPT:")
dana_meta = get_agent_metadata('Admin Assistant & Workflow Funnel')
transcript_id = dana_meta.get('meeting_transcript_doc_id', '')

if transcript_id:
    try:
        creds = None
        if os.path.exists('token.json'):
            try:
                creds = Credentials.from_authorized_user_file('token.json', ['https://www.googleapis.com/auth/documents.readonly'])
            except:
                try:
                    creds = Credentials.from_authorized_user_file('token.json', None)
                except:
                    pass
        
        if creds and not creds.valid and creds.expired and creds.refresh_token:
            try:
                creds.refresh(Request())
            except:
                pass
        
        if creds:
            docs_service = build('docs', 'v1', credentials=creds)
            doc = docs_service.documents().get(documentId=transcript_id).execute()
            content = ''
            if 'body' in doc and 'content' in doc['body']:
                for element in doc['body']['content']:
                    if 'paragraph' in element:
                        for para in element['paragraph'].get('elements', []):
                            if 'textRun' in para:
                                content += para['textRun'].get('content', '')
            
            if content.strip():
                print(f"   ✅ ACTIVE - {len(content)} characters")
                print(f"   Preview: {content[-200:].strip()}")
            else:
                print(f"   ❌ Empty or not accessible")
    except Exception as e:
        print(f"   ⚠️  Error checking: {e}")

print("\n" + "="*80)

