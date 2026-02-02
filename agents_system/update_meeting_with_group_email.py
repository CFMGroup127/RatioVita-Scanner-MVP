"""
Update Meeting to Use Group Email
This script updates the 2:30 PM EST meeting to use all.15.team.members@ratiovita.com
as the attendee, which will send invitations to all group members.
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
    """Update meeting with group email"""
    print("\n" + "="*80)
    print("📅 UPDATING MEETING TO USE GROUP EMAIL")
    print("="*80)
    print(f"Group Email: {GROUP_EMAIL}")
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}")
    print("="*80)
    
    # Get credentials
    print("\n🔐 Authenticating...")
    creds = get_credentials()
    calendar_service = build('calendar', 'v3', credentials=creds)
    
    # Find the 2:30 PM meeting
    print(f"\n🔍 Searching for 2:30 PM meeting...")
    today = datetime.now()
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
            print("❌ Meeting not found")
            return False
        
        print(f"✅ Found meeting: {meeting_event.get('summary')}")
        print(f"   Event ID: {meeting_event.get('id')}")
        
        # Update event to use group email
        meeting_event['attendees'] = [
            {'email': GROUP_EMAIL}
        ]
        meeting_event['sendUpdates'] = 'all'
        
        print(f"\n📝 Updating meeting to use group email...")
        print(f"   Attendee: {GROUP_EMAIL}")
        print(f"   This will send invitations to all group members")
        
        updated_event = calendar_service.events().update(
            calendarId=PROJECT_CALENDAR_ID,
            eventId=meeting_event.get('id'),
            body=meeting_event
        ).execute()
        
        print(f"✅ Meeting updated successfully!")
        print(f"   Event ID: {updated_event.get('id')}")
        print(f"   Link: {updated_event.get('htmlLink')}")
        
        # Verify attendees
        print(f"\n🔍 Verifying attendees...")
        final_event = calendar_service.events().get(
            calendarId=PROJECT_CALENDAR_ID,
            eventId=meeting_event.get('id')
        ).execute()
        
        attendees = final_event.get('attendees', [])
        print(f"   Total Attendees: {len(attendees)}")
        
        if attendees:
            for att in attendees:
                email = att.get('email', 'Unknown')
                status = att.get('responseStatus', 'unknown')
                print(f"   ✅ {email} ({status})")
        
        print("\n" + "="*80)
        print("✅ Meeting update complete!")
        print("="*80)
        print(f"\n📋 IMPORTANT: Adding Members to Group")
        print(f"   The group email {GROUP_EMAIL} is now set as the attendee.")
        print(f"   To ensure all 15 agents receive invitations, you need to:")
        print(f"   1. Go to Google Workspace Admin Console")
        print(f"   2. Navigate to Groups > {GROUP_EMAIL}")
        print(f"   3. Add all 15 agent email addresses as members")
        print(f"   4. Wait a few minutes for changes to propagate")
        print(f"\n   Agent emails to add:")
        print(f"   - dana.flores@ratiovita.com")
        print(f"   - kyle.law@ratiovita.com")
        print(f"   - david.chen@ratiovita.com")
        print(f"   - ash.roy@ratiovita.com")
        print(f"   - sophia.vance@ratiovita.com")
        print(f"   - megan.parker@ratiovita.com")
        print(f"   - arthur.jensen@ratiovita.com")
        print(f"   - ethan.hayes@ratiovita.com")
        print(f"   - chloe.park@ratiovita.com")
        print(f"   - samuel.reed@ratiovita.com")
        print(f"   - alice.kim@ratiovita.com")
        print(f"   - victor.alvarez@ratiovita.com")
        print(f"   - jennifer.jurvais@ratiovita.com")
        print(f"   - tyler.cobb@ratiovita.com")
        print(f"   - rachel.stone@ratiovita.com")
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

