"""
Dana Flores Coordination Task
This script adds Dana's formal delegation and coordination for current running blocks.
Can be run concurrently with BLOCK P, Ash Roy, and David's merge protocol.
"""
import os
from datetime import datetime
from crewai import Agent, Task, Crew, Process
from config import Config
from main import load_agents_from_yaml, get_agent_metadata

def dana_coordination_task():
    """
    Execute Dana Flores's coordination task to formally acknowledge and coordinate
    the current work blocks (BLOCK P, Ash Roy, David merge).
    """
    print("\n" + "="*80)
    print("📋 DANA FLORES: COORDINATION & WORKFLOW MANAGEMENT")
    print("="*80)
    print("Formally coordinating current work blocks and ensuring proper delegation")
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
    
    # Get Dana Flores
    dana_role = "Admin Assistant & Workflow Funnel"
    dana_agent = None
    dana_metadata = None
    
    for agent in agents:
        if agent.role == dana_role:
            dana_agent = agent
            dana_metadata = get_agent_metadata(dana_role)
            break
    
    if not dana_agent:
        print(f"❌ Error: Dana Flores not found")
        return None
    
    print(f"\n✅ Dana Flores (Admin Assistant) loaded")
    
    dana_memory_id = dana_metadata.get('memory_doc_id', '')
    
    tasks = []
    
    # ============================================================================
    # PRE-TASK: Dana - Read Memory for Context
    # ============================================================================
    print("\n" + "="*80)
    print("PRE-TASK: Dana Flores - Read Memory for Context")
    print("="*80)
    
    dana_read_memory_task = Task(
        description=(
            f"Before starting coordination, read your memory document to understand your current context.\n\n"
            f"**MANDATORY FIRST STEP:**\n"
            f"1. Use the Google Docs Read Tool with your memory_doc_id: {dana_memory_id}\n"
            f"2. Review the contents of your memory document\n"
            f"3. Note any prior coordination work or task delegations\n\n"
            f"This ensures you have full context before beginning coordination."
        ),
        agent=dana_agent,
        expected_output="Confirmation that memory document has been read and context understood",
        max_iter=3
    )
    tasks.append(dana_read_memory_task)
    
    # ============================================================================
    # MAIN TASK: Dana - Coordinate Current Work Blocks
    # ============================================================================
    print("\n" + "="*80)
    print("MAIN TASK: Dana Flores - Coordinate Current Work Blocks")
    print("="*80)
    
    dana_task_description = (
        f"Execute your **COORDINATION & WORKFLOW MANAGEMENT** role for the current work blocks.\n\n"
        f"**CURRENT WORK BLOCKS IN PROGRESS:**\n\n"
        f"**BLOCK P: Pre-Flight Strategy** (Running concurrently)\n"
        f"- Samuel Reed: Conducting Market Analysis & Competitive Audit\n"
        f"- Arthur Jensen: Defining Design System Foundation\n"
        f"- Megan Parker: Developing V2 Branding & Core Value Proposition\n"
        f"- Status: In progress, running concurrently with other blocks\n\n"
        f"**Ash Roy: V2 Technical Baseline Mission** (Running concurrently)\n"
        f"- Phase 1: Quarantining V1 legacy codebase\n"
        f"- Phase 2: Analyzing V2 codebase in batches\n"
        f"- Phase 3: Creating V2 Technical Baseline and Dependencies report\n"
        f"- Status: In progress, running concurrently\n\n"
        f"**David Chen: Report Handoff Protocol** (Waiting for BLOCK P completion)\n"
        f"- Will merge all reports (Alice's archival, Samuel's market analysis, "
        f"Arthur's design system, Megan's branding)\n"
        f"- Will prepare Executive Strategy Group meeting agenda\n"
        f"- Status: Waiting for BLOCK P to complete\n\n"
        f"**YOUR COORDINATION TASK:**\n\n"
        f"1. **Acknowledge Current Work:**\n"
        f"   - Formally acknowledge that BLOCK P, Ash Roy's mission, and David's merge protocol are in progress\n"
        f"   - Note that these blocks are running concurrently for efficiency\n"
        f"   - Confirm that all agents are following their protocols\n\n"
        f"2. **Monitor Workflow:**\n"
        f"   - Ensure all blocks are progressing according to plan\n"
        f"   - Note any dependencies (David waiting for BLOCK P)\n"
        f"   - Confirm that all deliverables will be ready for the Executive Strategy Group meeting\n\n"
        f"3. **Document Coordination:**\n"
        f"   - Create a coordination summary in your memory document\n"
        f"   - Include: Current block status, Expected completion timeline, Key dependencies\n\n"
        f"4. **Team Communication (Optional but Recommended):**\n"
        f"   - Consider sending a brief status update email to key stakeholders if needed\n"
        f"   - Use Gmail Tool if coordination update is necessary\n\n"
        f"**IMPORTANT:**\n"
        f"- You are coordinating work that is already in progress\n"
        f"- Your role is to ensure proper workflow management and documentation\n"
        f"- All blocks are running as designed for concurrent execution efficiency"
    )
    
    dana_task = Task(
        description=dana_task_description,
        agent=dana_agent,
        expected_output="Confirmation that coordination task has been completed and status documented in memory",
        context=[dana_read_memory_task],
        max_iter=10
    )
    tasks.append(dana_task)
    
    # ============================================================================
    # POST-TASK: Dana - Write Completion Status to Memory
    # ============================================================================
    print("\n" + "="*80)
    print("POST-TASK: Dana Flores - Write Completion Status to Memory")
    print("="*80)
    
    dana_write_memory_task = Task(
        description=(
            f"After completing the coordination task, update your memory document with the completion status.\n\n"
            f"**MANDATORY FINAL STEP:**\n"
            f"1. Use the Google Docs Memory Tool\n"
            f"2. doc_id: {dana_memory_id}\n"
            f"3. content: 'Coordination Task Completed - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\\n\\n"
            f"Status: COMPLETED\\n"
            f"Coordinated Work Blocks:\\n"
            f"- BLOCK P: Pre-Flight Strategy (Samuel, Arthur, Megan) - In progress\\n"
            f"- Ash Roy: V2 Technical Baseline Mission - In progress\\n"
            f"- David Chen: Report Handoff Protocol - Waiting for BLOCK P\\n"
            f"All blocks are running according to plan. Workflow is properly managed.'\n"
            f"4. append: True\n"
            f"5. Verify you receive SUCCESS message\n\n"
            f"**IMPORTANT:** You must see a SUCCESS message confirming the update was written."
        ),
        agent=dana_agent,
        expected_output="SUCCESS message confirming completion status written to memory document",
        context=[dana_task],
        max_iter=3
    )
    tasks.append(dana_write_memory_task)
    
    # ============================================================================
    # EXECUTE COORDINATION TASK
    # ============================================================================
    print("\n" + "="*80)
    print(f"🚀 Creating crew with {len(tasks)} tasks...")
    print("="*80)
    
    crew = Crew(
        agents=[dana_agent],
        tasks=tasks,
        process=Process.sequential,
        verbose=True,
        max_iter=50,
        max_execution_time=1800  # 30 minutes
    )
    
    print("✅ Crew created")
    print("\n" + "="*80)
    print("Starting Dana Flores coordination task...")
    print("="*80 + "\n")
    
    try:
        result = crew.kickoff()
        print("\n" + "="*80)
        print("✅ DANA COORDINATION TASK COMPLETE")
        print("="*80)
        print("\n📊 Results:")
        print(result)
        print("\n" + "="*80)
        return result
    except Exception as e:
        print(f"\n❌ Error during coordination task execution: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    dana_coordination_task()



