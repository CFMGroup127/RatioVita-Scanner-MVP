"""
Base agent structure for the multi-agent system.
This provides the foundation for creating agents with personas.
"""
from crewai import Agent
from typing import Optional, List
import os

class AgentBase:
    """
    Base class for creating agents with personas.
    Each agent will have a designation, persona, and specific role.
    """
    
    def __init__(
        self,
        designation: str,
        persona: str,
        role: str,
        goal: str,
        backstory: str,
        verbose: bool = True,
        allow_delegation: bool = False,
        tools: Optional[List] = None
    ):
        """
        Initialize an agent with its persona and role.
        
        Args:
            designation: Unique identifier/name for the agent
            persona: Personality and behavioral traits
            role: The agent's role in the system
            goal: What the agent is trying to achieve
            backstory: Background story that shapes the agent's behavior
            verbose: Whether to output detailed logs
            allow_delegation: Whether agent can delegate tasks
            tools: List of tools the agent can use
        """
        self.designation = designation
        self.persona = persona
        self.role = role
        self.goal = goal
        self.backstory = backstory
        self.verbose = verbose
        self.allow_delegation = allow_delegation
        self.tools = tools or []
        
        # Create the CrewAI agent
        self.agent = self._create_agent()
    
    def _create_agent(self) -> Agent:
        """Create a CrewAI agent instance."""
        return Agent(
            role=self.role,
            goal=self.goal,
            backstory=f"{self.backstory}\n\nPersona: {self.persona}",
            verbose=self.verbose,
            allow_delegation=self.allow_delegation,
            tools=self.tools
        )
    
    def get_info(self) -> dict:
        """Get agent information as a dictionary."""
        return {
            "designation": self.designation,
            "persona": self.persona,
            "role": self.role,
            "goal": self.goal,
            "backstory": self.backstory
        }
    
    def __repr__(self) -> str:
        return f"AgentBase(designation='{self.designation}', role='{self.role}')"

