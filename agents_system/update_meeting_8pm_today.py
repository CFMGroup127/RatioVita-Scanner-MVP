"""
Update Meeting to 8:00 PM EST Today
This script updates the Executive Strategy Group Meeting to 8:00 PM EST today
using the group email all.15.team.members@ratiovita.com as attendee.
"""
import os
import sys
from datetime import datetime, timedelta
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient.discovery import build

# Scopes required
SCOPES = [
    'https://www.googleapis.com/auth/calendar'
]

# Project Schedule Calendar ID
PROJECT_CALENDAR_ID = "c_4e1c24ca3fdea15ff6de1ee2e0d025f75a1f8ff58ef58e2119e5273e51a5e7dc@group.calendar.google.com"

GROUP_EMAIL = "all.15.team.members@ratiovita.com"

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

def main():
    """Update meeting to 8 PM EST today"""
    print("\n" + "="*80)
    print("📅 UPDATING MEETING TO 8:00 PM EST TODAY")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}")
    print(f"New Time: 8:00 PM - 10:00 PM EST")
    print(f"Attendee: {GROUP_EMAIL}")
    print("="*80)
    
    # Get credentials
    print("\n🔐 Authenticating...")
    creds = get_credentials()
    calendar_service = build('calendar', 'v3', credentials=creds)
    
    # Calculate meeting times (8:00 PM - 10:00 PM EST today)
    today = datetime.now()
    start_time = today.replace(hour=20, minute=0, second=0, microsecond=0)  # 8:00 PM
    end_time = start_time + timedelta(hours=2)  # 10:00 PM
    
    # Format for Google Calendar API (EST timezone)
    start_time_iso = start_time.strftime('%Y-%m-%dT%H:%M:00')
    end_time_iso = end_time.strftime('%Y-%m-%dT%H:%M:00')
    
    print(f"\n🕐 Meeting Time:")
    print(f"   Start: {start_time.strftime('%B %d, %Y at %I:%M %p')} EST")
    print(f"   End: {end_time.strftime('%B %d, %Y at %I:%M %p')} EST")
    
    # Find the meeting
    print(f"\n🔍 Searching for existing meeting...")
    start_of_day = today.replace(hour=0, minute=0, second=0, microsecond=0)
    end_of_day = today.replace(hour=23, minute=59, second=59, microsecond=0)
    
    time_min = start_of_day.isoformat() + 'Z'
    time_max = end_of_day.isoformat() + 'Z'
    
    try:
        events_result = calendar_service.events().list(
            calendarId=PROJECT_CALENDAR_ID,
            timeMin=time_min,
            timeMax=time_max,
            maxResults=20,
            singleEvents=True,
            orderBy='startTime'
        ).execute()
        
        events = events_result.get('items', [])
        
        # Find the Executive Strategy Group Meeting
        meeting_event = None
        for event in events:
            event_title = event.get('summary', '')
            if 'Executive Strategy Group' in event_title or 'V1 Legacy Review' in event_title:
                meeting_event = event
                break
        
        if not meeting_event:
            print("❌ Meeting not found. Creating new event...")
            # Create new event
            event = {
                'summary': 'Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning',
                'description': 'Executive Strategy Group Meeting for V1 Legacy Review and V2 Planning. All 15 agents are required to attend.',
                'start': {
                    'dateTime': start_time_iso,
                    'timeZone': 'America/New_York'
                },
                'end': {
                    'dateTime': end_time_iso,
                    'timeZone': 'America/New_York'
                },
                'location': 'Virtual Meeting',
                'attendees': [{'email': GROUP_EMAIL}],
                'sendUpdates': 'all'
            }
            
            created_event = calendar_service.events().insert(
                calendarId=PROJECT_CALENDAR_ID,
                body=event
            ).execute()
            
            print(f"✅ New meeting created!")
            print(f"   Event ID: {created_event.get('id')}")
            print(f"   Link: {created_event.get('htmlLink')}")
            meeting_event = created_event
        else:
            print(f"✅ Found existing meeting: {meeting_event.get('summary')}")
            print(f"   Event ID: {meeting_event.get('id')}")
            
            # Update the event
            meeting_event['start'] = {
                'dateTime': start_time_iso,
                'timeZone': 'America/New_York'
            }
            meeting_event['end'] = {
                'dateTime': end_time_iso,
                'timeZone': 'America/New_York'
            }
            
            # Ensure group email is the attendee
            meeting_event['attendees'] = [{'email': GROUP_EMAIL}]
            meeting_event['sendUpdates'] = 'all'
            
            print(f"\n📝 Updating meeting time and attendees...")
            print(f"   New time: 8:00 PM - 10:00 PM EST")
            print(f"   Attendee: {GROUP_EMAIL}")
            
            updated_event = calendar_service.events().update(
                calendarId=PROJECT_CALENDAR_ID,
                eventId=meeting_event.get('id'),
                body=meeting_event
            ).execute()
            
            print(f"✅ Meeting updated successfully!")
            print(f"   Event ID: {updated_event.get('id')}")
            print(f"   Link: {updated_event.get('htmlLink')}")
            meeting_event = updated_event
        
        # Verify final event
        print(f"\n🔍 Verifying final meeting details...")
        final_event = calendar_service.events().get(
            calendarId=PROJECT_CALENDAR_ID,
            eventId=meeting_event.get('id')
        ).execute()
        
        final_start = final_event.get('start', {})
        final_end = final_event.get('end', {})
        final_attendees = final_event.get('attendees', [])
        
        print(f"\n📊 FINAL MEETING DETAILS:")
        print(f"   Title: {final_event.get('summary', 'Unknown')}")
        print(f"   Start: {final_start.get('dateTime', final_start.get('date', 'Unknown'))}")
        print(f"   End: {final_end.get('dateTime', final_end.get('date', 'Unknown'))}")
        print(f"   Location: {final_event.get('location', 'Not specified')}")
        print(f"   Attendees: {len(final_attendees)}")
        
        if final_attendees:
            for att in final_attendees:
                email = att.get('email', 'Unknown')
                status = att.get('responseStatus', 'unknown')
                print(f"      • {email} ({status})")
        
        print("\n" + "="*80)
        print("✅ Meeting update complete!")
        print("="*80)
        print(f"\n📅 Meeting Scheduled:")
        print(f"   Time: 8:00 PM - 10:00 PM EST")
        print(f"   Date: {start_time.strftime('%B %d, %Y')}")
        print(f"   Attendee: {GROUP_EMAIL}")
        print(f"   All group members will receive invitations")
        print("="*80)
        
        return True
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)


