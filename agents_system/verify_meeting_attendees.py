"""
Verify Meeting Attendees on Project Schedule Calendar
This script checks the Project Schedule Calendar for the Executive Strategy Group Meeting
and verifies all 15 agents are listed as attendees.
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
    'https://www.googleapis.com/auth/calendar.readonly'
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
            print(f"⚠️  Could not load token with requested scopes: {e}")
            try:
                creds = Credentials.from_authorized_user_file(token_path, None)
                if creds.scopes:
                    has_calendar = any('calendar' in s for s in creds.scopes)
                    if has_calendar:
                        print("✅ Using existing token with compatible scopes")
                    else:
                        raise Exception("Token missing required scopes")
            except Exception as e2:
                print(f"⚠️  Could not use existing token: {e2}")
                creds = None
    
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            try:
                creds.refresh(Request())
            except Exception as e:
                print(f"⚠️  Token refresh failed: {e}")
                print("   Will request new authentication...")
                creds = None
        
        if not creds:
            print("🔐 Requesting new authentication...")
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
    """Main verification function"""
    print("\n" + "="*80)
    print("📅 VERIFYING MEETING ATTENDEES - PROJECT SCHEDULE CALENDAR")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}")
    print(f"Calendar ID: {PROJECT_CALENDAR_ID}")
    print("="*80)
    
    # Get credentials
    print("\n🔐 Authenticating...")
    creds = get_credentials()
    
    # Build calendar service
    calendar_service = build('calendar', 'v3', credentials=creds)
    
    # Load agents
    print("📋 Loading agent configurations...")
    agents_data = load_agents()
    agents = agents_data.get('agents', [])
    
    # Get all agent emails
    agent_emails = set()
    agent_names = {}
    for agent in agents:
        email = agent.get('email_address', '')
        if email:
            agent_emails.add(email.lower())
            agent_names[email.lower()] = agent.get('role', 'Unknown')
    
    print(f"\n🔍 Searching for meeting on Project Schedule Calendar...")
    print(f"   Expected attendees: {len(agent_emails)} agents")
    print("-" * 80)
    
    # Search for the meeting event today
    today = datetime.now()
    start_of_day = today.replace(hour=0, minute=0, second=0, microsecond=0)
    end_of_day = today.replace(hour=23, minute=59, second=59, microsecond=0)
    
    time_min = start_of_day.isoformat() + 'Z'
    time_max = end_of_day.isoformat() + 'Z'
    
    try:
        # Search for events on the Project Schedule Calendar
        events_result = calendar_service.events().list(
            calendarId=PROJECT_CALENDAR_ID,
            timeMin=time_min,
            timeMax=time_max,
            maxResults=20,
            singleEvents=True,
            orderBy='startTime'
        ).execute()
        
        events = events_result.get('items', [])
        
        if not events:
            print("❌ No events found on Project Schedule Calendar for today")
            print("\n💡 Checking if calendar is accessible...")
            try:
                calendar = calendar_service.calendars().get(calendarId=PROJECT_CALENDAR_ID).execute()
                print(f"✅ Calendar accessible: {calendar.get('summary', 'Unknown')}")
            except Exception as e:
                print(f"❌ Cannot access calendar: {e}")
            return
        
        print(f"\n📅 Found {len(events)} event(s) on Project Schedule Calendar today")
        print("="*80)
        
        # Look for the Executive Strategy Group Meeting
        meeting_found = False
        for event in events:
            event_title = event.get('summary', '')
            if 'Executive Strategy Group' in event_title or 'V1 Legacy Review' in event_title:
                meeting_found = True
                print(f"\n✅ MEETING FOUND: {event_title}")
                print("-" * 80)
                
                # Get event details
                event_id = event.get('id', '')
                start = event.get('start', {})
                end = event.get('end', {})
                start_time = start.get('dateTime', start.get('date', 'Unknown'))
                end_time = end.get('dateTime', end.get('date', 'Unknown'))
                location = event.get('location', 'Not specified')
                description = event.get('description', '')
                
                print(f"📅 Event ID: {event_id}")
                print(f"🕐 Start Time: {start_time}")
                print(f"🕐 End Time: {end_time}")
                print(f"📍 Location: {location}")
                
                # Check attendees
                attendees = event.get('attendees', [])
                print(f"\n👥 ATTENDEES: {len(attendees)} total")
                print("-" * 80)
                
                if not attendees:
                    print("❌ NO ATTENDEES FOUND - Event has no attendees listed")
                    print("\n⚠️  This means the automatic attendee addition did not work.")
                    print("   You may need to manually add all 15 agents as attendees.")
                else:
                    # Categorize attendees
                    agent_attendees = []
                    other_attendees = []
                    
                    for attendee in attendees:
                        email = attendee.get('email', '').lower()
                        name = attendee.get('displayName', 'Unknown')
                        response = attendee.get('responseStatus', 'needsAction')
                        organizer = attendee.get('organizer', False)
                        
                        if email in agent_emails:
                            agent_attendees.append({
                                'email': email,
                                'name': name,
                                'response': response,
                                'role': agent_names.get(email, 'Unknown')
                            })
                        else:
                            other_attendees.append({
                                'email': email,
                                'name': name,
                                'response': response,
                                'organizer': organizer
                            })
                    
                    # Display agent attendees
                    print(f"\n✅ AGENT ATTENDEES: {len(agent_attendees)}/{len(agent_emails)}")
                    print("-" * 80)
                    
                    if agent_attendees:
                        for attendee in sorted(agent_attendees, key=lambda x: x['role']):
                            response_icon = {
                                'accepted': '✅',
                                'declined': '❌',
                                'tentative': '⏳',
                                'needsAction': '⏸️'
                            }.get(attendee['response'], '❓')
                            
                            print(f"   {response_icon} {attendee['role']}")
                            print(f"      Email: {attendee['email']}")
                            print(f"      Status: {attendee['response']}")
                            print()
                    else:
                        print("   ❌ No agent attendees found")
                    
                    # Check for missing agents
                    found_emails = {a['email'] for a in agent_attendees}
                    missing_emails = agent_emails - found_emails
                    
                    if missing_emails:
                        print(f"\n⚠️  MISSING AGENTS: {len(missing_emails)} agents not in attendee list")
                        print("-" * 80)
                        for email in sorted(missing_emails):
                            role = agent_names.get(email, 'Unknown')
                            print(f"   ❌ {role}")
                            print(f"      Email: {email}")
                        print()
                    else:
                        print(f"\n✅ ALL {len(agent_emails)} AGENTS ARE ATTENDEES!")
                    
                    # Display other attendees (non-agents)
                    if other_attendees:
                        print(f"\n👤 OTHER ATTENDEES: {len(other_attendees)}")
                        print("-" * 80)
                        for attendee in other_attendees:
                            org_marker = " (Organizer)" if attendee['organizer'] else ""
                            print(f"   • {attendee['name']} ({attendee['email']}){org_marker}")
                            print(f"     Status: {attendee['response']}")
                
                # Summary
                print("\n" + "="*80)
                print("📊 SUMMARY")
                print("="*80)
                print(f"Total Attendees: {len(attendees)}")
                print(f"Agent Attendees: {len(agent_attendees) if attendees else 0}/{len(agent_emails)}")
                print(f"Missing Agents: {len(missing_emails) if attendees else len(agent_emails)}")
                
                if attendees and len(agent_attendees) == len(agent_emails):
                    print("\n✅ SUCCESS: All agents are attendees!")
                elif attendees:
                    print(f"\n⚠️  WARNING: {len(missing_emails)} agents are missing from attendee list")
                    print("   Manual addition may be required.")
                else:
                    print("\n❌ CRITICAL: No attendees found. Manual addition required.")
                
                break
        
        if not meeting_found:
            print("\n❌ Executive Strategy Group Meeting not found in today's events")
            print("\n📅 Today's events on Project Schedule Calendar:")
            for event in events:
                print(f"   • {event.get('summary', 'Untitled')} - {event.get('start', {}).get('dateTime', 'Unknown time')}")
    
    except Exception as e:
        print(f"\n❌ Error accessing calendar: {e}")
        import traceback
        traceback.print_exc()
    
    print("\n" + "="*80)
    print("✅ Verification complete")
    print("="*80)

if __name__ == "__main__":
    main()

