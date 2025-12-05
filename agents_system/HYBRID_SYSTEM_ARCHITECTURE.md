# Hybrid System Architecture: Bridging AI Memory & Human UI

## 🎯 Vision: AI-Auditable + Human-Interactive

The goal is to create a system where:
- **AI agents** can efficiently write structured data (Markdown) via API
- **Humans** can interact with the same data through Google Docs UI features (tabs, sidebars, etc.)

## 🛑 Current Gap Analysis

| Element | Current (AI System) | Desired (Human UI) |
|---------|---------------------|---------------------|
| **New Day/Date** | Markdown heading (`### YYYY-MM-DD`) in single document | New Tab or New Document with date as title |
| **Tasks** | Markdown checkboxes (`- [ ] Task 1`) in main text | Google Tasks Sidebar for interactive tracking |
| **Calendar** | P12 logs confirming event created | Event appears in Google Calendar Sidebar |
| **Custom Tabs** | User-created tabs (To-do list, Journal, Meeting Notes) ignored by AI | Agents actively use custom tabs for organized memory |

## 💡 Hybrid System Architecture

### A. New-Day Tabs (Journaling Approach)

**Implementation:**
1. Main Tab 1: Profile/Template (unchanged)
2. Daily Logs: New tab titled `YYYY-MM-DD Daily Log` for each day
3. Agent Logic: Check if today's tab exists, create if not

**Benefits:**
- Creates "log book" directory effect
- Easier human navigation
- Maintains AI efficiency (still uses API)

**Code Changes:**
- Modify `google_docs_memory_tool` to check/create tabs
- Use Google Docs API `createNamedRange` or document structure
- Map section/subsection to tab names

### B. Google Tasks API Integration (P3 Protocol)

**Current State:**
- P3 logs tasks as markdown text: `- [ ] Task 1`
- No Google Tasks Sidebar integration

**Required Implementation:**
1. Add Google Tasks API to `tools.py`
2. Create `google_tasks_tool` function
3. Update P3 protocol to:
   - Write to memory document (AI-auditable)
   - Create Google Task (Human-interactive)

**API Requirements:**
```python
# New tool in tools.py
@tool("Google Tasks Tool")
def google_tasks_tool(
    task_title: str,
    task_notes: str = None,
    due_date: str = None,
    task_list_id: str = None
) -> str:
    """
    Create a task in Google Tasks for P3 protocol compliance.
    This makes tasks visible in the Google Tasks Sidebar.
    """
    # Implementation using Google Tasks API
    # https://developers.google.com/tasks
```

**Integration Points:**
- `force_meeting_retroactive_logging_fixed.py`: Add task creation
- `enforce_p3_p7_accountability.py`: Add task creation
- Agent protocols: Update P3 to call both memory tool AND tasks tool

### C. Custom Tab Usage (Role-Specific Organization)

**Current State:**
- Agents ignore custom tabs (Knowledge Base, Archival Log, etc.)
- All content goes to default sections

**Required Implementation:**
1. Map agent roles to custom tabs:
   - Alice (Documentation): Use "ARCHIVAL LOG" tab for P3 sign-offs
   - Dana (Admin): Use "WORKFLOW MANAGEMENT" tab
   - Others: Use role-specific tabs when available

2. Update `google_docs_memory_tool` to:
   - Accept `tab_name` parameter
   - Check if tab exists in document
   - Write to specified tab instead of default section

**Example (Alice's P3):**
```python
# When Alice completes "V1 codebase archival process"
google_docs_memory_tool(
    doc_id=alice_memory_doc_id,
    content="P3 Sign-Off: V1 archival complete...",
    tab_name="ARCHIVAL LOG",  # NEW: Use custom tab
    section="P3_COMPLETIONS",
    template="Admin"
)
```

### D. Calendar Sidebar Integration (P12 Protocol)

**Current State:**
- ✅ P12 creates calendar events via Google Calendar API
- ✅ Events appear in Google Calendar (visible in sidebar)

**Status:** Already working! The Calendar API integration is complete.

**Enhancement Opportunity:**
- Add calendar event links to memory documents
- Cross-reference calendar events with meeting logs

## 🚀 Implementation Roadmap

### Phase 1: Google Tasks API Integration (Priority 1)
1. Add Google Tasks API scope to OAuth
2. Create `google_tasks_tool` in `tools.py`
3. Update P3 protocol scripts to use both memory + tasks
4. Test with Alice's "V1 archival" task

### Phase 2: Tab-Based Architecture (Priority 2)
1. Enhance `google_docs_memory_tool` to support tab names
2. Implement tab detection/creation logic
3. Map agent roles to custom tabs
4. Update retroactive logging to use tabs

### Phase 3: Daily Journal Tabs (Priority 3)
1. Implement daily tab creation logic
2. Update all logging scripts to use date-based tabs
3. Maintain backward compatibility with section-based approach

## 📋 Next Steps

1. **Wait for Step 3 completion** (current retroactive logging)
2. **Validate current fixes** (P3/P12 in memory documents)
3. **Implement Google Tasks API** (Phase 1)
4. **Test hybrid system** (AI writes to memory + Tasks sidebar)
5. **Roll out tab-based architecture** (Phase 2 & 3)

## 🔧 Technical Requirements

### OAuth Scopes (New)
```
https://www.googleapis.com/auth/tasks
https://www.googleapis.com/auth/tasks.readonly
```

### Google Tasks API
- Task Lists: Default list or custom list per agent
- Task Creation: Title, notes, due date
- Task Updates: Mark complete, update status

### Tab Detection
- Use Google Docs API to read document structure
- Check for named ranges or headings that represent tabs
- Create tabs if they don't exist

---

**Status:** Architecture defined, ready for implementation after Step 3 validation.

