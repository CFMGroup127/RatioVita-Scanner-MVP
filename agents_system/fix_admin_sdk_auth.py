"""
Fix Admin SDK Authentication
This script deletes the existing token and forces re-authentication
with Admin SDK scopes to enable group member management.
"""
import os
import json
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow

# REQUIRED SCOPES for Admin SDK group member management
SCOPES = [
    'https://www.googleapis.com/auth/admin.directory.group.member',  # Write access for members
    'https://www.googleapis.com/auth/admin.directory.group.readonly'  # Read access for groups
]

def fix_admin_sdk_auth():
    """
    Delete existing token.json and force fresh OAuth with Admin SDK scopes.
    """
    print("\n" + "="*80)
    print("🔧 FIXING ADMIN SDK AUTHENTICATION")
    print("="*80)
    print("This will delete token.json and force a fresh OAuth sign-in")
    print("with Admin SDK scopes for group member management.")
    print("="*80)
    
    # Check if credentials.json exists
    if not os.path.exists('credentials.json'):
        print("\n❌ ERROR: credentials.json not found!")
        print("   Please ensure credentials.json is in the agents_system directory")
        return False
    
    # Delete existing token.json if it exists
    if os.path.exists('token.json'):
        print("\n🗑️  Deleting existing token.json...")
        os.remove('token.json')
        print("   ✅ token.json deleted")
    else:
        print("\n⚠️  token.json not found - will create new one")
    
    # Start OAuth flow
    print("\n🔐 Starting OAuth flow...")
    print("   You will be prompted to sign in and grant permissions")
    print("   REQUIRED SCOPES:")
    for scope in SCOPES:
        print(f"      - {scope}")
    
    print("\n⚠️  IMPORTANT:")
    print("   - You must sign in as a Google Workspace SUPER ADMIN")
    print("   - The account must have permission to manage groups")
    print("   - Domain-wide delegation may be required")
    
    try:
        flow = InstalledAppFlow.from_client_secrets_file('credentials.json', SCOPES)
        # CRITICAL: Request offline access to get a permanent refresh token
        creds = flow.run_local_server(port=0, access_type='offline', prompt='consent')
        
        # Save the credentials
        with open('token.json', 'w') as token:
            token.write(creds.to_json())
        
        print("\n✅ OAuth authentication successful!")
        print("   token.json created with Admin SDK scopes")
        
        # Verify scopes
        print("\n📋 Verifying granted scopes...")
        granted_scopes = creds.scopes if hasattr(creds, 'scopes') else []
        
        for required_scope in SCOPES:
            found = any(required_scope in scope for scope in granted_scopes)
            status = "✅" if found else "❌"
            print(f"   {status} {required_scope}")
        
        all_granted = all(any(req in scope for scope in granted_scopes) for req in SCOPES)
        
        if all_granted:
            print("\n✅ ALL REQUIRED SCOPES GRANTED!")
            print("   You can now add members to groups programmatically.")
            return True
        else:
            print("\n⚠️  WARNING: Some scopes may be missing")
            print("   Please verify all scopes were granted during sign-in")
            return False
            
    except Exception as e:
        print(f"\n❌ Error during OAuth flow: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = fix_admin_sdk_auth()
    if success:
        print("\n" + "="*80)
        print("✅ Authentication fixed!")
        print("="*80)
        print("\n📝 Next step: Run add_agents_to_group.py again")
        print("   python3 add_agents_to_group.py")
        print("="*80)
    else:
        print("\n" + "="*80)
        print("❌ Authentication failed")
        print("="*80)
        print("\n💡 Troubleshooting:")
        print("   1. Ensure you're signed in as a Google Workspace SUPER ADMIN")
        print("   2. Check that Admin SDK API is enabled in Google Cloud Console")
        print("   3. Verify your account has permission to manage groups")
        print("   4. Domain-wide delegation may need to be configured")
        print("="*80)


