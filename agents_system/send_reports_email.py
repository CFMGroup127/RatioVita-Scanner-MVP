#!/usr/bin/env python3
"""
Send both audit reports via email directly
Bypasses CrewAI tool wrapper to send emails directly
"""
import os
import sys
import json
import base64
from pathlib import Path
from datetime import datetime
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

# Add current directory to path
sys.path.insert(0, str(Path(__file__).parent))

# Google API imports
try:
    from google.oauth2.credentials import Credentials
    from google_auth_oauthlib.flow import InstalledAppFlow
    from google.auth.transport.requests import Request
    from googleapiclient.discovery import build
    from googleapiclient.errors import HttpError
    GOOGLE_DOCS_AVAILABLE = True
except ImportError:
    GOOGLE_DOCS_AVAILABLE = False
    print("❌ Error: Google API libraries not available")

MANDATORY_CC_EMAIL = 'collin.m@ratiovita.com'

def send_email(to_list, subject, body, cc_list=None):
    """Send email directly using Gmail API"""
    if not GOOGLE_DOCS_AVAILABLE:
        return "Error: Gmail API not available."
    
    try:
        script_dir = Path(__file__).parent
        token_path = script_dir / 'token.json'
        credentials_path = script_dir / 'credentials.json'
        
        creds = None
        SCOPES = ['https://www.googleapis.com/auth/gmail.send']
        
        if token_path.exists():
            creds = Credentials.from_authorized_user_file(str(token_path), SCOPES)
        
        if not creds or not creds.valid:
            if creds and creds.expired and creds.refresh_token:
                creds.refresh(Request())
            else:
                if not credentials_path.exists():
                    return "Error: credentials.json not found."
                flow = InstalledAppFlow.from_client_secrets_file(str(credentials_path), SCOPES)
                creds = flow.run_local_server(port=0)
            
            with open(token_path, 'w') as token:
                token.write(creds.to_json())
        
        service = build('gmail', 'v1', credentials=creds)
        
        to_emails = [email.strip() for email in to_list.split(',')]
        cc_emails = [MANDATORY_CC_EMAIL]
        if cc_list:
            cc_emails.extend([email.strip() for email in cc_list.split(',')])
            cc_emails = list(set(cc_emails))
        
        # Create message
        is_html = '<html' in body.lower() or '<body' in body.lower() or '<br>' in body or '<p>' in body
        
        if is_html:
            message = MIMEMultipart('alternative')
            import re
            plain_text = re.sub(r'<[^>]+>', '', body)
            message.attach(MIMEText(plain_text, 'plain'))
            message.attach(MIMEText(body, 'html'))
        else:
            message = MIMEText(body)
        
        message['to'] = ', '.join(to_emails)
        message['cc'] = ', '.join(cc_emails)
        message['subject'] = subject
        
        raw_message = base64.urlsafe_b64encode(message.as_bytes()).decode('utf-8')
        message_id = service.users().messages().send(userId='me', body={'raw': raw_message}).execute()
        
        return f"SUCCESS: Email sent (Message ID: {message_id.get('id')})"
    
    except Exception as e:
        return f"Error: {str(e)}"

def main():
    print("📧 SENDING AUDIT REPORTS VIA EMAIL")
    print("="*80)
    print()
    
    script_dir = Path(__file__).parent
    
    # Send Full Codebase Analysis Report
    print("1️⃣ Sending Full Codebase Analysis Report...")
    codebase_report = script_dir / 'FULL_CODEBASE_ANALYSIS_20251124_200419.md'
    if codebase_report.exists():
        with open(codebase_report, 'r', encoding='utf-8') as f:
            report_content = f.read()
        
        email_body = f"""
🔍 FULL CODEBASE ANALYSIS REPORT

================================================================================
KIMI K2 FULL CODEBASE ANALYSIS
================================================================================

Date: November 24, 2025 08:04 PM EST
Analyst: Kimi K2 - Codebase Analyst & Technical Architect
Scope: Entire RatioVita_v2 Codebase

================================================================================

FULL ANALYSIS REPORT:

{report_content}

================================================================================

This is an automated codebase analysis from the RatioVita V2 system.
Review the report above for detailed findings, assessments, and recommendations.

---
Kimi K2 - Codebase Analyst & Technical Architect
RatioVita V2 Multi-Agent System
"""
        
        result = send_email(
            to_list="collin.m@ratiovita.com",
            subject="[CODEBASE ANALYSIS] Full RatioVita_v2 Analysis Report - November 24, 2025",
            body=email_body,
            cc_list="david.chen@ratiovita.com,dana.flores@ratiovita.com"
        )
        print(f"   {result}")
    else:
        print(f"   ❌ Report file not found: {codebase_report}")
    
    print()
    
    # Send Protocol Compliance Audit Report (if complete)
    print("2️⃣ Sending Protocol Compliance Audit Report...")
    protocol_reports = sorted(script_dir.glob('PROTOCOL_COMPLIANCE_AUDIT_*.md'), key=lambda p: p.stat().st_mtime, reverse=True)
    if protocol_reports:
        latest_protocol = protocol_reports[0]
        with open(latest_protocol, 'r', encoding='utf-8') as f:
            report_content = f.read()
        
        # Only send if report is substantial (more than 500 bytes)
        if len(report_content) > 500:
            email_body = f"""
🔍 PROTOCOL COMPLIANCE AUDIT REPORT

================================================================================
KIMI K2 PROTOCOL COMPLIANCE AUDIT
================================================================================

Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}
Auditor: Kimi K2 - Protocol Compliance Auditor
Scope: All 15 Operational Agents + Meeting Transcripts

================================================================================

FULL AUDIT REPORT:

{report_content}

================================================================================

This is an automated compliance audit from the RatioVita V2 system.
Review the report above to identify protocol violations and corrective actions.

---
Kimi K2 - Protocol Compliance Auditor
RatioVita V2 Multi-Agent System
"""
            
            result = send_email(
                to_list="collin.m@ratiovita.com",
                subject=f"[COMPLIANCE AUDIT] Protocol Compliance Report - {datetime.now().strftime('%B %d, %Y')}",
                body=email_body,
                cc_list="david.chen@ratiovita.com,dana.flores@ratiovita.com"
            )
            print(f"   {result}")
        else:
            print(f"   ⚠️  Report appears incomplete ({len(report_content)} bytes) - skipping email")
            print(f"   📄 File: {latest_protocol.name}")
    else:
        print("   ❌ No protocol compliance audit reports found")
    
    print()
    print("="*80)
    print("✅ Email sending complete")
    print("="*80)

if __name__ == "__main__":
    main()

