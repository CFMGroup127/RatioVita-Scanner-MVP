"""
Force Meeting Retroactive Logging - FIXED VERSION
- Role-specific notes (not full minutes for all)
- Dana creates full minutes/transcript (her role)
- P3 task logging (updates TASKS section)
- P12 calendar event creation
- Prevents duplicate logging
"""
import os
import sys
import re
from datetime import datetime
from crewai import Agent, Task, Crew
from main import load_agents_from_yaml, get_agent_metadata

# Import the parse function from the original script
from force_meeting_retroactive_logging import parse_meeting_outcomes_file

def get_role_specific_meeting_notes(role, agent_name, meeting_data, relevant_actions):
    """Generate role-specific meeting notes based on agent's role"""
    meeting_title = meeting_data['title']
    meeting_date = meeting_data['date']
    meeting_time = meeting_data['time']
    decisions = meeting_data['decisions']
    
    # Dana Flores (Admin Assistant) - Full meeting minutes
    if "Admin Assistant" in role or "Workflow Funnel" in role:
        decisions_text = ""
        for i, decision in enumerate(decisions, 1):
            decisions_text += f"**Decision {i}:** {decision} | **Vote:** Unanimous\n"
        
        action_items_text = ""
        for action in meeting_data['action_items']:
            action_items_text += f"**Task:** {action['task']} | **Owner:** {action['owner']} | **Due Date:** {action['deadline']}\n"
        
        present_list = ", ".join(meeting_data['attendees']['present'][:10]) if meeting_data['attendees']['present'] else "All 15 agents"
        absent_list = ", ".join(meeting_data['attendees']['absent']) if meeting_data['attendees']['absent'] else "None"
        
        return f"""MEETING MINUTES: {meeting_title} - {meeting_date}

I. Overview:
- Time: {meeting_time}
- Location: Virtual Meeting
- Type: Executive Strategy Group

II. Attendance:
- Present: {present_list}
- Absent: {absent_list}

III. Decisions Made:
{decisions_text}

IV. Action Items:
{action_items_text}

V. Key Discussion Points:
- V1 Legacy Review: Systematic archival process approved
- V2 Planning: Competitive analysis and legal risk assessment prioritized
- Task Delegation: Specific action items assigned with deadlines

VI. Notes:
Full meeting minutes recorded by {agent_name} (Admin Assistant) as per role requirements."""
    
    # Other agents - Role-specific notes only
    role_notes = {
        "Documentation and Knowledge Archivist": f"""**Meeting Notes - {meeting_title} ({meeting_date})**

**Relevant to My Role:**
- V1 codebase archival process approved and assigned to me
- Documentation requirements discussed
- Archive structure and mapping requirements confirmed

**My Assigned Tasks:**
{chr(10).join([f"- {action['task']} (Deadline: {action['deadline']})" for action in relevant_actions]) if relevant_actions else "- No specific tasks assigned"}

**Action Items for Others:**
- {len(meeting_data['action_items'])} total action items assigned across team

**Next Steps:**
- Begin systematic V1 codebase archival process
- Create documentation mapping structure""",
        
        "Legal Compliance and Risk Assessor": f"""**Meeting Notes - {meeting_title} ({meeting_date})**

**Relevant to My Role:**
- Legal risk assessment for V2 feature set prioritized
- Compliance requirements discussed
- Data privacy considerations noted

**My Assigned Tasks:**
{chr(10).join([f"- {action['task']} (Deadline: {action['deadline']})" for action in relevant_actions]) if relevant_actions else "- No specific tasks assigned"}

**Key Decisions:**
- V2 features require compliance review before implementation
- Legal risk assessment is a prerequisite for development""",
        
        "Competitive Intelligence Specialist": f"""**Meeting Notes - {meeting_title} ({meeting_date})**

**Relevant to My Role:**
- Competitive analysis priority shifted to Tier 1 competitors
- Focus on direct competitors with similar market positioning
- Market intelligence requirements discussed

**My Assigned Tasks:**
{chr(10).join([f"- {action['task']} (Deadline: {action['deadline']})" for action in relevant_actions]) if relevant_actions else "- No specific tasks assigned"}""",
        
        "Market Strategist and Voice of the Customer": f"""**Meeting Notes - {meeting_title} ({meeting_date})**

**Relevant to My Role:**
- V2 market positioning discussed
- Customer requirements and feedback integration
- Market strategy alignment with competitive analysis""",
        
        "Financial Guardian and Strategy Modeler": f"""**Meeting Notes - {meeting_title} ({meeting_date})**

**Relevant to My Role:**
- V2 financial planning and resource allocation
- Budget considerations for competitive analysis and legal review
- Financial modeling requirements""",
        
        "Technical and Product Visionary": f"""**Meeting Notes - {meeting_title} ({meeting_date})**

**Relevant to My Role:**
- V2 technical architecture and product vision
- Integration with V1 legacy archival
- Technical requirements for competitive features""",
        
        "Lead Code Execution and V2 Development": f"""**Meeting Notes - {meeting_title} ({meeting_date})**

**Relevant to My Role:**
- V2 development priorities and timeline
- Code execution requirements
- Integration with legal and competitive analysis""",
        
        "Process and Factual Integrity Auditor": f"""**Meeting Notes - {meeting_title} ({meeting_date})**

**Relevant to My Role:**
- Process compliance and integrity requirements
- Audit requirements for V2 planning
- Factual verification of meeting decisions""",
        
        "Process Architect and Schedule Publisher": f"""**Meeting Notes - {meeting_title} ({meeting_date})**

**Relevant to My Role:**
- Project schedule and timeline coordination
- Meeting scheduling and coordination
- Process architecture for V2 planning""",
        
        "Visionary and Final Decision Maker": f"""**Meeting Notes - {meeting_title} ({meeting_date})**

**Relevant to My Role:**
- Strategic decisions and final approvals
- V2 vision and direction
- High-level strategic alignment""",
        
        "Go-to-Market Strategy": f"""**Meeting Notes - {meeting_title} ({meeting_date})**

**Relevant to My Role:**
- GTM strategy for V2 launch
- Market entry strategy
- Competitive positioning for launch""",
        
        "Budget and Conflict Guardrail": f"""**Meeting Notes - {meeting_title} ({meeting_date})**

**Relevant to My Role:**
- Budget oversight and conflict resolution
- Resource allocation and guardrails
- Financial conflict prevention""",
        
        "Collateral Support and Lead Qualification": f"""**Meeting Notes - {meeting_title} ({meeting_date})**

**Relevant to My Role:**
- Marketing collateral requirements
- Lead qualification processes
- Support materials for V2 launch""",
        
        "External Communication and Trust Builder": f"""**Meeting Notes - {meeting_title} ({meeting_date})**

**Relevant to My Role:**
- External communication strategy
- Trust building and stakeholder relations
- Public-facing messaging for V2"""
    }
    
    # Default role-specific notes
    for key_role, notes in role_notes.items():
        if key_role in role:
            return notes
    
    # Generic role-specific notes
    return f"""**Meeting Notes - {meeting_title} ({meeting_date})**

**Relevant to My Role:**
- Meeting attended and participated in discussions
- {len(decisions)} decisions made
- {len(meeting_data['action_items'])} action items assigned

**My Assigned Tasks:**
{chr(10).join([f"- {action['task']} (Deadline: {action['deadline']})" for action in relevant_actions]) if relevant_actions else "- No specific tasks assigned"}"""

def force_retroactive_meeting_logging_fixed():
    """Force all agents to retroactively log the meeting - FIXED VERSION"""
    print("🔄 FORCING RETROACTIVE MEETING LOGGING (FIXED VERSION)")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
    
    # Parse meeting outcomes file
    print("📄 Reading MEETING_OUTCOMES_V1.txt...")
    meeting_data = parse_meeting_outcomes_file('MEETING_OUTCOMES_V1.txt')
    
    meeting_title = meeting_data['title']
    meeting_date = meeting_data['date']
    meeting_time = meeting_data['time']
    decisions = meeting_data['decisions']
    action_items = meeting_data['action_items']
    full_transcript = meeting_data['full_transcript']
    attendees = meeting_data['attendees']
    next_meeting = meeting_data['next_meeting']
    
    print(f"✅ Meeting data loaded:")
    print(f"   Title: {meeting_title}")
    print(f"   Date: {meeting_date}")
    print(f"   Time: {meeting_time}")
    print(f"   Decisions: {len(decisions)}")
    print(f"   Action Items: {len(action_items)}")
    print(f"   Transcript Length: {len(full_transcript)} characters\n")
    
    agents = load_agents_from_yaml('agents.yaml')
    dana_email = "dana.flores@ratiovita.com"
    david_email = "david.chen@ratiovita.com"
    
    tasks = []
    
    for agent in agents:
        role = agent.role
        meta = get_agent_metadata(role)
        
        agent_name = meta.get('email_address', '').split('@')[0].replace('.', ' ').title()
        if not agent_name:
            agent_name = role.split()[0] if role else 'Unknown'
        
        memory_doc_id = meta.get('memory_doc_id', '')
        calendar_id = meta.get('personal_calendar_id', '')
        email_address = meta.get('email_address', '')
        
        if not memory_doc_id:
            print(f"⚠️  Skipping {agent_name}: No memory_doc_id")
            continue
        
        # Check if this agent has action items assigned (for P3/P7)
        relevant_actions = [ai for ai in action_items if agent_name.lower() in ai['owner'].lower() or role.lower() in ai['owner'].lower()]
        has_action_items = len(relevant_actions) > 0
        
        # Check if this is Dana (Admin Assistant) - she creates full minutes/transcript
        is_dana = "Admin Assistant" in role or "Workflow Funnel" in role
        
        # Get role-specific meeting notes
        role_specific_notes = get_role_specific_meeting_notes(role, agent_name, meeting_data, relevant_actions)
        
        # Format P3 task list for TASKS section
        p3_tasks_text = ""
        if has_action_items:
            for action in relevant_actions:
                p3_tasks_text += f"- [ ] {action['task']} (Deadline: {action['deadline']}) - Assigned: {meeting_date}\n"
        else:
            p3_tasks_text = "- [ ] Review meeting notes and action items\n"
        
        task_description = f"""
**MANDATORY RETROACTIVE MEETING LOGGING (FIXED VERSION)**

You attended a meeting that occurred on {meeting_date} at {meeting_time}, but you failed to properly log it according to protocols. You must now retroactively complete all required protocols.

**MEETING DETAILS:**
- Title: {meeting_title}
- Date: {meeting_date}
- Time: {meeting_time}
- Status: Meeting has already occurred
- Attendance: 100% (All 15 agents present)

**YOU MUST COMPLETE THE FOLLOWING RETROACTIVE ACTIONS:**

**STEP 1: RETROACTIVE P8 PROTOCOL LOGGING (PROTOCOLS Section)**
- Use the **Google Docs Memory Tool** to log to your memory document (doc_id: {memory_doc_id}):
  - Section: "PROTOCOLS"
  - Subsection: "{meeting_date}"
  - Content: "RETROACTIVE P8 LOG: MEETING ACCEPTED: {meeting_title} - {meeting_date} at {meeting_time} EST - Logged: {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}"
  - Template: "Compliance Log"

**STEP 2: RETROACTIVE EMAIL CONFIRMATION (P8 Protocol)**
- Use the **GMailTool** to send a retroactive confirmation email:
  - To: {dana_email}, {david_email}
  - CC: collin.m@ratiovita.com (MANDATORY)
  - Subject: "Retroactive Meeting Acceptance: {meeting_title}"
  - Body: "I am retroactively confirming my attendance at {meeting_title} that occurred on {meeting_date} at {meeting_time}. I apologize for the delay in sending this confirmation. I was present at the meeting and participated in all discussions. {agent_name}"

**STEP 3: RETROACTIVE P5 MEETING NOTES (MEETINGS Section)**
{"**CRITICAL - DANA'S ROLE:** As Admin Assistant, you MUST create FULL MEETING MINUTES using the MEETING_MINUTES template. This is your specific responsibility." if is_dana else "**CRITICAL - ROLE-SPECIFIC NOTES ONLY:** You MUST create BRIEF, ROLE-SPECIFIC meeting notes. DO NOT write full meeting minutes. DO NOT copy the entire meeting transcript. Write ONLY what is relevant to YOUR specific role."}
- Use the **Google Docs Memory Tool**:
  - Section: "MEETINGS"
  - Subsection: "{meeting_date}"
  {"- Template: \"MEETING_MINUTES\" (Full structured minutes)" if is_dana else "- Template: \"Meeting Notes\" (Brief role-specific summary)"}
  - Content: "{role_specific_notes}"
  
{"**VERIFICATION:** Your notes must include ALL sections (I-VI) with full decisions and action items. This is your role requirement." if is_dana else "**VERIFICATION:** Your notes must be BRIEF (3-5 bullet points) and focus ONLY on items relevant to your role. If you write full minutes, you have FAILED this protocol."}

**STEP 4: P3 TASK LOGGING (Hybrid System - Memory + Google Tasks)**
- **PART A: Memory Document (AI-Auditable)**
  - Use the **Google Docs Memory Tool** to update your TASKS section:
    - Section: "TASKS"
    - Subsection: "{meeting_date}"
    - Content: "{p3_tasks_text}"
    - Template: "Task Tracker"

- **PART B: Google Tasks (Human-Interactive Sidebar)**
{f"- For each assigned task, use the **Google Tasks Tool** to create a task in Google Tasks:" if has_action_items else "- No specific tasks assigned, skip Google Tasks creation"}
{f"- Task Title: [Task Name from action items]" if has_action_items else ""}
{f"- Task Notes: [Task details and deadline]" if has_action_items else ""}
{f"- Due Date: [Deadline from action items]" if has_action_items else ""}
{f"- This makes your tasks visible in the Google Tasks Sidebar for human interaction" if has_action_items else ""}

**STEP 5: RETROACTIVE CALENDAR EVENT (P12 Protocol)**
- Use the **Google Calendar Tool** to add the meeting to your personal calendar (calendar_id: {calendar_id}):
  - Title: "{meeting_title}"
  - Date: {meeting_date}
  - Time: {meeting_time}
  - Description: "Retroactive calendar entry for meeting that occurred on {meeting_date}"

**STEP 6: RETROACTIVE TRANSCRIPT ENTRY (TRANSCRIPTS Section)**
{"**CRITICAL - DANA'S ROLE:** As Admin Assistant, you MUST log the FULL MEETING TRANSCRIPT. This is your specific responsibility for archival." if is_dana else "**CRITICAL - ROLE-SPECIFIC SUMMARY ONLY:** You MUST log a BRIEF summary (2-3 sentences) of key points relevant to YOUR role. DO NOT copy the full transcript. DO NOT write extensive notes."}
- Use the **Google Docs Memory Tool**:
  - Section: "TRANSCRIPTS"
  - Subsection: "{meeting_date}"
  - Template: "MEETING_TRANSCRIPT_ARCHIVE"
  {"- Content: Full transcript (first 5000 characters): {full_transcript[:5000]}" if is_dana else f"- Content: Brief role-specific summary (2-3 sentences maximum): Key discussion points relevant to {role} role from {meeting_title}. Focus only on items that directly impact my work."}
  
{"**VERIFICATION:** Your transcript entry must be the FULL meeting transcript. This is your role requirement." if is_dana else "**VERIFICATION:** Your transcript entry must be BRIEF (2-3 sentences). If you write more than 100 words, you have FAILED this protocol."}

**STEP 7: P7 TASK DELEGATION EMAIL (If Action Items Assigned)**
{f"- You have {len(relevant_actions)} action item(s) assigned to you. Use the **GMailTool** to send acknowledgment emails:" if has_action_items else "- No specific action items assigned to you in this meeting."}
{f"- For each action item, send an email to {dana_email} and {david_email} (CC: collin.m@ratiovita.com):" if has_action_items else ""}
{f"- Subject: 'Task Acknowledgment: [Task Name]'" if has_action_items else ""}
{f"- Body: 'I acknowledge receipt of the following task assigned during {meeting_title}: [Task Details]. I will complete this by [Deadline]. {agent_name}'" if has_action_items else ""}

**CRITICAL:** 
- Complete ALL applicable steps to ensure full compliance
- {"As Admin Assistant, you must create FULL meeting minutes and transcript (your specific role)" if is_dana else "Create role-specific notes only (not full minutes)"}
- Update TASKS section with assigned tasks (P3 protocol)
- Add calendar event to personal calendar (P12 protocol)
"""
        
        expected_output_parts = [
            "P8 protocol logged to PROTOCOLS section",
            "P8 confirmation email sent",
            f"P5 meeting notes added to MEETINGS section ({'FULL MEETING MINUTES' if is_dana else 'role-specific notes'})",
            "P3 tasks logged to TASKS section",
            "P12 calendar event added to personal calendar",
            f"Transcript entry added to TRANSCRIPTS section ({'FULL TRANSCRIPT' if is_dana else 'role-specific summary'})"
        ]
        
        if has_action_items:
            expected_output_parts.append(f"P7 task delegation emails sent for {len(relevant_actions)} action item(s)")
        
        expected_output = f"Retroactive logging complete: {'; '.join(expected_output_parts)} for {meeting_title}"
        
        task = Task(
            description=task_description,
            agent=agent,
            expected_output=expected_output
        )
        
        tasks.append((agent, task))
    
    print(f"📋 Created {len(tasks)} retroactive logging tasks\n")
    print("🚀 Executing retroactive logging SEQUENTIALLY (one agent at a time)...")
    print("="*80)
    print("This will take longer but is more reliable.\n")
    
    success_count = 0
    error_count = 0
    results = []
    
    # Process agents SEQUENTIALLY (one at a time)
    for i, (agent, task) in enumerate(tasks, 1):
        agent_name = agent.role
        print(f"\n[{i}/{len(tasks)}] Processing: {agent_name}")
        print("-" * 80)
        
        try:
            crew = Crew(
                agents=[agent],
                tasks=[task],
                verbose=True
            )
            
            result = crew.kickoff()
            
            print(f"\n[{agent_name}]: ✅ Retroactive logging complete")
            results.append({'agent': agent_name, 'status': 'success', 'result': result})
            success_count += 1
            
        except Exception as e:
            print(f"\n[{agent_name}]: ❌ Error: {e}")
            import traceback
            traceback.print_exc()
            results.append({'agent': agent_name, 'status': 'error', 'error': str(e)})
            error_count += 1
        
        print("-" * 80)
    
    # Summary
    print("\n" + "="*80)
    print("✅ SEQUENTIAL EXECUTION COMPLETE")
    print("="*80)
    print(f"Total Agents: {len(tasks)}")
    print(f"✅ Successful: {success_count}")
    print(f"❌ Errors: {error_count}")
    
    if error_count > 0:
        print(f"\n⚠️  Agents with errors:")
        for result in results:
            if result['status'] == 'error':
                print(f"   - {result['agent']}: {result.get('error', 'Unknown error')}")
    
    return success_count > 0

if __name__ == "__main__":
    success = force_retroactive_meeting_logging_fixed()
    sys.exit(0 if success else 1)

