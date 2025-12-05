"""
Check Calendar Permissions
This script checks the Project Schedule Calendar permissions to determine
if we can grant the necessary access to add attendees.
"""
import os
import sys
from datetime import datetime
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient.discovery import build

# Scopes required
SCOPES = [
    'https://www.googleapis.com/auth/calendar.readonly',
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

def main():
    """Main permission check function"""
    print("\n" + "="*80)
    print("🔐 CHECKING CALENDAR PERMISSIONS")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}")
    print(f"Calendar ID: {PROJECT_CALENDAR_ID}")
    print("="*80)
    
    # Get credentials
    print("\n🔐 Authenticating...")
    creds = get_credentials()
    
    # Build calendar service
    calendar_service = build('calendar', 'v3', credentials=creds)
    
    # Get authenticated user info
    print("\n👤 Authenticated User Information:")
    print("-" * 80)
    try:
        # Get user info from token
        if hasattr(creds, 'id_token'):
            import jwt
            try:
                decoded = jwt.decode(creds.id_token, verify=False)
                email = decoded.get('email', 'Unknown')
                print(f"   Email: {email}")
            except:
                pass
        
        # Try to get user info from calendar
        calendar_list = calendar_service.calendarList().list().execute()
        primary_calendar = None
        for cal in calendar_list.get('items', []):
            if cal.get('primary'):
                primary_calendar = cal
                break
        
        if primary_calendar:
            print(f"   Primary Calendar: {primary_calendar.get('summary', 'Unknown')}")
    except Exception as e:
        print(f"   ⚠️  Could not get user info: {e}")
    
    # Check calendar access
    print("\n📅 Calendar Access Check:")
    print("-" * 80)
    
    try:
        # Get calendar details
        calendar = calendar_service.calendars().get(calendarId=PROJECT_CALENDAR_ID).execute()
        
        print(f"✅ Calendar accessible")
        print(f"   Summary: {calendar.get('summary', 'Unknown')}")
        print(f"   Description: {calendar.get('description', 'No description')}")
        print(f"   Time Zone: {calendar.get('timeZone', 'Unknown')}")
        print(f"   Location: {calendar.get('location', 'Not specified')}")
        
        # Check calendar list entry for access role
        calendar_list_entry = None
        try:
            calendar_list = calendar_service.calendarList().list().execute()
            for cal in calendar_list.get('items', []):
                if cal.get('id') == PROJECT_CALENDAR_ID:
                    calendar_list_entry = cal
                    break
        except Exception as e:
            print(f"   ⚠️  Could not get calendar list entry: {e}")
        
        if calendar_list_entry:
            access_role = calendar_list_entry.get('accessRole', 'unknown')
            print(f"\n   📊 Access Role: {access_role}")
            
            # Interpret access role
            role_descriptions = {
                'owner': 'Full control - can add attendees, modify events, delete calendar',
                'writer': 'Can create and modify events, but may have restrictions on attendees',
                'reader': 'Read-only access - cannot modify events',
                'freeBusyReader': 'Can only see free/busy information'
            }
            
            description = role_descriptions.get(access_role, 'Unknown role')
            print(f"   📝 Role Description: {description}")
            
            if access_role == 'owner':
                print(f"\n   ✅ You have OWNER access - should be able to add attendees")
            elif access_role == 'writer':
                print(f"\n   ⚠️  You have WRITER access - may have restrictions")
                print(f"      Some shared calendars restrict attendee management for writers")
            else:
                print(f"\n   ❌ You have {access_role.upper()} access - cannot modify events")
        
        # Check ACL (Access Control List) - only works if we're the owner
        print(f"\n🔐 Access Control List (ACL) Check:")
        print("-" * 80)
        try:
            acl = calendar_service.acl().list(calendarId=PROJECT_CALENDAR_ID).execute()
            acl_items = acl.get('items', [])
            
            if acl_items:
                print(f"   ✅ Found {len(acl_items)} ACL entries")
                print(f"\n   📋 ACL Entries:")
                for item in acl_items:
                    scope = item.get('scope', {})
                    role = item.get('role', 'unknown')
                    email = scope.get('value', scope.get('type', 'Unknown'))
                    print(f"      • {email}")
                    print(f"        Role: {role}")
                    print(f"        Type: {scope.get('type', 'Unknown')}")
            else:
                print(f"   ⚠️  No ACL entries found (may not be owner)")
        except Exception as e:
            error_msg = str(e)
            if '403' in error_msg or 'Forbidden' in error_msg:
                print(f"   ⚠️  Cannot access ACL - not the calendar owner")
                print(f"      Error: {error_msg}")
            else:
                print(f"   ⚠️  Error accessing ACL: {e}")
        
        # Test event creation with attendees
        print(f"\n🧪 Testing Event Creation with Attendees:")
        print("-" * 80)
        try:
            from datetime import timedelta
            test_start = datetime.now() + timedelta(hours=1)
            test_end = test_start + timedelta(hours=1)
            
            test_event = {
                'summary': 'TEST - Permission Check (Will Delete)',
                'description': 'This is a test event to check attendee permissions. Will be deleted immediately.',
                'start': {
                    'dateTime': test_start.isoformat(),
                    'timeZone': 'America/New_York'
                },
                'end': {
                    'dateTime': test_end.isoformat(),
                    'timeZone': 'America/New_York'
                },
                'attendees': [
                    {'email': 'collin.m@ratiovita.com'}
                ],
                'sendUpdates': 'none'  # Don't send notifications for test
            }
            
            print(f"   Creating test event with 1 attendee...")
            created = calendar_service.events().insert(
                calendarId=PROJECT_CALENDAR_ID,
                body=test_event
            ).execute()
            
            test_event_id = created.get('id')
            print(f"   ✅ Test event created: {test_event_id}")
            
            # Check if attendee was added
            retrieved = calendar_service.events().get(
                calendarId=PROJECT_CALENDAR_ID,
                eventId=test_event_id
            ).execute()
            
            attendees = retrieved.get('attendees', [])
            print(f"   📊 Attendees in created event: {len(attendees)}")
            
            if attendees:
                print(f"   ✅ SUCCESS: Attendees can be added!")
                for att in attendees:
                    print(f"      • {att.get('email', 'Unknown')} ({att.get('responseStatus', 'unknown')})")
            else:
                print(f"   ⚠️  WARNING: Attendee was not added to event")
                print(f"      This indicates a permissions or configuration issue")
            
            # Delete test event
            print(f"\n   🗑️  Deleting test event...")
            calendar_service.events().delete(
                calendarId=PROJECT_CALENDAR_ID,
                eventId=test_event_id
            ).execute()
            print(f"   ✅ Test event deleted")
            
        except Exception as e:
            error_msg = str(e)
            print(f"   ❌ Error creating test event: {e}")
            if '403' in error_msg or 'Forbidden' in error_msg:
                print(f"      This indicates insufficient permissions to create events with attendees")
            elif 'attendees' in error_msg.lower():
                print(f"      This indicates a specific issue with attendee management")
    
    except Exception as e:
        error_msg = str(e)
        print(f"\n❌ Error accessing calendar: {e}")
        if '404' in error_msg or 'Not Found' in error_msg:
            print(f"   Calendar not found - check calendar ID")
        elif '403' in error_msg or 'Forbidden' in error_msg:
            print(f"   Access forbidden - you may not have permission to access this calendar")
        elif '401' in error_msg or 'Unauthorized' in error_msg:
            print(f"   Authentication failed - token may be invalid")
    
    # Recommendations
    print("\n" + "="*80)
    print("💡 RECOMMENDATIONS")
    print("="*80)
    
    if calendar_list_entry:
        access_role = calendar_list_entry.get('accessRole', 'unknown')
        if access_role == 'owner':
            print("✅ You are the calendar owner - attendee management should work")
            print("   If attendees are not being added, check:")
            print("   1. Calendar settings in Google Calendar UI")
            print("   2. Whether 'Guests can modify event' is enabled")
            print("   3. Whether there are any domain-level restrictions")
        elif access_role == 'writer':
            print("⚠️  You are a writer (not owner) - attendee management may be restricted")
            print("   Solutions:")
            print("   1. Request owner access to the calendar")
            print("   2. Have the calendar owner add attendees manually")
            print("   3. Check if the calendar owner can grant 'Make changes to events' permission")
        else:
            print("❌ You do not have write access to this calendar")
            print("   Solutions:")
            print("   1. Request write access from the calendar owner")
            print("   2. Have the calendar owner add attendees manually")
    
    print("\n" + "="*80)
    print("✅ Permission check complete")
    print("="*80)

if __name__ == "__main__":
    main()

