# Quick Start Guide

## ✅ Step 1: API Key - DONE!
Your OpenAI API key is configured.

## 📝 Step 2: Add Your 15 Agent Personas

Open `load_personas.py` and add your personas in the `get_personas()` function.

### Format for each agent:
```python
{
    "designation": "unique_name",           # e.g., "analyst_1", "writer_2"
    "persona": "Personality description",   # How they behave/think
    "role": "Agent's role",                 # e.g., "Senior Data Analyst"
    "goal": "What they're trying to achieve",
    "backstory": "Background story"
}
```

### Example:
```python
def get_personas():
    personas = [
        {
            "designation": "analyst_1",
            "persona": "Analytical, detail-oriented, methodical, prefers data-driven decisions",
            "role": "Senior Data Analyst",
            "goal": "Analyze complex datasets and provide actionable insights",
            "backstory": "A seasoned data analyst with 10 years of experience in business intelligence and statistical analysis. Known for thoroughness and accuracy."
        },
        {
            "designation": "writer_1",
            "persona": "Creative, innovative, thinks outside the box, expressive",
            "role": "Creative Writer",
            "goal": "Create engaging and original content",
            "backstory": "An award-winning writer with a passion for storytelling and creative expression."
        },
        # ... add 13 more agents
    ]
    return personas
```

## 🚀 Step 3: Load Your Agents

Once you've added all 15 personas, run:

```bash
cd agents_system
source venv/bin/activate
python3 load_personas.py
```

This will:
- ✅ Validate your setup
- ✅ Create all 15 agents
- ✅ Save the configuration
- ✅ Show you a summary

## 🎯 Step 4: Use Your Agents

After loading, you can create tasks and crews to use your agents!

