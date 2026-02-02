# Agent Personas

This directory is for storing agent personas. 

## Structure

You can organize personas in several ways:

1. **JSON files**: Create `agent_1.json`, `agent_2.json`, etc. with persona definitions
2. **Python files**: Create Python modules that define personas
3. **Single config file**: Use `personas.json` with all personas

## Persona Format

Each persona should include:
- `designation`: Unique identifier
- `persona`: Personality and behavioral traits
- `role`: The agent's role
- `goal`: What the agent is trying to achieve
- `backstory`: Background story

Example:
```json
{
  "designation": "analyst_1",
  "persona": "Analytical, detail-oriented, methodical",
  "role": "Data Analyst",
  "goal": "Analyze data and provide insights",
  "backstory": "A seasoned data analyst with 10 years of experience..."
}
```

