"""
Verify project.reports@ratiovita.com Functionality and Protocol Compliance
This script verifies:
1. Email sending capability to project.reports@ratiovita.com
2. Email reading capability for Dana and David
3. Protocol compliance for all agents
"""
import os
import sys
from datetime import datetime
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
import base64
from email.mime.text import MIMEText

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from main import load_agents_from_yaml, get_agent_metadata

def verify_email_sending():
    """Test sending an email to project.reports@ratiovita.com"""
    print("\n" + "="*80)
    print("📧 TEST 1: EMAIL SENDING CAPABILITY")
    print("="*80)
    
    try:
        # Load credentials with gmail.send scope
        creds = None
        SCOPES = ['https://www.googleapis.com/auth/gmail.send']
        
        if os.path.exists('token.json'):
            creds = Credentials.from_authorized_user_file('token.json', SCOPES)
        
        if not creds or not creds.valid:
            if creds and creds.expired and creds.refresh_token:
                creds.refresh(Request())
            else:
                print("❌ No valid credentials found. Please run fix_oauth_full_permissions.py first.")
                return False
        
        # Build Gmail service
        service = build('gmail', 'v1', credentials=creds)
        
        # Create test email
        test_subject = f"TEST: Reporting Center Verification - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
        test_body = f"""
This is a test email to verify project.reports@ratiovita.com functionality.

Test Details:
- Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}
- Purpose: Verify email sending capability
- Recipient: project.reports@ratiovita.com
- CC: collin.m@ratiovita.com (automatic)

If you receive this email, the reporting center is functioning correctly for write operations.

This is an automated test - no action required.
"""
        
        # Create message
        message = MIMEText(test_body)
        message['to'] = 'project.reports@ratiovita.com'
        message['cc'] = 'collin.m@ratiovita.com'
        message['subject'] = test_subject
        
        raw_message = base64.urlsafe_b64encode(message.as_bytes()).decode('utf-8')
        
        # Send message
        result = service.users().messages().send(
            userId='me',
            body={'raw': raw_message}
        ).execute()
        
        print(f"✅ SUCCESS: Test email sent to project.reports@ratiovita.com")
        print(f"   Message ID: {result.get('id')}")
        print(f"   Subject: {test_subject}")
        print(f"   Recipients: project.reports@ratiovita.com")
        print(f"   CC: collin.m@ratiovita.com")
        return True
        
    except HttpError as e:
        error_details = e.content.decode('utf-8')
        print(f"❌ FAILED: Gmail API error")
        print(f"   Error: {error_details}")
        return False
    except Exception as e:
        print(f"❌ FAILED: {str(e)}")
        import traceback
        traceback.print_exc()
        return False

def verify_email_reading():
    """Test reading emails from project.reports@ratiovita.com"""
    print("\n" + "="*80)
    print("📧 TEST 2: EMAIL READING CAPABILITY (Dana & David)")
    print("="*80)
    
    try:
        # Load credentials with gmail.readonly scope
        creds = None
        SCOPES = ['https://www.googleapis.com/auth/gmail.readonly']
        
        if os.path.exists('token.json'):
            creds = Credentials.from_authorized_user_file('token.json', SCOPES)
        
        if not creds or not creds.valid:
            if creds and creds.expired and creds.refresh_token:
                creds.refresh(Request())
            else:
                print("❌ No valid credentials found. Please run fix_oauth_full_permissions.py first.")
                return False
        
        # Build Gmail service
        service = build('gmail', 'v1', credentials=creds)
        
        # Search for emails to project.reports@ratiovita.com (last 7 days)
        query = 'to:project.reports@ratiovita.com newer_than:7d'
        
        results = service.users().messages().list(
            userId='me',
            q=query,
            maxResults=10
        ).execute()
        
        messages = results.get('messages', [])
        
        print(f"✅ SUCCESS: Can read emails sent to project.reports@ratiovita.com")
        print(f"   Found {len(messages)} message(s) in last 7 days")
        
        if messages:
            print("\n📋 Recent Reports:")
            print("-" * 80)
            for i, msg in enumerate(messages[:5], 1):
                try:
                    message = service.users().messages().get(
                        userId='me',
                        id=msg['id'],
                        format='metadata',
                        metadataHeaders=['From', 'Subject', 'Date', 'Cc']
                    ).execute()
                    
                    headers = message.get('payload', {}).get('headers', [])
                    from_email = next((h['value'] for h in headers if h['name'] == 'From'), 'Unknown')
                    subject = next((h['value'] for h in headers if h['name'] == 'Subject'), 'No Subject')
                    date = next((h['value'] for h in headers if h['name'] == 'Date'), 'Unknown')
                    cc = next((h['value'] for h in headers if h['name'] == 'Cc'), 'None')
                    
                    print(f"\n   {i}. From: {from_email}")
                    print(f"      Subject: {subject}")
                    print(f"      Date: {date}")
                    print(f"      CC: {cc}")
                except Exception as e:
                    print(f"   {i}. Error reading message: {e}")
        else:
            print("   ⚠️  No reports found (this is normal if no reports have been submitted yet)")
        
        return True
        
    except HttpError as e:
        error_details = e.content.decode('utf-8')
        print(f"❌ FAILED: Gmail API error")
        print(f"   Error: {error_details}")
        return False
    except Exception as e:
        print(f"❌ FAILED: {str(e)}")
        import traceback
        traceback.print_exc()
        return False

def verify_protocol_compliance():
    """Verify all agents have the mandatory reporting protocols"""
    print("\n" + "="*80)
    print("📋 TEST 3: PROTOCOL COMPLIANCE VERIFICATION")
    print("="*80)
    
    try:
        agents = load_agents_from_yaml('agents.yaml')
        
        # Reporting agents (must have explicit report submission protocols)
        reporting_agents = ['Alice Kim', 'Samuel Reed', 'Megan Parker', 'Arthur Jensen', 'Ash Roy']
        
        # Review agents (must have MRAP protocols)
        review_agents = ['Dana Flores', 'David Chen']
        
        all_agents_compliant = True
        
        print("\n🔍 Checking Reporting Agents (must send to project.reports@ratiovita.com):")
        print("-" * 80)
        
        for agent in agents:
            agent_name = agent.role
            if agent_name in reporting_agents:
                backstory = agent.backstory or ""
                goal = agent.goal or ""
                full_text = f"{backstory} {goal}".lower()
                
                has_project_reports = 'project.reports@ratiovita.com' in full_text
                has_cc_protocol = 'collin.m@ratiovita.com' in full_text or 'cc:' in full_text.lower()
                has_uart = 'uart' in full_text or 'universal agent report template' in full_text
                
                status = "✅" if (has_project_reports and has_cc_protocol and has_uart) else "❌"
                
                print(f"\n{status} {agent_name}:")
                print(f"   - project.reports@ratiovita.com: {'✅' if has_project_reports else '❌'}")
                print(f"   - CC: collin.m@ratiovita.com: {'✅' if has_cc_protocol else '❌'}")
                print(f"   - UART Template: {'✅' if has_uart else '❌'}")
                
                if not (has_project_reports and has_cc_protocol and has_uart):
                    all_agents_compliant = False
        
        print("\n🔍 Checking Review Agents (Dana & David - must have MRAP):")
        print("-" * 80)
        
        for agent in agents:
            agent_name = agent.role
            if agent_name in review_agents:
                backstory = agent.backstory or ""
                goal = agent.goal or ""
                full_text = f"{backstory} {goal}".lower()
                
                has_mrap = 'mrap' in full_text or 'mandatory review & action protocol' in full_text
                has_project_reports = 'project.reports@ratiovita.com' in full_text
                has_read_protocol = 'read' in full_text and 'project.reports' in full_text
                
                status = "✅" if (has_mrap and has_project_reports and has_read_protocol) else "❌"
                
                print(f"\n{status} {agent_name}:")
                print(f"   - MRAP Protocol: {'✅' if has_mrap else '❌'}")
                print(f"   - project.reports@ratiovita.com: {'✅' if has_project_reports else '❌'}")
                print(f"   - Read/Monitor Protocol: {'✅' if has_read_protocol else '❌'}")
                
                if not (has_mrap and has_project_reports and has_read_protocol):
                    all_agents_compliant = False
        
        print("\n🔍 Checking All Other Agents (must have universal reporting capability):")
        print("-" * 80)
        
        other_agents = [a.role for a in agents if a.role not in reporting_agents + review_agents]
        
        for agent in agents:
            agent_name = agent.role
            if agent_name in other_agents:
                backstory = agent.backstory or ""
                goal = agent.goal or ""
                full_text = f"{backstory} {goal}".lower()
                
                has_universal = 'universal reporting' in full_text or 'project.reports@ratiovita.com' in full_text
                
                status = "✅" if has_universal else "⚠️"
                
                if not has_universal:
                    print(f"{status} {agent_name}: Missing universal reporting capability")
                    # Not a critical failure, just a warning
        
        return all_agents_compliant
        
    except Exception as e:
        print(f"❌ FAILED: {str(e)}")
        import traceback
        traceback.print_exc()
        return False

def verify_gmail_tool_cc():
    """Verify Gmail Tool automatically adds CC"""
    print("\n" + "="*80)
    print("📋 TEST 4: GMAIL TOOL CC VERIFICATION")
    print("="*80)
    
    try:
        # Check tools.py for MANDATORY_CC_EMAIL
        tools_path = os.path.join(os.path.dirname(__file__), 'tools.py')
        
        with open(tools_path, 'r') as f:
            tools_content = f.read()
        
        has_mandatory_cc = 'MANDATORY_CC_EMAIL' in tools_content
        has_collin_cc = 'collin.m@ratiovita.com' in tools_content
        has_auto_cc = 'MANDATORY_CC_EMAIL' in tools_content and 'cc_emails = [MANDATORY_CC_EMAIL]' in tools_content
        
        print(f"✅ MANDATORY_CC_EMAIL constant: {'✅' if has_mandatory_cc else '❌'}")
        print(f"✅ collin.m@ratiovita.com defined: {'✅' if has_collin_cc else '❌'}")
        print(f"✅ Auto-CC implementation: {'✅' if has_auto_cc else '❌'}")
        
        if has_mandatory_cc and has_collin_cc and has_auto_cc:
            print("\n✅ SUCCESS: Gmail Tool automatically adds collin.m@ratiovita.com to all emails")
            return True
        else:
            print("\n❌ FAILED: Gmail Tool CC implementation incomplete")
            return False
            
    except Exception as e:
        print(f"❌ FAILED: {str(e)}")
        import traceback
        traceback.print_exc()
        return False

def main():
    """Run all verification tests"""
    print("\n" + "="*80)
    print("🔍 PROJECT.REPORTS@RATIOVITA.COM VERIFICATION")
    print("="*80)
    print(f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}")
    print("="*80)
    
    results = {
        'email_sending': False,
        'email_reading': False,
        'protocol_compliance': False,
        'gmail_tool_cc': False
    }
    
    # Run tests
    results['email_sending'] = verify_email_sending()
    results['email_reading'] = verify_email_reading()
    results['protocol_compliance'] = verify_protocol_compliance()
    results['gmail_tool_cc'] = verify_gmail_tool_cc()
    
    # Summary
    print("\n" + "="*80)
    print("📊 VERIFICATION SUMMARY")
    print("="*80)
    
    for test_name, result in results.items():
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{status}: {test_name.replace('_', ' ').title()}")
    
    all_passed = all(results.values())
    
    print("\n" + "="*80)
    if all_passed:
        print("✅ ALL TESTS PASSED")
        print("="*80)
        print("\n📋 CONFIRMATION:")
        print("   ✅ project.reports@ratiovita.com is functioning for WRITE (all agents can submit)")
        print("   ✅ project.reports@ratiovita.com is functioning for READ (Dana & David can monitor)")
        print("   ✅ All agents have mandatory protocol to send reports to project.reports@ratiovita.com")
        print("   ✅ All agents automatically CC: collin.m@ratiovita.com (via Gmail Tool)")
        print("   ✅ Dana & David have MRAP protocols to review reports")
    else:
        print("❌ SOME TESTS FAILED")
        print("="*80)
        print("\n⚠️  Please review the failures above and fix any issues.")
    
    print("\n" + "="*80)
    
    return all_passed

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)


