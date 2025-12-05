"""
Kimi K2: Protocol Compliance Audit
Comprehensive review of all agent memory documents and meeting transcripts
to verify compliance with all mandated protocols (P0-P13).
"""
import os
import sys
import yaml
from pathlib import Path
from datetime import datetime
from crewai import Agent, Task, Crew
from config import Config

def get_credentials():
    """Get Google API credentials - load without scope restriction to avoid refresh issues"""
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    
    creds = None
    token_path = Path(__file__).parent / 'token.json'
    
    if token_path.exists():
        # Load without scope restriction (token has all scopes, readonly is subset)
        try:
            creds = Credentials.from_authorized_user_file(str(token_path), None)
        except Exception as e:
            print(f"⚠️  Warning: Could not load credentials: {e}")
            return None
    
    if not creds:
        return None
    
    # Only refresh if expired and we have a refresh token
    # Skip refresh if token is still valid
    if not creds.valid:
        if creds.expired and creds.refresh_token:
            try:
                creds.refresh(Request())
            except Exception:
                # Refresh failed - this is OK, token might still work
                # Silently continue - token may still be usable for readonly operations
                pass
        elif not creds.refresh_token:
            # No refresh token - token might still work if not expired
            pass
    
    return creds

def get_agent_metadata_local():
    """Get metadata for all agents"""
    yaml_path = Path(__file__).parent / 'agents.yaml'
    with open(yaml_path, 'r') as f:
        data = yaml.safe_load(f)
    return data.get('agents', [])

def extract_text_from_document(doc):
    """Extract all text content from a Google Docs document"""
    content = ''
    if 'body' in doc and 'content' in doc['body']:
        for element in doc['body']['content']:
            if 'paragraph' in element:
                para = element['paragraph']
                if 'elements' in para:
                    for elem in para['elements']:
                        if 'textRun' in elem:
                            content += elem['textRun'].get('content', '')
    return content

def retrieve_all_agent_memories():
    """Retrieve memory documents from all 15 agents"""
    print("📚 RETRIEVING ALL AGENT MEMORY DOCUMENTS...")
    print("="*80)
    
    creds = get_credentials()
    if not creds:
        print("❌ Error: Could not get credentials")
        return None, {}
    
    from googleapiclient.discovery import build
    service = build('docs', 'v1', credentials=creds)
    
    agents_data = get_agent_metadata_local()
    all_memories = {}
    
    for agent_data in agents_data:
        role = agent_data.get('role', 'Unknown')
        email = agent_data.get('email_address', '')
        memory_doc_id = agent_data.get('memory_doc_id', '')
        name = agent_data.get('name', email.split('@')[0] if email else role)
        
        if not memory_doc_id:
            print(f"⚠️  Skipping {name} ({role}): No memory_doc_id")
            continue
        
        try:
            doc = service.documents().get(documentId=memory_doc_id).execute()
            content = extract_text_from_document(doc)
            
            all_memories[name] = {
                'role': role,
                'email': email,
                'doc_id': memory_doc_id,
                'content': content,
                'word_count': len(content.split())
            }
            
            print(f"✅ {name} ({role}): {len(content.split())} words")
            
        except Exception as e:
            print(f"❌ {name} ({role}): Error - {e}")
            all_memories[name] = {
                'role': role,
                'email': email,
                'doc_id': memory_doc_id,
                'content': '',
                'word_count': 0
            }
    
    print(f"\n📊 Retrieved {len(all_memories)} agent memory documents")
    print()
    
    # Format context string
    context_string = "="*80 + "\n"
    context_string += "ALL AGENT MEMORY DOCUMENTS FOR PROTOCOL COMPLIANCE AUDIT\n"
    context_string += f"Retrieved: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n"
    context_string += "="*80 + "\n\n"
    
    for name, memory_data in all_memories.items():
        context_string += f"\n{'='*80}\n"
        context_string += f"AGENT: {name}\n"
        context_string += f"ROLE: {memory_data['role']}\n"
        context_string += f"EMAIL: {memory_data['email']}\n"
        context_string += f"WORD COUNT: {memory_data['word_count']}\n"
        context_string += f"{'='*80}\n\n"
        context_string += memory_data['content']
        context_string += "\n\n"
    
    return context_string, all_memories

def retrieve_meeting_transcripts():
    """Retrieve meeting transcripts from all agents' TRANSCRIPTS sections"""
    print("📝 RETRIEVING MEETING TRANSCRIPTS...")
    print("="*80)
    
    creds = get_credentials()
    if not creds:
        print("❌ Error: Could not get credentials")
        return []
    
    from googleapiclient.discovery import build
    service = build('docs', 'v1', credentials=creds)
    
    agents_data = get_agent_metadata_local()
    transcripts = []
    
    for agent_data in agents_data:
        name = agent_data.get('name', '')
        role = agent_data.get('role', '')
        memory_doc_id = agent_data.get('memory_doc_id', '')
        
        if not memory_doc_id:
            continue
        
        try:
            doc = service.documents().get(documentId=memory_doc_id).execute()
            content = extract_text_from_document(doc)
            
            # Look for TRANSCRIPTS section
            if 'TRANSCRIPTS' in content or 'MEETING TRANSCRIPT' in content:
                # Extract transcript content
                transcript_section = ""
                lines = content.split('\n')
                in_transcript = False
                
                for line in lines:
                    if 'TRANSCRIPTS' in line.upper() or 'MEETING TRANSCRIPT' in line.upper():
                        in_transcript = True
                    if in_transcript:
                        transcript_section += line + "\n"
                        # Stop at next major section (all caps heading)
                        if line.isupper() and len(line) > 5 and 'TRANSCRIPTS' not in line.upper():
                            break
                
                if transcript_section:
                    transcripts.append({
                        'agent': name,
                        'role': role,
                        'content': transcript_section
                    })
                    print(f"✅ {name}: Found transcript section ({len(transcript_section.split())} words)")
        
        except Exception as e:
            print(f"⚠️  {name}: Error retrieving transcript - {e}")
    
    print(f"\n📊 Retrieved {len(transcripts)} meeting transcripts")
    print()
    
    return transcripts

def kimi_k2_protocol_compliance_audit():
    """
    Kimi K2 Protocol Compliance Audit
    Reviews all agent memory documents and meeting transcripts for protocol compliance.
    """
    print("\n" + "="*80)
    print("🔍 KIMI K2: PROTOCOL COMPLIANCE AUDIT")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
    
    # Validate configuration
    try:
        Config.validate()
        print("✅ Configuration validated")
    except ValueError as e:
        print(f"❌ Configuration Error: {e}")
        return None
    
    os.environ['OPENAI_API_KEY'] = Config.OPENAI_API_KEY
    
    # Step 1: Retrieve all agent memories
    context_string, all_memories = retrieve_all_agent_memories()
    
    if not context_string or not all_memories:
        print("❌ Error: Failed to retrieve agent memories")
        return None
    
    # Step 2: Retrieve meeting transcripts
    transcripts = retrieve_meeting_transcripts()
    
    # Format transcripts for context
    transcripts_context = ""
    if transcripts:
        transcripts_context = "\n" + "="*80 + "\n"
        transcripts_context += "MEETING TRANSCRIPTS\n"
        transcripts_context += "="*80 + "\n\n"
        for transcript in transcripts:
            transcripts_context += f"\n{'='*80}\n"
            transcripts_context += f"AGENT: {transcript['agent']}\n"
            transcripts_context += f"ROLE: {transcript['role']}\n"
            transcripts_context += f"{'='*80}\n\n"
            transcripts_context += transcript['content']
            transcripts_context += "\n\n"
    
    # Step 3: Load tools for Kimi K2
    from tools import get_gmail_tool
    
    kimi_k2_tools = []
    try:
        kimi_k2_tools.append(get_gmail_tool(agent_role="Kimi K2 - Protocol Compliance Auditor"))
    except:
        pass
    
    # Step 4: Define Kimi K2 as Protocol Compliance Auditor
    kimi_k2_agent = Agent(
        role="Protocol Compliance Auditor",
        goal="Review all agent memory documents and meeting transcripts to verify 100% compliance with all mandated protocols (P0-P13). Identify violations and provide corrective recommendations.",
        backstory="""You are the Protocol Compliance Auditor for the RatioVita V2 multi-agent system. 
Your primary responsibility is to ensure all 15 agents are following all mandated protocols:

**PROTOCOLS TO AUDIT:**

**P0 (Critical Priority Tasks):** Agents must immediately acknowledge and log P0 tasks.

**P3 (Task Sign-Off):** Agents must log task completion with:
- Task logged to TASKS section in memory document
- Task created in Google Tasks (P3 Hybrid System)
- Artifact references (URLs, document links)
- Completion timestamp

**P5 (Active Note-Taking & Logging):** 
- For Dana Flores (Admin Assistant): Full meeting minutes and transcripts
- For all other agents: BRIEF, ROLE-SPECIFIC notes (under 150 words)
- Must NOT copy full transcripts (that's Dana's role)

**P8 (Meeting Acceptance Acknowledgment):** Agents must:
- Log meeting acceptance to PROTOCOLS section
- Add event to personal calendar
- Send confirmation email
- Log email confirmation to memory

**P11 (Mandatory Transcript Detail):** 
- Dana Flores ONLY: Must create full meeting minutes and transcripts
- All other agents: Brief role-specific summaries only

**P12 (Corrective Acknowledgment & Audit):** Non-compliant agents must:
- Check inboxes
- Log audit tasks
- Resubmit reports

**P13 (Executive Strategy Report):** 
- Dana Flores ONLY: Must generate detailed, multi-page executive reports
- Must synthesize data from all agent memories
- Must include: Executive Summary, Project Status, Compliance & Risk, Technical Update, Meeting Log

**MEETING TRANSCRIPT REQUIREMENTS:**
- Full transcripts must be in TRANSCRIPTS section
- Only Dana creates full transcripts
- Other agents create brief summaries only

You must provide a comprehensive audit report identifying:
1. Protocol violations by agent
2. Missing required entries
3. Incorrect formatting or structure
4. Chronological order violations (entries out of sequence)
5. Entry completeness issues (missing fields, incomplete data)
6. Entry correctness issues (invalid dates, broken references, placeholder text)
7. Recommendations for corrective action

**CHRONOLOGICAL ORDER CHECKING:**
- Verify all entries in dated sections are sorted oldest to newest
- Check timestamp format: YYYY-MM-DD HH:MM:SS EST (or similar)
- Identify any entries that appear before earlier-dated entries
- Flag entries with missing or malformed timestamps

**COMPLETENESS & CORRECTNESS CHECKING:**
- Verify all required fields are present in each entry
- Check that dates are valid and consistent
- Verify URLs and document references are properly formatted
- Identify placeholder text or incomplete entries
- Check formatting matches template requirements""",
        tools=kimi_k2_tools if kimi_k2_tools else None,
        verbose=True,
        allow_delegation=False,
        max_iter=10,
        max_execution_time=600
    )
    
    # Step 5: Define Compliance Audit Task
    audit_task_description = f"""
**PROTOCOL COMPLIANCE AUDIT - COMPREHENSIVE REVIEW**

You must review all agent memory documents and meeting transcripts to verify 100% compliance with all mandated protocols.

**AGENT MEMORY DOCUMENTS PROVIDED:**
{context_string[:100000]}

**MEETING TRANSCRIPTS PROVIDED:**
{transcripts_context[:50000]}

**YOUR AUDIT MUST COVER:**

## 1. P3 PROTOCOL COMPLIANCE (Task Sign-Off)
For each agent, verify:
- Tasks are logged in TASKS section
- Tasks are created in Google Tasks (check for references)
- Artifact references are included
- Completion timestamps are present

## 2. P5 PROTOCOL COMPLIANCE (Active Note-Taking)
For each agent, verify:
- **Dana Flores**: Has full meeting minutes and transcripts
- **All other agents**: Have brief, role-specific notes (under 150 words)
- No agent (except Dana) has copied full transcripts

## 3. P8 PROTOCOL COMPLIANCE (Meeting Acceptance)
For each agent, verify:
- Meeting acceptance logged in PROTOCOLS section
- Calendar events added (check for references)
- Confirmation emails sent (check for references)
- Email confirmations logged

## 4. P11 PROTOCOL COMPLIANCE (Mandatory Transcript Detail)
- **Dana Flores**: Must have full meeting minutes and transcripts
- **All other agents**: Must have brief summaries only (not full transcripts)

## 5. P12 PROTOCOL COMPLIANCE (Corrective Acknowledgment)
- Non-compliant agents must have audit tasks logged
- Reports must be resubmitted

## 6. P13 PROTOCOL COMPLIANCE (Executive Strategy Report)
- **Dana Flores ONLY**: Must have P13 Executive Strategy Reports
- Reports must include: Executive Summary, Project Status, Compliance & Risk, Technical Update, Meeting Log
- Reports must synthesize data from multiple sources

## 7. MEETING TRANSCRIPT COMPLIANCE
- Full transcripts must be in TRANSCRIPTS section
- Only Dana creates full transcripts
- Other agents create brief summaries only

## 8. CHRONOLOGICAL ORDER COMPLIANCE
For all dated sections (TASKS, PROTOCOLS, MEETINGS, TRANSCRIPTS, REPORTS):
- Verify all entries are in proper chronological order (oldest to newest)
- Check timestamp format consistency (YYYY-MM-DD HH:MM:SS EST)
- Identify any entries that are out of chronological sequence
- Flag entries with missing or malformed timestamps

## 9. ENTRY COMPLETENESS & CORRECTNESS
For each entry in memory documents, verify:
- **Completeness**: All required fields are present
  - Tasks: Title, priority, due date, status, assigned date
  - Protocols: Timestamp, action taken, result
  - Meetings: Date, attendees, decisions, action items
  - Reports: Title, date, sections, recommendations
- **Correctness**: 
  - Formatting matches template requirements
  - Dates are valid and consistent
  - References (URLs, document IDs) are valid
  - No placeholder text or incomplete entries
- **Structure**: 
  - Proper section/subsection hierarchy
  - Correct template usage
  - Consistent formatting throughout

**OUTPUT FORMAT:**

# PROTOCOL COMPLIANCE AUDIT REPORT
**Date:** {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}
**Auditor:** Kimi K2 - Protocol Compliance Auditor

## EXECUTIVE SUMMARY
[Overall compliance rate, key findings, critical violations]

## AGENT-BY-AGENT COMPLIANCE AUDIT

### [Agent Name]
**Role:** [Role]
**Overall Compliance:** [Compliant/Non-Compliant/Partial]

#### P3 Compliance (Task Sign-Off)
- Status: [Compliant/Non-Compliant]
- Issues: [List any violations]
- Tasks Logged: [Count]
- Google Tasks Created: [Count/Status]

#### P5 Compliance (Active Note-Taking)
- Status: [Compliant/Non-Compliant]
- Issues: [List any violations]
- Note Type: [Full Minutes/Brief Role-Specific/None]
- Word Count: [If applicable]

#### P8 Compliance (Meeting Acceptance)
- Status: [Compliant/Non-Compliant]
- Issues: [List any violations]
- Acceptances Logged: [Count]

#### P11 Compliance (Transcript Detail)
- Status: [Compliant/Non-Compliant]
- Issues: [List any violations]
- Transcript Type: [Full/Brief/None]

#### P12 Compliance (Corrective Acknowledgment)
- Status: [Compliant/Non-Compliant]
- Issues: [List any violations]

#### P13 Compliance (Executive Strategy Report)
- Status: [Compliant/Non-Compliant/Not Applicable]
- Issues: [List any violations]
- Reports Generated: [Count]

#### Chronological Order Compliance
- Status: [Compliant/Non-Compliant]
- Issues: [List entries out of order, with specific dates/timestamps]
- Out-of-Order Entries: [Count and details]
- Missing Timestamps: [Count and locations]

#### Entry Completeness & Correctness
- Status: [Compliant/Non-Compliant]
- Issues: [List incomplete or incorrect entries]
- Incomplete Entries: [Count and details]
- Incorrect Formatting: [Count and details]
- Missing Required Fields: [Count and details]

## MEETING TRANSCRIPT COMPLIANCE
- Full Transcripts: [Count, should only be from Dana]
- Brief Summaries: [Count]
- Violations: [List agents who created full transcripts when they shouldn't]

## CRITICAL VIOLATIONS
[List all critical protocol violations that require immediate action]

## RECOMMENDATIONS
[Specific corrective actions for each non-compliant agent]

## CHRONOLOGICAL ORDER AUDIT
- Overall Status: [Compliant/Non-Compliant]
- Out-of-Order Entries: [Total count across all agents]
- Missing Timestamps: [Total count]
- Detailed Issues: [List all chronological violations with agent, section, and entry details]

## ENTRY COMPLETENESS & CORRECTNESS AUDIT
- Overall Status: [Compliant/Non-Compliant]
- Incomplete Entries: [Total count]
- Incorrect Formatting: [Total count]
- Missing Required Fields: [Total count]
- Detailed Issues: [List all completeness/correctness violations with specific details]

## COMPLIANCE SUMMARY TABLE
| Agent | P3 | P5 | P8 | P11 | P12 | P13 | Chrono | Complete | Overall |
|-------|----|----|----|-----|-----|-----|--------|----------|---------|
| [Agent] | ✅/❌ | ✅/❌ | ✅/❌ | ✅/❌ | ✅/❌ | ✅/❌ | ✅/❌ | ✅/❌ | [%] |

**CRITICAL:** This audit must be thorough, specific, and actionable. Identify exact violations with references to specific sections of memory documents.
"""
    
    audit_task = Task(
        description=audit_task_description,
        agent=kimi_k2_agent,
        expected_output="Comprehensive Protocol Compliance Audit Report with agent-by-agent analysis, violation identification, and corrective recommendations"
    )
    
    # Step 6: Execute Audit
    print("🚀 EXECUTING PROTOCOL COMPLIANCE AUDIT...")
    print("="*80)
    print()
    
    try:
        crew = Crew(
            agents=[kimi_k2_agent],
            tasks=[audit_task],
            verbose=True
        )
        
        result = crew.kickoff()
        
        print("\n" + "="*80)
        print("✅ PROTOCOL COMPLIANCE AUDIT COMPLETE")
        print("="*80)
        
        # Extract full result content - CrewAI returns different formats
        result_str = ""
        if hasattr(result, 'raw'):
            result_str = str(result.raw)
        elif hasattr(result, 'content'):
            result_str = str(result.content)
        elif hasattr(result, 'output'):
            result_str = str(result.output)
        elif hasattr(result, 'result'):
            result_str = str(result.result)
        elif hasattr(result, '__str__'):
            result_str = str(result)
        else:
            # Try to get all attributes
            result_str = str(result)
            # Also try to access internal attributes
            if hasattr(result, '__dict__'):
                for key, value in result.__dict__.items():
                    if 'output' in key.lower() or 'content' in key.lower() or 'result' in key.lower():
                        result_str = str(value)
                        break
        
        # If result is still too short, try to get the actual task output
        if len(result_str) < 100:
            # CrewAI sometimes returns a TaskOutput object
            try:
                if hasattr(result, 'task_output'):
                    result_str = str(result.task_output)
                elif hasattr(result, 'final_output'):
                    result_str = str(result.final_output)
            except:
                pass
        
        print(f"\nAudit Result Length: {len(result_str)} characters")
        if len(result_str) > 500:
            print(f"Result Preview: {result_str[:500]}...")
        else:
            print(f"Result: {result_str}")
        print()
        
        # Step 7: Send email alert
        print("📧 SENDING COMPLIANCE AUDIT REPORT...")
        
        try:
            # Use inline email sending to avoid import issues
            import base64
            from email.mime.multipart import MIMEMultipart
            from email.mime.text import MIMEText
            from google.oauth2.credentials import Credentials
            from google.auth.transport.requests import Request
            from googleapiclient.discovery import build
            
            # Load credentials
            creds = None
            SCOPES = ['https://www.googleapis.com/auth/gmail.send']
            token_path = Path(__file__).parent / 'token.json'
            credentials_path = Path(__file__).parent / 'credentials.json'
            
            if token_path.exists():
                creds = Credentials.from_authorized_user_file(str(token_path), SCOPES)
            
            if not creds or not creds.valid:
                if creds and creds.expired and creds.refresh_token:
                    creds.refresh(Request())
                else:
                    if credentials_path.exists():
                        from google_auth_oauthlib.flow import InstalledAppFlow
                        flow = InstalledAppFlow.from_client_secrets_file(str(credentials_path), SCOPES)
                        creds = flow.run_local_server(port=0)
                    else:
                        raise Exception("credentials.json not found")
                
                with open(token_path, 'w') as token:
                    token.write(creds.to_json())
            
            service = build('gmail', 'v1', credentials=creds)
            
            # Use the result_str already extracted above
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

{result_str}

================================================================================

This is an automated compliance audit from the RatioVita V2 system.
Review the report above to identify protocol violations and corrective actions.

---
Kimi K2 - Protocol Compliance Auditor
RatioVita V2 Multi-Agent System
"""
            
            # Send email directly
            to_emails = ["collin.m@ratiovita.com"]
            cc_emails = ["collin.m@ratiovita.com", "david.chen@ratiovita.com", "dana.flores@ratiovita.com"]
            cc_emails = list(set(cc_emails))  # Remove duplicates
            
            message = MIMEMultipart('alternative')
            import re
            plain_text = re.sub(r'<[^>]+>', '', email_body)
            message.attach(MIMEText(plain_text, 'plain'))
            message.attach(MIMEText(email_body, 'html'))
            message['to'] = ', '.join(to_emails)
            message['cc'] = ', '.join(cc_emails)
            message['subject'] = f"[COMPLIANCE AUDIT] Protocol Compliance Report - {datetime.now().strftime('%B %d, %Y')}"
            
            raw_message = base64.urlsafe_b64encode(message.as_bytes()).decode('utf-8')
            message_id = service.users().messages().send(userId='me', body={'raw': raw_message}).execute()
            
            print(f"✅ Compliance audit report sent via email (Message ID: {message_id.get('id')})")
            
        except Exception as e:
            print(f"⚠️  Warning: Could not send email: {e}")
            import traceback
            traceback.print_exc()
        
        # Step 8: Save report
        try:
            report_file = Path(__file__).parent / f"PROTOCOL_COMPLIANCE_AUDIT_{datetime.now().strftime('%Y%m%d_%H%M%S')}.md"
            with open(report_file, 'w', encoding='utf-8') as f:
                f.write(f"# PROTOCOL COMPLIANCE AUDIT REPORT\n")
                f.write(f"**Date:** {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
                f.write(f"**Auditor:** Kimi K2 - Protocol Compliance Auditor\n\n")
                f.write("---\n\n")
                # Use the extracted result_str from above
                f.write(result_str)
            print(f"✅ Full report saved to: {report_file.name}")
            print(f"   Report size: {report_file.stat().st_size:,} bytes")
            print(f"   Report lines: {len(result_str.split(chr(10)))}")
        except Exception as e:
            print(f"⚠️  Warning: Could not save report to file: {e}")
            import traceback
            traceback.print_exc()
        
        return result
        
    except Exception as e:
        print("\n" + "="*80)
        print("❌ PROTOCOL COMPLIANCE AUDIT FAILED")
        print("="*80)
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    kimi_k2_protocol_compliance_audit()

