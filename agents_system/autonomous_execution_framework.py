"""
Autonomous Execution Framework
Provides a reusable framework for triggering autonomous task execution after P3 logging.
"""
import os
import sys
from pathlib import Path
from datetime import datetime
from crewai import Agent, Task, Crew
from config import Config

def get_execution_tools_for_agent(role):
    """
    Get appropriate execution tools based on agent role.
    
    Args:
        role: The agent's role
        
    Returns:
        List of execution tools
    """
    from tools import (
        get_code_execution_tool,
        get_file_read_tool,
        get_file_write_tool,
        get_cursor_llm_tool,
        get_google_docs_memory_tool,
        get_google_tasks_tool
    )
    
    tools = []
    
    # All agents get memory and tasks tools
    try:
        tools.append(get_google_docs_memory_tool())
    except:
        pass
    try:
        tools.append(get_google_tasks_tool())
    except:
        pass
    
    # Code execution tools for engineering roles
    if role in [
        "Lead Code Execution and V2 Development",
        "Technical and Product Visionary",
        "Process and Factual Integrity Auditor"
    ]:
        try:
            tools.append(get_code_execution_tool())
        except:
            pass
        try:
            tools.append(get_file_read_tool())
        except:
            pass
        try:
            tools.append(get_file_write_tool())
        except:
            pass
        try:
            tools.append(get_cursor_llm_tool())
        except:
            pass
    
    # File tools for documentation roles
    elif role in ["Documentation and Knowledge Archivist"]:
        try:
            tools.append(get_file_read_tool())
        except:
            pass
        try:
            tools.append(get_file_write_tool())
        except:
            pass
        try:
            tools.append(get_cursor_llm_tool())
        except:
            pass
    
    return tools

def create_autonomous_execution_task(
    agent,
    task_name,
    task_description,
    execution_instructions,
    expected_artifacts=None
):
    """
    Create a task that includes both P3 logging and P4 execution.
    
    Args:
        agent: The CrewAI agent
        task_name: Name of the task
        task_description: Full task description
        execution_instructions: Specific instructions for execution
        expected_artifacts: List of expected artifacts (file paths, URLs, etc.)
    
    Returns:
        Task object with P3 + P4 protocols
    """
    
    full_task_description = f"""
**TASK ASSIGNMENT: {task_name}**

{task_description}

**MANDATORY P3 PROTOCOL (Task Logging):**

**STEP 1: P0 ACKNOWLEDGMENT**
- Immediately acknowledge receipt of this task
- Log the acknowledgment to your memory document with timestamp

**STEP 2: P3 HYBRID LOGGING - PART A (Memory Document)**
- Use the **Google Docs Memory Tool** to update your TASKS section:
  - section: "TASKS"
  - subsection: "{datetime.now().strftime('%B %d, %Y')}"
  - content: Task details with priority, due date, and status
  - template: "Task Tracker"

**STEP 3: P3 HYBRID LOGGING - PART B (Google Tasks)**
- Use the **Google Tasks Tool** to create the task in Google Tasks
- Set appropriate due date and priority

**MANDATORY P4 PROTOCOL (Autonomous Execution):**

After completing P3 logging, you MUST immediately execute the task:

{execution_instructions}

**EXECUTION REQUIREMENTS:**
- Use your available execution tools (CodeInterpreterTool, FileReadTool, FileWriteTool, CursorLLMTool) as appropriate
- Do not wait for manual triggers - execute immediately after P3 logging
- Log progress to your memory document as you work
- Document any issues or blockers encountered

**COMPLETION REQUIREMENTS:**
- Verify task completion criteria are met
- Test/validate the work completed
- Update memory document with completion status
- Mark Google Task as COMPLETE
- Include artifact references: {expected_artifacts if expected_artifacts else 'file paths, commit hashes, URLs, etc.'}

**CRITICAL:** You must EXECUTE the task, not just log it. Use your tools to actually complete the work.

**OUTPUT:**
After completing P3 + P4 protocols, provide:
1. P3 confirmation: Task logged to memory + Google Tasks
2. P4 execution: Task executed with details of work completed
3. Completion: Task marked COMPLETE with artifact references
"""
    
    expected_output = f"P3 + P4 protocols completed: Task '{task_name}' logged (P3), executed (P4), and marked COMPLETE with artifact references."
    
    return Task(
        description=full_task_description,
        agent=agent,
        expected_output=expected_output
    )

def execute_task_autonomously(
    agent_role,
    task_name,
    task_description,
    execution_instructions,
    expected_artifacts=None
):
    """
    Execute a task autonomously using P3 + P4 protocols.
    
    Args:
        agent_role: The role of the agent to execute the task
        task_name: Name of the task
        task_description: Full task description
        execution_instructions: Specific instructions for execution
        expected_artifacts: List of expected artifacts
    
    Returns:
        Execution result
    """
    from main import load_agents_from_yaml, get_agent_metadata
    
    print("\n" + "="*80)
    print("🚀 AUTONOMOUS TASK EXECUTION")
    print("="*80)
    print(f"Agent: {agent_role}")
    print(f"Task: {task_name}")
    print("="*80)
    print()
    
    # Validate configuration
    try:
        Config.validate()
        print("✅ Configuration validated")
    except ValueError as e:
        print(f"❌ Configuration Error: {e}")
        return None
    
    os.environ['OPENAI_API_KEY'] = Config.OPENAI_API_KEY
    
    # Load agents
    print("📋 Loading agents...")
    try:
        agents = load_agents_from_yaml('agents.yaml')
        print(f"✅ Loaded {len(agents)} agents")
    except Exception as e:
        print(f"❌ Error loading agents: {e}")
        import traceback
        traceback.print_exc()
        return None
    
    # Find the agent
    target_agent = None
    for agent in agents:
        if agent.role == agent_role:
            target_agent = agent
            break
    
    if not target_agent:
        print(f"❌ Error: Could not find agent with role '{agent_role}'")
        return None
    
    print(f"✅ Found agent: {target_agent.role}")
    print()
    
    # Load execution tools
    print("🔧 Loading execution tools...")
    execution_tools = get_execution_tools_for_agent(agent_role)
    target_agent.tools = execution_tools
    print(f"✅ Loaded {len(execution_tools)} tools")
    print()
    
    # Create task with P3 + P4 protocols
    task = create_autonomous_execution_task(
        agent=target_agent,
        task_name=task_name,
        task_description=task_description,
        execution_instructions=execution_instructions,
        expected_artifacts=expected_artifacts
    )
    
    # Create crew
    print("🚀 Creating execution crew...")
    crew = Crew(
        agents=[target_agent],
        tasks=[task],
        verbose=True
    )
    
    print("✅ Crew created")
    print()
    print("="*80)
    print("Starting autonomous task execution (P3 + P4)...")
    print("="*80)
    print()
    
    try:
        result = crew.kickoff()
        
        print()
        print("="*80)
        print("✅ AUTONOMOUS TASK EXECUTION COMPLETE")
        print("="*80)
        print()
        print("📊 Execution Result:")
        print(result)
        print()
        
        return result
        
    except Exception as e:
        print()
        print("="*80)
        print("❌ AUTONOMOUS TASK EXECUTION FAILED")
        print("="*80)
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return None

