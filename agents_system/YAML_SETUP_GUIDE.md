# YAML-Based Setup Guide

## ✅ Project Structure (Standard CrewAI Approach)

Your project now uses the recommended YAML-based structure:

```
agents_system/
├── agents.yaml      # All 15 agent definitions
├── tasks.yaml       # Task definitions (BLOCK A, B, C, D, etc.)
├── .env            # API keys (already configured)
├── main.py         # Execution entry point
└── venv/           # Virtual environment
```

## 📋 Step 1: Add Your 15 Agents to `agents.yaml`

Open `agents.yaml` and add all 15 agents. Each agent needs:

```yaml
agents:
  - role: "Agent's Role Title"
    goal: "What this agent is trying to achieve"
    backstory: |
      Detailed background story that shapes the agent's behavior.
      Can be multiple lines.
    verbose: true
    allow_delegation: false
    # tools: []  # Optional: Add tools like [CalendarTool, SearchTool]
```

### Example:
```yaml
agents:
  - role: "Senior Data Analyst"
    goal: "Analyze complex datasets and provide actionable insights"
    backstory: |
      A seasoned data analyst with 10 years of experience in business 
      intelligence and statistical analysis. Known for thoroughness and 
      accuracy. Prefers data-driven decisions.
    verbose: true
    allow_delegation: false
```

## 📋 Step 2: Define Tasks in `tasks.yaml`

Open `tasks.yaml` and define your tasks (BLOCK A, B, C, D, etc.):

```yaml
tasks:
  - description: "BLOCK A - Task description"
    expected_output: "What output is expected"
    agent: "Agent Role Name"  # Must match exactly with agents.yaml
    # async_execution: false  # Optional
```

### Important:
- The `agent` field must **exactly match** the `role` from `agents.yaml`
- Each task must have an `expected_output`

### Example:
```yaml
tasks:
  - description: "BLOCK A - Analyze the provided dataset"
    expected_output: "A comprehensive analysis report with key insights"
    agent: "Senior Data Analyst"
  
  - description: "BLOCK B - Create content based on the analysis"
    expected_output: "Engaging written content"
    agent: "Creative Writer"
```

## 🚀 Step 3: Run the System

Once you've added your agents and tasks:

```bash
cd agents_system
source venv/bin/activate
python3 main.py
```

## 📝 Quick Reference

### Agent Fields:
- `role`: Agent's role/title (used to match with tasks)
- `goal`: What the agent is trying to achieve
- `backstory`: Background story (use `|` for multi-line)
- `verbose`: true/false (show detailed logs)
- `allow_delegation`: true/false (can delegate to other agents)
- `tools`: [] (optional list of tools)

### Task Fields:
- `description`: What the task is
- `expected_output`: What output is expected
- `agent`: Must match `role` from agents.yaml exactly
- `async_execution`: true/false (optional)

## ✅ Current Status

- ✅ `.env` configured with OpenAI API key
- ✅ Model: `gpt-4o-mini`
- ✅ `agents.yaml` template created
- ✅ `tasks.yaml` template created
- ✅ `main.py` ready to execute
- ✅ YAML support installed

## 🎯 Next Steps

1. **Add your 15 agents** to `agents.yaml`
2. **Define your tasks** (BLOCK A, B, C, D, etc.) in `tasks.yaml`
3. **Run**: `python3 main.py`

## 💡 Tips

- Use consistent role names between `agents.yaml` and `tasks.yaml`
- The `backstory` field is important - it shapes how the agent behaves
- You can add tools to agents if needed (e.g., CalendarTool, SearchTool)
- Set `verbose: true` to see detailed agent thinking processes

