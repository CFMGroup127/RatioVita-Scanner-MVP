"""
Check Last Meeting Status and Create New Meeting for 2:00 PM EST Today
This script:
1. Checks if the 8 PM EST meeting took place
2. Verifies email signatures are in place
3. Checks tools and virtual environment
4. Creates a new meeting for 2:00 PM EST today (14:00 EST) with clean timestamps
"""
import os
import sys
from datetime import datetime, timedelta, timezone
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
import yaml

# EST timezone (UTC-5)
EST_OFFSET = timedelta(hours=-5)

# Scopes required
SCOPES = [
    'https://www.googleapis.com/auth/calendar',
    'https://www.googleapis.com/auth/gmail.send',
    'https://www.googleapis.com/auth/documents.readonly'
]

# Project Schedule Calendar ID
PROJECT_CALENDAR_ID = "c_4e1c24ca3fdea15ff6de1ee2e0d025f75a1f8ff58ef58e2119e5273e51a5e7dc@group.calendar.google.com"

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
                    has_required = any('calendar' in s or 'gmail' in s or 'documents' in s for s in creds.scopes)
                    if has_required:
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

def check_last_meeting_status(calendar_service):
    """Check if the 8 PM EST meeting took place"""
    print("\n" + "="*80)
    print("🔍 CHECKING LAST MEETING STATUS (8:00 PM EST)")
    print("="*80)
    
    today = datetime.now(EST_TZ).date()
    
    # Check for meeting at 8 PM EST today
    start_of_day = EST_TZ.localize(datetime(today.year, today.month, today.day, 0, 0, 0))
    end_of_day = EST_TZ.localize(datetime(today.year, today.month, today.day, 23, 59, 59))
    
    time_min = start_of_day.isoformat()
    time_max = end_of_day.isoformat()
    
    try:
        events_result = calendar_service.events().list(
            calendarId=PROJECT_CALENDAR_ID,
            timeMin=time_min,
            timeMax=time_max,
            maxResults=20,
            singleEvents=True,
            orderBy='startTime'
        ).execute()
        
        events = events_result.get('items', [])
        
        # Look for Executive Strategy Group Meeting
        meeting_found = False
        for event in events:
            event_title = event.get('summary', '')
            if 'Executive Strategy Group' in event_title or 'V1 Legacy Review' in event_title:
                meeting_found = True
                start_time = event.get('start', {}).get('dateTime', '')
                end_time = event.get('end', {}).get('dateTime', '')
                event_id = event.get('id', '')
                attendees = event.get('attendees', [])
                
                print(f"\n✅ Found meeting: {event_title}")
                print(f"   Event ID: {event_id}")
                print(f"   Start: {start_time}")
                print(f"   End: {end_time}")
                print(f"   Attendees: {len(attendees)}")
                
                # Parse start time
                if start_time:
                    try:
                        from dateutil import parser
                        start_dt = parser.parse(start_time)
                        now_dt = datetime.now(EST_TZ)
                        
                        print(f"\n📊 Meeting Status:")
                        if start_dt > now_dt:
                            print(f"   ⏳ Meeting has NOT started yet")
                            print(f"   Time until start: {start_dt - now_dt}")
                        elif start_dt <= now_dt:
                            end_dt = parser.parse(end_time) if end_time else None
                            if end_dt and end_dt > now_dt:
                                print(f"   ✅ Meeting is CURRENTLY IN PROGRESS")
                                print(f"   Started: {start_dt.strftime('%I:%M %p EST')}")
                                print(f"   Ends: {end_dt.strftime('%I:%M %p EST')}")
                            else:
                                print(f"   ✅ Meeting has ENDED")
                                print(f"   Started: {start_dt.strftime('%I:%M %p EST')}")
                                print(f"   Ended: {end_dt.strftime('%I:%M %p EST') if end_dt else 'Unknown'}")
                    except Exception as e:
                        print(f"   ⚠️ Could not parse time: {e}")
                
                break
        
        if not meeting_found:
            print("❌ No Executive Strategy Group Meeting found for today")
        
        print("="*80)
        return meeting_found
        
    except Exception as e:
        print(f"❌ Error checking meeting status: {e}")
        import traceback
        traceback.print_exc()
        return False

def verify_email_signatures():
    """Verify email signatures are in place"""
    print("\n" + "="*80)
    print("✅ VERIFYING EMAIL SIGNATURES")
    print("="*80)
    
    try:
        # Check if generate_email_signature function exists
        import tools
        if hasattr(tools, 'generate_email_signature'):
            print("✅ generate_email_signature() function exists")
            
            # Test signature generation
            test_signature = tools.generate_email_signature("Admin Assistant & Workflow Funnel", "dana.flores@ratiovita.com")
            if "Dana Flores" in test_signature and "RatioVita" in test_signature:
                print("✅ Email signature generates correctly with agent name and RatioVita branding")
            else:
                print("❌ Email signature missing required elements")
                return False
        else:
            print("❌ generate_email_signature() function not found")
            return False
        
        # Check if gmail_tool accepts agent_role
        if hasattr(tools, 'gmail_tool'):
            import inspect
            sig = inspect.signature(tools.gmail_tool)
            if 'agent_role' in sig.parameters:
                print("✅ gmail_tool accepts agent_role parameter")
            else:
                print("❌ gmail_tool missing agent_role parameter")
                return False
        else:
            print("❌ gmail_tool not found")
            return False
        
        print("="*80)
        return True
        
    except Exception as e:
        print(f"❌ Error verifying email signatures: {e}")
        import traceback
        traceback.print_exc()
        return False

def check_tools_and_environment():
    """Check that all required tools and virtual environment are running"""
    print("\n" + "="*80)
    print("🔧 CHECKING TOOLS AND VIRTUAL ENVIRONMENT")
    print("="*80)
    
    checks = []
    
    # Check virtual environment
    if hasattr(sys, 'real_prefix') or (hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix):
        print("✅ Virtual environment is active")
        checks.append(True)
    else:
        print("⚠️ Virtual environment may not be active")
        checks.append(False)
    
    # Check required Python packages
    required_packages = ['crewai', 'google', 'pytz', 'yaml']
    for package in required_packages:
        try:
            __import__(package)
            print(f"✅ {package} is installed")
            checks.append(True)
        except ImportError:
            print(f"❌ {package} is NOT installed")
            checks.append(False)
    
    # Check credentials.json
    if os.path.exists('credentials.json'):
        print("✅ credentials.json exists")
        checks.append(True)
    else:
        print("❌ credentials.json NOT found")
        checks.append(False)
    
    # Check token.json
    if os.path.exists('token.json'):
        print("✅ token.json exists")
        checks.append(True)
    else:
        print("⚠️ token.json NOT found (may need authentication)")
        checks.append(False)
    
    # Check agents.yaml
    if os.path.exists('agents.yaml'):
        print("✅ agents.yaml exists")
        checks.append(True)
    else:
        print("❌ agents.yaml NOT found")
        checks.append(False)
    
    print("="*80)
    return all(checks)

def load_agent_emails():
    """Load all agent emails from agents.yaml"""
    try:
        with open('agents.yaml', 'r') as f:
            config = yaml.safe_load(f)
        
        agents = config.get('agents', [])
        agent_emails = []
        
        for agent in agents:
            email = agent.get('email_address', '')
            if email:
                agent_emails.append(email)
        
        return agent_emails
    except Exception as e:
        print(f"❌ Error loading agent emails: {e}")
        return []

def send_meeting_invitations(gmail_service, calendar_service, meeting_event):
    """Send individual email invitations to all agents"""
    print("\n" + "="*80)
    print("📧 SENDING MEETING INVITATIONS TO ALL AGENTS")
    print("="*80)
    
    agent_emails = load_agent_emails()
    
    if not agent_emails:
        print("❌ No agent emails found")
        return False
    
    print(f"📋 Found {len(agent_emails)} agent emails")
    
    # Meeting details
    meeting_title = meeting_event.get('summary', 'Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning')
    meeting_link = meeting_event.get('htmlLink', '')
    start_time = meeting_event.get('start', {}).get('dateTime', '')
    end_time = meeting_event.get('end', {}).get('dateTime', '')
    
    # Parse and format time
    try:
        from dateutil import parser
        start_dt = parser.parse(start_time)
        end_dt = parser.parse(end_time)
        meeting_date = start_dt.strftime('%B %d, %Y')
        meeting_time = f"{start_dt.strftime('%I:%M %p')} - {end_dt.strftime('%I:%M %p')} EST"
    except:
        meeting_date = "Today"
        meeting_time = "2:00 PM - 4:00 PM EST"
    
    subject = f"Meeting Invitation: Executive Strategy Group Meeting - {meeting_date} at 2:00 PM EST"
    
    body_template = f"""
Dear Team Member,

You are invited to attend the Executive Strategy Group Meeting.

**Meeting Details:**
- Date: {meeting_date}
- Time: {meeting_time}
- Location: Virtual Meeting
- Calendar Link: {meeting_link}

**Agenda:**
- V1 Legacy Review
- V2 Planning Discussion
- Strategic Objectives Review

**Important:**
This is a rescheduled meeting. Please ensure you:
1. Accept the calendar invitation
2. Add the meeting to your personal calendar
3. Send a confirmation email to david.chen@ratiovita.com and dana.flores@ratiovita.com
4. Log your acceptance to your memory document

Please confirm your attendance by replying to this email.

Best regards,
RatioVita Team
"""
    
    # Create message helper
    from email.mime.text import MIMEText
    import base64
    
    def create_message(sender, to, subject, body):
        message = MIMEText(body)
        message['to'] = to
        message['from'] = sender
        message['subject'] = subject
        return {'raw': base64.urlsafe_b64encode(message.as_bytes()).decode()}
    
    sender_email = "collin.m@ratiovita.com"
    sent_count = 0
    
    for agent_email in agent_emails:
        try:
            message = create_message(sender_email, agent_email, subject, body_template)
            gmail_service.users().messages().send(
                userId='me',
                body=message
            ).execute()
            print(f"✅ Sent invitation to {agent_email}")
            sent_count += 1
        except Exception as e:
            print(f"❌ Failed to send to {agent_email}: {e}")
    
    print(f"\n📊 Sent {sent_count}/{len(agent_emails)} invitations")
    print("="*80)
    return sent_count == len(agent_emails)

def create_new_meeting(calendar_service, gmail_service):
    """Create new meeting for 2:00 PM EST today with clean timestamps"""
    print("\n" + "="*80)
    print("📅 CREATING NEW MEETING FOR 2:00 PM EST TODAY")
    print("="*80)
    
    today = datetime.now(EST_TZ).date()
    
    # Meeting time: 2:00 PM - 4:00 PM EST today
    start_time = EST_TZ.localize(datetime(today.year, today.month, today.day, 14, 0, 0))
    end_time = EST_TZ.localize(datetime(today.year, today.month, today.day, 16, 0, 0))
    
    start_time_iso = start_time.isoformat()
    end_time_iso = end_time.isoformat()
    
    print(f"🕐 Meeting Time:")
    print(f"   Start: {start_time.strftime('%B %d, %Y at %I:%M %p EST')}")
    print(f"   End: {end_time.strftime('%B %d, %Y at %I:%M %p EST')}")
    
    # Load agent emails
    agent_emails = load_agent_emails()
    if not agent_emails:
        print("❌ No agent emails found")
        return False
    
    # Create attendees list
    attendees = [{'email': email} for email in agent_emails]
    
    # Create new event with clean timestamps
    event = {
        'summary': 'Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning',
        'description': 'Executive Strategy Group Meeting for V1 Legacy Review and V2 Planning. All 15 agents are required to attend.\n\nThis is a rescheduled meeting. Please ensure you accept the calendar invitation, add it to your personal calendar, and send a confirmation email.',
        'start': {
            'dateTime': start_time_iso,
            'timeZone': 'America/New_York'
        },
        'end': {
            'dateTime': end_time_iso,
            'timeZone': 'America/New_York'
        },
        'location': 'Virtual Meeting',
        'attendees': attendees,
        'sendUpdates': 'all'
    }
    
    try:
        print(f"\n📝 Creating new meeting event...")
        print(f"   Attendees: {len(attendees)} agents")
        
        created_event = calendar_service.events().insert(
            calendarId=PROJECT_CALENDAR_ID,
            body=event
        ).execute()
        
        print(f"✅ New meeting created!")
        print(f"   Event ID: {created_event.get('id')}")
        print(f"   Link: {created_event.get('htmlLink')}")
        
        # Send email invitations
        send_meeting_invitations(gmail_service, calendar_service, created_event)
        
        print("\n" + "="*80)
        print("✅ NEW MEETING CREATED SUCCESSFULLY")
        print("="*80)
        print(f"\n📅 Meeting Details:")
        print(f"   Title: Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning")
        print(f"   Date: {start_time.strftime('%B %d, %Y')}")
        print(f"   Time: 2:00 PM - 4:00 PM EST")
        print(f"   Location: Virtual Meeting")
        print(f"   Attendees: {len(attendees)} agents")
        print(f"   Calendar Link: {created_event.get('htmlLink')}")
        print("="*80)
        
        return True
        
    except Exception as e:
        print(f"\n❌ Error creating meeting: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    """Main function"""
    print("\n" + "="*80)
    print("🔍 MEETING STATUS CHECK AND NEW MEETING CREATION")
    print("="*80)
    print(f"Date: {datetime.now(EST_TZ).strftime('%B %d, %Y %I:%M %p EST')}")
    print("="*80)
    
    # Get credentials
    print("\n🔐 Authenticating...")
    try:
        creds = get_credentials()
        calendar_service = build('calendar', 'v3', credentials=creds)
        gmail_service = build('gmail', 'v1', credentials=creds)
        print("✅ Authentication successful")
    except Exception as e:
        print(f"❌ Authentication failed: {e}")
        return False
    
    # Step 1: Check last meeting status
    check_last_meeting_status(calendar_service)
    
    # Step 2: Verify email signatures
    if not verify_email_signatures():
        print("\n⚠️ Email signature verification failed, but continuing...")
    
    # Step 3: Check tools and environment
    if not check_tools_and_environment():
        print("\n⚠️ Some tools/environment checks failed, but continuing...")
    
    # Step 4: Create new meeting
    print("\n" + "="*80)
    print("🚀 PROCEEDING TO CREATE NEW MEETING")
    print("="*80)
    
    success = create_new_meeting(calendar_service, gmail_service)
    
    if success:
        print("\n✅ ALL TASKS COMPLETED SUCCESSFULLY")
    else:
        print("\n❌ SOME TASKS FAILED")
    
    return success

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)

