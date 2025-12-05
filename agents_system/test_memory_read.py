"""
Test Memory Reading Functionality
This script tests that agents can read from their memory documents.
"""
import os
from crewai import Agent, Task, Crew, Process
from config import Config
from main import load_agents_from_yaml, get_agent_metadata
from tools import get_google_docs_read_tool

def test_memory_read():
    """
    Test that agents can read from their memory documents.
    Tests with 2-3 agents to verify the read functionality works.
    """
    print("\n" + "="*80)
    print("📖 MEMORY READ TEST")
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
    
    # Select a few test agents (Dana, Kyle, and one more)
    test_roles = [
        "Admin Assistant & Workflow Funnel",  # Dana
        "Visionary and Final Decision Maker",  # Kyle
        "Process Architect and Schedule Publisher"  # David Chen
    ]
    
    test_agents = {}
    for agent in agents:
        if agent.role in test_roles:
            metadata = get_agent_metadata(agent.role)
            test_agents[agent.role] = {
                'agent': agent,
                'designation': metadata.get('designation', agent.role),
                'memory_id': metadata.get('memory_doc_id', ''),
            }
    
    if len(test_agents) < 2:
        print(f"❌ Error: Expected at least 2 test agents, found {len(test_agents)}")
        return None
    
    print(f"\n✅ Testing with {len(test_agents)} agents:")
    for role, info in test_agents.items():
        print(f"   - {info['designation']} ({role})")
        print(f"     Memory Doc ID: {info['memory_id'][:50]}...")
    
    tasks = []
    
    # Create read tasks for each test agent
    for role, info in test_agents.items():
        read_task = Task(
            description=(
                f"Read your persistent memory document using the Google Docs Read Tool.\n\n"
                f"Your memory document ID is: {info['memory_id']}\n\n"
                f"Use the Google Docs Read Tool with doc_id=\"{info['memory_id']}\" to read the contents of your memory document.\n\n"
                f"After reading, summarize what information is currently stored in your memory document, including:\n"
                f"- Your name and role\n"
                f"- Any personal information (birth date, favorite restaurant, etc.)\n"
                f"- Any other information that has been stored\n\n"
                f"IMPORTANT: Use the Google Docs Read Tool. Do not use any other tool."
            ),
            agent=info['agent'],
            expected_output=f"Summary of the contents of your memory document (ID: {info['memory_id']})",
            max_iter=3
        )
        tasks.append(read_task)
    
    # Create crew
    print("\n" + "="*80)
    print(f"🚀 Creating crew with {len(tasks)} read tasks...")
    print("="*80)
    
    crew = Crew(
        agents=[info['agent'] for info in test_agents.values()],
        tasks=tasks,
        process=Process.sequential,
        verbose=True,
        max_iter=20,
        max_execution_time=600  # 10 minute timeout
    )
    
    print("✅ Crew created")
    print("\n" + "="*80)
    print("Starting memory read test...")
    print("="*80 + "\n")
    
    try:
        result = crew.kickoff()
        print("\n" + "="*80)
        print("✅ MEMORY READ TEST COMPLETE")
        print("="*80)
        print("\n📊 Results:")
        print(result)
        print("\n" + "="*80)
        return result
    except Exception as e:
        print(f"\n❌ Error during test: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    test_memory_read()

