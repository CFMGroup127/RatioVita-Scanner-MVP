"""
Direct Google Tasks API Test
Isolated test to debug the Google Tasks API integration.
"""
import os
import sys
from datetime import datetime
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

def test_google_tasks_direct():
    """Test Google Tasks Tool directly with known-good parameters"""
    print("🧪 DIRECT GOOGLE TASKS API TEST")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
    
    # Test parameters
    test_task = {
        'task_title': 'TEST: P3 Hybrid System Validation',
        'task_notes': 'This is a test task created to validate Google Tasks API integration for P3 protocol. Created: ' + datetime.now().strftime('%Y-%m-%d %H:%M:%S EST'),
        'due_date': '2025-11-22',  # Tomorrow
        'task_list_id': '@default'
    }
    
    print("📋 Test Parameters:")
    print(f"   Task Title: {test_task['task_title']}")
    print(f"   Task Notes: {test_task['task_notes'][:80]}...")
    print(f"   Due Date: {test_task['due_date']}")
    print(f"   Task List ID: {test_task['task_list_id']}\n")
    
    print("🚀 Calling Google Tasks Tool directly...")
    print("="*80)
    
    try:
        # Direct API call to test Google Tasks API
        SCOPES = ['https://www.googleapis.com/auth/tasks']
        
        # Get credentials
        creds = None
        if os.path.exists('token.json'):
            try:
                creds = Credentials.from_authorized_user_file('token.json', SCOPES)
            except:
                try:
                    creds = Credentials.from_authorized_user_file('token.json', None)
                    if creds and creds.scopes:
                        if 'https://www.googleapis.com/auth/tasks' not in creds.scopes:
                            creds = creds.with_scopes(creds.scopes + SCOPES)
                except:
                    pass
        
        if not creds or not creds.valid:
            if creds and creds.expired and creds.refresh_token:
                try:
                    creds.refresh(Request())
                except:
                    result = "ERROR: Could not get credentials for Google Tasks API. Please run fix_oauth_full_permissions.py with Tasks scope."
                    print(result)
                    return False
            else:
                result = "ERROR: Could not get credentials for Google Tasks API. Please run fix_oauth_full_permissions.py with Tasks scope."
                print(result)
                return False
        
        service = build('tasks', 'v1', credentials=creds)
        
        # Build task body
        task_body = {
            'title': test_task['task_title'],
            'status': 'needsAction'
        }
        
        if test_task['task_notes']:
            task_body['notes'] = test_task['task_notes']
        
        if test_task['due_date']:
            try:
                due_dt = datetime.strptime(test_task['due_date'], '%Y-%m-%d')
                task_body['due'] = due_dt.strftime('%Y-%m-%dT%H:%M:%S.000Z')
            except ValueError:
                task_body['due'] = test_task['due_date']
        
        # Insert task
        api_result = service.tasks().insert(
            tasklist=test_task['task_list_id'],
            body=task_body
        ).execute()
        
        task_id = api_result.get('id')
        task_url = f"https://tasks.google.com/embed/list/{test_task['task_list_id']}/tasks/{task_id}"
        
        result = f"SUCCESS: Task '{test_task['task_title']}' created in Google Tasks (ID: {task_id}). Visible in Tasks Sidebar. URL: {task_url}"
        
        print("\n" + "="*80)
        print("✅ GOOGLE TASKS API TEST RESULT")
        print("="*80)
        print(result)
        print("\n📋 Analysis:")
        if "SUCCESS" in result:
            print("   ✅ Google Tasks API call successful")
            print("   ✅ Task created in Google Tasks")
            print("   ✅ Task should be visible in Google Tasks Sidebar")
        elif "ERROR" in result:
            print("   ❌ Google Tasks API call failed")
            print("   🔍 Error details in result above")
        else:
            print("   ⚠️  Unexpected response format")
        
        return "SUCCESS" in result
        
    except Exception as e:
        print(f"\n❌ Exception during test: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = test_google_tasks_direct()
    sys.exit(0 if success else 1)

