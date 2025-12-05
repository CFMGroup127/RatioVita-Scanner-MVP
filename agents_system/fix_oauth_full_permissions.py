"""
Fix OAuth to Grant Full Permissions
This script deletes token.json and forces a fresh OAuth flow with ALL required scopes.
CRITICAL: This fixes the 403 errors preventing memory document access.
"""
import os
import json
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow

# ALL REQUIRED SCOPES - MUST INCLUDE FULL DOCUMENTS (NOT READONLY)
# Added Google Tasks API scope for P3 protocol (Hybrid System Phase 1)
SCOPES = [
    'https://www.googleapis.com/auth/documents',  # FULL read/write access (CRITICAL)
    'https://www.googleapis.com/auth/drive',
    'https://www.googleapis.com/auth/calendar',
    'https://www.googleapis.com/auth/gmail.send',
    'https://www.googleapis.com/auth/gmail.readonly',
    'https://www.googleapis.com/auth/tasks'  # Google Tasks API for P3 protocol (Hybrid System)
]

def fix_oauth_permissions():
    """
    Delete existing token.json and force fresh OAuth with all required scopes.
    """
    print("\n" + "="*80)
    print("🔧 FIXING OAUTH PERMISSIONS")
    print("="*80)
    print("This will delete token.json and force a fresh OAuth sign-in")
    print("with ALL required scopes, including full documents access.")
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
    
    try:
        flow = InstalledAppFlow.from_client_secrets_file('credentials.json', SCOPES)
        # CRITICAL: Request offline access to get a permanent refresh token
        # This ensures the token can be refreshed indefinitely without manual re-authentication
        creds = flow.run_local_server(port=0, access_type='offline', prompt='consent')
        
        # Save the credentials
        with open('token.json', 'w') as token:
            token.write(creds.to_json())
        
        print("\n✅ OAuth authentication successful!")
        print("   token.json created with all required scopes")
        
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
            print("   Agents can now:")
            print("   - Read and write to memory documents")
            print("   - Send and read emails")
            print("   - Manage calendar events")
            print("   - Access Google Drive")
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
    fix_oauth_permissions()

