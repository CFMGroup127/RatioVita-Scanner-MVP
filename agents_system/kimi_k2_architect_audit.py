"""
Kimi K2 Architectural Assurance Layer (AAL) & Build Leader
Performs comprehensive system audits and leads V2 development.
Uses massive context window to analyze all 15 agent memory documents simultaneously.
"""
import os
import sys
import yaml
from pathlib import Path
from datetime import datetime
from crewai import Agent, Task, Crew
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build

def get_credentials():
    """Get Google API credentials"""
    SCOPES = [
        'https://www.googleapis.com/auth/documents.readonly',
        'https://www.googleapis.com/auth/drive.readonly'
    ]
    
    creds = None
    token_path = Path(__file__).parent / 'token.json'
    
    if token_path.exists():
        creds = Credentials.from_authorized_user_file(str(token_path), SCOPES)
    
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            return None
    
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
    """
    Universal Data Access Function
    Retrieves the most recent memory documents from all 15 agents.
    Returns a comprehensive context string for Kimi K2 analysis.
    """
    print("📊 RETRIEVING ALL AGENT MEMORY DOCUMENTS")
    print("="*80)
    
    creds = get_credentials()
    if not creds:
        print("❌ Error: Could not get credentials")
        return None
    
    service = build('docs', 'v1', credentials=creds)
    
    # Get all agent metadata
    agents_data = get_agent_metadata_local()
    
    all_memories = {}
    successful_retrievals = 0
    failed_retrievals = 0
    
    for agent_data in agents_data:
        role = agent_data.get('role', 'Unknown')
        email = agent_data.get('email_address', '')
        memory_doc_id = agent_data.get('memory_doc_id', '')
        
        if not memory_doc_id:
            print(f"⚠️  Skipping {role}: No memory_doc_id")
            failed_retrievals += 1
            continue
        
        try:
            # Fetch document
            doc = service.documents().get(documentId=memory_doc_id).execute()
            content = extract_text_from_document(doc)
            
            # Store with agent identification
            agent_name = email.split('@')[0].replace('.', ' ').title() if email else role
            all_memories[agent_name] = {
                'role': role,
                'email': email,
                'doc_id': memory_doc_id,
                'content': content,
                'word_count': len(content.split()),
                'last_updated': datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')
            }
            
            print(f"✅ {agent_name} ({role}): {len(content.split())} words retrieved")
            successful_retrievals += 1
            
        except Exception as e:
            print(f"❌ {role}: Error retrieving memory - {e}")
            failed_retrievals += 1
    
    print()
    print(f"📊 RETRIEVAL SUMMARY:")
    print(f"   ✅ Successful: {successful_retrievals}")
    print(f"   ❌ Failed: {failed_retrievals}")
    print(f"   📄 Total Memory Documents: {len(all_memories)}")
    print()
    
    # Format comprehensive context for Kimi K2
    context_string = "="*80 + "\n"
    context_string += "COMPREHENSIVE AGENT MEMORY DOCUMENT RETRIEVAL\n"
    context_string += f"Retrieved: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n"
    context_string += "="*80 + "\n\n"
    
    for agent_name, memory_data in all_memories.items():
        context_string += f"\n{'='*80}\n"
        context_string += f"AGENT: {agent_name}\n"
        context_string += f"ROLE: {memory_data['role']}\n"
        context_string += f"EMAIL: {memory_data['email']}\n"
        context_string += f"WORD COUNT: {memory_data['word_count']}\n"
        context_string += f"{'='*80}\n\n"
        context_string += memory_data['content']
        context_string += "\n\n"
    
    return context_string, all_memories

def kimi_k2_architect_audit():
    """
    Kimi K2 Final Assurance Audit
    Performs comprehensive system analysis using all 15 agent memory documents.
    """
    print("\n" + "="*80)
    print("🏗️ KIMI K2 ARCHITECTURAL ASSURANCE LAYER - FINAL ASSURANCE AUDIT")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
    
    # Step 1: Retrieve all agent memories
    context_string, all_memories = retrieve_all_agent_memories()
    
    if not context_string or not all_memories:
        print("❌ Error: Failed to retrieve agent memories")
        return False
    
    print(f"📊 Total Context Retrieved: {len(context_string.split())} words")
    print(f"📄 Memory Documents: {len(all_memories)} agents\n")
    
    # Step 2: Define Kimi K2 Agent
    # Note: This assumes Kimi K2 is accessible via an API or LLM endpoint
    # For now, we'll use a high-capacity model configuration
    
    kimi_k2_agent = Agent(
        role="Architectural Assurance Layer (AAL) & Build Leader",
        goal="Maintain global system stability, enforce protocol consistency, and optimize the V2 development timeline. Perform comprehensive audits of all 15 operational agents to ensure architectural integrity.",
        backstory="""You are the final authority on system architecture for the RatioVita V2 project. 
You have a vast context window (up to 200K tokens) that allows you to simultaneously hold and analyze 
the memory of all 15 operational agents. Your primary tasks are:
1. Audit system compliance (P3, P5, P11, P13 protocols)
2. Identify architectural risks and inconsistencies
3. Lead the V2 build process with strategic optimization
4. Ensure all agents are operating within defined protocols

You have complete visibility into all agent memory documents, meeting transcripts, task logs, and 
reports. Your analysis drives executive decision-making and system stability.""",
        verbose=True,
        allow_delegation=False,
        max_iter=5,
        max_execution_time=300
    )
    
    # Step 3: Create the Final Assurance Audit Task
    audit_task_description = f"""
**FINAL ASSURANCE AUDIT - COMPREHENSIVE SYSTEM ANALYSIS**

You have been granted universal access to all 15 agent memory documents. Your task is to perform 
a comprehensive architectural audit of the entire RatioVita V2 agent system.

**ATTACHED DATA:**
Below is the complete memory content from all 15 operational agents, retrieved at 
{datetime.now().strftime('%B %d, %Y %I:%M %p EST')}:

{context_string[:50000]}...

[Note: Full context contains {len(context_string.split())} words from all 15 agents]

**AUDIT REQUIREMENTS:**

**1. P5 PROTOCOL COMPLIANCE AUDIT:**
- Review all meeting notes in the MEETINGS sections of all 14 non-Dana agents
- Verify that each agent's meeting notes are BRIEF (under 150 words)
- Verify that notes are ROLE-SPECIFIC (focused only on items relevant to that agent's role)
- Identify any agents with FULL meeting minutes (which should only exist for Dana Flores)
- Report: List all P5 violations with agent names, word counts, and specific issues

**2. P3 PROTOCOL COMPLIANCE AUDIT:**
- Review all TASKS sections across all 15 agents
- Verify that all assigned tasks are logged in memory documents
- Check for consistency between task assignments in MEETINGS and actual TASKS sections
- Identify any missing task logs or incomplete P3 compliance
- Report: List all P3 violations with agent names, missing tasks, and inconsistencies

**3. P11 PROTOCOL COMPLIANCE AUDIT:**
- Verify that Dana Flores has FULL meeting minutes and FULL transcripts for all meetings
- Check that Dana's MEETINGS and TRANSCRIPTS sections contain comprehensive records
- Verify that other agents do NOT have full transcripts (only brief summaries)
- Report: P11 compliance status for Dana and any violations by other agents

**4. P13 PROTOCOL COMPLIANCE AUDIT:**
- Check if P13 Executive Strategy Reports have been generated
- Verify report structure (5 mandatory sections: Executive Summary, Project Status, Compliance & Risk, Technical Architecture, Meeting & Decision Log)
- Assess report quality and detail level
- Report: P13 compliance status and recommendations for improvement

**5. ARCHITECTURAL RISK ASSESSMENT:**
- Identify the top 3 architectural risks to V2 stability based on the memory analysis
- Assess protocol consistency across all agents
- Identify any systemic issues or patterns of non-compliance
- Evaluate data quality and organization across memory documents
- Report: Top 3 risks with severity, impact, and recommended mitigation strategies

**6. SYSTEM HEALTH SUMMARY:**
- Overall compliance rate (percentage of agents following protocols)
- Data quality assessment (chronological order, redundancy, organization)
- System stability indicators
- Recommendations for immediate improvements

**OUTPUT FORMAT:**

Your audit report must be structured as follows:

# FINAL ASSURANCE AUDIT REPORT
**Date:** {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}
**Auditor:** Kimi K2 - Architectural Assurance Layer

## I. EXECUTIVE SUMMARY
[2-3 paragraph synthesis of overall system health, compliance status, and critical findings]

## II. PROTOCOL COMPLIANCE AUDIT

### P5 Compliance (Role-Specific Notes)
- **Compliance Rate:** [X%]
- **Violations:** [List of agents with issues]
- **Details:** [Specific violations with word counts and recommendations]

### P3 Compliance (Task Logging)
- **Compliance Rate:** [X%]
- **Violations:** [List of agents with missing or incomplete task logs]
- **Details:** [Specific missing tasks and inconsistencies]

### P11 Compliance (Full Minutes/Transcript)
- **Dana Flores Status:** [Compliant/Non-Compliant]
- **Other Agents Status:** [Any violations]
- **Details:** [Specific issues found]

### P13 Compliance (Executive Reporting)
- **Report Generation Status:** [Generated/Not Generated]
- **Report Quality:** [Assessment]
- **Recommendations:** [Improvements needed]

## III. TOP 3 ARCHITECTURAL RISKS

### Risk #1: [Title]
- **Severity:** [High/Medium/Low]
- **Impact:** [Description]
- **Mitigation:** [Recommended actions]

### Risk #2: [Title]
- **Severity:** [High/Medium/Low]
- **Impact:** [Description]
- **Mitigation:** [Recommended actions]

### Risk #3: [Title]
- **Severity:** [High/Medium/Low]
- **Impact:** [Description]
- **Mitigation:** [Recommended actions]

## IV. SYSTEM HEALTH METRICS
- **Overall Compliance Rate:** [X%]
- **Data Quality Score:** [X/10]
- **Protocol Consistency:** [Assessment]
- **System Stability:** [Assessment]

## V. IMMEDIATE ACTION ITEMS
1. [Priority action item]
2. [Priority action item]
3. [Priority action item]

## VI. RECOMMENDATIONS FOR V2 BUILD LEADERSHIP
[Strategic recommendations for optimizing the V2 development timeline and ensuring continued system stability]

---

**CRITICAL:** This audit must be comprehensive, detailed, and actionable. Use your vast context window 
to synthesize patterns across all 15 agents and provide executive-level insights.
"""
    
    audit_task = Task(
        description=audit_task_description,
        agent=kimi_k2_agent,
        expected_output="Comprehensive Final Assurance Audit Report with protocol compliance analysis, risk assessment, and actionable recommendations"
    )
    
    # Step 4: Execute the audit
    print("🚀 EXECUTING KIMI K2 FINAL ASSURANCE AUDIT")
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
        print("✅ KIMI K2 FINAL ASSURANCE AUDIT COMPLETE")
        print("="*80)
        print(f"\nAudit Result:\n{result}")
        
        # Step 5: Log the audit report
        print("\n📝 LOGGING AUDIT REPORT TO SYSTEM...")
        
        # Get Dana's memory doc ID for logging the audit report
        dana_meta = None
        for agent_data in get_agent_metadata_local():
            if "Admin Assistant" in agent_data.get('role', '') or "Workflow Funnel" in agent_data.get('role', ''):
                dana_meta = agent_data
                break
        
        if dana_meta:
            dana_doc_id = dana_meta.get('memory_doc_id', '')
            if dana_doc_id:
                from tools import google_docs_memory_tool
                
                audit_report_content = f"""# FINAL ASSURANCE AUDIT REPORT
**Date:** {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}
**Auditor:** Kimi K2 - Architectural Assurance Layer
**Scope:** All 15 Operational Agents

---

{result}

---

**Report Status:** Archived
**Next Audit:** Scheduled for next cycle
"""
                
                try:
                    log_result = google_docs_memory_tool(
                        doc_id=dana_doc_id,
                        content=audit_report_content,
                        section="REPORTS",
                        subsection=datetime.now().strftime('%B %d, %Y'),
                        template="Report Archive"
                    )
                    print(f"✅ Audit report logged to Dana's memory document: {log_result[:100]}...")
                except Exception as e:
                    print(f"⚠️  Warning: Could not log audit report to memory: {e}")
        
        return True
        
    except Exception as e:
        print("\n" + "="*80)
        print("❌ KIMI K2 AUDIT FAILED")
        print("="*80)
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = kimi_k2_architect_audit()
    sys.exit(0 if success else 1)

