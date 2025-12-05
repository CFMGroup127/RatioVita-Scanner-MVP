"""
Fix Dana Flores' Missing Memory Update
Force Dana to write her coordination task completion to memory.
"""
import os
from datetime import datetime
from crewai import Agent, Task, Crew, Process
from config import Config
from main import load_agents_from_yaml, get_agent_metadata

def fix_dana_memory():
    """Force Dana Flores to write coordination task completion to memory."""
    print("\n" + "="*80)
    print("🔧 FIXING DANA FLORES' MEMORY UPDATE")
    print("="*80)
    print("Writing coordination task completion to Dana's memory document")
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
    
    print(f"\n✅ Agent loaded: Dana Flores")
    
    dana_memory_id = dana_metadata.get('memory_doc_id', '')
    
    if not dana_memory_id:
        print("❌ Error: Dana's memory_doc_id not found")
        return None
    
    print(f"   Memory Doc ID: {dana_memory_id}")
    
    # ============================================================================
    # TASK: Write Coordination Task Completion
    # ============================================================================
    print("\n" + "="*80)
    print("TASK: Write Coordination Task Completion to Memory")
    print("="*80)
    
    dana_task = Task(
        description=(
            f"**YOUR TASK:** Write your coordination task completion status to your memory document.\n\n"
            f"**What to Write:**\n\n"
            f"BLOCK P and Concurrent Work Coordination Task Completed - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n"
            f"Status: COMPLETED\n\n"
            f"Coordinated Work Blocks:\n"
            f"- BLOCK P: Pre-Flight Strategy (Samuel Reed, Arthur Jensen, Megan Parker) - Completed\n"
            f"- Ash Roy: V2 Technical Baseline Mission - Completed\n"
            f"- David Chen: Report Handoff Protocol - Completed\n\n"
            f"All blocks have been successfully coordinated and completed. Workflow is properly managed.\n\n"
            f"**CRITICAL INSTRUCTIONS:**\n"
            f"1. Use Google Docs Memory Tool\n"
            f"2. doc_id: {dana_memory_id}\n"
            f"3. content: [Write the ENTIRE completion status above]\n"
            f"4. append: True\n"
            f"5. **YOU MUST SEE A SUCCESS MESSAGE** before you are done\n"
            f"6. If you don't see SUCCESS, try again\n"
            f"7. Do NOT finish until you see: 'SUCCESS: Content appended to Google Doc'\n\n"
            f"**THIS IS MANDATORY - YOU MUST WRITE TO MEMORY AND SEE SUCCESS**"
        ),
        agent=dana_agent,
        expected_output="SUCCESS message: 'SUCCESS: Content appended to Google Doc (ID: [doc_id]). Document updated successfully.'",
        max_iter=20
    )
    
    # ============================================================================
    # EXECUTE
    # ============================================================================
    print("\n" + "="*80)
    print(f"🚀 Creating crew with 1 task...")
    print("="*80)
    
    crew = Crew(
        agents=[dana_agent],
        tasks=[dana_task],
        process=Process.sequential,
        verbose=True,
        max_iter=30,
        max_execution_time=1800  # 30 minutes
    )
    
    print("✅ Crew created")
    print("\n" + "="*80)
    print("Starting Dana's memory update...")
    print("="*80 + "\n")
    
    try:
        result = crew.kickoff()
        print("\n" + "="*80)
        print("✅ DANA'S MEMORY UPDATE COMPLETE")
        print("="*80)
        print("\n📊 Results:")
        print(result)
        print("\n" + "="*80)
        return result
    except Exception as e:
        print(f"\n❌ Error during execution: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    fix_dana_memory()



