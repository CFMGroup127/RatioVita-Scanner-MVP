# Daily Task Report (DTR) Protocol

**Effective Date:** December 4, 2025  
**Mandatory For:** All agents assigned to RatioVita V2 tasks

---

## 📋 Protocol Overview

All agents assigned to RatioVita V2 development tasks MUST submit a Daily Task Report (DTR) in table format. This ensures:
- Clear visibility of progress
- Early identification of blockers
- Proper documentation of work
- Accountability and transparency

---

## ✅ DTR Requirements

### **1. Format Requirements**
- **Format:** Table format (see DTR_TEMPLATE.md)
- **Location:** Agent's memory document (REPORTS section)
- **Distribution:** Email to Dana Flores and David Chen
- **CC:** collin.m@ratiovita.com (mandatory)

### **2. Content Requirements**

**Required Sections:**
1. **Daily Task Report Table** - Summary of all tasks worked on
2. **Summary Statistics** - Overall progress metrics
3. **Detailed Task Breakdown** - Detailed information for each task
4. **Key Decisions Made** - Important decisions and rationale
5. **Information Shared** - What was shared with other agents
6. **Blockers & Issues** - Any blockers preventing progress
7. **Quality Metrics** - Code quality, test coverage, etc.
8. **Tomorrow's Plan** - What will be worked on next

### **3. Submission Requirements**

**When to Submit:**
- **Daily** - At end of each work day
- **Time:** Before 6:00 PM EST
- **Frequency:** Every day a task is actively worked on

**Where to Submit:**
1. **Memory Document:** REPORTS section with date subsection
2. **Email:** To dana.flores@ratiovita.com and david.chen@ratiovita.com
3. **CC:** collin.m@ratiovita.com (mandatory)

**Email Format:**
- **Subject:** `DTR - [Agent Name] - [Date] - [Task IDs]`
- **Body:** Full DTR in table format
- **Attachment:** None (DTR in email body)

---

## 📊 DTR Table Format

### **Main Task Summary Table:**

| Task ID | Task Name | Status | Time Spent | Progress % | Blockers | Next Steps | Artifacts |
|---------|-----------|--------|------------|------------|----------|------------|-----------|
| V2-001 | Connect CameraCaptureView | In Progress | 2.5h | 60% | None | Implement error handling | CameraCaptureView.swift |

**Column Definitions:**
- **Task ID:** Task identifier (e.g., V2-001)
- **Task Name:** Full task name
- **Status:** In Progress / Complete / Blocked
- **Time Spent:** Hours spent on task today
- **Progress %:** Overall progress percentage (0-100%)
- **Blockers:** List of blockers (or "None")
- **Next Steps:** What needs to be done next
- **Artifacts:** Files created/modified, commits, etc.

---

## 📝 Detailed Task Breakdown Format

For each task, provide:

```markdown
### Task: [Task ID] - [Task Name]
- **Status:** [In Progress/Complete/Blocked]
- **Time Spent:** [Hours]
- **Progress:** [Percentage]%
- **Description:** [What was done today]
- **Challenges:** [Any issues encountered]
- **Solutions:** [How challenges were resolved]
- **Artifacts:** [Files created/modified, commits, etc.]
- **Next Steps:** [What needs to be done next]
- **Blockers:** [Any blockers preventing progress]
```

---

## 🔄 Information Sharing Table

| Shared With | Content | Method | Timestamp |
|------------|---------|--------|-----------|
| Tyler Cobb | Code review request | Email + Memory Doc | 2025-12-04 14:30 EST |
| Ash Roy | Architecture question | Email | 2025-12-04 15:00 EST |

---

## ⚠️ Blocker Reporting

**Format:**
| Blocker | Impact | Resolution Plan | Assigned To |
|---------|--------|------------------|-------------|
| Missing API documentation | Cannot implement integration | Request from Ash Roy | Ash Roy |

**Requirements:**
- Report blockers immediately (don't wait for DTR)
- Include impact assessment
- Propose resolution plan
- Identify who can help resolve

---

## ✅ Quality Metrics

**Required Metrics:**
- **Code Quality Score:** [Score]% (from code review)
- **Test Coverage:** [Percentage]% (if applicable)
- **Documentation Complete:** [Yes/No]
- **Review Status:** [Pending/In Progress/Complete]

---

## 📅 Tomorrow's Plan

List 3-5 specific tasks/actions planned for tomorrow:
1. [Specific task/action]
2. [Specific task/action]
3. [Specific task/action]

---

## 🎯 DTR Checklist

Before submitting DTR, verify:

- [ ] All tasks worked on today are listed
- [ ] Time spent is accurate
- [ ] Progress percentages are updated
- [ ] Blockers are clearly identified
- [ ] Artifacts are listed (files, commits, etc.)
- [ ] Information shared is documented
- [ ] Quality metrics are included
- [ ] Tomorrow's plan is specific
- [ ] DTR is in memory document (REPORTS section)
- [ ] Email sent to Dana and David (CC: collin.m@ratiovita.com)
- [ ] Email subject follows format: `DTR - [Agent Name] - [Date] - [Task IDs]`

---

## 📧 Email Template

**Subject:** `DTR - [Agent Name] - [Date] - [Task IDs]`

**Body:**
```
Dear Dana Flores and David Chen,

Please find my Daily Task Report for [Date].

[Full DTR content in table format - copy from memory document]

Best regards,
[Agent Name]
[Role]
```

**CC:** collin.m@ratiovita.com (mandatory)

---

## 🚨 Non-Compliance

**If DTR is not submitted:**
- **First offense:** Warning from Dana Flores
- **Second offense:** Escalation to Kimi K2
- **Third offense:** Escalation to Human

**If DTR is incomplete:**
- Dana Flores will request completion
- Agent must resubmit within 24 hours

---

## 📚 Reference

- **DTR Template:** `DTR_TEMPLATE.md`
- **Task Specifications:** `AGENT_TASK_SPECIFICATIONS_V2.md`
- **Workflow Guide:** `AGENT_WORKFLOW_ORCHESTRATION.md`

---

**Protocol Version:** 1.0  
**Last Updated:** December 4, 2025  
**Maintained By:** Kimi K2

