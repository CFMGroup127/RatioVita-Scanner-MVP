"""
Main execution file for the CrewAI multi-agent system.
This is the file you run to kick off the entire crew.
Enhanced to support per-agent API keys, models, and document IDs.
"""
import os
import yaml
from crewai import Agent, Task, Crew, Process
from config import Config
from typing import Dict, List, Any
from langchain_openai import ChatOpenAI
from tools import (
    get_code_execution_tool, 
    get_cursor_llm_tool,
    get_search_tool,
    get_cursor_web_browser_tool,
    get_file_read_tool,
    get_file_write_tool,
    get_file_move_tool,
    get_budget_check_tool,
    get_code_review_tool,
    get_email_scrubbing_tool,
    get_archival_directory_list_tool,
    get_google_docs_memory_tool,
    get_meeting_transcript_tool,
    get_google_calendar_tool,
    get_google_docs_read_tool,
    get_gmail_tool
)

# Legacy V1 Path - Shared constant for the entire crew
LEGACY_V1_PATH = "/Users/colliemorris/Projects 2/RatioVita_v2/RatioVita_v1"

# Store agent metadata (designation, email, IDs, etc.)
agent_metadata: Dict[str, Dict[str, Any]] = {}

def load_agents_from_yaml(filepath='agents.yaml'):
    """Load agent definitions from YAML file with enhanced metadata."""
    global agent_metadata
    agent_metadata = {}
    
    with open(filepath, 'r') as f:
        data = yaml.safe_load(f)
    
    agents = []
    for agent_data in data.get('agents', []):
        # Extract metadata
        designation = agent_data.get('designation', agent_data.get('role', 'Unknown'))
        email = agent_data.get('email_address', '')
        model = agent_data.get('model', Config.OPENAI_MODEL)
        api_key = agent_data.get('api_key', Config.OPENAI_API_KEY)
        
        # Helper function to strip URLs down to clean ID strings
        def clean_id(id_string):
            """Strip Google Docs/Sheets URLs down to clean ID strings."""
            if not id_string or id_string.startswith('[PASTE'):
                return id_string
            # Remove https://docs.google.com/document/d/ or similar prefixes
            if 'docs.google.com' in id_string:
                # Extract ID from URL pattern: .../d/{ID}/edit...
                parts = id_string.split('/d/')
                if len(parts) > 1:
                    id_part = parts[1].split('/')[0].split('?')[0]
                    return id_part
            # Remove /edit?usp=sharing suffix if present
            if '/edit' in id_string:
                id_string = id_string.split('/edit')[0]
            if '?usp=' in id_string:
                id_string = id_string.split('?usp=')[0]
            return id_string
        
        memory_doc_id = clean_id(agent_data.get('memory_doc_id', ''))
        calendar_id = clean_id(agent_data.get('personal_calendar_id', ''))
        project_schedule_cal_id = clean_id(agent_data.get('project_schedule_calendar_id', ''))
        transcript_doc_id = clean_id(agent_data.get('meeting_transcript_doc_id', ''))
        protocol = agent_data.get('protocol', '')
        birth_date = agent_data.get('birth_date', '')
        favorite_restaurant = agent_data.get('favorite_restaurant', '')
        address = agent_data.get('address', '')
        phone_number = agent_data.get('phone_number', '')
        
        # Combine backstory and protocol
        backstory = agent_data.get('backstory', '')
        if protocol:
            # Replace LEGACY_V1_PATH placeholder with actual constant value
            protocol_with_path = protocol.replace('LEGACY_V1_PATH', LEGACY_V1_PATH)
            full_backstory = f"{backstory}\n\nPROTOCOL:\n{protocol_with_path}"
        else:
            full_backstory = backstory
        
        # Use agent-specific API key if provided (and not placeholder)
        agent_api_key = api_key if api_key and not api_key.startswith('[PASTE') else Config.OPENAI_API_KEY
        
        # Create LLM instance with agent-specific API key and model
        agent_llm = ChatOpenAI(
            model=model,
            openai_api_key=agent_api_key,
            temperature=0.7
        )
        
        # Determine tools based on agent role
        agent_tools = agent_data.get('tools', [])
        
        role = agent_data['role']
        
        # CursorWebBrowserTool for agents needing real-time data (replaces SearchTool)
        # These agents must use the Cursor execution environment's integrated web browser
        roles_needing_cursor_browser = [
            "Technical and Product Visionary",  # CTO/CPO - Ash Roy
            "Lead Code Execution and V2 Development",  # Head of Engineering - Ethan Hayes
            "Competitive Intelligence Specialist",  # Market Analyst - Samuel Reed
        ]
        
        if role in roles_needing_cursor_browser:
            try:
                cursor_browser_tool = get_cursor_web_browser_tool()
                if agent_tools:
                    agent_tools.append(cursor_browser_tool)
                else:
                    agent_tools = [cursor_browser_tool]
            except Exception:
                # Cursor browser tool not available, continue without it
                pass
        
        # SearchTool for other agents who need fact-checking/research capabilities
        # Administrative roles (Admin Assistant, COO, CEO) don't need search - they delegate
        roles_needing_search = [
            "Market Strategist and Voice of the Customer",  # CMO
            "Legal Compliance and Risk Assessor",  # CLO
            "Process and Factual Integrity Auditor",  # Head of QA
            "Documentation and Knowledge Archivist",  # Technical Writer
            "Go-to-Market Strategy",  # Sales Manager
            "Financial Guardian and Strategy Modeler",  # CFO
        ]
        
        if role in roles_needing_search:
            try:
                search_tool = get_search_tool()
                # Test if the tool is actually functional (has API key)
                if os.getenv('SERPER_API_KEY') or os.getenv('TAVILY_API_KEY'):
                    if agent_tools:
                        agent_tools.append(search_tool)
                    else:
                        agent_tools = [search_tool]
            except Exception:
                # Search tool not available, continue without it
                pass
        
        if not agent_tools:
            agent_tools = []
        
        # Assign role-specific tools (role already defined above)
        
        # File Management Tools (for Engineering & Docs team)
        if role in ["Technical and Product Visionary", "Lead Code Execution and V2 Development", 
                    "Process and Factual Integrity Auditor", "Documentation and Knowledge Archivist"]:
            file_read = get_file_read_tool()
            file_write = get_file_write_tool()
            file_move = get_file_move_tool()
            agent_tools.extend([file_read, file_write, file_move])
            
            # Add Cursor LLM Tool for Ash Roy (CTO) for code analysis
            if role == "Technical and Product Visionary":
                try:
                    cursor_tool = get_cursor_llm_tool()
                    agent_tools.append(cursor_tool)
                except Exception:
                    pass  # Tool not available, continue without it
            
            # Add filtered ArchivalDirectoryListTool and CursorLLMTool for Alice Kim
            if role == "Documentation and Knowledge Archivist":
                try:
                    archival_dir_tool = get_archival_directory_list_tool()
                    cursor_tool = get_cursor_llm_tool()
                    agent_tools.extend([archival_dir_tool, cursor_tool])
                except Exception:
                    pass  # Tools not available, continue without them
        
        # Code Execution Tools (for Engineering)
        if role == "Lead Code Execution and V2 Development":
            # Ethan Hayes gets CodeExecutionTool and Cursor LLM tool
            code_tool = get_code_execution_tool()
            cursor_tool = get_cursor_llm_tool()
            agent_tools.extend([code_tool, cursor_tool])
        
        # Code Review Tool (for CTO and Head of QA)
        if role in ["Technical and Product Visionary", "Process and Factual Integrity Auditor"]:
            code_review = get_code_review_tool()
            agent_tools.append(code_review)
        
        # Budget Check Tool (for CFO and CHRO)
        if role in ["Financial Guardian and Strategy Modeler", "Budget and Conflict Guardrail"]:
            budget_tool = get_budget_check_tool()
            agent_tools.append(budget_tool)
        
        # Email Scrubbing Tool (for CLO)
        if role == "Legal Compliance and Risk Assessor":
            email_scrub = get_email_scrubbing_tool()
            agent_tools.append(email_scrub)
        
        # Google Docs Memory Tool (for ALL agents to update persistent memory)
        # All agents have memory_doc_id and should update their memory documents
        try:
            google_memory_tool = get_google_docs_memory_tool()
            agent_tools.append(google_memory_tool)
        except Exception:
            # Google Docs tool not available, continue without it
            pass
        
        # Meeting Transcript Tool (for Dana Flores only)
        if role == "Admin Assistant & Workflow Funnel":
            try:
                meeting_tool = get_meeting_transcript_tool()
                agent_tools.append(meeting_tool)
            except Exception:
                # Meeting transcript tool not available, continue without it
                pass
        
        # Google Calendar Tool (for all agents with calendar IDs)
        # All agents have personal_calendar_id, and COO has project_schedule_calendar_id
        try:
            calendar_tool = get_google_calendar_tool()
            agent_tools.append(calendar_tool)
        except Exception:
            # Google Calendar tool not available, continue without it
            pass
        
        # Google Docs Read Tool (for ALL agents to read their own and others' memory documents)
        # This ensures context continuity and allows agents to access shared knowledge
        try:
            docs_read_tool = get_google_docs_read_tool()
            agent_tools.append(docs_read_tool)
        except Exception:
            # Google Docs Read tool not available, continue without it
            pass
        
        # Gmail Tool (for all agents to send emails)
        try:
            gmail_tool = get_gmail_tool()
            agent_tools.append(gmail_tool)
        except Exception:
            # Gmail tool not available, continue without it
            pass
        
        # Create agent
        agent = Agent(
            role=agent_data['role'],
            goal=agent_data['goal'],
            backstory=full_backstory,
            verbose=agent_data.get('verbose', True),
            allow_delegation=agent_data.get('allow_delegation', False),
            tools=agent_tools,
            llm=agent_llm  # Use agent-specific LLM with correct API key
        )
        
        # Store metadata
        agent_metadata[agent_data['role']] = {
            'designation': designation,
            'email_address': email,
            'model': model,
            'api_key': agent_api_key,
            'memory_doc_id': memory_doc_id,
            'personal_calendar_id': calendar_id,
            'project_schedule_calendar_id': project_schedule_cal_id,
            'meeting_transcript_doc_id': transcript_doc_id,
            'protocol': protocol,
            'birth_date': birth_date,
            'favorite_restaurant': favorite_restaurant,
            'address': address,
            'phone_number': phone_number,
            'agent': agent
        }
        
        agents.append(agent)
    
    return agents

def get_agent_metadata(role: str) -> Dict[str, Any]:
    """Get metadata for a specific agent by role."""
    return agent_metadata.get(role, {})

def load_tasks_from_yaml(agents, filepath='tasks.yaml'):
    """Load task definitions from YAML file and match with agents."""
    with open(filepath, 'r') as f:
        data = yaml.safe_load(f)
    
    # Create a mapping of role to agent
    agent_map = {agent.role: agent for agent in agents}
    
    tasks = []
    for task_data in data.get('tasks', []):
        agent_role = task_data['agent']
        if agent_role not in agent_map:
            raise ValueError(f"Agent role '{agent_role}' not found in agents.yaml")
        
        task = Task(
            description=task_data['description'],
            expected_output=task_data['expected_output'],
            agent=agent_map[agent_role],
            async_execution=task_data.get('async_execution', False)
        )
        tasks.append(task)
    
    return tasks

def print_agent_summary():
    """Print a summary of all agents with their metadata."""
    print("\n" + "="*60)
    print("Agent Summary")
    print("="*60)
    for role, metadata in agent_metadata.items():
        print(f"\n{metadata['designation']}")
        print(f"  Role: {role}")
        print(f"  Email: {metadata['email_address']}")
        print(f"  Model: {metadata['model']}")
        if metadata['memory_doc_id'] and not metadata['memory_doc_id'].startswith('[PASTE'):
            print(f"  Memory Doc ID: {metadata['memory_doc_id']}")
        if metadata['personal_calendar_id'] and not metadata['personal_calendar_id'].startswith('[PASTE'):
            print(f"  Calendar ID: {metadata['personal_calendar_id']}")
        if metadata.get('project_schedule_calendar_id') and not metadata['project_schedule_calendar_id'].startswith('[PASTE'):
            print(f"  Project Schedule Calendar ID: {metadata['project_schedule_calendar_id']}")
        if metadata['meeting_transcript_doc_id'] and not metadata['meeting_transcript_doc_id'].startswith('[PASTE'):
            print(f"  Transcript Doc ID: {metadata['meeting_transcript_doc_id']}")

def main():
    """Main execution function."""
    print("\n" + "="*60)
    print("CrewAI Multi-Agent System")
    print("="*60)
    
    # Validate configuration
    try:
        Config.validate()
        print("✅ Configuration validated")
    except ValueError as e:
        print(f"❌ Configuration Error: {e}")
        return
    
    # Set default OpenAI API key for CrewAI
    os.environ['OPENAI_API_KEY'] = Config.OPENAI_API_KEY
    
    # Load agents from YAML
    print("\n📋 Loading agents from agents.yaml...")
    try:
        agents = load_agents_from_yaml('agents.yaml')
        print(f"✅ Loaded {len(agents)} agents")
        for i, agent in enumerate(agents, 1):
            print(f"   {i}. {agent.role}")
        
        # Show agent summary with metadata
        print_agent_summary()
        
    except FileNotFoundError:
        print("❌ agents.yaml not found. Please create it with your agent definitions.")
        return
    except Exception as e:
        print(f"❌ Error loading agents: {e}")
        import traceback
        traceback.print_exc()
        return
    
    # Check for placeholder values
    print("\n⚠️  Configuration Check:")
    needs_config = False
    for role, metadata in agent_metadata.items():
        if metadata['api_key'].startswith('[PASTE') or metadata['api_key'] == Config.OPENAI_API_KEY:
            if metadata['api_key'].startswith('[PASTE'):
                print(f"   ⚠️  {role}: API key needs to be set")
                needs_config = True
        if metadata['memory_doc_id'].startswith('[PASTE'):
            print(f"   ⚠️  {role}: Memory doc ID needs to be set")
        if metadata['personal_calendar_id'].startswith('[PASTE'):
            print(f"   ⚠️  {role}: Calendar ID needs to be set")
        if metadata.get('project_schedule_calendar_id') and metadata['project_schedule_calendar_id'].startswith('[PASTE'):
            print(f"   ⚠️  {role}: Project schedule calendar ID needs to be set")
        if metadata['meeting_transcript_doc_id'].startswith('[PASTE'):
            print(f"   ⚠️  {role}: Meeting transcript doc ID needs to be set")
    
    if needs_config:
        print("\n💡 Tip: Update agents.yaml with actual API keys and document IDs")
    
    # Load tasks from YAML
    print("\n📋 Loading tasks from tasks.yaml...")
    try:
        tasks = load_tasks_from_yaml(agents, 'tasks.yaml')
        print(f"✅ Loaded {len(tasks)} tasks")
        for i, task in enumerate(tasks, 1):
            print(f"   {i}. {task.description[:50]}...")
    except FileNotFoundError:
        print("❌ tasks.yaml not found. Please create it with your task definitions.")
        print("   You can still view agent configuration above.")
        return
    except Exception as e:
        print(f"❌ Error loading tasks: {e}")
        return
    
    # Create crew
    print("\n🚀 Creating crew...")
    crew = Crew(
        agents=agents,
        tasks=tasks,
        process=Process.sequential,  # Change to Process.hierarchical if needed
        verbose=True
    )
    print("✅ Crew created")
    
    # Execute the crew
    print("\n" + "="*60)
    print("Starting crew execution...")
    print("="*60 + "\n")
    
    try:
        result = crew.kickoff()
        print("\n" + "="*60)
        print("✅ Crew execution completed!")
        print("="*60)
        print("\nResults:")
        print(result)
    except Exception as e:
        print(f"\n❌ Error during execution: {e}")
        import traceback
        traceback.print_exc()

def launch_block_a(agents):
    """
    Launch the system with BLOCK A: Initial Data Ingestion & Archival task.
    This task is directed to Dana Flores, who will delegate to Alice Kim and other agents.
    """
    print("\n" + "="*80)
    print("🚀 HURUMOAI V2 SYSTEM LAUNCH - BLOCK A: Initial Data Ingestion & Archival")
    print("="*80)
    
    # Find agents
    dana_flores_agent = None
    alice_kim_agent = None
    
    for agent in agents:
        if agent.role == "Admin Assistant & Workflow Funnel":
            dana_flores_agent = agent
        elif agent.role == "Documentation and Knowledge Archivist":
            alice_kim_agent = agent
    
    if not dana_flores_agent:
        print("❌ Error: Dana Flores (Admin Assistant & Workflow Funnel) not found in agents list")
        return None
    
    if not alice_kim_agent:
        print("❌ Error: Alice Kim (Documentation and Knowledge Archivist) not found in agents list")
        return None
    
    print(f"\n✅ Found workflow funnel: {dana_flores_agent.role}")
    print(f"✅ Found technical writer: {alice_kim_agent.role}")
    
    # Task 1: Dana's delegation task
    dana_task_description = (
        "Initiate the project workflow for RatioVita_v2. "
        "Your first priority is BLOCK A: Initial Data Ingestion & Archival. "
        "You must coordinate and delegate the retrieval and summarization of all non-code V1 assets "
        f"and documentation from the LEGACY_V1_PATH ({LEGACY_V1_PATH}) to the Technical Writer (Alice Kim). "
        "The final summary report must be filed and ready for the upcoming Executive Strategy Group meeting scheduled for **Friday, November 21, 2025**."
    )
    
    dana_task = Task(
        description=dana_task_description,
        agent=dana_flores_agent,
        expected_output=(
            "A confirmation that all tasks for BLOCK A have been properly coordinated and delegated to the Technical Writer "
            "and other relevant agents, and a timeline for completion. The summary report should be ready "
            "for the Executive Strategy Group meeting scheduled for Friday, November 21, 2025."
        )
    )
    
    # Task 2: Alice's archival task (follows Dana's task)
    # First, discover what files exist in the directory
    import os
    doc_files = []
    if os.path.exists(LEGACY_V1_PATH):
        for root, dirs, filenames in os.walk(LEGACY_V1_PATH):
            # Skip code directories
            dirs[:] = [d for d in dirs if d not in ['.git', 'Pods', 'MailCore2', 'node_modules', '.xcodeproj', '.xcworkspace']]
            for filename in filenames:
                if filename.endswith(('.md', '.txt', '.json', '.pdf', '.doc', '.docx')) and not filename.startswith('.'):
                    full_path = os.path.join(root, filename)
                    rel_path = os.path.relpath(full_path, LEGACY_V1_PATH)
                    doc_files.append(rel_path)
                    if len(doc_files) >= 30:  # Limit to prevent too long task description
                        break
            if len(doc_files) >= 30:
                break
    
    files_list = "\n".join([f"  - {f}" for f in sorted(doc_files)[:25]])
    
    alice_task_description = (
        f"BLOCK A: Initial Data Ingestion & Archival - Execute the archival task delegated by Dana Flores. "
        f"Retrieve and summarize all non-code V1 assets and documentation from LEGACY_V1_PATH ({LEGACY_V1_PATH}).\n\n"
        f"Key documentation files to retrieve and summarize include:\n{files_list}\n\n"
        f"CRITICAL BATCH PROCESSING REQUIREMENT: You MUST process files in batches of no more than 10 files at a time. "
        f"Read files individually using FileReadTool (NOT Archival Directory List Tool for repeated listing - use it only once initially). "
        f"For each batch of 10 files, you MUST delegate the summarization to the Cursor Archival Assistant using the Cursor LLM Interface Tool "
        f"with the prompt: 'Act as a V1 Documentation and Asset Extraction Bot. Your task is ONLY to read the provided text block and extract "
        f"all relevant UI/UX design specifications, marketing copy, and archival documentation. IGNORE all Python/Shell script syntax. "
        f"Provide a single, concise summary of the findings.' After receiving the Cursor summary, validate it against the LEGACY ACCESS "
        f"PROTOCOL (checking for code contamination), then immediately use the Google Docs Memory Tool to save the validated summary to your "
        f"persistent memory Google Doc (memory_doc_id: 1flDFYht_YAdcVsTcInDdgV5KPZH1Hua6cGiVXMjwdKI) before proceeding to the next batch. "
        f"Do NOT use File Writer Tool for memory updates - use Google Docs Memory Tool. This is MANDATORY - do not proceed to the next batch "
        f"until the current batch summary is validated and saved to your persistent memory document. This delegation approach prevents "
        f"context overflow.\n\n"
        f"Follow the LEGACY ACCESS PROTOCOL: Use LEGACY_V1_PATH to retrieve V1 documentation and design assets only. "
        f"Must never write to this path. Output must be a summary written to your memory document, never the raw code or files. "
        f"Focus on clarity and conciseness in all summaries. "
        f"The final summary report must be ready for the Executive Strategy Group meeting scheduled for **Friday, November 21, 2025**."
    )
    
    alice_task = Task(
        description=alice_task_description,
        agent=alice_kim_agent,
        expected_output=(
            "A comprehensive summary report of all non-code V1 assets and documentation retrieved from LEGACY_V1_PATH. "
            "The report should be organized, clear, and concise, containing summaries (not raw code) of all relevant "
            "documentation, design assets, and planning materials. The report must be filed in your memory document "
            "and ready for the Executive Strategy Group meeting scheduled for Friday, November 21, 2025."
        ),
        context=[dana_task]  # Alice's task depends on Dana's task
    )
    
    # Create a crew with both tasks
    print("\n🚀 Creating crew for BLOCK A execution...")
    crew = Crew(
        agents=agents,
        tasks=[dana_task, alice_task],
        process=Process.sequential,
        verbose=True
    )
    print("✅ Crew created with Dana's delegation task and Alice's archival task")
    
    # Execute the crew
    print("\n" + "="*80)
    print("Starting BLOCK A execution...")
    print("="*80 + "\n")
    
    try:
        result = crew.kickoff()
        print("\n" + "="*80)
        print("✅ HURUMOAI V2 SYSTEM LAUNCH COMPLETE")
        print("="*80)
        print("\n📊 System Response:")
        print(result)
        print("\n" + "="*80)
        return result
    except Exception as e:
        print(f"\n❌ Error during BLOCK A execution: {e}")
        import traceback
        traceback.print_exc()
        return None

def test_agent_introductions(agents):
    """
    Test function: Each agent writes to their memory doc and sends introduction emails.
    This tests Google Docs Memory Tool, Google Docs Read Tool, and Gmail Tool connectivity.
    """
    print("\n" + "="*80)
    print("🧪 AGENT INTRODUCTION TEST - Testing Memory Docs & Email Connectivity")
    print("="*80)
    
    # Get all agent emails and metadata
    agent_emails = {}
    agent_info = {}
    
    for agent in agents:
        role = agent.role
        metadata = agent_metadata.get(role, {})
        email = metadata.get('email_address', '')
        designation = metadata.get('designation', role)
        memory_id = metadata.get('memory_doc_id', '')
        
        if email:
            agent_emails[role] = email
            agent_info[role] = {
                'email': email,
                'designation': designation,
                'role': role,
                'memory_id': memory_id
            }
    
    # Create tasks for each agent
    tasks = []
    
    for agent in agents:
        role = agent.role
        info = agent_info.get(role, {})
        
        if not info:
            continue
        
        # Get all other agent emails
        other_emails = [email for r, email in agent_emails.items() if r != role]
        other_emails_str = ", ".join(other_emails)
        
        # Task 1: Write to memory doc
        memory_task_description = (
            f"Write your introduction to your persistent memory document. "
            f"Use the Google Docs Memory Tool to write the following information to your memory document "
            f"(memory_doc_id: {info['memory_id']}):\n\n"
            f"Format: \"{info['designation']}, {role}, [Your key duties and responsibilities based on your goal and backstory]\"\n\n"
            f"This is a test to verify your Google Docs Memory Tool connectivity."
        )
        
        memory_task = Task(
            description=memory_task_description,
            agent=agent,
            expected_output=f"Confirmation that introduction has been written to memory document (ID: {info['memory_id']})"
        )
        tasks.append(memory_task)
        
        # Task 2: Send introduction emails
        email_task_description = (
            f"Send introduction emails to all other team members. "
            f"Use the Gmail Tool to send an email to each of the following recipients: {other_emails_str}\n\n"
            f"Email Subject: \"Introduction: {info['designation']}\"\n\n"
            f"Email Body should include:\n"
            f"- Greeting to the recipient\n"
            f"- Your name: {info['designation']}\n"
            f"- Your title/role: {role}\n"
            f"- Brief introduction of yourself and your role in the RatioVita_v2 project\n"
            f"- Professional closing\n\n"
            f"You may send one email with all recipients in the 'to' field, or send individual emails. "
            f"This is a test to verify your Gmail Tool connectivity."
        )
        
        email_task = Task(
            description=email_task_description,
            agent=agent,
            expected_output=f"Confirmation that introduction emails have been sent to all team members",
            context=[memory_task]  # Email task depends on memory task
        )
        tasks.append(email_task)
    
    # Create crew with all tasks
    print(f"\n🚀 Creating crew with {len(tasks)} introduction tasks for {len(agents)} agents...")
    crew = Crew(
        agents=agents,
        tasks=tasks,
        process=Process.sequential,
        verbose=True
    )
    print("✅ Crew created")
    
    # Execute the crew
    print("\n" + "="*80)
    print("Starting Agent Introduction Test...")
    print("="*80 + "\n")
    
    try:
        result = crew.kickoff()
        print("\n" + "="*80)
        print("✅ AGENT INTRODUCTION TEST COMPLETE")
        print("="*80)
        print("\n📊 Test Results:")
        print(result)
        print("\n" + "="*80)
        return result
    except Exception as e:
        print(f"\n❌ Error during introduction test: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    # Option 1: Run standard main() with tasks.yaml
    # main()
    
    # Option 2: Launch with BLOCK A initial task
    print("\n" + "="*80)
    print("CrewAI Multi-Agent System - RatioVita_v2")
    print("="*80)
    
    # Validate configuration
    try:
        Config.validate()
        print("✅ Configuration validated")
    except ValueError as e:
        print(f"❌ Configuration Error: {e}")
        exit(1)
    
    # Set default OpenAI API key for CrewAI
    os.environ['OPENAI_API_KEY'] = Config.OPENAI_API_KEY
    
    # Load agents from YAML
    print("\n📋 Loading agents from agents.yaml...")
    try:
        agents = load_agents_from_yaml('agents.yaml')
        print(f"✅ Loaded {len(agents)} agents")
        
        # Show agent summary
        print_agent_summary()
        
    except FileNotFoundError:
        print("❌ agents.yaml not found. Please create it with your agent definitions.")
        exit(1)
    except Exception as e:
        print(f"❌ Error loading agents: {e}")
        import traceback
        traceback.print_exc()
        exit(1)
    
    # Option 3: Run agent introduction test
    test_agent_introductions(agents)
    
    # Launch BLOCK A (commented out for testing)
    # launch_block_a(agents)
