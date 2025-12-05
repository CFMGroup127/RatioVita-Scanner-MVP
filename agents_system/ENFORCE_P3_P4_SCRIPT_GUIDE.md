# Enforce P3/P4 Protocol & Execute Overdue Tasks - Script Guide

## Overview

The `enforce_p3_and_execute_overdue_tasks.py` script is a comprehensive solution to address all pending and overdue tasks by:

1. **Cleaning up duplicate tasks** in Google Tasks
2. **Assigning tasks to appropriate agents** based on their roles
3. **Enforcing P3 Protocol** (Hybrid System: Memory Documents + Google Tasks)
4. **Triggering P4 Autonomous Execution** (actually doing the work)
5. **Generating execution summary** reports

---

## Task Assignments

The script automatically assigns each overdue task to the most appropriate agent:

| Task | Assigned Agent | Priority | Due Date |
|------|---------------|----------|----------|
| **URGENT FIX: Implement authenticated logging hook** | Samuel Reed (System Architect) | P0 (Critical) | Today |
| **Draft compliance strategy for Feature 7 (CCPA risk)** | Arthur Jensen (Legal & Compliance) | P1 (High) | Tomorrow |
| **Draft legal risk assessment for V2 feature set** | Arthur Jensen (Legal & Compliance) | P1 (High) | Day after tomorrow |
| **TEST: P3 Hybrid System Validation** | Samuel Reed (System Architect) | P2 (Medium) | Today |

---

## What the Script Does

### 1. Clean Up Duplicates
- Scans Google Tasks for duplicate entries
- Removes all duplicates except the first occurrence
- Prevents confusion from multiple identical tasks

### 2. P3 Protocol Enforcement (Hybrid System)

For each task, the script ensures:

**Part A: Memory Document (AI-Auditable)**
- Task logged to agent's memory document (TASKS section)
- Includes priority, due date, status, and assignment timestamp
- Uses "Task Tracker" template

**Part B: Google Tasks (Human-Interactive)**
- Task created in Google Tasks sidebar
- Includes full task details, priority, and due date
- Makes task visible to human users

**Critical:** Both parts must be completed for full P3 compliance.

### 3. P4 Autonomous Execution

After P3 logging, the script triggers immediate execution:

- **URGENT FIX:** Locates data_processor.py, updates library, implements logging hook, verifies CCPA compliance
- **Compliance Strategy:** Reviews Feature 7, analyzes CCPA risks, drafts strategy document, submits report
- **Legal Risk Assessment:** Reviews V2 features, identifies privacy risks, drafts assessment, prioritizes risks
- **P3 Validation Test:** Creates test task, validates both systems, documents results

### 4. Completion Requirements

Each task must:
- ✅ Be executed (not just logged)
- ✅ Include artifact references (file paths, commit hashes, URLs)
- ✅ Be marked COMPLETE in both memory document and Google Tasks
- ✅ Include sign-off: "TASK COMPLETE: [Task Name] - VERIFIED BY AGENT [Agent Name] [Timestamp]"

---

## Usage

### Prerequisites

1. **OAuth Credentials:** Ensure `token.json` exists and has all required scopes
2. **Configuration:** Verify `config.py` has valid API keys
3. **Agent Definitions:** Ensure `agents.yaml` is up to date

### Running the Script

```bash
cd agents_system
source venv/bin/activate
python3 enforce_p3_and_execute_overdue_tasks.py
```

### Expected Output

The script will:
1. Validate configuration
2. Get Google API credentials
3. Clean up duplicate tasks
4. Process each task sequentially:
   - Assign to appropriate agent
   - Enforce P3 protocol
   - Trigger P4 execution
   - Monitor completion
5. Generate summary report

### Execution Time

- **Per Task:** 10-20 minutes (depending on complexity)
- **Total:** 40-80 minutes for all 4 tasks
- Tasks run sequentially to avoid conflicts

---

## Output Files

### Execution Summary

The script generates:
- `P3_P4_EXECUTION_SUMMARY_[timestamp].md` - Detailed summary of all task executions

### Agent Memory Documents

Each agent's memory document will be updated with:
- Task assignments in TASKS section
- Execution progress logs
- Completion sign-offs
- Artifact references

### Google Tasks

Google Tasks sidebar will show:
- All assigned tasks
- Due dates and priorities
- Completion status

---

## Troubleshooting

### OAuth Issues

If you get OAuth errors:
```bash
python3 fix_oauth_full_permissions.py
```

### Task Not Executing

If tasks are logged but not executed:
1. Check agent has appropriate tools loaded
2. Verify execution instructions are clear
3. Check agent's max_iter and max_execution_time settings

### Memory Document Not Updating

If memory documents aren't updating:
1. Verify memory_doc_id in agents.yaml
2. Check OAuth has documents scope
3. Verify document permissions

---

## Next Steps After Execution

1. **Verify Completion:**
   - Check Google Tasks sidebar for completed tasks
   - Review agent memory documents for completion logs
   - Verify artifacts were created

2. **Monitor Progress:**
   - Use `comprehensive_task_status_report.py` to check status
   - Review execution summary report

3. **Follow Up:**
   - Address any failed tasks
   - Review artifact references
   - Ensure all P3/P4 protocols were followed

---

## Status

✅ **Script Created:** December 2, 2025  
✅ **Ready for Execution:** Yes  
✅ **All Dependencies:** Verified  

---

**Note:** This script processes tasks sequentially to ensure proper execution and avoid conflicts. Each task will be fully completed (P3 + P4) before moving to the next.

