"""
BLOCK A: Initial Delegation & Archival Setup
This script launches the initial RatioVita_v2 project phase with proper delegation and archival protocols.
"""
import os
from datetime import datetime
from crewai import Agent, Task, Crew, Process
from config import Config
from main import load_agents_from_yaml, get_agent_metadata

# LEGACY_V1_PATH constant
LEGACY_V1_PATH = "/Users/colliemorris/Projects 2/RatioVita_v2/RatioVita_v1"

def block_a_initial_delegation():
    """
    Execute BLOCK A: Initial Data Ingestion & Archival
    
    This block:
    1. Dana Flores coordinates the archival task
    2. Alice Kim processes V1 legacy assets using ArchivalDirectoryListTool
    3. Alice Kim follows BATCH PROCESSING MANDATE and FINAL REPORT MANDATE
    4. David Chen retrieves final report and prepares Executive Strategy Group meeting
    """
    print("\n" + "="*80)
    print("🚀 BLOCK A: INITIAL DELEGATION & ARCHIVAL SETUP")
    print("="*80)
    print(f"Target Meeting Date: Friday, November 21, 2025")
    print(f"Legacy Path: {LEGACY_V1_PATH}")
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
    
    # Get key agents
    dana_role = "Admin Assistant & Workflow Funnel"
    alice_role = "Documentation and Knowledge Archivist"
    david_role = "Process Architect and Schedule Publisher"
    
    dana_agent = None
    alice_agent = None
    david_agent = None
    alice_metadata = None
    david_metadata = None
    
    for agent in agents:
        if agent.role == dana_role:
            dana_agent = agent
        elif agent.role == alice_role:
            alice_agent = agent
            alice_metadata = get_agent_metadata(alice_role)
        elif agent.role == david_role:
            david_agent = agent
            david_metadata = get_agent_metadata(david_role)
    
    if not dana_agent or not alice_agent or not david_agent:
        missing = []
        if not dana_agent: missing.append("Dana Flores")
        if not alice_agent: missing.append("Alice Kim")
        if not david_agent: missing.append("David Chen")
        print(f"❌ Error: Missing required agents: {', '.join(missing)}")
        return None
    
    print(f"\n✅ Key agents loaded:")
    print(f"   - Dana Flores (Admin Assistant)")
    print(f"   - Alice Kim (Technical Writer)")
    print(f"   - David Chen (COO)")
    
    tasks = []
    
    # Get memory IDs
    alice_memory_id = alice_metadata.get('memory_doc_id', '')
    dana_memory_id = get_agent_metadata(dana_role).get('memory_doc_id', '')
    david_memory_id = david_metadata.get('memory_doc_id', '')
    
    # ============================================================================
    # PRE-TASK: Dana Flores - Read Memory for Context
    # ============================================================================
    print("\n" + "="*80)
    print("PRE-TASK: Dana Flores - Read Memory for Context")
    print("="*80)
    
    dana_read_memory_task = Task(
        description=(
            f"Before starting your task, read your memory document to understand your current context and any prior instructions.\n\n"
            f"**MANDATORY FIRST STEP:**\n"
            f"1. Use the Google Docs Read Tool with your memory_doc_id: {dana_memory_id}\n"
            f"2. Review the contents of your memory document\n"
            f"3. Note any relevant context, prior tasks, or instructions\n\n"
            f"This ensures you have full context before beginning the BLOCK A delegation task."
        ),
        agent=dana_agent,
        expected_output="Confirmation that memory document has been read and context understood",
        max_iter=3
    )
    tasks.append(dana_read_memory_task)
    
    # ============================================================================
    # TASK 1: Dana Flores - Initial Coordination & Delegation
    # ============================================================================
    print("\n" + "="*80)
    print("TASK 1: Dana Flores - Initial Coordination & Delegation")
    print("="*80)
    
    dana_task_description = (
        f"Initiate the project workflow for RatioVita_v2. Your first priority is BLOCK A: Initial Data Ingestion & Archival.\n\n"
        f"You must coordinate and delegate the retrieval and summarization of all non-code V1 assets and documentation "
        f"from the LEGACY_V1_PATH ({LEGACY_V1_PATH}) to the Technical Writer (Alice Kim).\n\n"
        f"**Delegation Instructions:**\n"
        f"1. Delegate the archival task to Alice Kim (Technical Writer)\n"
        f"2. Ensure Alice Kim uses the **ArchivalDirectoryListTool** to get the initial file list\n"
        f"3. Ensure Alice Kim adheres to the **BATCH PROCESSING MANDATE** (processes files in batches of 10, "
        f"validates output, and saves each batch summary to her memory document before proceeding)\n"
        f"4. Ensure Alice Kim follows the **FINAL REPORT MANDATE** (creates a single, cohesive final report "
        f"after all batches are complete)\n"
        f"5. Monitor progress and confirm when the archival task is complete\n\n"
        f"The final summary report must be filed and ready for the upcoming Executive Strategy Group meeting "
        f"scheduled for **Friday, November 21, 2025**.\n\n"
        f"Alice Kim's memory document ID: {alice_memory_id}\n"
        f"Once Alice completes her task, you will coordinate with David Chen (COO) to retrieve the final report "
        f"and prepare the meeting agenda."
    )
    
    dana_task = Task(
        description=dana_task_description,
        agent=dana_agent,
        expected_output="Confirmation that archival task has been delegated to Alice Kim and coordination is in progress",
        context=[dana_read_memory_task],
        max_iter=5
    )
    tasks.append(dana_task)
    
    # ============================================================================
    # POST-TASK: Dana Flores - Write Completion Status to Memory
    # ============================================================================
    print("\n" + "="*80)
    print("POST-TASK: Dana Flores - Write Completion Status to Memory")
    print("="*80)
    
    dana_write_memory_task = Task(
        description=(
            f"After completing the delegation task, update your memory document with the completion status.\n\n"
            f"**MANDATORY FINAL STEP:**\n"
            f"1. Use the Google Docs Memory Tool\n"
            f"2. doc_id: {dana_memory_id}\n"
            f"3. content: 'BLOCK A Delegation Task Completed - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}. "
            f"Successfully delegated archival task to Alice Kim (Technical Writer). Task status: COMPLETED.'\n"
            f"4. append: True\n"
            f"5. Verify you receive SUCCESS message\n\n"
            f"**IMPORTANT:** You must see a SUCCESS message confirming the update was written to your memory document."
        ),
        agent=dana_agent,
        expected_output="SUCCESS message confirming completion status written to memory document",
        context=[dana_task],
        max_iter=3
    )
    tasks.append(dana_write_memory_task)
    
    # ============================================================================
    # PRE-TASK: Alice Kim - Read Memory for Context
    # ============================================================================
    print("\n" + "="*80)
    print("PRE-TASK: Alice Kim - Read Memory for Context")
    print("="*80)
    
    alice_read_memory_task = Task(
        description=(
            f"Before starting the archival task, read your memory document to understand your current context and any prior instructions.\n\n"
            f"**MANDATORY FIRST STEP:**\n"
            f"1. Use the Google Docs Read Tool with your memory_doc_id: {alice_memory_id}\n"
            f"2. Review the contents of your memory document\n"
            f"3. Note any relevant context, protocols, or prior archival work\n\n"
            f"This ensures you have full context before beginning the V1 legacy asset archival task."
        ),
        agent=alice_agent,
        expected_output="Confirmation that memory document has been read and context understood",
        context=[dana_write_memory_task],
        max_iter=3
    )
    tasks.append(alice_read_memory_task)
    
    # ============================================================================
    # TASK 2: Alice Kim - Archival Processing (SIMPLIFIED)
    # ============================================================================
    print("\n" + "="*80)
    print("TASK 2: Alice Kim - Archival Processing (SIMPLIFIED - Starting with 3 files)")
    print("="*80)
    
    alice_task_description = (
        f"Execute the V1 Legacy Asset Archival task as delegated by Dana Flores.\n\n"
        f"**SIMPLIFIED APPROACH: Start with 3 files to verify the workflow, then scale up.**\n\n"
        f"**STEP-BY-STEP INSTRUCTIONS:**\n\n"
        f"**STEP 1: Get File List**\n"
        f"- Use ArchivalDirectoryListTool ONCE with directory: {LEGACY_V1_PATH}\n"
        f"- This will return a list of documentation files\n\n"
        f"**STEP 2: Process First 3 Files (Test Batch)**\n"
        f"For each of the first 3 files from the list:\n"
        f"  a. Read the file using FileReadTool with FULL ABSOLUTE PATH: {LEGACY_V1_PATH}/[filename]\n"
        f"  b. **MANDATORY:** Delegate summarization to Cursor Archival Assistant using Cursor LLM Interface Tool:\n"
        f"     - Prompt: 'Act as a V1 Documentation and Asset Extraction Bot. Your task is ONLY to read the provided text block and extract "
        f"all relevant UI/UX design specifications, marketing copy, and archival documentation. IGNORE all Python/Shell script syntax. "
        f"Provide a single, concise summary of the findings.'\n"
        f"     - Pass the file content to Cursor LLM Interface Tool\n"
        f"     - Validate the Cursor output (check for code contamination)\n"
        f"  c. **MANDATORY:** Write the validated summary to your memory document:\n"
        f"     - Use Google Docs Memory Tool\n"
        f"     - doc_id: {alice_memory_id}\n"
        f"     - content: 'Batch 1 - File: [filename]\\n\\nSummary: [your summary]'\n"
        f"     - append: True\n"
        f"  d. **VERIFY:** You MUST see a SUCCESS message before proceeding to next file\n\n"
        f"**STEP 3: After All 3 Files Are Processed and Written to Memory**\n"
        f"- Create a consolidated summary of the 3 files\n"
        f"- **MANDATORY:** Write this consolidated summary to memory:\n"
        f"  - Use Google Docs Memory Tool\n"
        f"  - doc_id: {alice_memory_id}\n"
        f"  - content: 'Batch 1 Consolidated Summary:\\n\\n[summary of all 3 files]'\n"
        f"  - append: True\n"
        f"  - **VERIFY:** You MUST see SUCCESS message\n\n"
        f"**STEP 4: Continue with Remaining Files**\n"
        f"- Process remaining files in batches of 5-10\n"
        f"- For each batch:\n"
        f"  a. Read files using FileReadTool (FULL ABSOLUTE PATHS)\n"
        f"  b. **MANDATORY:** Delegate summarization to Cursor Archival Assistant (use Cursor LLM Interface Tool)\n"
        f"  c. Validate Cursor output (check for code contamination)\n"
        f"  d. Write validated summary to memory → Verify SUCCESS\n"
        f"- Do NOT proceed to next batch until you see SUCCESS for current batch\n\n"
        f"**STEP 5: Create Final Report**\n"
        f"After ALL files are processed and all batch summaries are in your memory document:\n"
        f"1. Read your entire memory document using Google Docs Read Tool\n"
        f"2. Review all batch summaries\n"
        f"3. Create the FINAL REPORT following this format:\n\n"
        f"   Title: V1 Legacy Asset Archival and Strategy Summary (BLOCK A Final Report)\n"
        f"   Project: RatioVita_v1 Archival\n"
        f"   Agent: Alice Kim (Technical Writer)\n"
        f"   Date Completed: [Current Date]\n"
        f"   Source Path: {LEGACY_V1_PATH}\n\n"
        f"   Section 1: Executive Summary\n"
        f"   - V1 Core Strategy: [one paragraph]\n"
        f"   - Key Design Elements: [bulleted list]\n"
        f"   - Critical Dependencies: [any essential resources]\n\n"
        f"   Section 2: Consolidated Archival Findings\n"
        f"   - Marketing & Messaging: [findings]\n"
        f"   - UX & Design: [findings]\n"
        f"   - Development Documentation: [findings]\n\n"
        f"   Section 3: Appendices\n"
        f"   - Files Processed: [list]\n"
        f"   - Files Excluded: [list]\n\n"
        f"4. **MANDATORY:** Write the final report to your memory document:\n"
        f"   - Use Google Docs Memory Tool\n"
        f"   - doc_id: {alice_memory_id}\n"
        f"   - content: [the complete final report]\n"
        f"   - append: True\n"
        f"   - **VERIFY:** You MUST see SUCCESS message\n\n"
        f"**CRITICAL RULES:**\n"
        f"- Use FULL ABSOLUTE PATHS: {LEGACY_V1_PATH}/[filename]\n"
        f"- Write to memory after EACH file summary AND after EACH batch\n"
        f"- Verify SUCCESS message after EVERY memory write\n"
        f"- Do NOT proceed without SUCCESS confirmation\n"
        f"- Final report is the LAST thing you write to memory"
    )
    
    alice_task = Task(
        description=alice_task_description,
        agent=alice_agent,
        expected_output=f"Confirmation that all V1 legacy assets have been processed and final report is written to memory document (ID: {alice_memory_id})",
        context=[alice_read_memory_task],
        max_iter=200  # Much higher limit for archival task
    )
    tasks.append(alice_task)
    
    # ============================================================================
    # POST-TASK: Alice Kim - Write Completion Status to Memory
    # ============================================================================
    print("\n" + "="*80)
    print("POST-TASK: Alice Kim - Write Completion Status to Memory")
    print("="*80)
    
    alice_write_memory_task = Task(
        description=(
            f"After completing the archival task and creating the final report, update your memory document with the completion status.\n\n"
            f"**MANDATORY FINAL STEP:**\n"
            f"1. Use the Google Docs Memory Tool\n"
            f"2. doc_id: {alice_memory_id}\n"
            f"3. content: 'BLOCK A Archival Task Completion Status - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\\n\\n"
            f"Status: COMPLETED\\n"
            f"Final Report: V1 Legacy Asset Archival and Strategy Summary (BLOCK A Final Report) has been written to this memory document.\\n"
            f"Report is ready for Executive Strategy Group meeting on Friday, November 21, 2025.'\n"
            f"4. append: True\n"
            f"5. Verify you receive SUCCESS message\n\n"
            f"**IMPORTANT:** You must see a SUCCESS message confirming the completion status was written to your memory document."
        ),
        agent=alice_agent,
        expected_output="SUCCESS message confirming completion status written to memory document",
        context=[alice_task],
        max_iter=3
    )
    tasks.append(alice_write_memory_task)
    
    # ============================================================================
    # PRE-TASK: David Chen - Read Memory for Context
    # ============================================================================
    print("\n" + "="*80)
    print("PRE-TASK: David Chen - Read Memory for Context")
    print("="*80)
    
    david_read_memory_task = Task(
        description=(
            f"Before starting the report handoff task, read your memory document to understand your current context and any prior instructions.\n\n"
            f"**MANDATORY FIRST STEP:**\n"
            f"1. Use the Google Docs Read Tool with your memory_doc_id: {david_memory_id}\n"
            f"2. Review the contents of your memory document\n"
            f"3. Note any relevant context, protocols, or prior coordination work\n\n"
            f"This ensures you have full context before beginning the REPORT HANDOFF PROTOCOL."
        ),
        agent=david_agent,
        expected_output="Confirmation that memory document has been read and context understood",
        context=[alice_write_memory_task],
        max_iter=3
    )
    tasks.append(david_read_memory_task)
    
    # ============================================================================
    # TASK 3: David Chen - Report Retrieval & Meeting Preparation
    # ============================================================================
    print("\n" + "="*80)
    print("TASK 3: David Chen - Report Retrieval & Meeting Preparation")
    print("="*80)
    
    david_task_description = (
        f"Execute the **REPORT HANDOFF PROTOCOL**. Alice Kim's archival task has been completed (this task runs after hers in sequence).\n\n"
        f"**STEP-BY-STEP INSTRUCTIONS:**\n\n"
        f"**STEP 1: Read Alice's Memory Document (MANDATORY FIRST)**\n"
        f"- Use Google Docs Read Tool\n"
        f"- doc_id: {alice_memory_id}\n"
        f"- Read the entire document\n"
        f"- Find the 'V1 Legacy Asset Archival and Strategy Summary (BLOCK A Final Report)'\n"
        f"- Review the final report content\n\n"
        f"**STEP 2: Create Calendar Event (MANDATORY)**\n"
        f"- Use Google Calendar Tool\n"
        f"- calendar_id: {david_metadata.get('project_schedule_calendar_id', 'primary')}\n"
        f"- action: create\n"
        f"- event_title: Executive Strategy Group Meeting - V1 Legacy Review & V2 Planning\n"
        f"- event_description: Review V1 legacy assets and plan V2 strategy. Pre-read materials distributed via email.\n"
        f"- start_time: 2025-11-21T10:00:00\n"
        f"- end_time: 2025-11-21T12:00:00\n"
        f"- **VERIFY:** You must see SUCCESS message confirming event was created\n\n"
        f"**STEP 3: Draft Meeting Agenda**\n"
        f"- Based on the final report, create a clear meeting agenda\n"
        f"- Include: Review of V1 legacy assets, Discussion of key findings, V2 planning priorities\n\n"
        f"**STEP 4: Prepare Pre-Read Materials**\n"
        f"- Summarize key points from the archival report\n"
        f"- Make it concise and actionable\n\n"
        f"**STEP 5: Distribute Agenda via Email (MANDATORY)**\n"
        f"- Use Gmail Tool\n"
        f"- Send to ALL team members:\n"
        f"  kyle.law@ratiovita.com, dana.flores@ratiovita.com, ash.roy@ratiovita.com, david.chen@ratiovita.com, "
        f"alice.kim@ratiovita.com, megan.parker@ratiovita.com, ethan.hayes@ratiovita.com, chloe.park@ratiovita.com, "
        f"samuel.reed@ratiovita.com, victor.alvarez@ratiovita.com, jennifer.jurvais@ratiovita.com, tyler.cobb@ratiovita.com, "
        f"rachel.stone@ratiovita.com, arthur.jensen@ratiovita.com\n"
        f"- Subject: Executive Strategy Group Meeting - Friday, November 21, 2025 - Agenda & Pre-Read\n"
        f"- Body: Include the meeting agenda and pre-read materials\n"
        f"- CC: collin.m@ratiovita.com (automatic - tool will add this)\n"
        f"- **VERIFY:** You must see SUCCESS message for each email sent\n\n"
        f"**Meeting Details:**\n"
        f"- Date: Friday, November 21, 2025\n"
        f"- Time: 10:00 AM - 12:00 PM\n"
        f"- Purpose: Review V1 legacy assets and plan V2 strategy\n\n"
        f"**CRITICAL:**\n"
        f"- You MUST complete all 5 steps in order\n"
        f"- You MUST verify SUCCESS for calendar event creation\n"
        f"- You MUST verify SUCCESS for email distribution\n"
        f"- Do NOT skip any steps"
    )
    
    david_task = Task(
        description=david_task_description,
        agent=david_agent,
        expected_output="Confirmation that meeting agenda and pre-read materials have been distributed to all team members",
        context=[david_read_memory_task],
        max_iter=20  # Increased for multiple steps
    )
    tasks.append(david_task)
    
    # ============================================================================
    # POST-TASK: David Chen - Write Completion Status to Memory
    # ============================================================================
    print("\n" + "="*80)
    print("POST-TASK: David Chen - Write Completion Status to Memory")
    print("="*80)
    
    david_write_memory_task = Task(
        description=(
            f"After completing the report handoff and meeting preparation, update your memory document with the completion status.\n\n"
            f"**MANDATORY FINAL STEP:**\n"
            f"1. Use the Google Docs Memory Tool\n"
            f"2. doc_id: {david_memory_id}\n"
            f"3. content: 'BLOCK A Report Handoff Task Completion Status - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\\n\\n"
            f"Status: COMPLETED\\n"
            f"Actions Completed:\\n"
            f"- Retrieved final report from Alice Kim's memory document\\n"
            f"- Created calendar event for Executive Strategy Group meeting (November 21, 2025)\\n"
            f"- Drafted meeting agenda based on archival findings\\n"
            f"- Distributed agenda and pre-read materials to all team members via email\\n"
            f"Meeting scheduled: Friday, November 21, 2025, 10:00 AM - 12:00 PM'\n"
            f"4. append: True\n"
            f"5. Verify you receive SUCCESS message\n\n"
            f"**IMPORTANT:** You must see a SUCCESS message confirming the completion status was written to your memory document."
        ),
        agent=david_agent,
        expected_output="SUCCESS message confirming completion status written to memory document",
        context=[david_task],
        max_iter=3
    )
    tasks.append(david_write_memory_task)
    
    # ============================================================================
    # EXECUTE BLOCK A
    # ============================================================================
    print("\n" + "="*80)
    print(f"🚀 Creating crew with {len(tasks)} tasks...")
    print("="*80)
    
    crew = Crew(
        agents=[dana_agent, alice_agent, david_agent],
        tasks=tasks,
        process=Process.sequential,
        verbose=True,
        max_iter=300,  # Much higher limit for all tasks including memory operations
        max_execution_time=7200  # 2 hour timeout for archival task
    )
    
    print("✅ Crew created")
    print("\n" + "="*80)
    print("Starting BLOCK A execution...")
    print("="*80 + "\n")
    
    try:
        result = crew.kickoff()
        print("\n" + "="*80)
        print("✅ BLOCK A COMPLETE")
        print("="*80)
        print("\n📊 Results:")
        print(result)
        print("\n" + "="*80)
        print("\n📋 VERIFICATION CHECKLIST:")
        print("="*80)
        print(f"✓ Alice Kim's memory document contains final report (ID: {alice_memory_id})")
        print("✓ David Chen has retrieved report and distributed meeting agenda")
        print("✓ All team members received meeting invitation and pre-read materials")
        print("="*80)
        return result
    except Exception as e:
        print(f"\n❌ Error during BLOCK A execution: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    block_a_initial_delegation()

