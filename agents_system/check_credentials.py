#!/usr/bin/env python3
"""
Quick script to check if credentials.json exists and guide you to create it.
"""
import os

print("="*80)
print("Google API Credentials Checker")
print("="*80)
print()

current_dir = os.getcwd()
creds_file = os.path.join(current_dir, 'credentials.json')
token_file = os.path.join(current_dir, 'token.json')

print(f"Current directory: {current_dir}")
print()

# Check for credentials.json
if os.path.exists(creds_file):
    print("✅ FOUND: credentials.json")
    print(f"   Location: {creds_file}")
    print()
    
    # Check file size (should be a few KB)
    size = os.path.getsize(creds_file)
    print(f"   File size: {size} bytes")
    
    if size < 100:
        print("   ⚠️  WARNING: File seems too small. It might be empty or corrupted.")
    else:
        print("   ✅ File size looks good")
    
    # Check for token.json
    if os.path.exists(token_file):
        print()
        print("✅ FOUND: token.json")
        print("   You're ready to use Google APIs!")
    else:
        print()
        print("❌ MISSING: token.json")
        print("   Run: python3 setup_google_auth.py")
        print("   This will authenticate and create token.json")
    
else:
    print("❌ MISSING: credentials.json")
    print()
    print("To create credentials.json:")
    print()
    print("1. Go to: https://console.cloud.google.com/")
    print("2. Sign in with your Google account")
    print("3. Create a new project (or select existing)")
    print("4. Enable these APIs:")
    print("   - Google Docs API")
    print("   - Google Drive API")
    print("   - Google Calendar API")
    print("   - Gmail API")
    print("5. Go to: APIs & Services > Credentials")
    print("6. Click: + CREATE CREDENTIALS > OAuth client ID")
    print("7. Choose: Desktop app")
    print("8. Download the JSON file")
    print("9. Rename it to 'credentials.json'")
    print(f"10. Place it here: {creds_file}")
    print()
    print("📖 See CREATE_CREDENTIALS.md for detailed step-by-step instructions")
    print()

print("="*80)

