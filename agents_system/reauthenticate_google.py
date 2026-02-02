"""
Re-authenticate Google API with write permissions.
This script will trigger the OAuth flow to create a new token.json with write scopes.
"""
import os
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request

# Required scopes for writing to Google Docs
SCOPES = [
    'https://www.googleapis.com/auth/documents',  # Write to Google Docs
    'https://www.googleapis.com/auth/drive',      # Access Google Drive
    'https://www.googleapis.com/auth/calendar',   # Google Calendar
    'https://www.googleapis.com/auth/gmail.send'  # Send emails
]

def reauthenticate():
    """Re-authenticate and create new token.json with write permissions."""
    print("\n" + "="*80)
    print("🔐 GOOGLE API RE-AUTHENTICATION")
    print("="*80)
    print("\nThis will open a browser window for you to authenticate.")
    print("Please grant FULL permissions (not read-only).")
    print("\nRequired permissions:")
    for scope in SCOPES:
        print(f"  - {scope}")
    print("\n" + "="*80)
    
    creds = None
    
    # Check if token.json exists (it shouldn't if we deleted it)
    if os.path.exists('token.json'):
        print("\n⚠️  token.json already exists. Loading...")
        creds = Credentials.from_authorized_user_file('token.json', SCOPES)
    
    # If there are no (valid) credentials available, let the user log in.
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            print("\n🔄 Refreshing expired token...")
            try:
                creds.refresh(Request())
                print("✅ Token refreshed successfully")
            except Exception as e:
                print(f"❌ Failed to refresh token: {e}")
                print("Starting new authentication flow...")
                creds = None
        
        if not creds:
            if not os.path.exists('credentials.json'):
                print("\n❌ Error: credentials.json not found!")
                print("Please ensure credentials.json is in the agents_system directory.")
                return None
            
            print("\n🌐 Starting OAuth flow...")
            print("A browser window will open for authentication.")
            flow = InstalledAppFlow.from_client_secrets_file('credentials.json', SCOPES)
            creds = flow.run_local_server(port=0)
            print("\n✅ Authentication successful!")
        
        # Save the credentials for the next run
        with open('token.json', 'w') as token:
            token.write(creds.to_json())
        print("✅ Token saved to token.json")
        
        # Verify scopes
        print("\n📋 Verifying token scopes...")
        token_scopes = creds.scopes if hasattr(creds, 'scopes') else []
        print(f"Token has {len(token_scopes)} scopes:")
        for scope in token_scopes:
            readonly = 'readonly' in scope
            status = "✅" if not readonly else "⚠️  (read-only)"
            print(f"  {status} {scope}")
        
        # Check for write permissions
        has_write_docs = any('auth/documents' in s and 'readonly' not in s for s in token_scopes)
        has_write_drive = any('auth/drive' in s and 'readonly' not in s for s in token_scopes)
        
        if has_write_docs and has_write_drive:
            print("\n✅ Token has write permissions!")
            print("You can now use the Google Docs Memory Tool to write to documents.")
        else:
            print("\n⚠️  Warning: Token may not have full write permissions")
            if not has_write_docs:
                print("   - Missing: documents write scope")
            if not has_write_drive:
                print("   - Missing: drive write scope")
    
    print("\n" + "="*80)
    print("✅ RE-AUTHENTICATION COMPLETE")
    print("="*80)
    return creds

if __name__ == "__main__":
    reauthenticate()



