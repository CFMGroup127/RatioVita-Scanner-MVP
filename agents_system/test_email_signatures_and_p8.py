"""
Test Email Signatures and Updated P8 Protocol
This script tests:
1. Email signatures with agent names and RatioVita logo
2. Memory logging of email confirmations
3. Calendar event creation in personal calendars
"""
import os
import sys
from datetime import datetime
from crewai import Agent, Task, Crew
from main import load_agents_from_yaml, get_agent_metadata

def test_agent_email_signature_and_p8(agent_role):
    """
    Test a single agent's email signature and P8 protocol execution.
    """
    print("\n" + "="*80)
    print(f"🧪 TESTING: {agent_role}")
    print("="*80)
    
    # Load agents
    agents = load_agents_from_yaml('agents.yaml')
    
    # Find the agent
    test_agent = None
    for agent in agents:
        if agent.role == agent_role:
            test_agent = agent
            break
    
    if not test_agent:
        print(f"❌ Agent not found: {agent_role}")
        return False
    
    # Get agent metadata
    agent_meta = get_agent_metadata(agent_role)
    agent_email = agent_meta.get('email_address', '')
    memory_doc_id = agent_meta.get('memory_doc_id', '')
    personal_calendar_id = agent_meta.get('personal_calendar_id', '')
    
    print(f"✅ Agent found: {agent_role}")
    print(f"   Email: {agent_email}")
    print(f"   Memory Doc ID: {memory_doc_id}")
    print(f"   Personal Calendar ID: {personal_calendar_id}")
    
    # Create test task
    task_description = f"""
**TEST TASK: Execute Updated P8 Protocol**

You are testing the updated P8 (Meeting Acceptance Acknowledgment) protocol. Execute ALL steps:

1. **LOG TO MEMORY**: Log to your memory document:
   "MEETING ACCEPTED: TEST - Executive Strategy Group Meeting - November 18, 2025 at 8:00 PM EST - 10:00 PM EST - {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}"

2. **ADD TO PERSONAL CALENDAR**: Use the Google Calendar Tool to add this test meeting to your personal calendar:
   - calendar_id: {personal_calendar_id}
   - action: 'create'
   - event_title: "TEST - Executive Strategy Group Meeting"
   - event_description: "Test meeting to verify P8 protocol execution"
   - start_time: "2025-11-18T20:00:00"
   - end_time: "2025-11-18T22:00:00"
   - location: "Virtual Meeting"

3. **EMAIL CONFIRMATION**: Use the GMailTool to send a test confirmation email:
   - To: david.chen@ratiovita.com, dana.flores@ratiovita.com
   - Subject: "TEST - Meeting Acceptance Confirmation: Executive Strategy Group Meeting"
   - Body: "This is a TEST email to verify the updated P8 protocol. I have received and accepted the calendar invitation for Executive Strategy Group Meeting scheduled for November 18, 2025 at 8:00 PM EST - 10:00 PM EST. I will attend the meeting as scheduled. [Your Name]"
   - Note: The Gmail Tool will automatically add your email signature with your name and RatioVita logo, and CC collin.m@ratiovita.com

4. **LOG EMAIL CONFIRMATION TO MEMORY**: After sending the email, log to your memory document:
   "EMAIL CONFIRMATION SENT: TEST - Meeting Acceptance Confirmation for Executive Strategy Group Meeting sent to David Chen and Dana Flores on {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}"

5. **VERIFY**: Confirm you see SUCCESS messages from both the Gmail Tool and Google Calendar Tool.

**This test verifies:**
- Email signatures are automatically added
- Memory logging works for both meeting acceptance and email confirmation
- Calendar events are added to personal calendars
"""
    
    task = Task(
        description=task_description,
        agent=test_agent,
        expected_output="All P8 protocol steps completed: memory logged, calendar event created, confirmation email sent with signature, and email confirmation logged to memory."
    )
    
    crew = Crew(
        agents=[test_agent],
        tasks=[task],
        verbose=True
    )
    
    print(f"\n🚀 Executing test task...")
    print("="*80)
    
    try:
        result = crew.kickoff()
        print("\n" + "="*80)
        print("✅ TEST COMPLETE")
        print("="*80)
        return True
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    """Main test function"""
    print("\n" + "="*80)
    print("🧪 TESTING EMAIL SIGNATURES AND UPDATED P8 PROTOCOL")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}")
    print("="*80)
    
    # Test with Alice Kim (Documentation and Knowledge Archivist)
    # She's typically reliable and has all tools
    test_agent = "Documentation and Knowledge Archivist"
    
    print(f"\n📋 Testing with: {test_agent}")
    print("   This will verify:")
    print("   1. Email signatures with agent name and RatioVita logo")
    print("   2. Memory logging of meeting acceptance")
    print("   3. Calendar event creation in personal calendar")
    print("   4. Memory logging of email confirmation")
    
    success = test_agent_email_signature_and_p8(test_agent)
    
    if success:
        print("\n" + "="*80)
        print("✅ TEST SUCCESSFUL")
        print("="*80)
        print("\n📝 Next Steps:")
        print("   1. Check Alice Kim's memory document for both log entries")
        print("   2. Check Alice Kim's personal calendar for the test event")
        print("   3. Check email inboxes (david.chen, dana.flores, collin.m) for test email with signature")
        print("="*80)
    else:
        print("\n" + "="*80)
        print("❌ TEST FAILED")
        print("="*80)
        print("   Check the error messages above for details")
        print("="*80)

if __name__ == "__main__":
    main()


