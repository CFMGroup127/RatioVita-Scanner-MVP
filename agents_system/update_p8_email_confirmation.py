"""
Update P8 Protocol to Require Email Confirmation
This script updates all agents' P8 protocol to require email confirmation to David and Dana.
"""
import yaml
import os

def update_p8_protocol():
    """
    Update P8 protocol for all agents to require email confirmation.
    """
    print("\n" + "="*80)
    print("📋 UPDATING P8 PROTOCOL - EMAIL CONFIRMATION REQUIREMENT")
    print("="*80)
    
    yaml_file = 'agents.yaml'
    
    # Read the YAML file
    with open(yaml_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Parse YAML
    with open(yaml_file, 'r', encoding='utf-8') as f:
        data = yaml.safe_load(f)
    
    # New P8 protocol text
    new_p8_text = """P8: MEETING ACCEPTANCE ACKNOWLEDGMENT - Upon receiving a meeting invite via GMail or Google Calendar, you MUST:
1. LOG TO MEMORY: Log the meeting title, date/time, and a confirmation of acceptance (e.g., "MEETING ACCEPTED: [Meeting Title] - [Date/Time]") into your memory document. This replaces the physical "Accept" button click and provides an auditable, timestamped record in your memory.
2. EMAIL CONFIRMATION: Immediately use the GMailTool to send a confirmation email to BOTH David Chen (david.chen@ratiovita.com) and Dana Flores (dana.flores@ratiovita.com) with:
   - To: david.chen@ratiovita.com, dana.flores@ratiovita.com
   - CC: collin.m@ratiovita.com (MANDATORY - automatically added by Gmail Tool)
   - Subject: "Meeting Acceptance Confirmation: [Meeting Title]"
   - Body: "I have received and accepted the calendar invitation for [Meeting Title] scheduled for [Date/Time EST]. I will attend the meeting as scheduled. [Your Name]"
3. VERIFY: Ensure you see a SUCCESS message from the Gmail Tool before proceeding.
This ensures both David (meeting organizer) and Dana (coordination) receive formal confirmation of attendance, and provides an auditable email trail separate from memory logs."""
    
    # Count updates
    updated_count = 0
    
    # Update each agent's protocol
    for agent in data.get('agents', []):
        if 'protocol' in agent:
            protocol = agent['protocol']
            
            # Check if P8 exists and needs updating
            if 'P8: MEETING ACCEPTANCE ACKNOWLEDGMENT' in protocol:
                # Check if it already has email confirmation requirement
                if 'EMAIL CONFIRMATION:' in protocol and 'david.chen@ratiovita.com' in protocol and 'dana.flores@ratiovita.com' in protocol:
                    print(f"✅ {agent.get('role', 'Unknown')}: P8 already has email confirmation requirement")
                else:
                    # Replace old P8 with new P8
                    import re
                    # Find and replace P8 section
                    p8_pattern = r'P8: MEETING ACCEPTANCE ACKNOWLEDGMENT[^\n]*(?:\n[^\n]*(?:MEETING ACCEPTED|Accept|memory)[^\n]*)*'
                    if re.search(p8_pattern, protocol):
                        # Replace the old P8 with new one
                        protocol = re.sub(
                            p8_pattern,
                            new_p8_text,
                            protocol,
                            flags=re.MULTILINE | re.DOTALL
                        )
                        agent['protocol'] = protocol
                        updated_count += 1
                        print(f"✅ Updated P8 for {agent.get('role', 'Unknown')}")
                    else:
                        print(f"⚠️  {agent.get('role', 'Unknown')}: P8 pattern not found")
    
    if updated_count > 0:
        # Write back to file
        with open(yaml_file, 'w', encoding='utf-8') as f:
            yaml.dump(data, f, default_flow_style=False, allow_unicode=True, sort_keys=False)
        
        print(f"\n✅ Successfully updated P8 protocol for {updated_count} agent(s)")
    else:
        print("\n⚠️  No agents needed P8 updates (may already be updated)")
    
    return updated_count

if __name__ == "__main__":
    update_p8_protocol()


