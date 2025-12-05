"""
Verify Only One Meeting Exists at 14:30 EST
"""
import os
from datetime import datetime
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build

PROJECT_CALENDAR_ID = "c_4e1c24ca3fdea15ff6de1ee2e0d025f75a1f8ff58ef58e2119e5273e51a5e7dc@group.calendar.google.com"
SCOPES = ['https://www.googleapis.com/auth/calendar']

def get_credentials():
    creds = None
    if os.path.exists('token.json'):
        creds = Credentials.from_authorized_user_file('token.json', SCOPES)
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
    return creds

def main():
    print("\n" + "="*80)
    print("🔍 VERIFYING ONLY ONE MEETING AT 14:30 EST EXISTS")
    print("="*80)
    
    creds = get_credentials()
    calendar_service = build('calendar', 'v3', credentials=creds)
    
    today = datetime.now()
    start_of_day = today.replace(hour=0, minute=0, second=0, microsecond=0)
    end_of_day = today.replace(hour=23, minute=59, second=59, microsecond=0)
    
    time_min = start_of_day.isoformat() + 'Z'
    time_max = end_of_day.isoformat() + 'Z'
    
    events_result = calendar_service.events().list(
        calendarId=PROJECT_CALENDAR_ID,
        timeMin=time_min,
        timeMax=time_max,
        maxResults=50,
        singleEvents=True,
        orderBy='startTime'
    ).execute()
    
    events = events_result.get('items', [])
    strategy_meetings = []
    
    for event in events:
        event_title = event.get('summary', '')
        if 'Executive Strategy Group' in event_title or 'V1 Legacy Review' in event_title:
            strategy_meetings.append(event)
    
    print(f"\n📊 Found {len(strategy_meetings)} Executive Strategy Group Meeting(s):")
    print("="*80)
    
    for i, meeting in enumerate(strategy_meetings, 1):
        start_time = meeting.get('start', {}).get('dateTime', '')
        event_id = meeting.get('id', '')
        print(f"\n{i}. {meeting.get('summary', 'Unknown')}")
        print(f"   Start: {start_time}")
        print(f"   ID: {event_id}")
        
        # Parse time to check if it's 14:30
        try:
            from dateutil import parser
            start_dt = parser.parse(start_time)
            if start_dt.hour == 14 and start_dt.minute == 30:
                print(f"   ✅ CORRECT TIME: 14:30 EST")
            else:
                print(f"   ⚠️  WRONG TIME: {start_dt.hour}:{start_dt.minute:02d}")
        except:
            pass
    
    if len(strategy_meetings) == 1:
        print("\n" + "="*80)
        print("✅ SUCCESS: Only one meeting exists!")
        print("="*80)
    else:
        print("\n" + "="*80)
        print(f"⚠️  WARNING: Found {len(strategy_meetings)} meetings (expected 1)")
        print("="*80)

if __name__ == "__main__":
    main()

