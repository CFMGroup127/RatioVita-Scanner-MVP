"""
P13 Executive Strategy Report Enforcement
Orchestrates the generation of Dana Flores's mandatory Executive Strategy Report
by retrieving data from multiple agent memory documents and prompting synthesis.
"""
import os
import sys
import yaml
from pathlib import Path
from datetime import datetime
from crewai import Agent, Task, Crew

# Import tools - avoid circular imports
import sys
from pathlib import Path

# Add current directory to path
sys.path.insert(0, str(Path(__file__).parent))

# Import in correct order to avoid circular dependencies
from tools import get_google_docs_memory_tool

# Import memory_search_tool directly (avoiding main.py circular import)
def get_memory_search_tool_wrapper():
    """Get memory search tool - direct import to avoid circular dependency"""
    # Import here to avoid circular dependency
    from memory_search_tool import memory_search_tool
    return memory_search_tool

# Import main functions - use local versions to avoid circular import
import yaml
def load_agents_from_yaml_local(yaml_file='agents.yaml'):
    """Load agents from YAML - local version to avoid circular import"""
    yaml_path = Path(__file__).parent / yaml_file
    with open(yaml_path, 'r') as f:
        data = yaml.safe_load(f)
    from crewai import Agent
    agents = []
    for agent_data in data.get('agents', []):
        agent = Agent(
            role=agent_data.get('role', ''),
            goal=agent_data.get('goal', ''),
            backstory=agent_data.get('backstory', ''),
            verbose=True,
            allow_delegation=False
        )
        agents.append(agent)
    return agents

def get_agent_metadata_local(role):
    """Get agent metadata - local version to avoid circular import"""
    yaml_path = Path(__file__).parent / 'agents.yaml'
    with open(yaml_path, 'r') as f:
        data = yaml.safe_load(f)
    for agent_data in data.get('agents', []):
        if agent_data.get('role') == role:
            return agent_data
    return {}

def get_credentials():
    """Get Google API credentials"""
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from google_auth_oauthlib.flow import InstalledAppFlow
    from googleapiclient.discovery import build
    import os.path
    
    SCOPES = [
        'https://www.googleapis.com/auth/documents',
        'https://www.googleapis.com/auth/drive.readonly',
        'https://www.googleapis.com/auth/gmail.send'
    ]
    
    creds = None
    token_path = Path(__file__).parent / 'token.json'
    credentials_path = Path(__file__).parent / 'credentials.json'
    
    if token_path.exists():
        creds = Credentials.from_authorized_user_file(str(token_path), SCOPES)
    
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not credentials_path.exists():
                print("❌ Error: credentials.json not found")
                return None
            flow = InstalledAppFlow.from_client_secrets_file(
                str(credentials_path), SCOPES)
            creds = flow.run_local_server(port=0)
        
        with open(token_path, 'w') as token:
            token.write(creds.to_json())
    
    return creds

def retrieve_source_data():
    """Retrieve all source data needed for P13 report"""
    print("📊 RETRIEVING SOURCE DATA FOR P13 REPORT")
    print("="*80)
    
    creds = get_credentials()
    if not creds:
        print("❌ Failed to get credentials")
        return None
    
    # Get agent metadata
    agents = load_agents_from_yaml_local('agents.yaml')
    
    dana_meta = None
    arthur_meta = None
    ash_meta = None
    
    for agent in agents:
        meta = get_agent_metadata_local(agent.role)
        role = agent.role
        
        if "Admin Assistant" in role or "Workflow Funnel" in role:
            dana_meta = meta
        elif "Legal Compliance" in role or "Risk Assessor" in role:
            arthur_meta = meta
        elif "Technical" in role and "Visionary" in role:
            ash_meta = meta
    
    if not dana_meta:
        print("❌ Dana Flores metadata not found")
        return None
    
    source_data = {
        'dana_memory_doc_id': dana_meta.get('memory_doc_id', ''),
        'arthur_memory_doc_id': arthur_meta.get('memory_doc_id', '') if arthur_meta else None,
        'ash_memory_doc_id': ash_meta.get('memory_doc_id', '') if ash_meta else None,
        'current_date': datetime.now().strftime('%B %d, %Y'),
        'current_time': datetime.now().strftime('%I:%M %p EST')
    }
    
    print(f"✅ Dana Memory Doc ID: {source_data['dana_memory_doc_id']}")
    if source_data['arthur_memory_doc_id']:
        print(f"✅ Arthur Memory Doc ID: {source_data['arthur_memory_doc_id']}")
    if source_data['ash_memory_doc_id']:
        print(f"✅ Ash Memory Doc ID: {source_data['ash_memory_doc_id']}")
    
    return source_data

def enforce_p13_reporting():
    """Enforce P13 Executive Strategy Report generation"""
    print("\n" + "="*80)
    print("📋 P13 EXECUTIVE STRATEGY REPORT ENFORCEMENT")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
    
    # Retrieve source data
    source_data = retrieve_source_data()
    if not source_data:
        print("❌ Failed to retrieve source data")
        return False
    
    # Load Dana Flores agent
    agents = load_agents_from_yaml_local('agents.yaml')
    dana_agent = None
    
    for agent in agents:
        if "Admin Assistant" in agent.role or "Workflow Funnel" in agent.role:
            dana_agent = agent
            break
    
    if not dana_agent:
        print("❌ Dana Flores agent not found")
        return False
    
    # Get Dana's tools
    dana_meta = get_agent_metadata_local(dana_agent.role)
    dana_tools = []
    
    # Add Google Docs Memory Tool
    try:
        memory_tool = get_google_docs_memory_tool()
        dana_tools.append(memory_tool)
    except Exception as e:
        print(f"⚠️  Warning: Could not load memory tool: {e}")
    
    # Add Memory Search Tool
    try:
        search_tool = get_memory_search_tool_wrapper()
        dana_tools.append(search_tool)
    except Exception as e:
        print(f"⚠️  Warning: Could not load search tool: {e}")
    
    # Create task description
    task_description = f"""
**P13 EXECUTIVE STRATEGY REPORT - MANDATORY GENERATION**

You are required to generate a DETAILED, MULTI-PAGE Executive Strategy Report for the Human Owner.
This is NOT a brief summary - it must be comprehensive and executive-ready.

**REPORT STRUCTURE (MANDATORY):**

**Section I: Executive Summary**
- Write a 1-page narrative synthesis of all key decisions, risks, and strategic insights
- Focus on executive-level consumption
- Highlight critical decisions, blockers, and opportunities

**Section II: Project Status (RatioVita V2)**
- Provide detailed breakdown of ALL open, in-progress, and completed tasks
- Use your consolidated P3 task logs from your memory document
- Group tasks by:
  * Agent responsible
  * Priority level
  * Deadline
  * Status (Open/In Progress/Completed)
- Include task dependencies and blockers
- Reference your TASKS section for complete task inventory

**Section III: Compliance & Risk Status**
- Provide narrative analysis of legal/security risks identified in this cycle
- Use the **Memory Search Tool** to retrieve data from Arthur Jensen's memory document:
  * Search for: "RISK_STATUS" or "REPORTS" sections
  * Target Agent: Arthur Jensen (Legal Compliance and Risk Assessor)
  * Extract: Risk severity, mitigation status, compliance gaps
- Synthesize the legal/risk findings into executive-level narrative

**Section IV: Technical Architecture Update**
- Provide detailed update on architectural changes and code integration
- Use the **Memory Search Tool** to retrieve data from Ash Roy's memory document:
  * Search for: "ARCHITECTURAL_NOTES" or "REPORTS" sections
  * Target Agent: Ash Roy (Technical and Product Visionary)
  * Extract: Technical decisions, integration status, development milestones
- Synthesize the technical findings into executive-level narrative

**Section V: Meeting & Decision Log**
- Reference your full P11 meeting minutes for auditability
- Include meeting dates, key decisions made, and action items assigned
- Reference your MEETINGS section for complete meeting history

**DATA RETRIEVAL INSTRUCTIONS:**

1. **For Arthur Jensen's Data:**
   - Use Memory Search Tool with:
     * search_query: "risk assessment compliance legal"
     * target_agent_id: "Arthur Jensen" or "Legal Compliance"
     * target_section: "REPORTS" or "RISK_STATUS"
     * num_results: 10

2. **For Ash Roy's Data:**
   - Use Memory Search Tool with:
     * search_query: "technical architecture integration development"
     * target_agent_id: "Ash Roy" or "Technical Visionary"
     * target_section: "REPORTS" or "ARCHITECTURAL_NOTES"
     * num_results: 10

3. **For Your Own Data:**
   - Use Google Docs Memory Tool to read your own memory document:
     * Section: "TASKS" - for consolidated task list
     * Section: "MEETINGS" - for P11 full minutes
     * Section: "REPORTS" - for previous reports

**REPORT REQUIREMENTS:**

- **Length:** Multi-page (minimum 3-4 pages when formatted)
- **Detail Level:** Comprehensive, not summary
- **Audience:** Human Owner (executive-level)
- **Format:** Structured with clear sections I-V
- **Synthesis:** Must synthesize data from multiple sources, not just copy
- **Relevance:** Must be relevant to decision-making needs

**OUTPUT:**

1. Write the complete report to your memory document:
   - Section: "REPORTS"
   - Subsection: "{source_data['current_date']}"
   - Template: "Report Archive"
   - Content: Full P13 Executive Strategy Report

2. Send the report via email:
   - To: collin.m@ratiovita.com
   - CC: david.chen@ratiovita.com, kyle.law@ratiovita.com
   - Subject: "P13 Executive Strategy Report - {source_data['current_date']}"
   - Body: "Please find attached the P13 Executive Strategy Report for {source_data['current_date']}."

**CRITICAL:** This report must be DETAILED and MULTI-PAGE. Do not create a brief summary.
"""
    
    expected_output = f"P13 Executive Strategy Report generated and logged to memory document, sent via email to Human Owner on {source_data['current_date']}"
    
    # Create task
    task = Task(
        description=task_description,
        agent=dana_agent,
        expected_output=expected_output
    )
    
    # Create crew
    crew = Crew(
        agents=[dana_agent],
        tasks=[task],
        verbose=True
    )
    
    print("\n🚀 EXECUTING P13 REPORT GENERATION")
    print("="*80)
    print()
    
    try:
        result = crew.kickoff()
        print("\n" + "="*80)
        print("✅ P13 REPORT GENERATION COMPLETE")
        print("="*80)
        print(f"Result: {result}")
        return True
    except Exception as e:
        print("\n" + "="*80)
        print("❌ P13 REPORT GENERATION FAILED")
        print("="*80)
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = enforce_p13_reporting()
    sys.exit(0 if success else 1)

