"""
Direct email sending function (bypasses CrewAI tool wrapper)
Used by scripts that need to send emails directly without the @tool decorator.
"""
import os
import json
from datetime import datetime
from pathlib import Path

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

MANDATORY_CC_EMAIL = 'collin.m@ratiovita.com'

def send_email_direct(
    to_list: str,
    subject: str,
    body: str,
    cc_list: str = None,
    agent_role: str = None
) -> str:
    """
    Send an email directly using Gmail API (bypasses CrewAI tool wrapper).
    
    Args:
        to_list: Comma-separated list of recipient email addresses
        subject: Email subject line
        body: Email body content
        cc_list: Optional comma-separated list of CC recipients
        agent_role: The agent's role (for signature generation)
    
    Returns:
        Success message or error message
    """
    if not GOOGLE_DOCS_AVAILABLE:
        return "Error: Gmail API not available."
    
    try:
        # Load credentials
        creds = None
        SCOPES = ['https://www.googleapis.com/auth/gmail.send']
        
        script_dir = Path(__file__).parent
        token_path = script_dir / 'token.json'
        credentials_path = script_dir / 'credentials.json'
        
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
        
        # Build service
        service = build('gmail', 'v1', credentials=creds)
        
        # Parse recipients
        to_emails = [email.strip() for email in to_list.split(',')]
        
        # Always include mandatory CC
        cc_emails = [MANDATORY_CC_EMAIL]
        if cc_list:
            cc_emails.extend([email.strip() for email in cc_list.split(',')])
            cc_emails = list(set(cc_emails))  # Remove duplicates
        
        # Generate signature if agent_role provided
        if agent_role:
            try:
                from tools import generate_email_signature
                # Try to get agent email
                agent_email = None
                try:
                    from main import get_agent_metadata
                    metadata = get_agent_metadata(agent_role)
                    agent_email = metadata.get('email_address', '')
                except:
                    pass
                signature = generate_email_signature(agent_role, agent_email)
                # Check if body is HTML or plain text
                if '<html' in body.lower() or '<body' in body.lower() or '<br>' in body or '<p>' in body:
                    body = body + signature
                else:
                    body = body.replace('\n', '<br>') + signature
            except:
                pass  # Continue without signature if generation fails
        
        # Create message
        import base64
        from email.mime.multipart import MIMEMultipart
        from email.mime.text import MIMEText
        
        # Check if body contains HTML
        is_html = '<html' in body.lower() or '<body' in body.lower() or '<br>' in body or '<p>' in body or '<table' in body
        
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
        
        # Send message
        message_id = service.users().messages().send(userId='me', body={'raw': raw_message}).execute()
        
        return f"SUCCESS: Email sent successfully (Message ID: {message_id.get('id')}). Recipients: {', '.join(to_emails)}. CC: {', '.join(cc_emails)}."
    
    except HttpError as e:
        error_details = json.loads(e.content.decode('utf-8'))
        error_message = error_details.get('error', {}).get('message', str(e))
        return f"Error: Gmail API error - {error_message}"
    except Exception as e:
        error_msg = str(e)
        return f"Error: Failed to send email - {error_msg}"
