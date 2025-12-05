#!/usr/bin/env python3
"""
Google API Authentication Setup Script
This script helps you authenticate with Google APIs for the agent system.
"""
import os
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials

# Required scopes for all Google services
SCOPES = [
    'https://www.googleapis.com/auth/documents',  # Google Docs (write)
    'https://www.googleapis.com/auth/documents.readonly',  # Google Docs (read)
    'https://www.googleapis.com/auth/drive',  # Google Drive (access)
    'https://www.googleapis.com/auth/drive.readonly',  # Google Drive (read)
    'https://www.googleapis.com/auth/calendar',  # Google Calendar
    'https://www.googleapis.com/auth/gmail.send',  # Gmail (send)
]

def main():
    creds = None
    token_file = 'token.json'
    creds_file = 'credentials.json'
    
    print("="*80)
    print("Google API Authentication Setup")
    print("="*80)
    print()
    
    # Check if credentials.json exists
    if not os.path.exists(creds_file):
        print(f"❌ ERROR: {creds_file} not found!")
        print()
        print("To get credentials.json:")
        print("1. Go to: https://console.cloud.google.com/")
        print("2. Create a new project or select existing one")
        print("3. Enable these APIs:")
        print("   - Google Docs API")
        print("   - Google Drive API")
        print("   - Google Calendar API")
        print("   - Gmail API")
        print("4. Go to: APIs & Services > Credentials")
        print("5. Click 'Create Credentials' > 'OAuth client ID'")
        print("6. Choose 'Desktop app' as application type")
        print("7. Download the JSON file and save it as 'credentials.json' in this directory")
        print()
        print(f"Current directory: {os.getcwd()}")
        print()
        return
    
    print(f"✅ Found {creds_file}")
    
    # Check if token.json exists
    if os.path.exists(token_file):
        print(f"✅ Found existing {token_file}")
        try:
            creds = Credentials.from_authorized_user_file(token_file, SCOPES)
            print("✅ Loaded existing credentials")
        except Exception as e:
            print(f"⚠️  Could not load existing token: {e}")
            creds = None
    
    # If there are no (valid) credentials available, let the user log in
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            print("🔄 Refreshing expired credentials...")
            try:
                creds.refresh(Request())
                print("✅ Credentials refreshed successfully")
            except Exception as e:
                print(f"❌ Failed to refresh: {e}")
                print("🔄 Need to re-authenticate...")
                creds = None
        
        if not creds:
            print()
            print("🔐 Starting OAuth flow...")
            print("A browser window will open. Please:")
            print("1. Sign in with your Google account")
            print("2. Grant permissions for the requested scopes")
            print("3. Return here when complete")
            print()
            print("Opening browser in 3 seconds...")
            import time
            time.sleep(3)
            
            try:
                flow = InstalledAppFlow.from_client_secrets_file(creds_file, SCOPES)
                creds = flow.run_local_server(port=0)
                print("✅ Authentication successful!")
            except Exception as e:
                print(f"❌ Authentication failed: {e}")
                return
        
        # Save the credentials for the next run
        with open(token_file, 'w') as token:
            token.write(creds.to_json())
        print(f"✅ Credentials saved to {token_file}")
    
    print()
    print("="*80)
    print("✅ Google API Authentication Complete!")
    print("="*80)
    print()
    print("You can now run the agent system with Google API integration.")
    print()

if __name__ == '__main__':
    main()

