"""
Test Victor Alvarez Email and Calendar Functionality
This script tests both email sending and calendar access for Victor Alvarez.
"""
import os
from datetime import datetime
from config import Config
from main import load_agents_from_yaml, get_agent_metadata
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
import json

# Scopes needed for testing
SCOPES = [
    'https://www.googleapis.com/auth/gmail.send',
    'https://www.googleapis.com/auth/calendar',
    'https://www.googleapis.com/auth/documents.readonly'
]

def get_credentials():
    """Get valid user credentials from storage."""
    creds = None
    if os.path.exists('token.json'):
        creds = Credentials.from_authorized_user_file('token.json', SCOPES)
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            from google_auth_oauthlib.flow import InstalledAppFlow
            flow = InstalledAppFlow.from_client_secrets_file('credentials.json', SCOPES)
            creds = flow.run_local_server(port=0)
        with open('token.json', 'w') as token:
            token.write(creds.to_json())
    return creds

def test_victor_email_calendar():
    """
    Test Victor Alvarez's email and calendar functionality.
    """
    print("\n" + "="*80)
    print("🧪 TESTING VICTOR ALVAREZ EMAIL & CALENDAR")
    print("="*80)
    print(f"Test Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}")
    print("="*80)
    
    # Validate configuration
    try:
        Config.validate()
        print("✅ Configuration validated")
    except ValueError as e:
        print(f"❌ Configuration Error: {e}")
        return None
    
    # Load agents
    print("\n📋 Loading agents...")
    try:
        agents = load_agents_from_yaml('agents.yaml')
        print(f"✅ Loaded {len(agents)} agents")
    except Exception as e:
        print(f"❌ Error loading agents: {e}")
        return None
    
    # Get Victor's metadata
    victor_meta = get_agent_metadata("Go-to-Market Strategy")
    victor_email = victor_meta.get('email_address', 'victor.alvarez@ratiovita.com')
    victor_calendar_id = victor_meta.get('personal_calendar_id', '')
    victor_memory_doc_id = victor_meta.get('memory_doc_id', '')
    
    print("\n" + "="*80)
    print("👤 VICTOR ALVAREZ CONFIGURATION")
    print("="*80)
    print(f"Role: Go-to-Market Strategy")
    print(f"Email: {victor_email}")
    print(f"Calendar ID: {victor_calendar_id}")
    print(f"Memory Doc ID: {victor_memory_doc_id}")
    
    # Test 1: Email Configuration Check
    print("\n" + "="*80)
    print("📧 TEST 1: EMAIL CONFIGURATION CHECK")
    print("="*80)
    
    # Check if email is in invalid list
    try:
        from email_filter_helper import INVALID_EMAILS
        is_invalid = victor_email.lower() in [e.lower() for e in INVALID_EMAILS]
        if is_invalid:
            print(f"⚠️  Email is in INVALID_EMAILS list: {victor_email}")
            print("   This means it will be filtered out from mass communications")
        else:
            print(f"✅ Email is NOT in INVALID_EMAILS list")
            print("   Email will be included in all communications")
    except ImportError:
        print("⚠️  email_filter_helper.py not found - cannot check invalid list")
    
    # Test 2: Send Test Email
    print("\n" + "="*80)
    print("📧 TEST 2: SENDING TEST EMAIL TO VICTOR")
    print("="*80)
    
    try:
        creds = get_credentials()
        gmail_service = build('gmail', 'v1', credentials=creds)
        
        # Create test email
        test_subject = f"Test Email - Victor Alvarez Functionality Check - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
        test_body = f"""
This is a test email to verify Victor Alvarez's email functionality.

Test Details:
- Recipient: {victor_email}
- Test Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}
- Purpose: Verify email delivery capability

If you receive this email, Victor's email address is functioning correctly.
"""
        
        # Create message
        from email.mime.text import MIMEText
        import base64
        
        message = MIMEText(test_body)
        message['to'] = victor_email
        message['subject'] = test_subject
        message['from'] = 'collin.m@ratiovita.com'  # Using your email as sender
        
        raw_message = base64.urlsafe_b64encode(message.as_bytes()).decode()
        
        print(f"📤 Attempting to send test email to: {victor_email}")
        
        try:
            result = gmail_service.users().messages().send(
                userId='me',
                body={'raw': raw_message}
            ).execute()
            
            message_id = result.get('id', '')
            print(f"✅ Email sent successfully!")
            print(f"   Message ID: {message_id}")
            print(f"   Recipient: {victor_email}")
            print(f"   Subject: {test_subject}")
            print(f"\n📬 Check Victor's inbox ({victor_email}) to confirm receipt")
            
            email_test_passed = True
            
        except Exception as email_error:
            error_str = str(email_error)
            print(f"❌ Email send failed!")
            print(f"   Error: {error_str}")
            
            if 'invalid' in error_str.lower() or 'not found' in error_str.lower() or 'address' in error_str.lower():
                print(f"\n⚠️  DIAGNOSIS: Email address appears to be invalid")
                print(f"   - The email '{victor_email}' may not exist in your email system")
                print(f"   - You may need to create this email address in Google Workspace")
                print(f"   - Or update it using: python3 update_victor_email.py")
            elif 'permission' in error_str.lower() or 'insufficient' in error_str.lower():
                print(f"\n⚠️  DIAGNOSIS: Permission issue")
                print(f"   - Gmail API may not have send permission")
                print(f"   - Check token.json has gmail.send scope")
            else:
                print(f"\n⚠️  DIAGNOSIS: Unknown error - check error message above")
            
            email_test_passed = False
            
    except Exception as e:
        print(f"❌ Error setting up email test: {e}")
        email_test_passed = False
    
    # Test 3: Calendar Access
    print("\n" + "="*80)
    print("📅 TEST 3: CALENDAR ACCESS CHECK")
    print("="*80)
    
    if not victor_calendar_id:
        print("⚠️  No calendar ID configured for Victor")
        calendar_test_passed = False
    else:
        try:
            creds = get_credentials()
            calendar_service = build('calendar', 'v3', credentials=creds)
            
            print(f"📅 Attempting to access calendar: {victor_calendar_id}")
            
            try:
                # Try to get calendar info
                calendar = calendar_service.calendars().get(calendarId=victor_calendar_id).execute()
                
                calendar_name = calendar.get('summary', 'Unknown')
                calendar_timezone = calendar.get('timeZone', 'Unknown')
                
                print(f"✅ Calendar access successful!")
                print(f"   Calendar Name: {calendar_name}")
                print(f"   Time Zone: {calendar_timezone}")
                print(f"   Calendar ID: {victor_calendar_id}")
                
                # Try to list events
                print(f"\n📋 Attempting to list calendar events...")
                events_result = calendar_service.events().list(
                    calendarId=victor_calendar_id,
                    maxResults=5,
                    timeMin=datetime.now().isoformat() + 'Z'
                ).execute()
                
                events = events_result.get('items', [])
                print(f"✅ Found {len(events)} upcoming events")
                
                if events:
                    print(f"\n   Upcoming events:")
                    for event in events[:3]:
                        event_title = event.get('summary', 'No title')
                        event_start = event.get('start', {}).get('dateTime', event.get('start', {}).get('date', 'Unknown'))
                        print(f"   - {event_title} ({event_start})")
                
                calendar_test_passed = True
                
            except Exception as calendar_error:
                error_str = str(calendar_error)
                print(f"❌ Calendar access failed!")
                print(f"   Error: {error_str}")
                
                if 'not found' in error_str.lower() or '404' in error_str:
                    print(f"\n⚠️  DIAGNOSIS: Calendar not found")
                    print(f"   - Calendar ID may be incorrect: {victor_calendar_id}")
                    print(f"   - Calendar may not exist or may have been deleted")
                elif 'permission' in error_str.lower() or '403' in error_str:
                    print(f"\n⚠️  DIAGNOSIS: Permission issue")
                    print(f"   - You may not have access to this calendar")
                    print(f"   - Calendar may need to be shared with your account")
                else:
                    print(f"\n⚠️  DIAGNOSIS: Unknown error - check error message above")
                
                calendar_test_passed = False
                
        except Exception as e:
            print(f"❌ Error setting up calendar test: {e}")
            calendar_test_passed = False
    
    # Test 4: Memory Document Access
    print("\n" + "="*80)
    print("📄 TEST 4: MEMORY DOCUMENT ACCESS")
    print("="*80)
    
    if not victor_memory_doc_id:
        print("⚠️  No memory document ID configured for Victor")
        memory_test_passed = False
    else:
        try:
            creds = get_credentials()
            docs_service = build('docs', 'v1', credentials=creds)
            
            print(f"📄 Attempting to access memory document: {victor_memory_doc_id}")
            
            try:
                doc = docs_service.documents().get(documentId=victor_memory_doc_id).execute()
                
                doc_title = doc.get('title', 'Unknown')
                print(f"✅ Memory document access successful!")
                print(f"   Document Title: {doc_title}")
                print(f"   Document ID: {victor_memory_doc_id}")
                
                # Get content length
                content = doc.get('body', {}).get('content', [])
                print(f"   Document has {len(content)} content elements")
                
                memory_test_passed = True
                
            except Exception as memory_error:
                error_str = str(memory_error)
                print(f"❌ Memory document access failed!")
                print(f"   Error: {error_str}")
                
                if 'not found' in error_str.lower() or '404' in error_str:
                    print(f"\n⚠️  DIAGNOSIS: Document not found")
                    print(f"   - Document ID may be incorrect: {victor_memory_doc_id}")
                    print(f"   - Document may not exist or may have been deleted")
                else:
                    print(f"\n⚠️  DIAGNOSIS: Unknown error - check error message above")
                
                memory_test_passed = False
                
        except Exception as e:
            print(f"❌ Error setting up memory document test: {e}")
            memory_test_passed = False
    
    # Summary
    print("\n" + "="*80)
    print("📊 TEST SUMMARY")
    print("="*80)
    
    tests = {
        'Email Configuration': True,  # Always passes (just a check)
        'Email Send': email_test_passed if 'email_test_passed' in locals() else False,
        'Calendar Access': calendar_test_passed if 'calendar_test_passed' in locals() else False,
        'Memory Document': memory_test_passed if 'memory_test_passed' in locals() else False
    }
    
    print(f"\n{'Test':<30} {'Status'}")
    print("-" * 80)
    for test_name, passed in tests.items():
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"{test_name:<30} {status}")
    
    all_passed = all(tests.values())
    
    print("\n" + "="*80)
    if all_passed:
        print("✅ ALL TESTS PASSED - Victor Alvarez is fully functional!")
    else:
        print("⚠️  SOME TESTS FAILED - See details above")
        print("\n📝 RECOMMENDATIONS:")
        if not tests.get('Email Send', True):
            print("   - Fix Victor's email address (run: python3 update_victor_email.py)")
            print("   - Or create victor.alvarez@ratiovita.com in Google Workspace")
        if not tests.get('Calendar Access', True):
            print("   - Verify calendar ID is correct in agents.yaml")
            print("   - Ensure calendar is shared with your account")
        if not tests.get('Memory Document', True):
            print("   - Verify memory document ID is correct in agents.yaml")
            print("   - Ensure document exists and is accessible")
    print("="*80)
    
    return {
        'email_test': email_test_passed if 'email_test_passed' in locals() else False,
        'calendar_test': calendar_test_passed if 'calendar_test_passed' in locals() else False,
        'memory_test': memory_test_passed if 'memory_test_passed' in locals() else False,
        'all_passed': all_passed
    }

if __name__ == "__main__":
    test_victor_email_calendar()


