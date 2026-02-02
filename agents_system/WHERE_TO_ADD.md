# Where to Add Agent Personas, IDs, and Keys

## 📍 Location Guide

### 1. **Agent Personas** → `agents.yaml`

**File:** `agents_system/agents.yaml`

**What goes here:**
- ✅ **Already added!** All 15 agents with their personas are in this file
- The `backstory` field contains the persona/character description
- The `name` field is the agent's name (Dana Flores, Kyle Law, etc.)
- The `role` field is their job title

**Current structure:**
```yaml
agents:
  - name: "Dana Flores"           # ← Agent name/ID
    role: "Admin Assistant"        # ← Role (used for task assignment)
    goal: "..."                    # ← What they're trying to achieve
    backstory: |                   # ← THIS IS THE PERSONA
      Dana is an organized and...
    verbose: true
    allow_delegation: false
    # tools: []                    # ← Add tools here if needed
```

**To modify personas:** Edit the `backstory` field for each agent in `agents.yaml`

---

### 2. **API Keys** → `.env`

**File:** `agents_system/.env` (this file is hidden/protected)

**What goes here:**
- ✅ **Already configured!** Your OpenAI API key is here
- Add other API keys for tools/services if needed

**Current structure:**
```bash
# OpenAI API Configuration
OPENAI_API_KEY=sk-your-key-here          # ← Already set
OPENAI_MODEL=gpt-4o-mini                 # ← Already set

# If you need other API keys (for tools), add them here:
# GOOGLE_CALENDAR_API_KEY=...
# SERP_API_KEY=...
# etc.
```

**To add more keys:** Edit `.env` file directly

---

### 3. **Agent IDs** → Already in `agents.yaml`

**File:** `agents_system/agents.yaml`

**What are "IDs"?**
- The `name` field serves as the agent identifier (e.g., "Dana Flores", "Kyle Law")
- The `role` field is used to match agents with tasks in `tasks.yaml`

**Current structure:**
```yaml
- name: "Dana Flores"        # ← This is the agent ID/name
  role: "Admin Assistant"     # ← This is used in tasks.yaml
```

**No separate ID file needed** - everything is in `agents.yaml`

---

### 4. **Tool Keys** → `.env` (if using tools)

**File:** `agents_system/.env`

**If you want agents to use tools** (like CalendarTool, SearchTool, etc.):

1. **Add API keys to `.env`:**
```bash
# Example tool API keys
GOOGLE_CALENDAR_API_KEY=your-key-here
SERP_API_KEY=your-key-here
```

2. **Then add tools to agents in `agents.yaml`:**
```yaml
- name: "David Chen"
  role: "COO (Scheduler)"
  # ... other fields ...
  tools: [CalendarTool]  # ← Add tools here
```

---

## 📋 Summary

| Item | Location | Status |
|------|----------|--------|
| **Agent Personas** | `agents.yaml` → `backstory` field | ✅ Already added |
| **Agent Names/IDs** | `agents.yaml` → `name` field | ✅ Already added |
| **Agent Roles** | `agents.yaml` → `role` field | ✅ Already added |
| **OpenAI API Key** | `.env` → `OPENAI_API_KEY` | ✅ Already configured |
| **Tool API Keys** | `.env` → Add as needed | ⏳ Add if using tools |
| **Tools Assignment** | `agents.yaml` → `tools` field | ⏳ Add if needed |

---

## 🎯 What You Need to Do

### ✅ Already Done:
- All 15 agents with personas added
- OpenAI API key configured
- Agent names and roles defined

### ⏳ Optional (if needed):
- Add tool API keys to `.env` if you want agents to use external tools
- Uncomment and configure `tools: []` in `agents.yaml` for specific agents

### 📝 Next Step:
- **Define tasks** in `tasks.yaml` to assign work to your agents

---

## 💡 Quick Reference

**To modify an agent's persona:**
→ Edit `agents.yaml`, find the agent, modify the `backstory` field

**To add a new API key:**
→ Edit `.env`, add: `NEW_API_KEY=your-key-here`

**To assign tools to an agent:**
→ Edit `agents.yaml`, find the agent, change `# tools: []` to `tools: [ToolName]`

**To see all agents:**
→ Open `agents.yaml` or run: `python3 -c "from main import load_agents_from_yaml; [print(f'{a.role}') for a in load_agents_from_yaml()]"`

