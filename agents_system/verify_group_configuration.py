"""
Verify Group Configuration and Troubleshoot Member Addition
This script helps verify the all.15.team.members@ratiovita.com group configuration
and troubleshoot issues with adding members.
"""
import os
import sys
from datetime import datetime
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
import yaml

# Scopes required
SCOPES = [
    'https://www.googleapis.com/auth/calendar.readonly',
    'https://www.googleapis.com/auth/admin.directory.group.readonly',
    'https://www.googleapis.com/auth/admin.directory.group.member.readonly'
]

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

def check_group_exists(admin_service, group_email):
    """Check if group exists and get basic info"""
    try:
        group = admin_service.groups().get(groupKey=group_email).execute()
        return True, group
    except Exception as e:
        error_msg = str(e)
        if '404' in error_msg or 'not found' in error_msg.lower():
            return False, None
        else:
            return None, str(e)

def get_group_members(admin_service, group_email):
    """Get all members of the group"""
    try:
        members = []
        page_token = None
        
        while True:
            result = admin_service.members().list(
                groupKey=group_email,
                maxResults=200,
                pageToken=page_token
            ).execute()
            
            members.extend(result.get('members', []))
            page_token = result.get('nextPageToken')
            
            if not page_token:
                break
        
        return True, members
    except Exception as e:
        return False, str(e)

def main():
    """Main verification function"""
    print("\n" + "="*80)
    print("🔍 GROUP CONFIGURATION VERIFICATION & TROUBLESHOOTING")
    print("="*80)
    print(f"Group Email: {GROUP_EMAIL}")
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}")
    print("="*80)
    
    # Get credentials
    print("\n🔐 Authenticating...")
    creds = get_credentials()
    
    # Build services
    calendar_service = build('calendar', 'v3', credentials=creds)
    
    # Try to build admin service
    admin_service = None
    admin_available = False
    try:
        admin_service = build('admin', 'directory_v1', credentials=creds)
        admin_available = True
        print("✅ Admin Directory API available")
    except Exception as e:
        error_msg = str(e)
        if 'accessNotConfigured' in error_msg or '403' in error_msg:
            print("⚠️  Admin Directory API not enabled or insufficient permissions")
            print("   To enable: https://console.developers.google.com/apis/api/admin.googleapis.com")
        else:
            print(f"⚠️  Admin Directory API error: {e}")
    
    # Load expected agent emails
    print("\n📋 Loading agent configurations...")
    agents_data = load_agents()
    agents = agents_data.get('agents', [])
    
    expected_emails = set()
    agent_info = {}
    for agent in agents:
        email = agent.get('email_address', '')
        if email:
            expected_emails.add(email.lower())
            agent_info[email.lower()] = {
                'role': agent.get('role', 'Unknown'),
                'email': email
            }
    
    print(f"✅ Found {len(expected_emails)} agent email addresses")
    
    # Check group if admin service is available
    if admin_available and admin_service:
        print("\n" + "="*80)
        print("📊 GROUP INFORMATION")
        print("="*80)
        
        # Check if group exists
        print(f"\n🔍 Checking if group exists...")
        exists, group_info = check_group_exists(admin_service, GROUP_EMAIL)
        
        if exists:
            print(f"✅ Group exists!")
            print(f"   Name: {group_info.get('name', 'Unknown')}")
            print(f"   Email: {group_info.get('email', 'Unknown')}")
            print(f"   Description: {group_info.get('description', 'No description')}")
            print(f"   Admin Created: {group_info.get('adminCreated', False)}")
            print(f"   Direct Members Count: {group_info.get('directMembersCount', 'Unknown')}")
            
            # Get members
            print(f"\n👥 Checking group members...")
            success, members_result = get_group_members(admin_service, GROUP_EMAIL)
            
            if success:
                members = members_result
                member_emails = {m.get('email', '').lower() for m in members}
                
                print(f"✅ Found {len(members)} members in group")
                
                if members:
                    print(f"\n📋 Current Members:")
                    for i, member in enumerate(members, 1):
                        email = member.get('email', 'Unknown')
                        role = member.get('role', 'MEMBER')
                        status = member.get('status', 'ACTIVE')
                        agent_role = agent_info.get(email.lower(), {}).get('role', 'Not an agent')
                        print(f"   {i:2d}. {email}")
                        print(f"       Role: {role}, Status: {status}")
                        print(f"       Agent: {agent_role}")
                
                # Check which agents are missing
                missing = expected_emails - member_emails
                extra = member_emails - expected_emails
                
                print(f"\n📊 MEMBERSHIP ANALYSIS:")
                print(f"   Expected: {len(expected_emails)} agent emails")
                print(f"   Current: {len(member_emails)} members")
                print(f"   Missing: {len(missing)} agents")
                print(f"   Extra: {len(extra)} non-agent members")
                
                if missing:
                    print(f"\n❌ MISSING AGENTS ({len(missing)}):")
                    for email in sorted(missing):
                        role = agent_info.get(email.lower(), {}).get('role', 'Unknown')
                        print(f"   • {email} ({role})")
                
                if extra:
                    print(f"\n⚠️  EXTRA MEMBERS (not agents):")
                    for email in sorted(extra):
                        print(f"   • {email}")
                
                if not missing:
                    print(f"\n✅ SUCCESS: All {len(expected_emails)} agents are members!")
            else:
                print(f"❌ Error getting members: {members_result}")
        elif exists is False:
            print(f"❌ Group does not exist!")
            print(f"\n💡 SOLUTION: Create the group first")
            print(f"   1. Go to Google Workspace Admin Console")
            print(f"   2. Navigate to Directory > Groups")
            print(f"   3. Click 'Create Group'")
            print(f"   4. Set email: {GROUP_EMAIL}")
            print(f"   5. Set name: 'All 15 Team Members'")
            print(f"   6. Choose group type: 'Email list' or 'Security'")
        else:
            print(f"⚠️  Error checking group: {group_info}")
    else:
        print("\n" + "="*80)
        print("⚠️  ADMIN API NOT AVAILABLE")
        print("="*80)
        print("Cannot check group configuration programmatically.")
        print("You'll need to check manually in Google Workspace Admin Console.")
    
    # Test calendar invitation capability
    print("\n" + "="*80)
    print("📅 CALENDAR INVITATION TEST")
    print("="*80)
    
    try:
        # Check if group is in any calendar events
        today = datetime.now()
        start_of_day = today.replace(hour=0, minute=0, second=0, microsecond=0)
        end_of_day = today.replace(hour=23, minute=59, second=59, microsecond=0)
        
        events_result = calendar_service.events().list(
            calendarId='primary',
            timeMin=start_of_day.isoformat() + 'Z',
            timeMax=end_of_day.isoformat() + 'Z',
            maxResults=10
        ).execute()
        
        events = events_result.get('items', [])
        group_found = False
        
        for event in events:
            attendees = event.get('attendees', [])
            for att in attendees:
                if att.get('email', '').lower() == GROUP_EMAIL.lower():
                    group_found = True
                    print(f"✅ Group is used as attendee in: {event.get('summary', 'Unknown')}")
                    break
        
        if not group_found:
            print(f"ℹ️  Group not found in today's calendar events")
            print(f"   (This is normal if the meeting is on a different calendar)")
    except Exception as e:
        print(f"⚠️  Error checking calendar: {e}")
    
    # Troubleshooting guide
    print("\n" + "="*80)
    print("🔧 TROUBLESHOOTING GUIDE")
    print("="*80)
    
    print("\n📋 Common Issues & Solutions:")
    print("\n1. CAN'T ADD MEMBERS:")
    print("   • Check you have admin rights to modify the group")
    print("   • Verify the group type supports member management")
    print("   • Try adding one member at a time")
    print("   • Wait 5-15 minutes after group creation before adding members")
    
    print("\n2. MEMBERS NOT RECEIVING INVITATIONS:")
    print("   • Verify members are actually added (check group membership)")
    print("   • Check group email delivery settings")
    print("   • Ensure group can receive external emails")
    print("   • Verify member email addresses are valid")
    
    print("\n3. GROUP NOT FOUND:")
    print("   • Create the group in Google Workspace Admin Console")
    print("   • Use exact email: all.15.team.members@ratiovita.com")
    print("   • Choose appropriate group type (Email list recommended)")
    
    print("\n4. PERMISSION ERRORS:")
    print("   • Ensure you're logged in as a Workspace admin")
    print("   • Check Admin Console > Groups > Group Settings")
    print("   • Verify API access is enabled")
    
    print("\n" + "="*80)
    print("✅ Verification complete")
    print("="*80)
    
    # Next steps
    if admin_available and admin_service:
        exists, _ = check_group_exists(admin_service, GROUP_EMAIL)
        if exists:
            success, members_result = get_group_members(admin_service, GROUP_EMAIL)
            if success:
                members = members_result
                member_emails = {m.get('email', '').lower() for m in members}
                missing = expected_emails - member_emails
                
                if missing:
                    print(f"\n📝 NEXT STEPS:")
                    print(f"   1. Add {len(missing)} missing agents to the group")
                    print(f"   2. Wait 5-15 minutes for changes to propagate")
                    print(f"   3. Re-run this script to verify all members are added")

if __name__ == "__main__":
    main()

