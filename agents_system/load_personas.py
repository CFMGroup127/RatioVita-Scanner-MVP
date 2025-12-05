"""
Load and add agents from persona definitions.
You can define your personas here or in a separate JSON/Python file.
"""
from agent_base import AgentBase
from agent_manager import AgentManager
from config import Config

# ============================================================================
# ADD YOUR 15 AGENT PERSONAS BELOW
# ============================================================================

def get_personas():
    """
    Define your 15 agent personas here.
    Return a list of dictionaries with agent information.
    """
    personas = [
        # TODO: Add your 15 agents here
        # Example format:
        # {
        #     "designation": "agent_1",
        #     "persona": "Analytical, detail-oriented, methodical",
        #     "role": "Senior Data Analyst",
        #     "goal": "Analyze data and provide insights",
        #     "backstory": "A seasoned analyst with 10 years of experience..."
        # },
    ]
    return personas

def create_agents_from_personas(manager: AgentManager, personas: list):
    """Create and add agents from persona definitions."""
    for persona_data in personas:
        agent = AgentBase(
            designation=persona_data["designation"],
            persona=persona_data["persona"],
            role=persona_data["role"],
            goal=persona_data["goal"],
            backstory=persona_data["backstory"]
        )
        manager.add_agent(agent)

def main():
    """Main function to load and add agents."""
    # Validate configuration
    try:
        Config.validate()
        print("✓ Configuration validated")
    except ValueError as e:
        print(f"❌ Configuration Error: {e}")
        print("\nPlease make sure your .env file has OPENAI_API_KEY set.")
        return None
    
    # Initialize manager
    manager = AgentManager()
    
    # Get personas
    print("\n" + "="*60)
    print("Loading Agent Personas...")
    print("="*60)
    
    personas = get_personas()
    
    if not personas:
        print("\n⚠️  No personas defined yet.")
        print("   Please edit load_personas.py and add your 15 agent personas in get_personas()")
        return manager
    
    # Create and add agents
    create_agents_from_personas(manager, personas)
    
    # Summary
    print("\n" + "="*60)
    print(f"✓ Successfully added {len(manager.agents)} agents")
    print("="*60)
    
    if len(manager.agents) > 0:
        print("\nAgents in system:")
        for i, (designation, agent) in enumerate(manager.agents.items(), 1):
            print(f"  {i:2d}. {designation:20s} - {agent.role}")
        
        # Save configuration
        manager.save_agents_config("agents_config.json")
        print("\n✓ Agent configuration saved to agents_config.json")
    
    return manager

if __name__ == "__main__":
    manager = main()
    if manager and len(manager.agents) > 0:
        print("\n🎉 Your multi-agent system is ready!")
        print("\nNext: Create tasks and crews to start using your agents.")

