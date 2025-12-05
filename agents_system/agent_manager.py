"""
Agent Manager - Orchestrates multiple agents and their interactions.
"""
from typing import List, Dict, Optional
from agent_base import AgentBase
from crewai import Crew, Process
import json
import os

class AgentManager:
    """
    Manages a collection of agents and coordinates their work.
    """
    
    def __init__(self):
        """Initialize the agent manager."""
        self.agents: Dict[str, AgentBase] = {}
        self.crews: List[Crew] = []
    
    def add_agent(self, agent: AgentBase):
        """
        Add an agent to the manager.
        
        Args:
            agent: An AgentBase instance
        """
        if agent.designation in self.agents:
            raise ValueError(f"Agent with designation '{agent.designation}' already exists")
        
        self.agents[agent.designation] = agent
        print(f"✓ Added agent: {agent.designation} ({agent.role})")
    
    def get_agent(self, designation: str) -> Optional[AgentBase]:
        """Get an agent by its designation."""
        return self.agents.get(designation)
    
    def list_agents(self) -> List[Dict]:
        """List all agents and their information."""
        return [agent.get_info() for agent in self.agents.values()]
    
    def create_crew(
        self,
        agents: List[str],
        tasks: List,
        process: Process = Process.sequential,
        verbose: bool = True
    ) -> Crew:
        """
        Create a crew with specified agents and tasks.
        
        Args:
            agents: List of agent designations to include
            tasks: List of tasks for the crew
            process: How the crew processes tasks (sequential, hierarchical, etc.)
            verbose: Whether to output detailed logs
        """
        crew_agents = []
        for designation in agents:
            if designation not in self.agents:
                raise ValueError(f"Agent '{designation}' not found")
            crew_agents.append(self.agents[designation].agent)
        
        crew = Crew(
            agents=crew_agents,
            tasks=tasks,
            process=process,
            verbose=verbose
        )
        
        self.crews.append(crew)
        return crew
    
    def save_agents_config(self, filepath: str = "agents_config.json"):
        """Save all agents configuration to a JSON file."""
        config = {
            "agents": [agent.get_info() for agent in self.agents.values()]
        }
        
        with open(filepath, 'w') as f:
            json.dump(config, f, indent=2)
        
        print(f"✓ Saved agents configuration to {filepath}")
    
    def load_agents_config(self, filepath: str = "agents_config.json"):
        """Load agents configuration from a JSON file."""
        if not os.path.exists(filepath):
            print(f"⚠ Configuration file {filepath} not found")
            return
        
        with open(filepath, 'r') as f:
            config = json.load(f)
        
        print(f"✓ Loaded configuration from {filepath}")
        print(f"  Found {len(config.get('agents', []))} agent configurations")
        # Note: You'll need to recreate agents from this config
        return config

