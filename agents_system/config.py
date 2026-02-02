"""
Configuration management for the multi-agent system.
Loads API keys and configuration from environment variables.
"""
import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

class Config:
    """Configuration class for API keys and settings."""
    
    # OpenAI Configuration
    OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
    OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4-turbo-preview")
    
    # CrewAI Configuration
    CREWAI_TELEMETRY_OPT_OUT = os.getenv("CREWAI_TELEMETRY_OPT_OUT", "false").lower() == "true"
    
    @classmethod
    def validate(cls):
        """Validate that required configuration is present."""
        if not cls.OPENAI_API_KEY:
            raise ValueError(
                "OPENAI_API_KEY is not set. "
                "Please create a .env file with your OpenAI API key. "
                "See .env.example for reference."
            )
        return True

