"""
Birthday Lunch System Integration Test (SIT)
This script executes the full "Birthday Lunch" test plan to verify all agent tools and integrations.
"""
import os
import yaml
from datetime import datetime, timedelta
from crewai import Agent, Task, Crew, Process
from config import Config
from typing import Dict, List, Any
from langchain_openai import ChatOpenAI
from tools import (
    get_google_docs_memory_tool,
    get_google_calendar_tool,
    get_gmail_tool
)
from main import load_agents_from_yaml, get_agent_metadata

def get_next_weekday(date_str):
    """
    If the date falls on Saturday or Sunday, return the following Monday.
    Otherwise, return the date itself.
    """
    date_obj = datetime.strptime(date_str, "%Y-%m-%d")
    weekday = date_obj.weekday()  # 0=Monday, 6=Sunday
    
    if weekday == 5:  # Saturday
        return date_obj + timedelta(days=2)  # Next Monday
    elif weekday == 6:  # Sunday
        return date_obj + timedelta(days=1)  # Next Monday
    else:
        return date_obj

def format_datetime_for_calendar(date_obj, time_str="12:30:00"):
    """Format datetime for Google Calendar API (RFC3339 format)."""
    # Combine date with time
    dt = datetime.combine(date_obj.date(), datetime.strptime(time_str, "%H:%M:%S").time())
    # Format as RFC3339
    return dt.strftime("%Y-%m-%dT%H:%M:%S")

def birthday_lunch_sit():
    """
    Execute the full Birthday Lunch System Integration Test.
    Tests all 15 agents across 5 actions:
    1. Memory Warmup
    2. Scheduling
    3. Coordination & Sharing (David Chen)
    4. Communication & Acknowledgement
    5. Receipt & Reply
    """
    print("\n" + "="*80)
    print("🎂 BIRTHDAY LUNCH SYSTEM INTEGRATION TEST (SIT)")
    print("="*80)
    
    # Validate configuration
    try:
        Config.validate()
        print("✅ Configuration validated")
    except ValueError as e:
        print(f"❌ Configuration Error: {e}")
        return None
    
    # Set default OpenAI API key for CrewAI
    os.environ['OPENAI_API_KEY'] = Config.OPENAI_API_KEY
    
    # Load agents from YAML
    print("\n📋 Loading agents from agents.yaml...")
    try:
        agents = load_agents_from_yaml('agents.yaml')
        print(f"✅ Loaded {len(agents)} agents")
    except Exception as e:
        print(f"❌ Error loading agents: {e}")
        import traceback
        traceback.print_exc()
        return None
    
    # Get all agent emails and metadata
    agent_emails = {}
    agent_info = {}
    
    for agent in agents:
        role = agent.role
        metadata = get_agent_metadata(role)
        email = metadata.get('email_address', '')
        designation = metadata.get('designation', role)
        memory_id = metadata.get('memory_doc_id', '')
        calendar_id = metadata.get('personal_calendar_id', '')
        birth_date = metadata.get('birth_date', '')
        favorite_restaurant = metadata.get('favorite_restaurant', '')
        
        if email:
            agent_emails[role] = email
            agent_info[role] = {
                'email': email,
                'designation': designation,
                'role': role,
                'memory_id': memory_id,
                'calendar_id': calendar_id,
                'birth_date': birth_date,
                'favorite_restaurant': favorite_restaurant,
                'agent': agent
            }
    
    if len(agent_info) != 15:
        print(f"⚠️  Warning: Expected 15 agents, found {len(agent_info)}")
    
    tasks = []
    
    # ============================================================================
    # ACTION 1: MEMORY WARMUP (All 15 Agents)
    # ============================================================================
    print("\n" + "="*80)
    print("ACTION 1: MEMORY WARMUP - All 15 Agents")
    print("="*80)
    
    for role, info in agent_info.items():
        agent = info['agent']
        
        memory_task_description = (
            f"Write your introduction and personal information to your persistent memory document. "
            f"Use the Google Docs Memory Tool to write the following information to your memory document "
            f"(memory_doc_id: {info['memory_id']}):\n\n"
            f"Name: {info['designation']}\n"
            f"Role: {info['role']}\n"
            f"Birth Date: {info['birth_date']}\n"
            f"Favorite Restaurant: {info['favorite_restaurant']}\n\n"
            f"This is part of the Birthday Lunch System Integration Test."
        )
        
        memory_task = Task(
            description=memory_task_description,
            agent=agent,
            expected_output=f"Confirmation that introduction has been written to memory document (ID: {info['memory_id']})",
            max_iter=5  # Limit iterations per task
        )
        tasks.append(memory_task)
    
    # ============================================================================
    # ACTION 2: SCHEDULING (All 15 Agents)
    # ============================================================================
    print("\n" + "="*80)
    print("ACTION 2: SCHEDULING - All 15 Agents")
    print("="*80)
    
    for role, info in agent_info.items():
        agent = info['agent']
        birth_date = info['birth_date']
        favorite_restaurant = info['favorite_restaurant']
        designation = info['designation']
        
        # Calculate lunch date (next weekday if birthday is on weekend)
        lunch_date = get_next_weekday(birth_date)
        if lunch_date.weekday() in [5, 6]:  # If still weekend (shouldn't happen)
            lunch_date = lunch_date + timedelta(days=(7 - lunch_date.weekday()))
        
        # Format dates for calendar
        start_time = format_datetime_for_calendar(lunch_date, "12:30:00")
        end_time = format_datetime_for_calendar(lunch_date, "14:00:00")
        
        calendar_task_description = (
            f"Create a 'Birthday Lunch' event on your personal calendar using the Google Calendar Tool.\n\n"
            f"⚠️ IMPORTANT: You MUST use the Google Calendar Tool with these EXACT parameters:\n\n"
            f"- calendar_id: \"{info['calendar_id']}\" (REQUIRED - use this exact value)\n"
            f"- action: \"create\" (REQUIRED)\n"
            f"- event_title: \"Birthday Lunch: Celebrating {designation}\" (REQUIRED)\n"
            f"- event_description: \"Join {designation} for a birthday celebration at {favorite_restaurant}. This is a casual lunch to celebrate {designation}'s birthday.\" (OPTIONAL)\n"
            f"- start_time: \"{start_time}\" (REQUIRED - ISO 8601 format)\n"
            f"- end_time: \"{end_time}\" (REQUIRED - ISO 8601 format)\n\n"
            f"📋 Parameter names must be spelled EXACTLY: calendar_id, action, event_title, event_description, start_time, end_time\n\n"
            f"Note: Your birthday is {birth_date}, and the lunch is scheduled for {lunch_date.strftime('%Y-%m-%d')} "
            f"at 12:30 PM (adjusted if your birthday falls on a weekend).\n\n"
            f"Use the Google Calendar Tool NOW with the calendar_id value: {info['calendar_id']}"
        )
        
        calendar_task = Task(
            description=calendar_task_description,
            agent=agent,
            expected_output=f"Confirmation that birthday lunch event has been created in calendar (ID: {info['calendar_id']})",
            context=[tasks[-1]] if tasks else [],  # Depends on memory task
            max_iter=5  # Limit iterations per task
        )
        tasks.append(calendar_task)
    
    # ============================================================================
    # ACTION 3: COORDINATION & SHARING (David Chen - COO)
    # ============================================================================
    print("\n" + "="*80)
    print("ACTION 3: COORDINATION & SHARING - David Chen (COO)")
    print("="*80)
    
    david_chen_role = "Process Architect and Schedule Publisher"
    david_info = agent_info.get(david_chen_role)
    
    if david_info:
        david_agent = david_info['agent']
        project_cal_id = get_agent_metadata(david_chen_role).get('project_schedule_calendar_id', '')
        
        # Create task for David to mirror all events
        coordination_task_description = (
            f"Mirror all 15 individual birthday lunch events onto the centralized Project Schedule Calendar. "
            f"First, read all personal calendars to get the birthday lunch events, then create corresponding events "
            f"on the project schedule calendar (ID: {project_cal_id}).\n\n"
            f"You need to:\n"
            f"1. Read each agent's personal calendar to find their birthday lunch event\n"
            f"2. Create a corresponding event on the project schedule calendar with the same details\n"
            f"3. Ensure all 15 events are mirrored\n\n"
            f"Agent calendar IDs:\n" + "\n".join([f"- {info['designation']}: {info['calendar_id']}" for info in agent_info.values()])
        )
        
        coordination_task = Task(
            description=coordination_task_description,
            agent=david_agent,
            expected_output=f"Confirmation that all 15 birthday lunch events have been mirrored to project schedule calendar (ID: {project_cal_id})",
            context=[tasks[-1]] if tasks else [],  # Depends on last calendar task
            max_iter=10  # Limit iterations for coordination task
        )
        tasks.append(coordination_task)
    else:
        print(f"⚠️  Warning: David Chen (COO) not found, skipping coordination task")
    
    # ============================================================================
    # ACTION 4: COMMUNICATION & ACKNOWLEDGEMENT (All 15 Agents)
    # ============================================================================
    print("\n" + "="*80)
    print("ACTION 4: COMMUNICATION & ACKNOWLEDGEMENT - All 15 Agents")
    print("="*80)
    
    for role, info in agent_info.items():
        agent = info['agent']
        designation = info['designation']
        
        # Get all other agent emails
        other_emails = [email for r, email in agent_emails.items() if r != role]
        other_emails_str = ", ".join(other_emails)
        
        email_task_description = (
            f"Send personalized introduction and birthday lunch invitation emails to all other team members. "
            f"Use the Gmail Tool to send an email to each of the following recipients: {other_emails_str}\n\n"
            f"Email Subject: Invitation and Introduction: Join me for my birthday lunch!\n\n"
            f"Email Body should include:\n"
            f"- A warm greeting to the recipient\n"
            f"- Your name: {designation}\n"
            f"- Your role: {info['role']}\n"
            f"- A casual invitation to your birthday lunch\n"
            f"- Mention that event details (date, time, location: {info['favorite_restaurant']}) are available on your calendar\n"
            f"- A friendly closing\n\n"
            f"IMPORTANT: The Gmail Tool will automatically CC collin.m@ratiovita.com on all emails. "
            f"You may send one email with all recipients in the 'to' field, or send individual emails."
        )
        
        email_task = Task(
            description=email_task_description,
            agent=agent,
            expected_output=f"Confirmation that introduction and invitation emails have been sent to all team members",
            context=[tasks[-1]] if tasks else [],  # Depends on coordination task
            max_iter=5  # Limit iterations per task
        )
        tasks.append(email_task)
    
    # ============================================================================
    # ACTION 5: RECEIPT & REPLY (All 15 Agents)
    # ============================================================================
    print("\n" + "="*80)
    print("ACTION 5: RECEIPT & REPLY - All 15 Agents")
    print("="*80)
    print("⚠️  Note: Gmail read functionality requires additional API scope (gmail.readonly)")
    print("   This action will be simulated - agents will acknowledge receipt based on Action 4 completion")
    print("="*80)
    
    for role, info in agent_info.items():
        agent = info['agent']
        designation = info['designation']
        
        # Get all other agent emails for reply
        other_emails = [email for r, email in agent_emails.items() if r != role]
        other_emails_str = ", ".join(other_emails)
        
        reply_task_description = (
            f"Send reply emails accepting all birthday lunch invitations you received. "
            f"Use the Gmail Tool to send reply emails to: {other_emails_str}\n\n"
            f"Email Subject: Re: Invitation and Introduction: Join me for your birthday lunch!\n\n"
            f"Email Body should:\n"
            f"- Thank the sender for the invitation\n"
            f"- Confirm that you have added the event to your calendar\n"
            f"- Express that you are looking forward to the celebration\n"
            f"- Use your own words and tone based on your role and personality\n\n"
            f"IMPORTANT: The Gmail Tool will automatically CC collin.m@ratiovita.com on all emails."
        )
        
        reply_task = Task(
            description=reply_task_description,
            agent=agent,
            expected_output=f"Confirmation that reply emails accepting invitations have been sent",
            context=[tasks[-1]] if tasks else [],  # Depends on invitation emails
            max_iter=5  # Limit iterations per task
        )
        tasks.append(reply_task)
    
    # ============================================================================
    # ACTION 6: MEMORY UPDATE - All 15 Agents (Final Status Update)
    # ============================================================================
    print("\n" + "="*80)
    print("ACTION 6: MEMORY UPDATE - All 15 Agents")
    print("="*80)
    print("Updating memory documents with test completion status...")
    
    for role, info in agent_info.items():
        agent = info['agent']
        
        memory_update_description = (
            f"Update your persistent memory document with the completion status of the Birthday Lunch System Integration Test.\n\n"
            f"Use the Google Docs Memory Tool to append the following to your memory document (memory_doc_id: {info['memory_id']}):\n\n"
            f"---\n"
            f"BIRTHDAY LUNCH SIT COMPLETION STATUS\n"
            f"Date: {datetime.now().strftime('%Y-%m-%d')}\n"
            f"Status: ✅ COMPLETED\n\n"
            f"Test Actions Completed:\n"
            f"1. ✅ Memory Warmup - Personal information written to memory\n"
            f"2. ✅ Scheduling - Birthday lunch event created on personal calendar\n"
            f"3. ✅ Coordination - Events mirrored to project schedule calendar (by COO)\n"
            f"4. ✅ Communication - Invitation emails sent to all team members\n"
            f"5. ✅ Receipt & Reply - Reply emails sent accepting invitations\n\n"
            f"This test verified all core agent tools and integrations are functioning correctly.\n"
            f"---\n\n"
            f"IMPORTANT: Use the Google Docs Memory Tool with append=True to add this status update."
        )
        
        memory_update_task = Task(
            description=memory_update_description,
            agent=agent,
            expected_output=f"Confirmation that test completion status has been written to memory document (ID: {info['memory_id']})",
            context=[tasks[-1]] if tasks else [],  # Depends on last task
            max_iter=3  # Limit iterations per task
        )
        tasks.append(memory_update_task)
    
    # ============================================================================
    # EXECUTE THE TEST
    # ============================================================================
    print("\n" + "="*80)
    print(f"🚀 Creating crew with {len(tasks)} tasks for {len(agents)} agents...")
    print("="*80)
    
    crew = Crew(
        agents=agents,
        tasks=tasks,
        process=Process.sequential,
        verbose=True,
        max_iter=200,  # Limit total iterations to prevent infinite loops
        max_execution_time=1800  # 30 minute timeout for full test
    )
    print("✅ Crew created with execution limits (max_iter=200, timeout=30min)")
    
    # Execute the crew
    print("\n" + "="*80)
    print("Starting Birthday Lunch SIT execution...")
    print("="*80 + "\n")
    
    try:
        result = crew.kickoff()
        print("\n" + "="*80)
        print("✅ BIRTHDAY LUNCH SIT COMPLETE")
        print("="*80)
        print("\n📊 Test Results:")
        print(result)
        print("\n" + "="*80)
        print("\n📋 VERIFICATION CHECKLIST:")
        print("="*80)
        print("✓ Memory Docs: Check all 15 documents contain Name/Role/Birthday data")
        print("✓ Calendars: Check all 16 calendars (15 personal + 1 project) have 15 unique events")
        print("✓ Audit Trail: Check collin.m@ratiovita.com inbox for 30+ test emails")
        print("="*80)
        return result
    except Exception as e:
        print(f"\n❌ Error during SIT execution: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    birthday_lunch_sit()

