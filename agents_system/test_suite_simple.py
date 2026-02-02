"""
Simplified Birthday Lunch Test - Tests with just 2 agents first to verify connectivity
This helps identify issues before running the full 15-agent test.
"""
import os
from datetime import datetime, timedelta
from crewai import Agent, Task, Crew, Process
from config import Config
from main import load_agents_from_yaml, get_agent_metadata

def get_next_weekday(date_str):
    """If the date falls on Saturday or Sunday, return the following Monday."""
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
    dt = datetime.combine(date_obj.date(), datetime.strptime(time_str, "%H:%M:%S").time())
    return dt.strftime("%Y-%m-%dT%H:%M:%S")

def simple_test():
    """
    Simple test with just 2 agents (Dana and Kyle) to verify tools work.
    """
    print("\n" + "="*80)
    print("🧪 SIMPLIFIED BIRTHDAY LUNCH TEST - 2 Agents Only")
    print("="*80)
    
    # Validate configuration
    try:
        Config.validate()
        print("✅ Configuration validated")
    except ValueError as e:
        print(f"❌ Configuration Error: {e}")
        return None
    
    os.environ['OPENAI_API_KEY'] = Config.OPENAI_API_KEY
    
    # Load agents
    print("\n📋 Loading agents...")
    try:
        agents = load_agents_from_yaml('agents.yaml')
        print(f"✅ Loaded {len(agents)} agents")
    except Exception as e:
        print(f"❌ Error loading agents: {e}")
        import traceback
        traceback.print_exc()
        return None
    
    # Get just Dana and Kyle
    test_agents = {}
    test_roles = [
        "Admin Assistant & Workflow Funnel",  # Dana
        "Visionary and Final Decision Maker"  # Kyle
    ]
    
    for agent in agents:
        if agent.role in test_roles:
            metadata = get_agent_metadata(agent.role)
            test_agents[agent.role] = {
                'agent': agent,
                'designation': metadata.get('designation', agent.role),
                'email': metadata.get('email_address', ''),
                'memory_id': metadata.get('memory_doc_id', ''),
                'calendar_id': metadata.get('personal_calendar_id', ''),
                'birth_date': metadata.get('birth_date', ''),
                'favorite_restaurant': metadata.get('favorite_restaurant', ''),
            }
    
    if len(test_agents) != 2:
        print(f"❌ Error: Expected 2 test agents, found {len(test_agents)}")
        return None
    
    print(f"\n✅ Testing with {len(test_agents)} agents:")
    for role, info in test_agents.items():
        print(f"   - {info['designation']} ({role})")
    
    tasks = []
    
    # Test 1: Memory write for Dana
    dana_role = "Admin Assistant & Workflow Funnel"
    dana_info = test_agents[dana_role]
    
    print("\n" + "="*80)
    print("TEST 1: Dana writes to memory document")
    print("="*80)
    
    dana_memory_task = Task(
        description=(
            f"Write your introduction to your persistent memory document. "
            f"Use the Google Docs Memory Tool with memory_doc_id: {dana_info['memory_id']}\n\n"
            f"Write exactly this:\n"
            f"Name: {dana_info['designation']}\n"
            f"Role: {dana_role}\n"
            f"Birth Date: {dana_info['birth_date']}\n"
            f"Favorite Restaurant: {dana_info['favorite_restaurant']}\n\n"
            f"IMPORTANT: Use the Google Docs Memory Tool. Do not use any other tool."
        ),
        agent=dana_info['agent'],
        expected_output="SUCCESS message confirming content written to memory document",
        max_iter=3  # Limit iterations to prevent loops
    )
    tasks.append(dana_memory_task)
    
    # Test 2: Calendar event for Dana
    print("\n" + "="*80)
    print("TEST 2: Dana creates calendar event")
    print("="*80)
    
    lunch_date = get_next_weekday(dana_info['birth_date'])
    start_time = format_datetime_for_calendar(lunch_date, "12:30:00")
    end_time = format_datetime_for_calendar(lunch_date, "14:00:00")
    
    dana_calendar_task = Task(
        description=(
            f"Create a birthday lunch calendar event. "
            f"Use the Google Calendar Tool with:\n"
            f"- calendar_id: {dana_info['calendar_id']}\n"
            f"- action: create\n"
            f"- event_title: Birthday Lunch: Celebrating {dana_info['designation']}\n"
            f"- event_description: Birthday celebration at {dana_info['favorite_restaurant']}\n"
            f"- start_time: {start_time}\n"
            f"- end_time: {end_time}\n\n"
            f"IMPORTANT: Use the Google Calendar Tool. Do not use any other tool."
        ),
        agent=dana_info['agent'],
        expected_output="SUCCESS message confirming event created",
        context=[dana_memory_task],
        max_iter=3
    )
    tasks.append(dana_calendar_task)
    
    # Test 3: Email from Dana to Kyle
    print("\n" + "="*80)
    print("TEST 3: Dana sends email to Kyle")
    print("="*80)
    
    kyle_role = "Visionary and Final Decision Maker"
    kyle_info = test_agents[kyle_role]
    
    dana_email_task = Task(
        description=(
            f"Send an email to {kyle_info['email']} using the Gmail Tool.\n\n"
            f"Subject: Test: Birthday Lunch Invitation\n\n"
            f"Body: Hi {kyle_info['designation']}, I'm inviting you to my birthday lunch at {dana_info['favorite_restaurant']}. "
            f"This is a test email.\n\n"
            f"IMPORTANT: Use the Gmail Tool. The tool will automatically CC collin.m@ratiovita.com."
        ),
        agent=dana_info['agent'],
        expected_output="SUCCESS message confirming email sent",
        context=[dana_calendar_task],
        max_iter=3
    )
    tasks.append(dana_email_task)
    
    # Create crew
    print("\n" + "="*80)
    print(f"🚀 Creating crew with {len(tasks)} test tasks...")
    print("="*80)
    
    crew = Crew(
        agents=[dana_info['agent'], kyle_info['agent']],
        tasks=tasks,
        process=Process.sequential,
        verbose=True,
        max_iter=15,  # Limit total iterations
        max_execution_time=300  # 5 minute timeout
    )
    
    print("✅ Crew created with execution limits")
    print("\n" + "="*80)
    print("Starting simplified test...")
    print("="*80 + "\n")
    
    try:
        result = crew.kickoff()
        print("\n" + "="*80)
        print("✅ SIMPLIFIED TEST COMPLETE")
        print("="*80)
        print("\n📊 Results:")
        print(result)
        print("\n" + "="*80)
        return result
    except Exception as e:
        print(f"\n❌ Error during test: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    simple_test()

