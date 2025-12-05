"""
Monitor Agent Activity and Progress
This script checks all agent memory documents and verifies artwork/color scheme copying from v1 to v2.
"""
import os
from datetime import datetime
from config import Config
from main import load_agents_from_yaml, get_agent_metadata
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
import json

# Scopes
SCOPES = [
    'https://www.googleapis.com/auth/documents.readonly',
    'https://www.googleapis.com/auth/drive.readonly'
]

def get_credentials():
    """Get valid user credentials from storage."""
    creds = None
    if os.path.exists('token.json'):
        creds = Credentials.from_authorized_user_file('token.json', SCOPES)
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file('credentials.json', SCOPES)
            creds = flow.run_local_server(port=0)
        with open('token.json', 'w') as token:
            token.write(creds.to_json())
    return creds

def read_google_doc(doc_id):
    """Read content from a Google Doc."""
    try:
        creds = get_credentials()
        service = build('docs', 'v1', credentials=creds)
        doc = service.documents().get(documentId=doc_id).execute()
        content = doc.get('body', {}).get('content', [])
        text_content = []
        for element in content:
            if 'paragraph' in element:
                para = element['paragraph']
                for text_elem in para.get('elements', []):
                    if 'textRun' in text_elem:
                        text_content.append(text_elem['textRun'].get('content', ''))
        return ''.join(text_content)
    except Exception as e:
        return f"Error reading document: {e}"

def monitor_agent_activity():
    """
    Monitor all agent activity and check if Alice copied artwork/color schemes.
    """
    print("\n" + "="*80)
    print("📊 AGENT ACTIVITY MONITORING & PROGRESS REPORT")
    print("="*80)
    print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}")
    print("="*80)
    
    # Validate configuration
    try:
        Config.validate()
        print("✅ Configuration validated")
    except ValueError as e:
        print(f"❌ Configuration Error: {e}")
        return None
    
    # Load agents
    print("\n📋 Loading agents...")
    try:
        agents = load_agents_from_yaml('agents.yaml')
        print(f"✅ Loaded {len(agents)} agents")
    except Exception as e:
        print(f"❌ Error loading agents: {e}")
        return None
    
    print("\n" + "="*80)
    print("🔍 CHECKING ALICE KIM: ARTWORK/COLOR SCHEME COPY STATUS")
    print("="*80)
    
    # Get Alice's metadata
    alice_meta = get_agent_metadata("Documentation and Knowledge Archivist")
    alice_doc_id = alice_meta.get('memory_doc_id', '')
    alice_email = alice_meta.get('email_address', 'alice.kim@ratiovita.com')
    
    if not alice_doc_id:
        print("❌ Alice Kim memory document ID not found")
    else:
        print(f"📄 Alice Kim Memory Document ID: {alice_doc_id}")
        print(f"📧 Email: {alice_email}")
        print("\nReading Alice's memory document...")
        
        alice_memory = read_google_doc(alice_doc_id)
        
        if "Error" in alice_memory:
            print(f"❌ {alice_memory}")
        else:
            print(f"✅ Memory document read successfully ({len(alice_memory)} characters)")
            
            # Search for artwork/color scheme references
            print("\n🔍 Searching for artwork/color scheme copying references...")
            print("-" * 80)
            
            keywords = ['artwork', 'color', 'scheme', 'palette', 'design asset', 'copy', 'copied', 
                       'v1', 'v2', 'legacy', 'asset', 'image', 'logo', 'brand', 'visual']
            
            found_references = []
            lines = alice_memory.split('\n')
            for i, line in enumerate(lines):
                line_lower = line.lower()
                if any(keyword in line_lower for keyword in keywords):
                    found_references.append((i+1, line.strip()[:150]))
            
            if found_references:
                print(f"✅ Found {len(found_references)} relevant references:")
                for line_num, line_content in found_references[:20]:  # Show first 20
                    print(f"  Line {line_num}: {line_content}")
                if len(found_references) > 20:
                    print(f"  ... and {len(found_references) - 20} more references")
            else:
                print("⚠️  No explicit artwork/color scheme copying references found")
            
            # Check for completion status
            print("\n📋 Checking completion status...")
            if 'complete' in alice_memory.lower() or 'verified' in alice_memory.lower():
                print("✅ Completion/verification markers found in memory")
            else:
                print("⚠️  No completion markers found")
            
            # Check for report submission
            if 'BLOCK A' in alice_memory or 'V1 Legacy Asset' in alice_memory:
                print("✅ BLOCK A report found in memory")
            else:
                print("⚠️  BLOCK A report not clearly identified")
    
    print("\n" + "="*80)
    print("📁 CHECKING FILE SYSTEM: V1 TO V2 ARTWORK COPY STATUS")
    print("="*80)
    
    # Check v1 folder for artwork
    v1_path = "/Users/colliemorris/Projects 2/RatioVita_v2/RatioVita_v1"
    v2_path = "/Users/colliemorris/Projects 2/RatioVita_v2"
    
    print(f"\n📂 V1 Path: {v1_path}")
    print(f"📂 V2 Path: {v2_path}")
    
    # Find artwork files in v1
    import subprocess
    try:
        v1_artwork = subprocess.check_output(
            ['find', v1_path, '-type', 'f', 
             '(', '-name', '*.png', '-o', '-name', '*.jpg', '-o', '-name', '*.jpeg', 
             '-o', '-name', '*.svg', '-o', '-name', '*.ico', '-o', '-name', '*.gif',
             '-o', '-name', '*color*', '-o', '-name', '*palette*', '-o', '-name', '*design*',
             '-o', '-name', '*asset*', '-o', '-name', '*logo*', '-o', '-name', '*brand*', ')'],
            stderr=subprocess.DEVNULL
        ).decode('utf-8').strip().split('\n')
        v1_artwork = [f for f in v1_artwork if f]
        
        print(f"\n📊 Found {len(v1_artwork)} potential artwork/design files in V1:")
        for f in v1_artwork[:10]:
            rel_path = f.replace(v1_path, 'V1')
            print(f"  - {rel_path}")
        if len(v1_artwork) > 10:
            print(f"  ... and {len(v1_artwork) - 10} more files")
    except Exception as e:
        print(f"⚠️  Error scanning V1: {e}")
        v1_artwork = []
    
    # Check if any were copied to v2
    print(f"\n🔍 Checking if artwork was copied to V2...")
    copied_count = 0
    for v1_file in v1_artwork[:20]:  # Check first 20
        filename = os.path.basename(v1_file)
        try:
            # Search for file in v2 (excluding v1 folder)
            result = subprocess.check_output(
                ['find', v2_path, '-name', filename, '-not', '-path', f'{v1_path}/*'],
                stderr=subprocess.DEVNULL
            ).decode('utf-8').strip()
            if result:
                copied_count += 1
                rel_path = result.replace(v2_path, 'V2')
                print(f"  ✅ Found in V2: {rel_path}")
        except:
            pass
    
    if copied_count > 0:
        print(f"\n✅ Found {copied_count} artwork files that appear to be copied to V2")
    else:
        print(f"\n⚠️  No artwork files found copied to V2 (checked {min(20, len(v1_artwork))} files)")
    
    print("\n" + "="*80)
    print("📊 ALL AGENT STATUS SUMMARY")
    print("="*80)
    
    # Check all agents' memory documents
    agent_status = {}
    for agent in agents:
        agent_meta = get_agent_metadata(agent.role)
        doc_id = agent_meta.get('memory_doc_id', '')
        email = agent_meta.get('email_address', '')
        
        if doc_id:
            try:
                memory = read_google_doc(doc_id)
                if "Error" not in memory:
                    # Check for activity indicators
                    has_content = len(memory.strip()) > 100
                    has_complete = 'complete' in memory.lower() or 'verified' in memory.lower()
                    has_timestamp = any(char.isdigit() for char in memory[-200:])
                    
                    agent_status[agent.role] = {
                        'email': email,
                        'has_content': has_content,
                        'has_complete': has_complete,
                        'has_timestamp': has_timestamp,
                        'content_length': len(memory)
                    }
                else:
                    agent_status[agent.role] = {'error': memory}
            except Exception as e:
                agent_status[agent.role] = {'error': str(e)}
        else:
            agent_status[agent.role] = {'error': 'No memory doc ID'}
    
    # Print summary
    print(f"\n{'Agent':<40} {'Status':<20} {'Content':<15}")
    print("-" * 80)
    for role, status in agent_status.items():
        if 'error' in status:
            print(f"{role[:38]:<40} {'❌ ERROR':<20} {status['error'][:13]}")
        else:
            status_icon = "✅" if status['has_content'] else "⚠️"
            complete_icon = "✓" if status['has_complete'] else "✗"
            print(f"{role[:38]:<40} {status_icon:<20} {status['content_length']} chars {complete_icon}")
    
    print("\n" + "="*80)
    print("✅ MONITORING COMPLETE")
    print("="*80)
    
    return {
        'alice_memory': alice_memory if 'alice_memory' in locals() else None,
        'v1_artwork_count': len(v1_artwork) if 'v1_artwork' in locals() else 0,
        'copied_count': copied_count,
        'agent_status': agent_status
    }

if __name__ == "__main__":
    monitor_agent_activity()


