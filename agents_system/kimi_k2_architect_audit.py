"""
Kimi K2 Architectural Assurance Layer (AAL) & Build Leader
Performs comprehensive system audits and leads V2 development.
Uses massive context window to analyze all 15 agent memory documents simultaneously.
Enhanced with codebase access for security/compliance cross-referencing.
"""
import os
import sys
import yaml
from pathlib import Path
from datetime import datetime
from crewai import Agent, Task, Crew
from crewai_tools import FileReadTool
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

def retrieve_codebase_content(codebase_path=None):
    """
    Universal Codebase Access Function
    Retrieves and indexes the RatioVita_v2 codebase for architectural analysis.
    Returns a structured summary of code files, security implementations, and architecture.
    """
    if codebase_path is None:
        # Default to parent directory (RatioVita_v2 root)
        script_dir = Path(__file__).parent
        codebase_path = script_dir.parent
    
    codebase_path = Path(codebase_path)
    
    if not codebase_path.exists():
        print(f"⚠️  Warning: Codebase path does not exist: {codebase_path}")
        return None
    
    print("📂 RETRIEVING RATIOVITA_V2 CODEBASE")
    print("="*80)
    
    # File extensions to analyze
    code_extensions = {'.py', '.swift', '.yaml', '.yml', '.json', '.md', '.txt', '.plist', '.xcconfig'}
    # Directories to exclude
    exclude_dirs = {'__pycache__', '.git', 'node_modules', 'Pods', 'DerivedData', '.build', 'venv', 'env', '.venv'}
    
    codebase_index = {
        'python_files': [],
        'swift_files': [],
        'config_files': [],
        'documentation': [],
        'security_related': [],
        'compliance_related': [],
        'total_files': 0,
        'total_lines': 0
    }
    
    file_read_tool = FileReadTool()
    
    # Walk through codebase
    for root, dirs, files in os.walk(codebase_path):
        # Filter out excluded directories
        dirs[:] = [d for d in dirs if d not in exclude_dirs]
        
        for file in files:
            file_path = Path(root) / file
            file_ext = file_path.suffix.lower()
            
            # Skip if not a relevant file type
            if file_ext not in code_extensions and file_ext != '':
                continue
            
            # Skip if in excluded directory
            if any(excluded in str(file_path) for excluded in exclude_dirs):
                continue
            
            try:
                # Read file content
                relative_path = file_path.relative_to(codebase_path)
                content = file_read_tool.run(str(file_path))
                
                if content:
                    file_info = {
                        'path': str(relative_path),
                        'full_path': str(file_path),
                        'extension': file_ext,
                        'size': len(content),
                        'lines': len(content.split('\n')),
                        'content_preview': content[:500] if len(content) > 500 else content,  # First 500 chars
                        'full_content': content if len(content) < 10000 else content[:10000] + "\n...[truncated]"  # Limit to 10KB per file
                    }
                    
                    # Categorize files
                    if file_ext == '.py':
                        codebase_index['python_files'].append(file_info)
                        # Check for security/compliance keywords
                        content_lower = content.lower()
                        if any(keyword in content_lower for keyword in ['security', 'auth', 'oauth', 'token', 'credential', 'encrypt', 'privacy', 'ccpa', 'gdpr', 'compliance']):
                            codebase_index['security_related'].append(file_info)
                    elif file_ext == '.swift':
                        codebase_index['swift_files'].append(file_info)
                        # Check for security keywords
                        content_lower = content.lower()
                        if any(keyword in content_lower for keyword in ['security', 'auth', 'privacy', 'encrypt', 'keychain', 'userdefaults', 'data protection']):
                            codebase_index['security_related'].append(file_info)
                    elif file_ext in {'.yaml', '.yml', '.json', '.plist', '.xcconfig'}:
                        codebase_index['config_files'].append(file_info)
                    elif file_ext in {'.md', '.txt'}:
                        codebase_index['documentation'].append(file_info)
                    
                    codebase_index['total_files'] += 1
                    codebase_index['total_lines'] += file_info['lines']
                    
            except Exception as e:
                print(f"⚠️  Could not read {file_path}: {e}")
                continue
    
    print(f"✅ Codebase indexed: {codebase_index['total_files']} files, {codebase_index['total_lines']} lines")
    print(f"   - Python files: {len(codebase_index['python_files'])}")
    print(f"   - Swift files: {len(codebase_index['swift_files'])}")
    print(f"   - Config files: {len(codebase_index['config_files'])}")
    print(f"   - Security-related: {len(codebase_index['security_related'])}")
    print()
    
    # Format codebase summary for Kimi K2
    codebase_summary = f"""
================================================================================
RATIOVITA_V2 CODEBASE INDEX
Retrieved: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}
Total Files: {codebase_index['total_files']}
Total Lines: {codebase_index['total_lines']}
================================================================================

PYTHON FILES ({len(codebase_index['python_files'])}):
"""
    for py_file in codebase_index['python_files'][:20]:  # Limit to first 20
        codebase_summary += f"\n📄 {py_file['path']}\n"
        codebase_summary += f"   Lines: {py_file['lines']}, Size: {py_file['size']} bytes\n"
        codebase_summary += f"   Preview: {py_file['content_preview'][:200]}...\n"
    
    codebase_summary += f"\n\nSWIFT FILES ({len(codebase_index['swift_files'])}):\n"
    for swift_file in codebase_index['swift_files'][:20]:  # Limit to first 20
        codebase_summary += f"\n📄 {swift_file['path']}\n"
        codebase_summary += f"   Lines: {swift_file['lines']}, Size: {swift_file['size']} bytes\n"
        codebase_summary += f"   Preview: {swift_file['content_preview'][:200]}...\n"
    
    codebase_summary += f"\n\nSECURITY & COMPLIANCE RELATED FILES ({len(codebase_index['security_related'])}):\n"
    for sec_file in codebase_index['security_related']:
        codebase_summary += f"\n🔒 {sec_file['path']}\n"
        codebase_summary += f"   Full Content:\n{sec_file['full_content']}\n"
        codebase_summary += "\n" + "="*80 + "\n"
    
    return codebase_summary, codebase_index

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
    
    # Step 1.5: Retrieve codebase content
    print("📂 RETRIEVING CODEBASE FOR CROSS-REFERENCE ANALYSIS...")
    codebase_summary, codebase_index = retrieve_codebase_content()
    
    if codebase_summary:
        print(f"✅ Codebase retrieved: {codebase_index['total_files']} files indexed")
        print(f"   Security-related files: {len(codebase_index['security_related'])}")
        print()
    else:
        print("⚠️  Warning: Could not retrieve codebase. Continuing with memory-only audit.")
        codebase_summary = "Codebase access unavailable."
        codebase_index = {}
    
    # Step 2: Define Kimi K2 Agent
    # Note: This assumes Kimi K2 is accessible via an API or LLM endpoint
    # For now, we'll use a high-capacity model configuration
    
    # Load tools for Kimi K2 (including email capability)
    from tools import get_gmail_tool
    
    kimi_k2_tools = []
    try:
        kimi_k2_tools.append(get_gmail_tool(agent_role="Kimi K2 - Architectural Assurance Layer"))
    except Exception as e:
        print(f"⚠️  Warning: Could not load Gmail tool for Kimi K2: {e}")
    
    kimi_k2_agent = Agent(
        role="Architectural Assurance Layer (AAL) & Build Leader",
        goal="Maintain global system stability, enforce protocol consistency, and optimize the V2 development timeline. Perform comprehensive audits of all 15 operational agents to ensure architectural integrity. Send critical audit reports via email to human stakeholders.",
        backstory="""You are the final authority on system architecture for the RatioVita V2 project. 
You have a vast context window (up to 200K tokens) that allows you to simultaneously hold and analyze 
the memory of all 15 operational agents. Your primary tasks are:
1. Audit system compliance (P3, P5, P11, P13 protocols)
2. Identify architectural risks and inconsistencies
3. Lead the V2 build process with strategic optimization
4. Ensure all agents are operating within defined protocols
5. Send audit reports via email to human stakeholders (collin.m@ratiovita.com)

You have complete visibility into all agent memory documents, meeting transcripts, task logs, and 
reports. Your analysis drives executive decision-making and system stability. For critical findings, 
you must immediately alert human stakeholders via email.""",
        tools=kimi_k2_tools if kimi_k2_tools else None,
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

1. **AGENT MEMORY DOCUMENTS:**
Below is the complete memory content from all 15 operational agents, retrieved at 
{datetime.now().strftime('%B %d, %Y %I:%M %p EST')}:

{context_string[:40000]}...

[Note: Full memory context contains {len(context_string.split())} words from all 15 agents]

2. **RATIOVITA_V2 CODEBASE:**
Below is the indexed codebase content for cross-reference analysis:

{codebase_summary[:20000] if codebase_summary else "Codebase access unavailable."}...

[Note: Codebase contains {codebase_index.get('total_files', 0)} files with {codebase_index.get('total_lines', 0)} total lines of code]

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

**5. CODEBASE SECURITY & COMPLIANCE AUDIT:**
- Cross-reference the actual V2 codebase against compliance notes from Arthur Jensen's memory
- Identify security implementations (e.g., OAuth, encryption, data protection)
- Compare code security measures against CCPA/GDPR requirements documented in memory
- Check for security vulnerabilities or compliance gaps in the code
- Verify that security features mentioned in agent memories are actually implemented in code
- Report: Security compliance status, code-to-plan alignment, and identified gaps

**6. ARCHITECTURAL RISK ASSESSMENT:**
- Identify the top 3 architectural risks to V2 stability based on BOTH memory analysis AND codebase review
- Assess protocol consistency across all agents
- Identify any systemic issues or patterns of non-compliance
- Evaluate data quality and organization across memory documents
- Compare planned architecture (from memory) against actual implementation (from codebase)
- Report: Top 3 risks with severity, impact, and recommended mitigation strategies

**7. SYSTEM HEALTH SUMMARY:**
- Overall compliance rate (percentage of agents following protocols)
- Data quality assessment (chronological order, redundancy, organization)
- Code-to-plan alignment score (how well code matches documented plans)
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

## III. CODEBASE SECURITY & COMPLIANCE AUDIT

### Security Implementation Status
- **OAuth/Authentication:** [Assessment of auth implementation in code]
- **Data Encryption:** [Assessment of encryption in code]
- **Privacy Controls:** [Assessment of privacy features]
- **Compliance Alignment:** [How code aligns with CCPA/GDPR requirements from memory]

### Code-to-Plan Alignment
- **Planned Features vs. Implemented:** [Comparison]
- **Security Features:** [What was planned vs. what exists in code]
- **Compliance Gaps:** [Identified discrepancies]

### Recommendations
- [Specific code-level security improvements]
- [Compliance implementation priorities]

## IV. TOP 3 ARCHITECTURAL RISKS

### Risk #1: [Title]
- **Severity:** [High/Medium/Low]
- **Impact:** [Description]
- **Source:** [Memory-based / Code-based / Both]
- **Mitigation:** [Recommended actions]

### Risk #2: [Title]
- **Severity:** [High/Medium/Low]
- **Impact:** [Description]
- **Source:** [Memory-based / Code-based / Both]
- **Mitigation:** [Recommended actions]

### Risk #3: [Title]
- **Severity:** [High/Medium/Low]
- **Impact:** [Description]
- **Source:** [Memory-based / Code-based / Both]
- **Mitigation:** [Recommended actions]

## V. SYSTEM HEALTH METRICS
- **Overall Compliance Rate:** [X%]
- **Data Quality Score:** [X/10]
- **Code-to-Plan Alignment Score:** [X/10]
- **Security Implementation Score:** [X/10]
- **Protocol Consistency:** [Assessment]
- **System Stability:** [Assessment]

## VI. IMMEDIATE ACTION ITEMS
1. [Priority action item]
2. [Priority action item]
3. [Priority action item]

## VII. RECOMMENDATIONS FOR V2 BUILD LEADERSHIP
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
        
        # Step 5: Log the audit report and send email
        print("\n📝 LOGGING AUDIT REPORT TO SYSTEM...")
        
        # Format the audit report
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
                
                try:
                    log_result = google_docs_memory_tool(
                        doc_id=dana_doc_id,
                        content=audit_report_content,
                        section="REPORTS",
                        subsection=datetime.now().strftime('%B %d, %Y'),
                        template="Report Archive"
                    )
                    print(f"✅ Audit report logged to Dana's memory document")
                    print(f"   Result: {log_result[:200]}...")
                except Exception as e:
                    print(f"⚠️  Warning: Could not log audit report to memory: {e}")
                    import traceback
                    traceback.print_exc()
        
        # Step 6: Send email alert to human stakeholder
        print("\n📧 SENDING AUDIT REPORT EMAIL ALERT...")
        
        try:
            from tools import get_gmail_tool
            
            # Determine email subject based on findings
            # Check if result contains critical/high risk indicators
            result_str = str(result).lower()
            has_critical_risk = any(keyword in result_str for keyword in ['high risk', 'critical', 'p0', 'urgent', 'blocker', 'compliance drift'])
            
            if has_critical_risk:
                subject = f"[AAL ALERT] Kimi K2 Audit Report - Critical Risk Detected - {datetime.now().strftime('%B %d, %Y')}"
                priority_note = "🚨 CRITICAL RISK DETECTED - IMMEDIATE ATTENTION REQUIRED"
            else:
                subject = f"[AAL REPORT] Kimi K2 Final Assurance Audit - {datetime.now().strftime('%B %d, %Y')}"
                priority_note = "📊 System Status Report"
            
            # Format email body
            email_body = f"""
{priority_note}

================================================================================
KIMI K2 FINAL ASSURANCE AUDIT REPORT
================================================================================

Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}
Auditor: Kimi K2 - Architectural Assurance Layer
Scope: All 15 Operational Agents + RatioVita_v2 Codebase

================================================================================

FULL AUDIT REPORT:

{result}

================================================================================

REPORT ACCESS:
- Memory Document: Dana Flores's REPORTS section
- Trace Link: Check CrewAI dashboard for execution trace
- Local File: Saved to agents_system/logs/ (if enabled)

================================================================================

NEXT STEPS:
1. Review the audit report above
2. Address any critical risks identified (P0 tasks)
3. Verify protocol compliance improvements
4. Monitor system health metrics

================================================================================

This is an automated report from the RatioVita V2 Architectural Assurance Layer.
For questions or issues, review the full trace in the CrewAI dashboard.

---
Kimi K2 - Architectural Assurance Layer
RatioVita V2 Multi-Agent System
"""
            
            # Get Gmail tool
            gmail_tool = get_gmail_tool(agent_role="Kimi K2 - Architectural Assurance Layer")
            
            # Send email
            email_result = gmail_tool(
                to="collin.m@ratiovita.com",
                subject=subject,
                body=email_body,
                cc="david.chen@ratiovita.com,dana.flores@ratiovita.com"
            )
            
            print(f"✅ Audit report email sent successfully")
            print(f"   To: collin.m@ratiovita.com")
            print(f"   CC: david.chen@ratiovita.com, dana.flores@ratiovita.com")
            print(f"   Subject: {subject}")
            
        except Exception as e:
            print(f"⚠️  Warning: Could not send audit report email: {e}")
            import traceback
            traceback.print_exc()
        
        # Also save the full report to a local file for review
        try:
            report_file = Path(__file__).parent / f"KIMI_K2_AUDIT_REPORT_{datetime.now().strftime('%Y%m%d_%H%M%S')}.md"
            with open(report_file, 'w') as f:
                f.write(f"# FINAL ASSURANCE AUDIT REPORT\n")
                f.write(f"**Date:** {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
                f.write(f"**Auditor:** Kimi K2 - Architectural Assurance Layer\n")
                f.write(f"**Scope:** All 15 Operational Agents\n\n")
                f.write("---\n\n")
                f.write(str(result))
            print(f"✅ Full audit report saved to: {report_file.name}")
        except Exception as e:
            print(f"⚠️  Warning: Could not save audit report to file: {e}")
        
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

