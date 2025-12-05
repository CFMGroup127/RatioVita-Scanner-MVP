# Multi-Agent System

A foundation for building a multi-agent system with CrewAI and OpenAI, supporting 15 agents with custom personas.

## Setup Instructions

### 1. Create OpenAI Account

1. Go to https://platform.openai.com/
2. Sign up or log in
3. Navigate to https://platform.openai.com/api-keys
4. Create a new API key
5. Copy the key (you won't be able to see it again!)

### 2. Install Dependencies

```bash
cd agents_system
python3 -m pip install -r requirements.txt
```

### 3. Configure API Keys

```bash
# Copy the example environment file
cp .env.example .env

# Edit .env and add your OpenAI API key
# OPENAI_API_KEY=sk-your-actual-key-here
```

### 4. Test the Setup

```bash
python3 main.py
```

## Project Structure

```
agents_system/
├── main.py              # Main entry point
├── config.py            # Configuration management
├── agent_base.py        # Base agent class
├── agent_manager.py     # Agent orchestration
├── personas/            # Agent personas directory
│   └── README.md
├── requirements.txt     # Python dependencies
├── .env.example         # Environment variable template
└── README.md           # This file
```

## Adding Agents

Once you have your 15 agent personas ready, you can add them like this:

```python
from agent_base import AgentBase
from agent_manager import AgentManager

manager = AgentManager()

# Add agent 1
agent1 = AgentBase(
    designation="agent_1",
    persona="Your persona description here",
    role="Agent's role",
    goal="Agent's goal",
    backstory="Agent's backstory"
)
manager.add_agent(agent1)

# Repeat for all 15 agents...
```

## Next Steps

1. ✅ Create OpenAI account and get API key
2. ✅ Install dependencies
3. ✅ Configure .env file
4. ⏳ Define your 15 agent personas
5. ⏳ Add agents to the system
6. ⏳ Create tasks and crews
7. ⏳ Run your multi-agent workflows

## Resources

- [OpenAI Platform](https://platform.openai.com/)
- [CrewAI Documentation](https://docs.crewai.com/)
- [OpenAI Python SDK](https://github.com/openai/openai-python)

