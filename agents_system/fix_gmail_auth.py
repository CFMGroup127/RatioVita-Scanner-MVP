"""
Fix Gmail API 403 Error - Force Re-authentication with gmail.send scope
This script deletes the existing token.json and forces a fresh OAuth flow.
"""
import os
import shutil
from datetime import datetime
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request

# REQUIRED SCOPES - Must include gmail.send
SCOPES = [
    'https://www.googleapis.com/auth/documents',  # Write to Google Docs
    'https://www.googleapis.com/auth/documents.readonly',  # Read Google Docs
    'https://www.googleapis.com/auth/drive',  # Access Google Drive
    'https://www.googleapis.com/auth/drive.readonly',  # Read Google Drive
    'https://www.googleapis.com/auth/calendar',  # Google Calendar
    'https://www.googleapis.com/auth/gmail.send',  # CRITICAL: Gmail send permission
]

def fix_gmail_auth():
    """Delete token.json and force fresh OAuth authentication with gmail.send scope."""
    print("\n" + "="*80)
    print("🔐 FIXING GMAIL API AUTHENTICATION")
    print("="*80)
    print("\nThis will:")
    print("  1. Backup existing token.json (if it exists)")
    print("  2. Delete token.json to force fresh authentication")
    print("  3. Open browser for OAuth sign-in")
    print("  4. Verify gmail.send scope is granted")
    print("\n" + "="*80)
    
    token_file = 'token.json'
    backup_file = f'token.json.backup_{datetime.now().strftime("%Y%m%d_%H%M%S")}'
    
    # Backup existing token if it exists
    if os.path.exists(token_file):
        print(f"\n📦 Backing up existing token.json to {backup_file}...")
        shutil.copy2(token_file, backup_file)
        print("✅ Backup created")
        
        # Check current scopes
        try:
            creds = Credentials.from_authorized_user_file(token_file, SCOPES)
            if hasattr(creds, 'scopes') and creds.scopes:
                print("\n📋 Current token scopes:")
                for scope in creds.scopes:
                    has_gmail = 'gmail.send' in scope
                    status = "✅" if has_gmail else "❌"
                    print(f"  {status} {scope}")
                
                if not any('gmail.send' in s for s in creds.scopes):
                    print("\n⚠️  WARNING: Current token does NOT have gmail.send scope!")
                    print("   This is why you're getting 403 errors.")
        except Exception as e:
            print(f"⚠️  Could not read existing token: {e}")
        
        # Delete token.json
        print(f"\n🗑️  Deleting {token_file} to force fresh authentication...")
        os.remove(token_file)
        print("✅ Token deleted")
    else:
        print(f"\n📄 {token_file} not found - will create new one")
    
    # Check for credentials.json
    if not os.path.exists('credentials.json'):
        print("\n❌ ERROR: credentials.json not found!")
        print("Please ensure credentials.json is in the agents_system directory.")
        print("\nTo create credentials.json:")
        print("1. Go to: https://console.cloud.google.com/")
        print("2. Create OAuth 2.0 Client ID (Desktop app)")
        print("3. Download and save as 'credentials.json'")
        return None
    
    print("\n✅ Found credentials.json")
    
    # Start OAuth flow
    print("\n🌐 Starting OAuth authentication flow...")
    print("A browser window will open.")
    print("\n⚠️  CRITICAL: When prompted, make sure to:")
    print("   - Check ALL permission boxes")
    print("   - Specifically approve 'Send email on your behalf'")
    print("   - Grant access to Gmail")
    print("\n" + "="*80)
    
    try:
        flow = InstalledAppFlow.from_client_secrets_file('credentials.json', SCOPES)
        creds = flow.run_local_server(port=0)
        print("\n✅ Authentication successful!")
    except Exception as e:
        print(f"\n❌ Authentication failed: {e}")
        return None
    
    # Save new token
    print(f"\n💾 Saving new token to {token_file}...")
    with open(token_file, 'w') as token:
        token.write(creds.to_json())
    print("✅ Token saved")
    
    # Verify scopes
    print("\n📋 Verifying new token scopes...")
    token_scopes = creds.scopes if hasattr(creds, 'scopes') else []
    print(f"\nToken has {len(token_scopes)} scopes:")
    
    required_scopes = {
        'documents': False,
        'drive': False,
        'calendar': False,
        'gmail.send': False,
    }
    
    for scope in token_scopes:
        readonly = 'readonly' in scope
        status = "✅" if not readonly else "⚠️  (read-only)"
        print(f"  {status} {scope}")
        
        # Check for required scopes
        if 'auth/documents' in scope and 'readonly' not in scope:
            required_scopes['documents'] = True
        if 'auth/drive' in scope and 'readonly' not in scope:
            required_scopes['drive'] = True
        if 'auth/calendar' in scope:
            required_scopes['calendar'] = True
        if 'gmail.send' in scope:
            required_scopes['gmail.send'] = True
    
    # Verify all required scopes
    print("\n📊 Scope Verification:")
    all_good = True
    for scope_name, has_scope in required_scopes.items():
        status = "✅" if has_scope else "❌"
        print(f"  {status} {scope_name}: {'Granted' if has_scope else 'MISSING'}")
        if not has_scope:
            all_good = False
    
    if all_good:
        print("\n✅ ALL REQUIRED SCOPES GRANTED!")
        print("Gmail API should now work correctly.")
    else:
        print("\n⚠️  WARNING: Some required scopes are missing!")
        if not required_scopes['gmail.send']:
            print("   ❌ gmail.send is MISSING - this will cause 403 errors!")
            print("   Please re-run this script and ensure you approve Gmail permissions.")
    
    print("\n" + "="*80)
    print("✅ GMAIL AUTHENTICATION FIX COMPLETE")
    print("="*80)
    return creds

if __name__ == "__main__":
    fix_gmail_auth()


