"""
Kimi K2 OAuth Monitor & Auto-Fix
Automatically detects and handles OAuth issues, or notifies about them.
"""
import os
import sys
import subprocess
from pathlib import Path
from datetime import datetime
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from googleapiclient.errors import HttpError
from googleapiclient.discovery import build

def detect_oauth_issues(creds):
    """
    Detect OAuth issues by testing API access.
    
    Returns:
        dict with 'has_issues', 'missing_scopes', 'errors' keys
    """
    issues = {
        'has_issues': False,
        'missing_scopes': [],
        'errors': [],
        'services_affected': []
    }
    
    # Test each service
    services_to_test = [
        ('docs', 'v1', 'https://www.googleapis.com/auth/documents', 'Documents'),
        ('gmail', 'v1', 'https://www.googleapis.com/auth/gmail.readonly', 'Gmail'),
        ('calendar', 'v3', 'https://www.googleapis.com/auth/calendar.readonly', 'Calendar'),
        ('tasks', 'v1', 'https://www.googleapis.com/auth/tasks', 'Tasks'),
        ('drive', 'v3', 'https://www.googleapis.com/auth/drive.readonly', 'Drive')
    ]
    
    for service_name, version, scope, display_name in services_to_test:
        try:
            service = build(service_name, version, credentials=creds)
            # Try a simple API call
            if service_name == 'docs':
                # Test with a dummy document ID (will fail but show if auth works)
                try:
                    service.documents().get(documentId='test').execute()
                except HttpError as e:
                    if e.resp.status == 404:
                        # 404 means auth worked, doc just doesn't exist
                        pass
                    elif e.resp.status == 403:
                        issues['has_issues'] = True
                        issues['missing_scopes'].append(scope)
                        issues['services_affected'].append(display_name)
                        issues['errors'].append(f"{display_name}: {str(e)}")
            elif service_name == 'gmail':
                service.users().messages().list(userId='me', maxResults=1).execute()
            elif service_name == 'calendar':
                service.calendarList().list(maxResults=1).execute()
            elif service_name == 'tasks':
                service.tasklists().list().execute()
            elif service_name == 'drive':
                service.files().list(pageSize=1).execute()
        except HttpError as e:
            if e.resp.status == 403:
                issues['has_issues'] = True
                issues['missing_scopes'].append(scope)
                issues['services_affected'].append(display_name)
                issues['errors'].append(f"{display_name}: Insufficient permissions")
        except Exception as e:
            # Other errors (network, etc.) - not OAuth issues
            pass
    
    return issues

def auto_fix_oauth():
    """
    Automatically trigger OAuth re-authentication.
    
    Returns:
        bool: True if successful, False otherwise
    """
    print("\n" + "="*80)
    print("🔧 KIMI K2: AUTO-FIXING OAUTH ISSUES")
    print("="*80)
    print()
    
    try:
        # Run the OAuth fix script
        script_path = Path(__file__).parent / 'fix_oauth_full_permissions.py'
        if not script_path.exists():
            print("❌ Error: fix_oauth_full_permissions.py not found")
            return False
        
        print("🔄 Triggering OAuth re-authentication...")
        print("   This will open a browser window for authentication")
        print()
        
        result = subprocess.run(
            [sys.executable, str(script_path)],
            capture_output=False,
            text=True
        )
        
        if result.returncode == 0:
            print()
            print("✅ OAuth re-authentication successful!")
            return True
        else:
            print()
            print("❌ OAuth re-authentication failed")
            return False
            
    except Exception as e:
        print(f"❌ Error during auto-fix: {e}")
        import traceback
        traceback.print_exc()
        return False

def notify_oauth_issues(issues, auto_fix_attempted=False):
    """
    Send notification about OAuth issues.
    
    Args:
        issues: Dict from detect_oauth_issues()
        auto_fix_attempted: Whether auto-fix was attempted
    """
    from send_email_direct import send_email_direct
    
    subject = "[KIMI K2 ALERT] OAuth Authentication Issues Detected"
    
    body = f"""
🚨 OAUTH AUTHENTICATION ISSUES DETECTED

================================================================================
KIMI K2 OAUTH MONITOR ALERT
================================================================================

Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}
Monitor: Kimi K2 - OAuth Monitor & Auto-Fix

================================================================================

ISSUES DETECTED:

"""
    
    if issues['has_issues']:
        body += f"""
❌ OAuth Issues Found: YES

Affected Services:
"""
        for service in issues['services_affected']:
            body += f"   - {service}\n"
        
        body += f"""
Missing Scopes:
"""
        for scope in issues['missing_scopes']:
            body += f"   - {scope}\n"
        
        body += f"""
Errors:
"""
        for error in issues['errors']:
            body += f"   - {error}\n"
    else:
        body += "✅ No OAuth issues detected\n"
    
    body += f"""
================================================================================

AUTO-FIX STATUS:
"""
    
    if auto_fix_attempted:
        body += "✅ Auto-fix was attempted\n"
        body += "   Please verify authentication was successful\n"
    else:
        body += "⚠️  Auto-fix was not attempted\n"
        body += "   Manual intervention required\n"
    
    body += f"""
================================================================================

RECOMMENDED ACTIONS:

1. Run OAuth fix script:
   cd agents_system
   python3 fix_oauth_full_permissions.py

2. Re-authenticate with all required scopes

3. Verify all services are accessible

4. Re-run orchestrator after fix

================================================================================

This is an automated alert from the RatioVita V2 system.
Kimi K2 detected OAuth issues that may prevent system operations.

---
Kimi K2 - OAuth Monitor & Auto-Fix
RatioVita V2 Multi-Agent System
"""
    
    try:
        result = send_email_direct(
            to_list="collin.m@ratiovita.com",
            subject=subject,
            body=body,
            cc_list="david.chen@ratiovita.com,dana.flores@ratiovita.com",
            agent_role="Kimi K2 - OAuth Monitor"
        )
        print(f"✅ OAuth alert sent: {result}")
        return True
    except Exception as e:
        print(f"⚠️  Could not send OAuth alert: {e}")
        return False

def monitor_and_fix_oauth(auto_fix=True, notify=True):
    """
    Monitor OAuth status and automatically fix or notify.
    
    Args:
        auto_fix: Whether to attempt automatic fix
        notify: Whether to send notifications
    
    Returns:
        dict: Status report
    """
    print("\n" + "="*80)
    print("🔍 KIMI K2: OAUTH MONITORING & AUTO-FIX")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
    
    # Get credentials
    SCOPES = [
        'https://www.googleapis.com/auth/documents',
        'https://www.googleapis.com/auth/drive.readonly',
        'https://www.googleapis.com/auth/gmail.readonly',
        'https://www.googleapis.com/auth/calendar.readonly',
        'https://www.googleapis.com/auth/tasks'
    ]
    
    creds = None
    if os.path.exists('token.json'):
        try:
            creds = Credentials.from_authorized_user_file('token.json', SCOPES)
        except:
            pass
    
    if not creds:
        print("❌ No credentials found")
        if auto_fix:
            print("🔄 Attempting auto-fix...")
            if auto_fix_oauth():
                print("✅ Auto-fix successful - credentials restored")
                return {'status': 'fixed', 'action': 'auto_fix'}
            else:
                if notify:
                    notify_oauth_issues({'has_issues': True, 'errors': ['No credentials found']}, auto_fix_attempted=True)
                return {'status': 'failed', 'action': 'auto_fix_attempted'}
        else:
            if notify:
                notify_oauth_issues({'has_issues': True, 'errors': ['No credentials found']}, auto_fix_attempted=False)
            return {'status': 'failed', 'action': 'notified'}
    
    # Detect issues
    print("🔍 Detecting OAuth issues...")
    issues = detect_oauth_issues(creds)
    
    if not issues['has_issues']:
        print("✅ No OAuth issues detected - all services accessible")
        return {'status': 'ok', 'issues': None}
    
    print(f"❌ OAuth issues detected: {len(issues['services_affected'])} services affected")
    
    # Attempt auto-fix if enabled
    if auto_fix:
        print("🔄 Attempting auto-fix...")
        if auto_fix_oauth():
            print("✅ Auto-fix successful")
            if notify:
                notify_oauth_issues(issues, auto_fix_attempted=True)
            return {'status': 'fixed', 'issues': issues, 'action': 'auto_fix'}
        else:
            print("❌ Auto-fix failed")
            if notify:
                notify_oauth_issues(issues, auto_fix_attempted=True)
            return {'status': 'failed', 'issues': issues, 'action': 'auto_fix_attempted'}
    else:
        if notify:
            notify_oauth_issues(issues, auto_fix_attempted=False)
        return {'status': 'notified', 'issues': issues, 'action': 'notified'}

if __name__ == "__main__":
    monitor_and_fix_oauth(auto_fix=True, notify=True)

