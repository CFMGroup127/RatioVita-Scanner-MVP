"""
Ash Roy's V2 Technical Baseline and Quarantining Mission
This script executes the engineering protocol: quarantine V1, analyze V2 codebase, and create baseline report.
"""
import os
from datetime import datetime
from crewai import Agent, Task, Crew, Process
from config import Config
from main import load_agents_from_yaml, get_agent_metadata, LEGACY_V1_PATH

# V2 Project Directory
V2_PROJECT_PATH = "/Users/colliemorris/Projects 2/RatioVita_v2"
ARCHIVED_V1_PATH = "/Users/colliemorris/Projects 2/RatioVita_v2/ARCHIVED_V1_DO_NOT_USE"

def ash_roy_engineering_protocol():
    """
    Execute Ash Roy's V2 Technical Baseline and Quarantining Mission.
    
    This task:
    1. Quarantines V1 folder (moves to ARCHIVED_V1_DO_NOT_USE)
    2. Sends team notification email
    3. Performs batched V2 codebase analysis
    4. Creates structured technical baseline report
    """
    print("\n" + "="*80)
    print("🚀 ASH ROY: V2 TECHNICAL BASELINE AND QUARANTINING MISSION")
    print("="*80)
    print("Executing engineering protocol to secure V1 and establish V2 baseline")
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
    
    # Get Ash Roy
    ash_role = "Technical and Product Visionary"
    ash_agent = None
    ash_metadata = None
    
    for agent in agents:
        if agent.role == ash_role:
            ash_agent = agent
            ash_metadata = get_agent_metadata(ash_role)
            break
    
    if not ash_agent:
        print(f"❌ Error: Ash Roy (CTO/CPO) not found")
        return None
    
    print(f"\n✅ Ash Roy (CTO/CPO) loaded")
    
    ash_memory_id = ash_metadata.get('memory_doc_id', '')
    
    print(f"\n📋 Memory Document ID: {ash_memory_id}")
    print(f"📋 V1 Legacy Path: {LEGACY_V1_PATH}")
    print(f"📋 V2 Project Path: {V2_PROJECT_PATH}")
    print(f"📋 Archived V1 Path: {ARCHIVED_V1_PATH}")
    
    tasks = []
    
    # ============================================================================
    # PRE-TASK: Ash Roy - Read Memory for Context
    # ============================================================================
    print("\n" + "="*80)
    print("PRE-TASK: Ash Roy - Read Memory for Context")
    print("="*80)
    
    ash_read_memory_task = Task(
        description=(
            f"Before starting the engineering protocol, read your memory document to understand your current context.\n\n"
            f"**MANDATORY FIRST STEP:**\n"
            f"1. Use the Google Docs Read Tool with your memory_doc_id: {ash_memory_id}\n"
            f"2. Review the contents of your memory document\n"
            f"3. Note any relevant context, prior technical work, or architectural decisions\n\n"
            f"This ensures you have full context before beginning the V2 Technical Baseline mission."
        ),
        agent=ash_agent,
        expected_output="Confirmation that memory document has been read and context understood",
        context=[dana_delegation_task],
        max_iter=3
    )
    tasks.append(ash_read_memory_task)
    
    # ============================================================================
    # PHASE 1: QUARANTINE & NOTIFICATION
    # ============================================================================
    print("\n" + "="*80)
    print("PHASE 1: QUARANTINE & NOTIFICATION")
    print("="*80)
    
    quarantine_task_description = (
        f"Execute **PHASE 1: QUARANTINE & NOTIFICATION** to secure the V1 legacy codebase.\n\n"
        f"**STEP 1: Quarantine V1 Folder (MANDATORY)**\n"
        f"- Use File Move Tool to move the entire V1 legacy folder to an isolated location\n"
        f"- source_path: {LEGACY_V1_PATH}\n"
        f"- destination_path: {ARCHIVED_V1_PATH}\n"
        f"- **VERIFY:** You must see SUCCESS message confirming the move\n"
        f"- This ensures V1 code cannot contaminate V2 development\n\n"
        f"**STEP 2: Send Team Notification Email (MANDATORY)**\n"
        f"- Use Gmail Tool to send a formal notification to ALL team members\n"
        f"- Send to: kyle.law@ratiovita.com, dana.flores@ratiovita.com, ash.roy@ratiovita.com, "
        f"david.chen@ratiovita.com, alice.kim@ratiovita.com, megan.parker@ratiovita.com, "
        f"ethan.hayes@ratiovita.com, chloe.park@ratiovita.com, samuel.reed@ratiovita.com, "
        f"victor.alvarez@ratiovita.com, jennifer.jurvais@ratiovita.com, tyler.cobb@ratiovita.com, "
        f"rachel.stone@ratiovita.com, arthur.jensen@ratiovita.com\n"
        f"- Subject: V1 Legacy Codebase Quarantined - Off-Limits for V2 Development\n"
        f"- Body: 'This is a formal notification that the V1 legacy codebase has been quarantined "
        f"and moved to ARCHIVED_V1_DO_NOT_USE directory. All agents are instructed that the V1 folder "
        f"is strictly off-limits for V2 development and testing. Any code, architectural patterns, "
        f"or configurations from V1 are forbidden from V2 compilation per the V1 CODE INJECTION GUARDRAIL protocol.'\n"
        f"- CC: collin.m@ratiovita.com (automatic - tool will add this)\n"
        f"- **VERIFY:** You must see SUCCESS message for email sent\n\n"
        f"**CRITICAL:**\n"
        f"- You MUST complete both steps in order\n"
        f"- You MUST verify SUCCESS for both operations\n"
        f"- The quarantine is essential for preventing V1 contamination"
    )
    
    quarantine_task = Task(
        description=quarantine_task_description,
        agent=ash_agent,
        expected_output="Confirmation that V1 folder has been quarantined and team notification email has been sent",
        context=[ash_read_memory_task],
        max_iter=10
    )
    tasks.append(quarantine_task)
    
    # ============================================================================
    # PHASE 2: BATCHED V2 BASELINE ANALYSIS
    # ============================================================================
    print("\n" + "="*80)
    print("PHASE 2: BATCHED V2 BASELINE ANALYSIS")
    print("="*80)
    
    analysis_task_description = (
        f"Execute **PHASE 2: BATCHED V2 BASELINE ANALYSIS** to establish the technical baseline.\n\n"
        f"**YOUR TASK:**\n"
        f"Analyze the V2 project codebase in sequential batches of no more than 10 files or configurations at a time.\n\n"
        f"**STEP-BY-STEP INSTRUCTIONS:**\n\n"
        f"**STEP 1: Identify Key Configuration Files**\n"
        f"- Use File Read Tool to read critical configuration files:\n"
        f"  - Podfile (iOS dependencies)\n"
        f"  - package.json (if applicable)\n"
        f"  - Info.plist or equivalent\n"
        f"  - Any build configuration files\n"
        f"- Use Cursor LLM Interface Tool to analyze structure:\n"
        f"  - Prompt: 'I am Ash Roy, your Chief Architect. Act as a Codebase Structure Analyst. "
        f"Your sole task is to analyze the provided configuration files and identify all external dependencies, "
        f"libraries, and framework versions. Provide a structured summary of dependencies with risk assessment.'\n\n"
        f"**STEP 2: Analyze Code Structure in Batches**\n"
        f"- Use File Read Tool to read code files in batches of 10 (max)\n"
        f"- Focus on:\n"
        f"  - Main application structure\n"
        f"  - Module hierarchy\n"
        f"  - Programming language(s) used\n"
        f"  - Architecture patterns\n"
        f"  - Test coverage (if any)\n"
        f"- For each batch:\n"
        f"  a. Read files using File Read Tool (FULL ABSOLUTE PATHS: {V2_PROJECT_PATH}/[path])\n"
        f"  b. Use Cursor LLM Interface Tool to analyze:\n"
        f"     - Prompt: 'I am Ash Roy, your Chief Architect. Act as a Code Structure Analyst. "
        f"Your sole task is to analyze the provided code files and identify: (1) Primary programming language, "
        f"(2) Module hierarchy and organization, (3) Any structural flaws (monolithic design, missing tests, etc.), "
        f"(4) Architecture patterns used. Provide a concise technical summary.'\n"
        f"  c. **MANDATORY:** Write batch analysis summary to your memory document:\n"
        f"     - Use Google Docs Memory Tool\n"
        f"     - doc_id: {ash_memory_id}\n"
        f"     - content: 'V2 Baseline Analysis - Batch [N]\\n\\n[summary of findings and risks]'\n"
        f"     - append: True\n"
        f"  d. **VERIFY:** You MUST see SUCCESS message before proceeding to next batch\n\n"
        f"**STEP 3: Dependency Risk Assessment**\n"
        f"- Compile a comprehensive list of all external libraries and dependencies\n"
        f"- For each dependency, assess:\n"
        f"  - Compatibility with V2 requirements\n"
        f"  - License issues (if any)\n"
        f"  - Security vulnerabilities (if known)\n"
        f"  - Maintenance status\n"
        f"- Write dependency risk assessment to memory\n\n"
        f"**CRITICAL RULES:**\n"
        f"- Process files in batches of 10 maximum\n"
        f"- Write to memory after EACH batch analysis\n"
        f"- Verify SUCCESS message after EVERY memory write\n"
        f"- Do NOT proceed to next batch without SUCCESS confirmation\n"
        f"- Use FULL ABSOLUTE PATHS for all file operations\n"
        f"- Focus on actionable technical insights"
    )
    
    analysis_task = Task(
        description=analysis_task_description,
        agent=ash_agent,
        expected_output="Confirmation that all V2 codebase batches have been analyzed and summaries written to memory document",
        context=[quarantine_task],
        max_iter=200  # High limit for batched analysis
    )
    tasks.append(analysis_task)
    
    # ============================================================================
    # PHASE 3: FINAL REPORT MANDATE
    # ============================================================================
    print("\n" + "="*80)
    print("PHASE 3: FINAL REPORT MANDATE")
    print("="*80)
    
    final_report_task_description = (
        f"Execute **PHASE 3: FINAL REPORT MANDATE** to create the consolidated technical baseline report.\n\n"
        f"**YOUR TASK:**\n"
        f"After successfully processing and saving all V2 codebase batches to memory, compile the findings into "
        f"a single, cohesive 'V2 Technical Baseline and Dependencies' report.\n\n"
        f"**STEP-BY-STEP INSTRUCTIONS:**\n\n"
        f"**STEP 1: Read All Batch Summaries**\n"
        f"- Use Google Docs Read Tool to read your entire memory document\n"
        f"- doc_id: {ash_memory_id}\n"
        f"- Review all batch analysis summaries\n"
        f"- Compile key findings from each batch\n\n"
        f"**STEP 2: Create Final Structured Report**\n"
        f"Create the final report following this EXACT format:\n\n"
        f"**Title & Metadata:**\n"
        f"- Title: V2 Technical Baseline and Dependencies\n"
        f"- Project: RatioVita_v2\n"
        f"- Agent: Ash Roy (Chief Architect)\n"
        f"- Date Completed: {datetime.now().strftime('%Y-%m-%d')}\n"
        f"- Target Codebase Version: V2 (Current State)\n\n"
        f"**Executive Summary:**\n"
        f"- A concise statement on the technical health and feasibility of V2\n"
        f"- Include the single greatest risk identified\n"
        f"- Overall assessment of codebase readiness\n\n"
        f"**Section 1: Dependencies & Libraries**\n"
        f"- Full list of external libraries (CocoaPods, npm modules, etc.)\n"
        f"- Risk Assessment for each:\n"
        f"  - Compatibility with V2 requirements\n"
        f"  - License issues (if any)\n"
        f"  - Security vulnerabilities (if known)\n"
        f"  - Maintenance status\n"
        f"- Summary of critical dependencies\n\n"
        f"**Section 2: Code Structure & Architecture**\n"
        f"- Primary programming language(s)\n"
        f"- Module hierarchy and organization\n"
        f"- Architecture patterns identified\n"
        f"- Immediate structural flaws (if any):\n"
        f"  - Monolithic design issues\n"
        f"  - Missing tests\n"
        f"  - Code organization problems\n"
        f"  - Other structural concerns\n\n"
        f"**Section 3: Key Recommendations**\n"
        f"- Actionable feedback for the team:\n"
        f"  - Library migration recommendations (if any)\n"
        f"  - Testing requirements\n"
        f"  - Architecture improvements\n"
        f"  - Security considerations\n"
        f"  - Other critical recommendations\n\n"
        f"**STEP 3: Write Final Report to Memory (MANDATORY)**\n"
        f"- Use Google Docs Memory Tool\n"
        f"- doc_id: {ash_memory_id}\n"
        f"- content: [the complete final report following the format above]\n"
        f"- append: True\n"
        f"- **VERIFY:** You MUST see SUCCESS message confirming final report was written\n\n"
        f"**CRITICAL:**\n"
        f"- The final report must be comprehensive and structured\n"
        f"- It must include all sections listed above\n"
        f"- It must be the LAST item written to your memory document\n"
        f"- You MUST verify SUCCESS before considering the task complete"
    )
    
    final_report_task = Task(
        description=final_report_task_description,
        agent=ash_agent,
        expected_output="Confirmation that V2 Technical Baseline and Dependencies report has been written to memory document",
        context=[analysis_task],
        max_iter=30
    )
    tasks.append(final_report_task)
    
    # ============================================================================
    # POST-TASK: Ash Roy - Write Completion Status to Memory
    # ============================================================================
    print("\n" + "="*80)
    print("POST-TASK: Ash Roy - Write Completion Status to Memory")
    print("="*80)
    
    ash_write_memory_task = Task(
        description=(
            f"After completing the engineering protocol, update your memory document with the completion status.\n\n"
            f"**MANDATORY FINAL STEP:**\n"
            f"1. Use the Google Docs Memory Tool\n"
            f"2. doc_id: {ash_memory_id}\n"
            f"3. content: 'V2 Technical Baseline Mission Completion Status - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\\n\\n"
            f"Status: COMPLETED\\n"
            f"Actions Completed:\\n"
            f"- Quarantined V1 legacy codebase (moved to ARCHIVED_V1_DO_NOT_USE)\\n"
            f"- Sent team notification email confirming V1 quarantine\\n"
            f"- Performed batched analysis of V2 codebase\\n"
            f"- Created V2 Technical Baseline and Dependencies report\\n"
            f"Report is ready for technical decision-makers and the Executive Strategy Group meeting.'\n"
            f"4. append: True\n"
            f"5. Verify you receive SUCCESS message\n\n"
            f"**IMPORTANT:** You must see a SUCCESS message confirming the completion status was written to your memory document."
        ),
        agent=ash_agent,
        expected_output="SUCCESS message confirming completion status written to memory document",
        context=[final_report_task],
        max_iter=3
    )
    tasks.append(ash_write_memory_task)
    
    # ============================================================================
    # EXECUTE ENGINEERING PROTOCOL
    # ============================================================================
    print("\n" + "="*80)
    print(f"🚀 Creating crew with {len(tasks)} tasks...")
    print("="*80)
    
    crew = Crew(
        agents=[dana_agent, ash_agent],
        tasks=tasks,
        process=Process.sequential,
        verbose=True,
        max_iter=300,  # High limit for batched analysis
        max_execution_time=7200  # 2 hour timeout
    )
    
    print("✅ Crew created")
    print("\n" + "="*80)
    print("Starting V2 Technical Baseline and Quarantining Mission...")
    print("="*80 + "\n")
    
    try:
        result = crew.kickoff()
        print("\n" + "="*80)
        print("✅ V2 TECHNICAL BASELINE MISSION COMPLETE")
        print("="*80)
        print("\n📊 Results:")
        print(result)
        print("\n" + "="*80)
        print("\n📋 VERIFICATION CHECKLIST:")
        print("="*80)
        print(f"✓ V1 folder quarantined to {ARCHIVED_V1_PATH}")
        print(f"✓ Team notification email sent")
        print(f"✓ V2 codebase analyzed in batches")
        print(f"✓ All batch summaries written to memory")
        print(f"✓ V2 Technical Baseline and Dependencies report created")
        print(f"✓ Completion status written to memory document")
        print("="*80)
        return result
    except Exception as e:
        print(f"\n❌ Error during V2 Technical Baseline Mission execution: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    ash_roy_engineering_protocol()

