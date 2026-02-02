"""
Test Adding All 15 Agents as Attendees
This script tests if we can successfully add all 15 agents as attendees to an event.
"""
import os
import sys
from datetime import datetime, timedelta
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
import yaml

# Scopes required
SCOPES = [
    'https://www.googleapis.com/auth/calendar'
]

# Project Schedule Calendar ID
PROJECT_CALENDAR_ID = "c_4e1c24ca3fdea15ff6de1ee2e0d025f75a1f8ff58ef58e2119e5273e51a5e7dc@group.calendar.google.com"

def get_credentials():
    """Get valid user credentials from storage."""
    creds = None
    token_path = 'token.json'
    
    if os.path.exists(token_path):
        try:
            creds = Credentials.from_authorized_user_file(token_path, SCOPES)
        except Exception as e:
            try:
                creds = Credentials.from_authorized_user_file(token_path, None)
                if creds.scopes:
                    has_calendar = any('calendar' in s for s in creds.scopes)
                    if has_calendar:
                        pass
                    else:
                        raise Exception("Token missing required scopes")
            except Exception as e2:
                creds = None
    
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            try:
                creds.refresh(Request())
            except Exception as e:
                creds = None
        
        if not creds:
            flow = InstalledAppFlow.from_client_secrets_file(
                'credentials.json', SCOPES)
            creds = flow.run_local_server(port=0, access_type='offline', prompt='consent')
            
            with open(token_path, 'w') as token:
                token.write(creds.to_json())
    
    return creds

def load_agents():
    """Load agent configurations from agents.yaml"""
    with open('agents.yaml', 'r') as f:
        return yaml.safe_load(f)

def main():
    """Test function"""
    print("\n" + "="*80)
    print("🧪 TESTING: Adding All 15 Agents as Attendees")
    print("="*80)
    
    # Get credentials
    creds = get_credentials()
    calendar_service = build('calendar', 'v3', credentials=creds)
    
    # Load agents
    agents_data = load_agents()
    agents = agents_data.get('agents', [])
    
    # Get all agent emails
    agent_emails = []
    for agent in agents:
        email = agent.get('email_address', '')
        if email:
            agent_emails.append(email)
    
    print(f"\n👥 Agent Emails ({len(agent_emails)}):")
    for i, email in enumerate(agent_emails, 1):
        print(f"   {i:2d}. {email}")
    
    # Create test event with all attendees
    test_start = datetime.now() + timedelta(hours=1)
    test_end = test_start + timedelta(minutes=30)
    
    print(f"\n📝 Creating test event with {len(agent_emails)} attendees...")
    print(f"   Start: {test_start.strftime('%Y-%m-%d %H:%M')}")
    
    # Create attendee list
    attendees = [{'email': email} for email in agent_emails]
    
    test_event = {
        'summary': 'TEST - All 15 Agents Attendee Test (Will Delete)',
        'description': f'Testing attendee addition with all {len(agent_emails)} agents. This event will be deleted.',
        'start': {
            'dateTime': test_start.isoformat(),
            'timeZone': 'America/New_York'
        },
        'end': {
            'dateTime': test_end.isoformat(),
            'timeZone': 'America/New_York'
        },
        'attendees': attendees,
        'sendUpdates': 'none'  # Don't send notifications for test
    }
    
    try:
        print(f"\n📤 Sending API request...")
        created = calendar_service.events().insert(
            calendarId=PROJECT_CALENDAR_ID,
            body=test_event
        ).execute()
        
        test_event_id = created.get('id')
        print(f"✅ Test event created: {test_event_id}")
        
        # Immediately retrieve the event to check attendees
        print(f"\n🔍 Retrieving event to verify attendees...")
        retrieved = calendar_service.events().get(
            calendarId=PROJECT_CALENDAR_ID,
            eventId=test_event_id
        ).execute()
        
        retrieved_attendees = retrieved.get('attendees', [])
        print(f"\n📊 RESULTS:")
        print(f"   Attendees requested: {len(attendees)}")
        print(f"   Attendees in event: {len(retrieved_attendees)}")
        
        if len(retrieved_attendees) == len(attendees):
            print(f"\n✅ SUCCESS: All {len(attendees)} attendees were added!")
        else:
            print(f"\n⚠️  WARNING: Only {len(retrieved_attendees)}/{len(attendees)} attendees were added")
        
        # List all attendees
        print(f"\n👥 Attendees in Event:")
        for i, att in enumerate(retrieved_attendees, 1):
            email = att.get('email', 'Unknown')
            status = att.get('responseStatus', 'unknown')
            print(f"   {i:2d}. {email} ({status})")
        
        # Check which agents are missing
        retrieved_emails = {att.get('email', '').lower() for att in retrieved_attendees}
        requested_emails = {email.lower() for email in agent_emails}
        missing = requested_emails - retrieved_emails
        
        if missing:
            print(f"\n❌ Missing Attendees ({len(missing)}):")
            for email in sorted(missing):
                print(f"   • {email}")
        else:
            print(f"\n✅ All requested attendees are present!")
        
        # Delete test event
        print(f"\n🗑️  Deleting test event...")
        calendar_service.events().delete(
            calendarId=PROJECT_CALENDAR_ID,
            eventId=test_event_id
        ).execute()
        print(f"✅ Test event deleted")
        
        # Conclusion
        print("\n" + "="*80)
        if len(retrieved_attendees) == len(attendees):
            print("✅ CONCLUSION: All attendees can be added successfully!")
            print("   The issue with the previous meeting update may have been:")
            print("   1. A timing issue (API response delay)")
            print("   2. The event was updated before attendees were processed")
            print("   3. A transient API issue")
        else:
            print("⚠️  CONCLUSION: Some attendees could not be added")
            print("   Possible reasons:")
            print("   1. Invalid email addresses")
            print("   2. Google Calendar API limits")
            print("   3. Domain restrictions")
        print("="*80)
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()

