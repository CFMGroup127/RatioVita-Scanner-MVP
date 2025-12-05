"""
Agent Request to Join Group
This script allows agents to request membership in the all.15.team.members@ratiovita.com group.
It sends an email request to the group administrator.
"""
import os
import sys
from datetime import datetime
from crewai import Agent, Task, Crew
from main import load_agents_from_yaml, get_agent_metadata
import yaml

GROUP_EMAIL = "all.15.team.members@ratiovita.com"
ADMIN_EMAIL = "collin.m@ratiovita.com"  # Group administrator

def agent_request_group_join(agent_role=None):
    """
    Have an agent request to join the group.
    If agent_role is None, all agents will request to join.
    """
    print("\n" + "="*80)
    print("📧 AGENT REQUEST TO JOIN GROUP")
    print("="*80)
    print(f"Group: {GROUP_EMAIL}")
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}")
    print("="*80)
    
    # Load agents
    agents = load_agents_from_yaml('agents.yaml')
    
    if agent_role:
        # Single agent request
        target_agent = None
        for agent in agents:
            if agent.role == agent_role:
                target_agent = agent
                break
        
        if not target_agent:
            print(f"❌ Agent not found: {agent_role}")
            return False
        
        agents_to_process = [target_agent]
    else:
        # All agents request
        agents_to_process = agents
    
    print(f"\n👥 Processing {len(agents_to_process)} agent(s)...")
    
    results = []
    
    for agent in agents_to_process:
        agent_meta = get_agent_metadata(agent.role)
        agent_email = agent_meta.get('email_address', '')
        
        if not agent_email:
            print(f"⚠️  Skipping {agent.role} - no email address")
            continue
        
        print(f"\n📧 {agent.role}")
        print(f"   Email: {agent_email}")
        
        task_description = f"""
**TASK: Request Group Membership**

You need to request membership in the group {GROUP_EMAIL} so you can receive calendar invitations for team meetings.

**INSTRUCTIONS:**

1. **Send Request Email:**
   - Use the **GMailTool** to send an email
   - To: {ADMIN_EMAIL}
   - CC: collin.m@ratiovita.com (MANDATORY - automatically added by Gmail Tool)
   - Subject: "Request to Join Group: {GROUP_EMAIL}"
   - Body: 
     "Hello,
     
     I am requesting to join the group {GROUP_EMAIL} so I can receive calendar invitations for team meetings.
     
     My details:
     - Role: {agent.role}
     - Email: {agent_email}
     
     Please add me to the group at your earliest convenience.
     
     Thank you,
     {agent.role}"
   
2. **Log Request:**
   - Update your memory document to log this request
   - Note: "Requested membership in {GROUP_EMAIL} on [current date/time]"

**This ensures you can receive calendar invitations for team meetings.**
"""
        
        task = Task(
            description=task_description,
            agent=agent,
            expected_output=f"Email sent to {ADMIN_EMAIL} requesting membership in {GROUP_EMAIL}, and request logged in memory document."
        )
        
        crew = Crew(
            agents=[agent],
            tasks=[task],
            verbose=True
        )
        
        try:
            print(f"   🚀 Executing request...")
            result = crew.kickoff()
            results.append({
                'agent': agent.role,
                'email': agent_email,
                'success': True
            })
            print(f"   ✅ Request sent")
        except Exception as e:
            print(f"   ❌ Error: {e}")
            results.append({
                'agent': agent.role,
                'email': agent_email,
                'success': False,
                'error': str(e)
            })
    
    # Summary
    print("\n" + "="*80)
    print("📊 SUMMARY")
    print("="*80)
    
    successful = sum(1 for r in results if r.get('success', False))
    failed = len(results) - successful
    
    print(f"\n✅ Successful requests: {successful}/{len(results)}")
    print(f"❌ Failed requests: {failed}/{len(results)}")
    
    if successful > 0:
        print(f"\n📧 Request emails sent to: {ADMIN_EMAIL}")
        print(f"   The administrator will receive {successful} request(s) to add agents to the group.")
    
    if failed > 0:
        print(f"\n⚠️  Failed requests:")
        for r in results:
            if not r.get('success', False):
                print(f"   • {r['agent']}: {r.get('error', 'Unknown error')}")
    
    print("\n" + "="*80)
    print("✅ Request process complete")
    print("="*80)
    
    return successful > 0

def create_self_join_instructions():
    """
    Create instructions for agents to self-join the group (if group allows it).
    """
    print("\n" + "="*80)
    print("📋 SELF-JOIN INSTRUCTIONS")
    print("="*80)
    
    instructions = f"""
**HOW AGENTS CAN REQUEST TO JOIN THE GROUP**

If the group {GROUP_EMAIL} is configured to allow self-join requests, agents can:

**Option 1: Via Email (Recommended)**
1. Send an email to {GROUP_EMAIL}
2. Subject: "Request to Join"
3. Body: "Please add me to this group. My email: [agent email]"
4. The group administrator will receive the request

**Option 2: Via Google Groups (if group is a Google Group)**
1. Go to https://groups.google.com
2. Search for {GROUP_EMAIL}
3. Click "Ask to join group"
4. Wait for approval from group administrator

**Option 3: Automated Request (Using this script)**
Run: python3 agent_request_group_join.py [agent_role]
Or run without arguments to have all agents request membership.

**Note:** The group administrator ({ADMIN_EMAIL}) must approve and add members.
"""
    
    print(instructions)
    
    # Save to file
    with open('GROUP_JOIN_INSTRUCTIONS.md', 'w') as f:
        f.write(instructions)
    
    print(f"\n✅ Instructions saved to: GROUP_JOIN_INSTRUCTIONS.md")

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Agent request to join group')
    parser.add_argument('--agent', type=str, help='Specific agent role to request join')
    parser.add_argument('--instructions', action='store_true', help='Show self-join instructions')
    
    args = parser.parse_args()
    
    if args.instructions:
        create_self_join_instructions()
    else:
        agent_request_group_join(args.agent)

