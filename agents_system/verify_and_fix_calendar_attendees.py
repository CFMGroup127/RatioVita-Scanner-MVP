"""
Verify and Fix Calendar Attendees
This script checks the Project Schedule Calendar event and ensures all 15 agents are added as attendees.
"""
import os
from datetime import datetime
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from main import load_agents_from_yaml, get_agent_metadata

def verify_and_fix_calendar_attendees():
    """
    Verify calendar event has all attendees and add them if missing.
    """
    print("\n" + "="*80)
    print("📅 VERIFYING AND FIXING CALENDAR ATTENDEES")
    print("="*80)
    print(f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}")
    print("="*80)
    
    # Get credentials
    creds = None
    if os.path.exists('token.json'):
        creds = Credentials.from_authorized_user_file('token.json', [
            'https://www.googleapis.com/auth/calendar',
            'https://www.googleapis.com/auth/gmail.readonly'
        ])
        if not creds.valid:
            if creds.expired and creds.refresh_token:
                creds.refresh(Request())
    
    if not creds:
        print("❌ Could not get credentials")
        return None
    
    # Load agents
    agents = load_agents_from_yaml('agents.yaml')
    
    # Get all agent emails
    agent_emails = []
    for agent in agents:
        agent_meta = get_agent_metadata(agent.role)
        email = agent_meta.get('email_address', '')
        if email:
            agent_emails.append(email)
    
    print(f"\n📧 Agent emails to add as attendees: {len(agent_emails)}")
    for email in agent_emails:
        print(f"   - {email}")
    
    # Project Schedule Calendar ID
    project_calendar_id = "c_4e1c24ca3fdea15ff6de1ee2e0d025f75a1f8ff58ef58e2119e5273e51a5e7dc@group.calendar.google.com"
    
    # Find the meeting event
    calendar_service = build('calendar', 'v3', credentials=creds)
    
    print(f"\n🔍 Searching for meeting event on Project Schedule Calendar...")
    print(f"   Calendar ID: {project_calendar_id}")
    
    # Search for events today
    time_min = datetime(2025, 11, 17, 0, 0, 0).isoformat() + 'Z'
    time_max = datetime(2025, 11, 18, 0, 0, 0).isoformat() + 'Z'
    
    try:
        events_result = calendar_service.events().list(
            calendarId=project_calendar_id,
            timeMin=time_min,
            timeMax=time_max,
            maxResults=10
        ).execute()
        
        events = events_result.get('items', [])
        
        print(f"\n📋 Found {len(events)} event(s) on Project Schedule Calendar today")
        
        meeting_event = None
        for event in events:
            title = event.get('summary', '')
            if 'Executive Strategy Group Meeting' in title:
                meeting_event = event
                break
        
        if not meeting_event:
            print("❌ Meeting event not found on Project Schedule Calendar")
            return None
        
        event_id = meeting_event.get('id')
        event_title = meeting_event.get('summary', '')
        event_start = meeting_event.get('start', {}).get('dateTime', '')
        
        print(f"\n✅ Found meeting event:")
        print(f"   Event ID: {event_id}")
        print(f"   Title: {event_title}")
        print(f"   Start: {event_start}")
        
        # Check current attendees
        current_attendees = meeting_event.get('attendees', [])
        current_attendee_emails = [a.get('email', '') for a in current_attendees if a.get('email')]
        
        print(f"\n📋 Current attendees: {len(current_attendees)}")
        for attendee in current_attendees:
            email = attendee.get('email', '')
            response = attendee.get('responseStatus', 'needsAction')
            print(f"   - {email} ({response})")
        
        # Check which agents are missing
        missing_attendees = []
        for email in agent_emails:
            if email not in current_attendee_emails:
                missing_attendees.append(email)
        
        if missing_attendees:
            print(f"\n⚠️  Missing {len(missing_attendees)} attendees:")
            for email in missing_attendees:
                print(f"   - {email}")
            
            # Add missing attendees
            print(f"\n➕ Adding missing attendees to calendar event...")
            
            # Create attendee list
            all_attendees = []
            for email in agent_emails:
                all_attendees.append({'email': email})
            
            # Update event with all attendees
            meeting_event['attendees'] = all_attendees
            
            try:
                updated_event = calendar_service.events().update(
                    calendarId=project_calendar_id,
                    eventId=event_id,
                    body=meeting_event,
                    sendUpdates='all'  # This sends email invites to all attendees
                ).execute()
                
                print(f"✅ Successfully added all {len(agent_emails)} attendees to calendar event")
                print(f"   Email invitations sent to all attendees")
                print(f"   Updated event ID: {updated_event.get('id')}")
                
                # Verify attendees were added
                final_attendees = updated_event.get('attendees', [])
                print(f"\n📋 Final attendee count: {len(final_attendees)}")
                for attendee in final_attendees:
                    email = attendee.get('email', '')
                    response = attendee.get('responseStatus', 'needsAction')
                    print(f"   - {email} ({response})")
                
            except Exception as e:
                print(f"❌ Error updating event: {e}")
                return None
        else:
            print(f"\n✅ All {len(agent_emails)} agents are already attendees")
            print("   No update needed")
        
        # Check individual agent calendars
        print(f"\n" + "="*80)
        print("📅 CHECKING INDIVIDUAL AGENT CALENDARS")
        print("="*80)
        
        for agent in agents[:5]:  # Check first 5 agents
            agent_meta = get_agent_metadata(agent.role)
            email = agent_meta.get('email_address', '')
            personal_calendar_id = agent_meta.get('personal_calendar_id', '')
            
            if personal_calendar_id:
                try:
                    # Check if event exists on personal calendar
                    personal_events = calendar_service.events().list(
                        calendarId=personal_calendar_id,
                        timeMin=time_min,
                        timeMax=time_max,
                        maxResults=10
                    ).execute()
                    
                    personal_event_list = personal_events.get('items', [])
                    has_meeting = any('Executive Strategy Group Meeting' in e.get('summary', '') for e in personal_event_list)
                    
                    status = "✅ HAS MEETING" if has_meeting else "❌ NOT FOUND"
                    print(f"{status} {agent.role[:40]}")
                    print(f"   Email: {email}")
                    print(f"   Calendar ID: {personal_calendar_id[:50]}...")
                    
                except Exception as e:
                    print(f"❌ ERROR {agent.role[:40]}")
                    print(f"   Error: {e}")
        
    except Exception as e:
        print(f"❌ Error accessing calendar: {e}")
        import traceback
        traceback.print_exc()
        return None
    
    return meeting_event

if __name__ == "__main__":
    verify_and_fix_calendar_attendees()


