"""
Add All Agents to Group
This script uses the Admin SDK API to programmatically add all 15 agents
to the all.15.team.members@ratiovita.com group.
"""
import os
import sys
from datetime import datetime
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
import yaml
import time

# Scopes required - need write access for adding members
SCOPES = [
    'https://www.googleapis.com/auth/admin.directory.group.member',
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
            print(f"⚠️  Could not load token with requested scopes: {e}")
            try:
                creds = Credentials.from_authorized_user_file(token_path, None)
                if creds.scopes:
                    has_admin = any('admin.directory' in s for s in creds.scopes)
                    if has_admin:
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
            print("   You will need to grant Admin Directory API permissions")
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

def get_current_members(admin_service, group_email):
    """Get current members of the group"""
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

def add_member_to_group(admin_service, group_email, member_email, role='MEMBER'):
    """Add a member to the group"""
    try:
        member = {
            'email': member_email,
            'role': role
        }
        
        admin_service.members().insert(
            groupKey=group_email,
            body=member
        ).execute()
        
        return True, None
    except Exception as e:
        error_msg = str(e)
        # Check if member already exists
        if 'duplicate' in error_msg.lower() or 'already exists' in error_msg.lower():
            return True, 'already_exists'
        else:
            return False, error_msg

def main():
    """Main function to add all agents to group"""
    print("\n" + "="*80)
    print("👥 ADDING ALL AGENTS TO GROUP")
    print("="*80)
    print(f"Group: {GROUP_EMAIL}")
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}")
    print("="*80)
    
    # Get credentials
    print("\n🔐 Authenticating...")
    creds = get_credentials()
    
    # Build admin service
    try:
        admin_service = build('admin', 'directory_v1', credentials=creds)
        print("✅ Admin Directory API service built")
    except Exception as e:
        print(f"❌ Error building Admin service: {e}")
        return False
    
    # Load agents
    print("\n📋 Loading agent configurations...")
    agents_data = load_agents()
    agents = agents_data.get('agents', [])
    
    # Get all agent emails
    agent_emails = []
    agent_info = {}
    for agent in agents:
        email = agent.get('email_address', '')
        if email:
            agent_emails.append(email)
            agent_info[email] = {
                'role': agent.get('role', 'Unknown'),
                'email': email
            }
    
    print(f"✅ Found {len(agent_emails)} agent email addresses")
    
    # Get current members
    print(f"\n🔍 Checking current group members...")
    success, current_members_result = get_current_members(admin_service, GROUP_EMAIL)
    
    if not success:
        print(f"❌ Error getting current members: {current_members_result}")
        return False
    
    current_members = current_members_result
    current_member_emails = {m.get('email', '').lower() for m in current_members}
    
    print(f"✅ Current members: {len(current_members)}")
    if current_members:
        for member in current_members:
            email = member.get('email', 'Unknown')
            print(f"   • {email}")
    
    # Find missing agents
    missing_emails = []
    for email in agent_emails:
        if email.lower() not in current_member_emails:
            missing_emails.append(email)
    
    if not missing_emails:
        print(f"\n✅ All {len(agent_emails)} agents are already members!")
        return True
    
    print(f"\n📊 MEMBERSHIP STATUS:")
    print(f"   Total agents: {len(agent_emails)}")
    print(f"   Current members: {len(current_members)}")
    print(f"   Missing: {len(missing_emails)} agents")
    
    # Add missing agents
    print(f"\n📝 Adding {len(missing_emails)} missing agents...")
    print("="*80)
    
    results = []
    for i, email in enumerate(missing_emails, 1):
        role = agent_info.get(email, {}).get('role', 'Unknown')
        print(f"\n[{i}/{len(missing_emails)}] Adding: {email}")
        print(f"   Role: {role}")
        
        success, error = add_member_to_group(admin_service, GROUP_EMAIL, email)
        
        if success:
            if error == 'already_exists':
                print(f"   ⚠️  Already a member (may have been added concurrently)")
                results.append({'email': email, 'status': 'already_exists', 'error': None})
            else:
                print(f"   ✅ Successfully added!")
                results.append({'email': email, 'status': 'added', 'error': None})
        else:
            print(f"   ❌ Failed: {error}")
            results.append({'email': email, 'status': 'failed', 'error': error})
        
        # Small delay to avoid rate limiting
        if i < len(missing_emails):
            time.sleep(0.5)
    
    # Summary
    print("\n" + "="*80)
    print("📊 SUMMARY")
    print("="*80)
    
    added = sum(1 for r in results if r['status'] == 'added')
    already_exists = sum(1 for r in results if r['status'] == 'already_exists')
    failed = sum(1 for r in results if r['status'] == 'failed')
    
    print(f"\n✅ Successfully added: {added}")
    print(f"⚠️  Already existed: {already_exists}")
    print(f"❌ Failed: {failed}")
    
    if failed > 0:
        print(f"\n❌ Failed additions:")
        for r in results:
            if r['status'] == 'failed':
                print(f"   • {r['email']}: {r['error']}")
    
    # Verify final membership
    print(f"\n🔍 Verifying final membership...")
    time.sleep(2)  # Wait for changes to propagate
    
    success, final_members_result = get_current_members(admin_service, GROUP_EMAIL)
    if success:
        final_members = final_members_result
        final_member_emails = {m.get('email', '').lower() for m in final_members}
        agent_emails_lower = {email.lower() for email in agent_emails}
        
        print(f"✅ Final members: {len(final_members)}")
        
        if final_member_emails == agent_emails_lower:
            print(f"\n🎉 SUCCESS: All {len(agent_emails)} agents are now members!")
        else:
            still_missing = agent_emails_lower - final_member_emails
            if still_missing:
                print(f"\n⚠️  Still missing {len(still_missing)} agents:")
                for email in sorted(still_missing):
                    print(f"   • {email}")
            else:
                print(f"\n✅ All agents are members!")
    
    print("\n" + "="*80)
    print("✅ Process complete")
    print("="*80)
    print(f"\n💡 Note: Changes may take 5-15 minutes to fully propagate.")
    print(f"   Calendar invitations will be sent to all group members.")
    print("="*80)
    
    return added > 0 or already_exists > 0

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)


