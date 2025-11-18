"""
Force Report Submissions to project.reports@ratiovita.com
This script forces all reporting agents to submit their reports to the unified reporting center.
"""
import os
from datetime import datetime
from crewai import Agent, Task, Crew, Process
from config import Config
from main import load_agents_from_yaml, get_agent_metadata

def force_report_submissions():
    """
    Force all reporting agents to submit their reports to project.reports@ratiovita.com.
    """
    print("\n" + "="*80)
    print("📧 FORCING REPORT SUBMISSIONS TO UNIFIED REPORTING CENTER")
    print("="*80)
    print("Target: project.reports@ratiovita.com")
    print("Agents: Alice Kim, Samuel Reed, Megan Parker, Arthur Jensen, Ash Roy")
    print("="*80)
    
    # Validate configuration
    try:
        Config.validate()
        print("✅ Configuration validated")
    except ValueError as e:
        print(f"❌ Configuration Error: {e}")
        return None
    
    os.environ['OPENAI_API_KEY'] = Config.OPENAI_API_KEY
    
    # Load agents
    print("\n📋 Loading agents...")
    try:
        agents = load_agents_from_yaml('agents.yaml')
        print(f"✅ Loaded {len(agents)} agents")
    except Exception as e:
        print(f"❌ Error loading agents: {e}")
        import traceback
        traceback.print_exc()
        return None
    
    # Get reporting agents
    reporting_agents = {}
    reporting_roles = {
        "Documentation and Knowledge Archivist": ("Alice Kim", "[BLOCK A] V1 Legacy Asset Archival - VERIFIED"),
        "Competitive Intelligence Specialist": ("Samuel Reed", "[BLOCK P] V2 Market and Competitive Landscape - VERIFIED"),
        "Market Strategist and Voice of the Customer": ("Megan Parker", "[BLOCK P] V2 Branding & Value Propositions - VERIFIED"),
        "Legal Compliance and Risk Assessor": ("Arthur Jensen", "[BLOCK P] V2 Design System Foundation - VERIFIED"),
        "Technical and Product Visionary": ("Ash Roy", "[V2 Engineering] V2 Technical Baseline and Dependencies - VERIFIED")
    }
    
    for agent in agents:
        if agent.role in reporting_roles:
            agent_name, subject = reporting_roles[agent.role]
            reporting_agents[agent] = (agent_name, subject)
    
    print(f"\n✅ Found {len(reporting_agents)} reporting agents")
    
    # Get agent metadata
    tasks = []
    for agent, (agent_name, subject) in reporting_agents.items():
        agent_meta = get_agent_metadata(agent.role)
        memory_doc_id = agent_meta.get('memory_doc_id', '')
        agent_email = agent_meta.get('email_address', '')
        
        task_description = f"""
**MANDATORY REPORT SUBMISSION TASK**

You MUST immediately submit your completed report to the Unified Reporting Center.

**STEP 1: Read Your Memory Document**
- Use the **Google Docs Read Tool** to read your memory document (doc_id: {memory_doc_id})
- Locate your final report (should follow UART template structure)
- Verify the report includes:
  - Section I: Report Metadata
  - Section II: Executive Summary & Key Takeaway
  - Section III: Detailed Findings
  - Section IV: Overall Summary & Final Recommendations
  - Section V: Audit & Verification Sign-Off with "TASK COMPLETE" and "VERIFIED" tag

**STEP 2: Submit to Unified Reporting Center**
- Use the **GMailTool** to send your complete report to project.reports@ratiovita.com
- Recipient: project.reports@ratiovita.com
- CC: collin.m@ratiovita.com (MANDATORY)
- Subject: "{subject}"
- Body: Include your complete report following the UART template structure
- End the email with: "VERIFIED: {agent_name} - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"

**STEP 3: Update Memory Document**
- After successful email submission, update your memory document with:
  - "Report submitted to project.reports@ratiovita.com on [Timestamp]"
  - "SUBMISSION CONFIRMED: [Report Title] sent to Unified Reporting Center"

**CRITICAL:** You MUST see a SUCCESS message for the email before proceeding. If the email fails, you must retry until successful.

**VERIFY:** Check that your report submission includes all required UART sections and the VERIFIED tag.
"""
        
        task = Task(
            description=task_description,
            agent=agent,
            expected_output=f"Report successfully submitted to project.reports@ratiovita.com with subject '{subject}', memory updated with submission confirmation."
        )
        tasks.append(task)
    
    # Create crew
    print("\n" + "="*80)
    print(f"🚀 Creating crew with {len(tasks)} concurrent tasks...")
    print("="*80)
    
    crew = Crew(
        agents=list(reporting_agents.keys()),
        tasks=tasks,
        process=Process.hierarchical,
        verbose=True
    )
    
    print("✅ Crew created")
    
    # Execute
    print("\n" + "="*80)
    print("Starting forced report submissions...")
    print("="*80)
    
    try:
        result = crew.kickoff()
        print("\n" + "="*80)
        print("✅ FORCED REPORT SUBMISSIONS COMPLETE")
        print("="*80)
        print(f"\n📊 Results:\n{result}")
        return result
    except Exception as e:
        print(f"\n❌ Error during execution: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    force_report_submissions()



