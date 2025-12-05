"""
Start Agent Work - Simple script to trigger agents to begin working
This runs one task at a time with clear progress tracking
"""
import os
import sys
import yaml
from pathlib import Path
from datetime import datetime, timedelta
from crewai import Agent, Task, Crew
from langchain_openai import ChatOpenAI

# Add agents_system to path
sys.path.insert(0, str(Path(__file__).parent))
os.chdir(Path(__file__).parent)

from config import Config
from tools import (
    get_google_docs_memory_tool,
    get_google_docs_read_tool,
    get_google_tasks_tool,
    get_gmail_tool,
    get_file_read_tool,
    get_file_write_tool
)

def load_agents():
    """Load agent definitions"""
    agents_yaml = Path(__file__).parent / 'agents.yaml'
    with open(agents_yaml, 'r') as f:
        data = yaml.safe_load(f)
    return data.get('agents', [])

def find_agent_by_name(agents, name):
    """Find agent by name"""
    name_lower = name.lower()
    for agent in agents:
        # Check designation
        if name_lower in agent.get('designation', '').lower():
            return agent
        # Check email address
        email = agent.get('email_address', '')
        if name_lower.replace(' ', '.') in email.lower():
            return agent
        # Check role
        if name_lower in agent.get('role', '').lower():
            return agent
    return None

def start_agent_work(agent_name, task_id):
    """Start an agent working on a specific task"""
    
    print(f"\n{'='*80}")
    print(f"🚀 STARTING: {agent_name} - Task {task_id}")
    print(f"{'='*80}\n")
    
    # Load agents
    agents = load_agents()
    agent_data = find_agent_by_name(agents, agent_name)
    
    if not agent_data:
        print(f"❌ Agent not found: {agent_name}")
        return None
    
    # Get tools
    tools = []
    try:
        tools.append(get_google_docs_memory_tool())  # Write to memory documents
        tools.append(get_google_docs_read_tool())   # Read memory documents
        tools.append(get_google_tasks_tool())        # P3 protocol - Google Tasks
        tools.append(get_gmail_tool(agent_role=agent_data.get('role', '')))  # DTR and reports to Dana/David
        tools.append(get_file_read_tool())           # Read code files
        tools.append(get_file_write_tool())          # Write code files
    except Exception as e:
        print(f"⚠️  Warning: Some tools failed to load: {e}")
    
    # Get API key - prioritize .env file over agents.yaml
    # Check if agents.yaml key is valid (OpenAI keys start with 'sk-')
    api_key = None
    yaml_key = agent_data.get('api_key', '')
    
    # Use .env key if available (preferred)
    if Config.OPENAI_API_KEY:
        api_key = Config.OPENAI_API_KEY
        print(f"✅ Using API key from .env file")
    # Fall back to agents.yaml key only if it looks valid
    elif yaml_key and yaml_key.startswith('sk-'):
        api_key = yaml_key
        print(f"✅ Using API key from agents.yaml")
    else:
        print(f"❌ Error: No valid OPENAI_API_KEY found")
        print(f"   - Checked .env file: {'Found' if Config.OPENAI_API_KEY else 'Not found'}")
        print(f"   - Checked agents.yaml: {'Found but invalid format' if yaml_key else 'Not found'}")
        print(f"   - Please create .env file with: OPENAI_API_KEY=sk-...")
        return None
    
    # Set environment variable for CrewAI
    import os
    os.environ['OPENAI_API_KEY'] = api_key
    
    # Create agent LLM
    agent_llm = ChatOpenAI(
        model=agent_data.get('model', Config.OPENAI_MODEL),
        openai_api_key=api_key,
        temperature=0.7
    )
    
    # Set execution time based on task constraint
    max_execution_seconds = max_hours * 3600  # Convert hours to seconds
    max_iter = max(15, int(max_execution_seconds / 300))  # Adjust iterations based on time
    
    agent = Agent(
        role=agent_data.get('role', ''),
        goal=agent_data.get('goal', ''),
        backstory=agent_data.get('backstory', ''),
        verbose=True,
        allow_delegation=False,
        tools=tools,
        llm=agent_llm,
        max_iter=max_iter,
        max_execution_time=max_execution_seconds
    )
    
    # Get agent's memory document ID
    memory_doc_id = agent_data.get('memory_doc_id', '')
    if not memory_doc_id:
        print(f"❌ Error: No memory_doc_id found for {agent_name}")
        return None
    
    # Get task time constraint
    from task_time_management import get_task_time_constraint
    time_constraint = get_task_time_constraint(task_id)
    estimated_hours = 8  # Default
    max_hours = 12  # Default
    if time_constraint:
        estimated_hours = time_constraint['estimated_hours']
        max_hours = time_constraint['max_hours']
        print(f"⏰ Time Constraint: {estimated_hours}h estimated, {max_hours}h max")
    else:
        print(f"⏰ Time Constraint: {estimated_hours}h estimated, {max_hours}h max (default)")
    
    # Create task - agent should read memory and begin work
    task_description = f"""
**READ YOUR MEMORY DOCUMENT AND BEGIN WORK**

You have been assigned tasks in your memory document. Please:

1. **Read your memory document** using the Google Docs Read Tool with document ID: {memory_doc_id}
2. **Find your assigned tasks** in the TASKS section
3. **Begin executing the highest priority task** (P0 first, then P1, etc.)
4. **Use your tools** (FileReadTool, FileWriteTool) to actually complete the work
5. **Log progress** to your memory document (ID: {memory_doc_id}) as you work
6. **Submit a DTR** (Daily Task Report) when you finish work for the day

**YOUR MEMORY DOCUMENT ID:** {memory_doc_id}
**Use this exact ID when reading or writing to your memory document.**

**DTR REQUIREMENT (Daily Task Report):**
- At the end of each work day, submit a Daily Task Report (DTR)
- Format: Table format (see DTR_TEMPLATE.md)
- Submit to: dana.flores@ratiovita.com and david.chen@ratiovita.com
- CC: collin.m@ratiovita.com (MANDATORY)
- Subject: "DTR - {agent_name} - [Date] - [Task IDs]"
- Include in memory document: REPORTS section with date subsection

**REPORTING REQUIREMENT:**
- All formal reports must be sent to project.reports@ratiovita.com
- Use Gmail Tool to send emails
- All emails automatically CC collin.m@ratiovita.com

**CRITICAL:** You must EXECUTE the work, not just log it. Read files, write code, make changes.

**Task ID to focus on:** {task_id}

**TIME CONSTRAINT:**
- Estimated Time: {estimated_hours} hours
- Maximum Time: {max_hours} hours
- Start Time: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}
- You must provide progress updates every 2 hours
- If you encounter issues or need more time, update your estimate immediately

**PROGRESS MONITORING:**
- Kimi K2 will monitor your progress
- You will receive prompts for updates at checkpoints
- If you get stuck, Kimi K2 will help you recover

Begin now.
"""
    
    task = Task(
        description=task_description,
        agent=agent,
        expected_output=f"Agent {agent_name} has read memory document, identified assigned tasks, and begun executing work on task {task_id}."
    )
    
    # Create crew
    crew = Crew(
        agents=[agent],
        tasks=[task],
        verbose=True,
        process="sequential"
    )
    
    print(f"✅ Starting execution for {agent_name}...\n")
    
    try:
        result = crew.kickoff()
        print(f"\n{'='*80}")
        print(f"✅ COMPLETE: {agent_name} - Task {task_id}")
        print(f"{'='*80}\n")
        return result
    except Exception as e:
        print(f"\n{'='*80}")
        print(f"❌ FAILED: {agent_name} - Task {task_id}")
        print(f"{'='*80}")
        print(f"Error: {e}\n")
        import traceback
        traceback.print_exc()
        return None

def main():
    """Main execution - start with highest priority task"""
    
    print("\n" + "="*80)
    print("🚀 STARTING AGENT WORK - RATIOVITA V2")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
    
    # Start with highest priority task
    print("📋 Starting with highest priority task: V2-001")
    print("   Agent: Ethan Hayes")
    print("   Task: Connect CameraCaptureView to RealScannerService\n")
    
    result = start_agent_work("Ethan Hayes", "V2-001")
    
    if result:
        print("\n✅ First task execution started successfully!")
        print("\n📋 Next steps:")
        print("   - Monitor agent progress in memory documents")
        print("   - Agent will submit DTR when work is complete")
        print("   - Kimi K2 will review quality")
    else:
        print("\n❌ Task execution failed. Check errors above.")
    
    print()

if __name__ == "__main__":
    main()

