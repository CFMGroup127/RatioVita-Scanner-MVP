"""
Test Group Email for Calendar Invitations
This script tests if the group email all.15.team.members@ratiovita.com
can be used as a calendar attendee.
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
    'https://www.googleapis.com/auth/calendar',
    'https://www.googleapis.com/auth/admin.directory.group.readonly'
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

def load_agents():
    """Load agent configurations from agents.yaml"""
    with open('agents.yaml', 'r') as f:
        return yaml.safe_load(f)

def check_group_members(admin_service, group_email):
    """Check if group exists and list members"""
    try:
        print(f"\n🔍 Checking group: {group_email}")
        group = admin_service.groups().get(groupKey=group_email).execute()
        
        print(f"✅ Group found: {group.get('name', 'Unknown')}")
        print(f"   Email: {group.get('email', 'Unknown')}")
        print(f"   Description: {group.get('description', 'No description')}")
        
        # Get group members
        members = admin_service.members().list(groupKey=group_email).execute()
        member_list = members.get('members', [])
        
        print(f"\n👥 Group Members: {len(member_list)}")
        for i, member in enumerate(member_list, 1):
            email = member.get('email', 'Unknown')
            role = member.get('role', 'MEMBER')
            print(f"   {i:2d}. {email} ({role})")
        
        return True, member_list
    except Exception as e:
        error_msg = str(e)
        if '404' in error_msg or 'not found' in error_msg.lower():
            print(f"❌ Group not found: {group_email}")
            print(f"   Error: {e}")
            return False, []
        elif '403' in error_msg or 'forbidden' in error_msg.lower():
            print(f"⚠️  Cannot access group (insufficient permissions)")
            print(f"   Error: {e}")
            print(f"   Note: Admin Directory API access may be required")
            return None, []
        else:
            print(f"❌ Error checking group: {e}")
            return None, []

def test_group_as_calendar_attendee(calendar_service, group_email):
    """Test if group email can be used as calendar attendee"""
    print(f"\n🧪 Testing group email as calendar attendee...")
    
    # Create test event with group as attendee
    test_start = datetime.now() + timedelta(hours=2)
    test_end = test_start + timedelta(minutes=30)
    
    test_event = {
        'summary': 'TEST - Group Email Attendee Test (Will Delete)',
        'description': f'Testing if {group_email} can be used as attendee. This event will be deleted.',
        'start': {
            'dateTime': test_start.isoformat(),
            'timeZone': 'America/New_York'
        },
        'end': {
            'dateTime': test_end.isoformat(),
            'timeZone': 'America/New_York'
        },
        'attendees': [
            {'email': group_email}
        ],
        'sendUpdates': 'none'  # Don't send notifications for test
    }
    
    try:
        print(f"   Creating test event with {group_email} as attendee...")
        created = calendar_service.events().insert(
            calendarId=PROJECT_CALENDAR_ID,
            body=test_event
        ).execute()
        
        test_event_id = created.get('id')
        print(f"   ✅ Test event created: {test_event_id}")
        
        # Retrieve event to check attendees
        retrieved = calendar_service.events().get(
            calendarId=PROJECT_CALENDAR_ID,
            eventId=test_event_id
        ).execute()
        
        attendees = retrieved.get('attendees', [])
        print(f"\n   📊 Attendees in event: {len(attendees)}")
        
        if attendees:
            print(f"   ✅ Group email accepted as attendee!")
            for att in attendees:
                email = att.get('email', 'Unknown')
                status = att.get('responseStatus', 'unknown')
                print(f"      • {email} ({status})")
        else:
            print(f"   ⚠️  Group email not added as attendee")
            print(f"      This may indicate the group doesn't exist or isn't configured correctly")
        
        # Delete test event
        print(f"\n   🗑️  Deleting test event...")
        calendar_service.events().delete(
            calendarId=PROJECT_CALENDAR_ID,
            eventId=test_event_id
        ).execute()
        print(f"   ✅ Test event deleted")
        
        return len(attendees) > 0
        
    except Exception as e:
        print(f"   ❌ Error: {e}")
        return False

def main():
    """Main test function"""
    print("\n" + "="*80)
    print("🧪 TESTING GROUP EMAIL FOR CALENDAR INVITATIONS")
    print("="*80)
    print(f"Group Email: {GROUP_EMAIL}")
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}")
    print("="*80)
    
    # Get credentials
    print("\n🔐 Authenticating...")
    creds = get_credentials()
    
    # Build services
    calendar_service = build('calendar', 'v3', credentials=creds)
    
    # Try to build admin service (may fail if no admin access)
    admin_service = None
    try:
        admin_service = build('admin', 'directory_v1', credentials=creds)
        print("✅ Admin Directory API access available")
    except Exception as e:
        print(f"⚠️  Admin Directory API not available: {e}")
        print("   Will skip group membership check")
    
    # Check group if admin service is available
    if admin_service:
        group_exists, members = check_group_members(admin_service, GROUP_EMAIL)
        
        if group_exists:
            if len(members) == 0:
                print(f"\n⚠️  WARNING: Group exists but has no members!")
                print(f"   You need to add the 15 agent emails to this group.")
            elif len(members) < 15:
                print(f"\n⚠️  WARNING: Group has only {len(members)}/15 members")
            else:
                print(f"\n✅ Group has {len(members)} members (expected 15)")
    else:
        print(f"\n⚠️  Cannot verify group membership (Admin API not available)")
        print(f"   You can still test if the group works as a calendar attendee")
    
    # Test group as calendar attendee
    print("\n" + "="*80)
    group_works = test_group_as_calendar_attendee(calendar_service, GROUP_EMAIL)
    
    # Summary and recommendations
    print("\n" + "="*80)
    print("💡 SUMMARY & RECOMMENDATIONS")
    print("="*80)
    
    if group_works:
        print(f"\n✅ SUCCESS: Group email {GROUP_EMAIL} can be used as calendar attendee!")
        print(f"   You can now use this group email in calendar events.")
        print(f"   All members of the group will receive the invitation.")
    else:
        print(f"\n❌ Group email {GROUP_EMAIL} cannot be used as calendar attendee")
        print(f"\n   Possible reasons:")
        print(f"   1. Group doesn't exist or isn't configured correctly")
        print(f"   2. Group needs to be created in Google Workspace Admin Console")
        print(f"   3. Group needs to have 'Allow external members' enabled")
        print(f"   4. Group needs proper permissions for calendar invitations")
        print(f"\n   Solutions:")
        print(f"   1. Create the group in Google Workspace Admin Console")
        print(f"   2. Add all 15 agent emails as members")
        print(f"   3. Ensure group settings allow calendar invitations")
        print(f"   4. Wait a few minutes for group changes to propagate")
    
    # Alternative: Update meeting with group email
    if group_works:
        print(f"\n📅 Next Step: Update Meeting with Group Email")
        print(f"   Would you like to update the 2:30 PM meeting to use {GROUP_EMAIL}?")
        print(f"   This will send invitations to all group members.")
    
    print("\n" + "="*80)
    print("✅ Test complete")
    print("="*80)

if __name__ == "__main__":
    main()

