# Agent Configuration Guide

## 📍 Where to Add Agent Information

### **All Agent Data → `agents.yaml`**

Everything for each agent goes in `agents_system/agents.yaml`. Each agent has:

```yaml
- designation: "Admin Assistant Agent"           # ← Agent identifier
  email_address: "dana.flores@hurumo.ai"         # ← Email address
  model: "gpt-4o-mini"                            # ← Model for this agent
  api_key: "[PASTE_CONFIDENTIAL_API_KEY_HERE]"    # ← Agent-specific API key
  memory_doc_id: "[PASTE_DANA_DOC_ID_HERE]"       # ← Memory document ID
  personal_calendar_id: "[PASTE_DANA_CALENDAR_ID_HERE]"  # ← Calendar ID
  meeting_transcript_doc_id: "[PASTE_MEETING_TRANSCRIPT_DOC_ID_HERE]"  # ← Transcript doc ID
  role: "Admin Assistant & Workflow Funnel"       # ← Role (used for tasks)
  goal: "Maintain absolute clarity..."            # ← Agent's goal
  backstory: |                                     # ← Agent's background
    Dana is an organized...
  protocol: |                                      # ← Mandatory protocols
    MANDATORY: Must use the MeetingTranscriptTool...
  verbose: true
  allow_delegation: false
  # tools: [MeetingTranscriptTool]                 # ← Tools for this agent
```

---

## 🔑 What to Replace

### 1. **API Keys** → Replace `[PASTE_CONFIDENTIAL_API_KEY_HERE]`

For each agent, replace the placeholder with their actual API key:

```yaml
api_key: "sk-proj-abc123..."  # ← Replace with actual key
```

**Note:** If an agent doesn't have a specific API key, you can:
- Use the main OpenAI key from `.env` (leave placeholder)
- Or set it to the same value for all agents

---

### 2. **Document IDs** → Replace `[PASTE_*_DOC_ID_HERE]`

Replace these placeholders with actual document IDs:

- `memory_doc_id`: ID for the agent's memory document
- `personal_calendar_id`: ID for the agent's calendar
- `meeting_transcript_doc_id`: ID for meeting transcripts

Example:
```yaml
memory_doc_id: "doc_abc123xyz"
personal_calendar_id: "cal_xyz789abc"
meeting_transcript_doc_id: "transcript_doc_123"
```

---

### 3. **Email Addresses** → Already Set

All email addresses are already configured in the format:
- `dana.flores@hurumo.ai`
- `kyle.law@hurumo.ai`
- etc.

---

## 📋 Current Status

✅ **All 15 agents added** with:
- Designation
- Email address
- Role
- Goal
- Backstory
- Protocol (for Dana)
- Placeholders for API keys and document IDs

⏳ **Need to fill in:**
- API keys (replace `[PASTE_CONFIDENTIAL_API_KEY_HERE]`)
- Memory document IDs
- Calendar IDs
- Meeting transcript document IDs

---

## 🎯 Quick Reference

| Field | Location | Example |
|-------|----------|---------|
| **Designation** | `agents.yaml` → `designation` | "Admin Assistant Agent" |
| **Email** | `agents.yaml` → `email_address` | "dana.flores@hurumo.ai" |
| **API Key** | `agents.yaml` → `api_key` | "sk-proj-..." |
| **Memory Doc ID** | `agents.yaml` → `memory_doc_id` | "doc_abc123" |
| **Calendar ID** | `agents.yaml` → `personal_calendar_id` | "cal_xyz789" |
| **Transcript Doc ID** | `agents.yaml` → `meeting_transcript_doc_id` | "transcript_123" |
| **Protocol** | `agents.yaml` → `protocol` | "MANDATORY: Must use..." |

---

## ✅ Next Steps

1. **Open `agents.yaml`**
2. **For each agent, replace:**
   - `[PASTE_CONFIDENTIAL_API_KEY_HERE]` → Actual API key
   - `[PASTE_*_DOC_ID_HERE]` → Actual document IDs
3. **Save the file**
4. **Run:** `python3 main.py` to verify

The system will show you which fields still need to be configured!

