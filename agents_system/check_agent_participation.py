"""
Check Agent Participation in Meeting
This script checks if agents are actively participating by:
1. Checking meeting transcript for agent contributions
2. Checking agent memory documents for P5 protocol (active note-taking)
3. Checking for recent meeting-related activity
"""
import os
from datetime import datetime, timedelta
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from main import load_agents_from_yaml, get_agent_metadata

def get_credentials():
    """Get credentials"""
    creds = None
    if os.path.exists('token.json'):
        try:
            creds = Credentials.from_authorized_user_file('token.json', [
                'https://www.googleapis.com/auth/documents.readonly'
            ])
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
    
    return creds

def check_transcript_for_agents(transcript_id):
    """Check meeting transcript for agent names/contributions"""
    creds = get_credentials()
    if not creds:
        return {'error': 'No credentials'}
    
    try:
        docs_service = build('docs', 'v1', credentials=creds)
        doc = docs_service.documents().get(documentId=transcript_id).execute()
        
        content = ''
        if 'body' in doc and 'content' in doc['body']:
            for element in doc['body']['content']:
                if 'paragraph' in element:
                    for para in element['paragraph'].get('elements', []):
                        if 'textRun' in para:
                            content += para['textRun'].get('content', '')
        
        # Agent names to look for
        agent_names = [
            'Dana', 'Kyle', 'David', 'Ash', 'Sophia', 'Megan', 'Arthur',
            'Ethan', 'Chloe', 'Samuel', 'Alice', 'Victor', 'Jennifer',
            'Tyler', 'Rachel'
        ]
        
        found_agents = []
        for name in agent_names:
            if name.lower() in content.lower():
                found_agents.append(name)
        
        return {
            'content_length': len(content),
            'agents_mentioned': found_agents,
            'full_content': content
        }
    except Exception as e:
        return {'error': str(e)}

def check_agent_memory_for_p5(memory_doc_id, agent_name):
    """Check agent memory for P5 protocol (active note-taking)"""
    if not memory_doc_id:
        return {'found': False, 'error': 'No memory doc ID'}
    
    creds = get_credentials()
    if not creds:
        return {'found': False, 'error': 'No credentials'}
    
    try:
        docs_service = build('docs', 'v1', credentials=creds)
        doc = docs_service.documents().get(documentId=memory_doc_id).execute()
        
        content = ''
        if 'body' in doc and 'content' in doc['body']:
            for element in doc['body']['content']:
                if 'paragraph' in element:
                    for para in element['paragraph'].get('elements', []):
                        if 'textRun' in para:
                            content += para['textRun'].get('content', '')
        
        # Check for P5 indicators (meeting notes, decisions, assignments)
        p5_indicators = [
            'meeting note',
            'meeting decision',
            'action item',
            'assigned',
            'discussed',
            'agreed',
            'decided',
            'P5',
            'note-taking',
            'during meeting'
        ]
        
        # Check for today's date in content (recent activity)
        today_str = datetime.now().strftime('%B %d, %Y')
        today_str_alt = datetime.now().strftime('%Y-%m-%d')
        has_today = today_str in content or today_str_alt in content
        
        # Check for meeting-related content from today
        meeting_keywords = [
            'executive strategy',
            'V1 legacy',
            'V2 planning',
            'meeting',
            'discussion'
        ]
        
        has_meeting_content = any(keyword.lower() in content.lower() for keyword in meeting_keywords)
        has_p5_activity = any(indicator.lower() in content.lower() for indicator in p5_indicators)
        
        # Get last 500 chars to see recent activity
        recent_content = content[-500:] if len(content) > 500 else content
        
        return {
            'found': has_p5_activity or (has_today and has_meeting_content),
            'has_p5_indicators': has_p5_activity,
            'has_today': has_today,
            'has_meeting_content': has_meeting_content,
            'recent_content': recent_content
        }
    except Exception as e:
        return {'found': False, 'error': str(e)}

def main():
    """Main function"""
    print("\n" + "="*80)
    print("👥 AGENT PARTICIPATION CHECK")
    print("="*80)
    print(f"Meeting: Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning")
    print(f"Date: {datetime.now().strftime('%B %d, %Y')}")
    print(f"Time: 2:30 PM - 4:30 PM EST")
    print(f"Current Time: {datetime.now().strftime('%I:%M:%S %p EST')}")
    print("="*80)
    
    # Check transcript
    print("\n📝 CHECKING MEETING TRANSCRIPT...")
    dana_meta = get_agent_metadata('Admin Assistant & Workflow Funnel')
    transcript_id = dana_meta.get('meeting_transcript_doc_id', '')
    
    if transcript_id:
        transcript_status = check_transcript_for_agents(transcript_id)
        if 'error' in transcript_status:
            print(f"   ❌ Error: {transcript_status['error']}")
        else:
            print(f"   ✅ Transcript has {transcript_status['content_length']} characters")
            if transcript_status['agents_mentioned']:
                print(f"   👥 Agents mentioned in transcript: {', '.join(transcript_status['agents_mentioned'])}")
            else:
                print(f"   ⚠️  No agent names found in transcript")
    
    # Check agent memory documents for P5 activity
    print(f"\n📋 CHECKING AGENT MEMORY DOCUMENTS FOR P5 ACTIVITY...")
    print("="*80)
    
    agents = load_agents_from_yaml('agents.yaml')
    participating_agents = []
    not_participating = []
    
    for agent in agents:
        agent_role = agent.role
        agent_meta = get_agent_metadata(agent_role)
        memory_doc_id = agent_meta.get('memory_doc_id', '')
        agent_name = agent_role.split()[0] if agent_role else 'Unknown'
        
        if not memory_doc_id:
            not_participating.append({'agent': agent_role, 'reason': 'No memory doc ID'})
            continue
        
        memory_status = check_agent_memory_for_p5(memory_doc_id, agent_name)
        
        if memory_status.get('found', False):
            participating_agents.append({
                'agent': agent_role,
                'has_p5': memory_status.get('has_p5_indicators', False),
                'has_today': memory_status.get('has_today', False),
                'has_meeting_content': memory_status.get('has_meeting_content', False)
            })
            status = "✅ PARTICIPATING"
            indicators = []
            if memory_status.get('has_p5_indicators'):
                indicators.append("P5 notes")
            if memory_status.get('has_today'):
                indicators.append("today's date")
            if memory_status.get('has_meeting_content'):
                indicators.append("meeting content")
            print(f"{status} {agent_role[:50]}")
            print(f"   Indicators: {', '.join(indicators)}")
        else:
            not_participating.append({
                'agent': agent_role,
                'reason': 'No P5 activity found',
                'error': memory_status.get('error', '')
            })
            print(f"❌ NOT PARTICIPATING {agent_role[:50]}")
            if memory_status.get('error'):
                print(f"   Error: {memory_status['error']}")
    
    # Summary
    print(f"\n" + "="*80)
    print("📊 PARTICIPATION SUMMARY")
    print("="*80)
    print(f"Total Agents: {len(agents)}")
    print(f"✅ Participating (P5 activity): {len(participating_agents)}/{len(agents)} ({len(participating_agents)*100//len(agents) if len(agents) > 0 else 0}%)")
    print(f"❌ Not Participating: {len(not_participating)}/{len(agents)}")
    
    if participating_agents:
        print(f"\n✅ PARTICIPATING AGENTS ({len(participating_agents)}):")
        for p in participating_agents:
            print(f"   - {p['agent']}")
    
    if not_participating:
        print(f"\n❌ NOT PARTICIPATING ({len(not_participating)}):")
        for np in not_participating[:10]:  # Show first 10
            print(f"   - {np['agent']}: {np.get('reason', 'Unknown')}")
        if len(not_participating) > 10:
            print(f"   ... and {len(not_participating) - 10} more")
    
    print("\n" + "="*80)
    print("✅ CHECK COMPLETE")
    print("="*80)

if __name__ == "__main__":
    main()

