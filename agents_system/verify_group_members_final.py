"""
Final Verification of Group Members
This script waits and then carefully verifies all group members are present.
"""
import os
import sys
import time
from datetime import datetime
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
import yaml

SCOPES = [
    'https://www.googleapis.com/auth/admin.directory.group.readonly'
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
            except:
                pass
    
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            try:
                creds.refresh(Request())
            except:
                pass
    
    return creds

def load_agents():
    """Load agent configurations from agents.yaml"""
    with open('agents.yaml', 'r') as f:
        return yaml.safe_load(f)

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
    """Final verification"""
    print("\n" + "="*80)
    print("🔍 FINAL GROUP MEMBERSHIP VERIFICATION")
    print("="*80)
    print(f"Group: {GROUP_EMAIL}")
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}")
    print("="*80)
    
    # Wait a bit for propagation
    print("\n⏳ Waiting 10 seconds for changes to propagate...")
    time.sleep(10)
    
    # Get credentials
    creds = get_credentials()
    if not creds:
        print("❌ Could not get credentials")
        return False
    
    admin_service = build('admin', 'directory_v1', credentials=creds)
    
    # Load agents
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
    
    # Get current members
    print("\n🔍 Checking group members...")
    success, members_result = get_group_members(admin_service, GROUP_EMAIL)
    
    if not success:
        print(f"❌ Error: {members_result}")
        return False
    
    members = members_result
    member_emails = {m.get('email', '').lower() for m in members}
    
    print(f"\n📊 MEMBERSHIP STATUS:")
    print(f"   Expected: {len(expected_emails)} agents")
    print(f"   Current: {len(member_emails)} members")
    
    if members:
        print(f"\n👥 Current Members:")
        for i, member in enumerate(sorted(members, key=lambda x: x.get('email', '')), 1):
            email = member.get('email', 'Unknown')
            role = member.get('role', 'MEMBER')
            status = member.get('status', 'ACTIVE')
            agent_role = agent_info.get(email.lower(), {}).get('role', 'Not an agent')
            print(f"   {i:2d}. {email}")
            print(f"       Role: {role}, Status: {status}")
            print(f"       Agent: {agent_role}")
    
    # Check missing
    missing = expected_emails - member_emails
    
    if missing:
        print(f"\n❌ MISSING AGENTS ({len(missing)}):")
        for email in sorted(missing):
            role = agent_info.get(email.lower(), {}).get('role', 'Unknown')
            print(f"   • {email} ({role})")
    else:
        print(f"\n✅ SUCCESS: All {len(expected_emails)} agents are members!")
    
    print("\n" + "="*80)
    print("✅ Verification complete")
    print("="*80)
    
    return len(missing) == 0

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)


