"""
Script to add your 15 agents with personas to the system.
Edit this file to add your agent definitions.
"""
from agent_base import AgentBase
from agent_manager import AgentManager
from config import Config

def create_agents(manager: AgentManager):
    """
    Add all 15 agents here with their personas.
    
    Template for each agent:
    agent = AgentBase(
        designation="unique_name",
        persona="Personality traits, communication style, behavioral patterns",
        role="Agent's role (e.g., 'Senior Data Analyst', 'Creative Writer')",
        goal="What this agent is trying to achieve",
        backstory="Background story that shapes the agent's behavior"
    )
    manager.add_agent(agent)
    """
    
    # TODO: Add your 15 agents here
    # Example:
    # agent_1 = AgentBase(
    #     designation="analyst_1",
    #     persona="Analytical, detail-oriented, methodical, prefers data-driven decisions",
    #     role="Senior Data Analyst",
    #     goal="Analyze complex datasets and provide actionable insights",
    #     backstory="A seasoned data analyst with 10 years of experience in business intelligence..."
    # )
    # manager.add_agent(agent_1)
    
    # Add your agents below:
    pass

def main():
    """Main function to set up and add agents."""
    # Validate configuration
    try:
        Config.validate()
        print("✓ Configuration validated")
    except ValueError as e:
        print(f"❌ Configuration Error: {e}")
        return
    
    # Initialize manager
    manager = AgentManager()
    
    # Add agents
    print("\n" + "="*60)
    print("Adding Agents to System...")
    print("="*60)
    
    create_agents(manager)
    
    # Summary
    print("\n" + "="*60)
    print(f"✓ Total agents added: {len(manager.agents)}")
    print("="*60)
    
    if len(manager.agents) > 0:
        print("\nAgents in system:")
        for designation, agent in manager.agents.items():
            print(f"  - {designation}: {agent.role}")
        
        # Save configuration
        manager.save_agents_config("agents_config.json")
        print("\n✓ Agent configuration saved to agents_config.json")
    else:
        print("\n⚠ No agents added yet. Edit add_agents.py to add your agents.")
    
    return manager

if __name__ == "__main__":
    manager = main()

