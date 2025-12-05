"""
Simple test to verify Memory Tool works for Alice Kim
Tests writing to memory document directly
"""
import os
from crewai import Agent, Task, Crew, Process
from config import Config
from main import load_agents_from_yaml, get_agent_metadata
from tools import get_google_docs_memory_tool

def test_alice_memory_write():
    """
    Simple test: Alice writes a test message to her memory document
    """
    print("\n" + "="*80)
    print("🧪 SIMPLE MEMORY WRITE TEST - Alice Kim")
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
        return None
    
    # Get Alice
    alice_role = "Documentation and Knowledge Archivist"
    alice_agent = None
    alice_metadata = None
    
    for agent in agents:
        if agent.role == alice_role:
            alice_agent = agent
            alice_metadata = get_agent_metadata(alice_role)
            break
    
    if not alice_agent:
        print(f"❌ Error: Alice Kim not found")
        return None
    
    alice_memory_id = alice_metadata.get('memory_doc_id', '')
    print(f"\n✅ Found Alice Kim")
    print(f"   Memory Doc ID: {alice_memory_id[:50]}...")
    
    # Create simple task
    test_task = Task(
        description=(
            f"Write a simple test message to your memory document using the Google Docs Memory Tool.\n\n"
            f"**MANDATORY STEPS:**\n"
            f"1. Use the Google Docs Memory Tool\n"
            f"2. Set doc_id to: {alice_memory_id}\n"
            f"3. Set content to: 'TEST MESSAGE: Memory Tool Test - {os.popen('date').read().strip()}'\n"
            f"4. Set append to: True\n"
            f"5. Execute the tool\n"
            f"6. Verify you receive a SUCCESS message\n\n"
            f"**IMPORTANT:** You MUST use the Google Docs Memory Tool. Do not use any other tool."
        ),
        agent=alice_agent,
        expected_output="SUCCESS message confirming content was written to memory document",
        max_iter=5
    )
    
    # Create crew
    print("\n🚀 Creating crew...")
    crew = Crew(
        agents=[alice_agent],
        tasks=[test_task],
        process=Process.sequential,
        verbose=True,
        max_iter=10,
        max_execution_time=300
    )
    
    print("✅ Crew created")
    print("\n" + "="*80)
    print("Starting memory write test...")
    print("="*80 + "\n")
    
    try:
        result = crew.kickoff()
        print("\n" + "="*80)
        print("✅ MEMORY WRITE TEST COMPLETE")
        print("="*80)
        print("\n📊 Results:")
        print(result)
        return result
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    test_alice_memory_write()



