"""
Update P8 Protocol for All Agents
This script updates the P8 (Meeting Acceptance Acknowledgment) protocol for all agents
to ensure they:
1. Log email confirmations to memory
2. Add events to their personal calendars
"""
import yaml
import re

def update_p8_protocol():
    """Update P8 protocol in agents.yaml"""
    print("\n" + "="*80)
    print("📝 UPDATING P8 PROTOCOL FOR ALL AGENTS")
    print("="*80)
    
    # Read agents.yaml
    with open('agents.yaml', 'r') as f:
        content = f.read()
        data = yaml.safe_load(content)
    
    # New P8 protocol text (with escaped newlines for YAML)
    new_p8_protocol = """P8: MEETING ACCEPTANCE ACKNOWLEDGMENT - Upon receiving a meeting invite via GMail or Google Calendar, you MUST:\n1. LOG TO MEMORY: Log the meeting title, date/time, and a confirmation of acceptance (e.g., \"MEETING ACCEPTED: [Meeting Title] - [Date/Time]\") into your memory document. This replaces the physical \"Accept\" button click and provides an auditable, timestamped record in your memory.\n2. ADD TO PERSONAL CALENDAR: Use the Google Calendar Tool to add the meeting event to your personal calendar (use your personal_calendar_id). This ensures the meeting appears on your calendar and you receive notifications.\n3. EMAIL CONFIRMATION: Immediately use the GMailTool to send a confirmation email to BOTH David Chen (david.chen@ratiovita.com) and Dana Flores (dana.flores@ratiovita.com) with:\n   - To: david.chen@ratiovita.com, dana.flores@ratiovita.com\n   - CC: collin.m@ratiovita.com (MANDATORY - automatically added by Gmail Tool)\n   - Subject: \"Meeting Acceptance Confirmation: [Meeting Title]\"\n   - Body: \"I have received and accepted the calendar invitation for [Meeting Title] scheduled for [Date/Time EST]. I will attend the meeting as scheduled. [Your Name]\"\n4. LOG EMAIL CONFIRMATION TO MEMORY: After sending the confirmation email, immediately log to your memory document: \"EMAIL CONFIRMATION SENT: Meeting Acceptance Confirmation for [Meeting Title] sent to David Chen and Dana Flores on [Date/Time EST]\"\n5. VERIFY: Ensure you see a SUCCESS message from both the Gmail Tool and Google Calendar Tool before proceeding.\nThis ensures both David (meeting organizer) and Dana (coordination) receive formal confirmation of attendance, the meeting is on your personal calendar, and provides an auditable email trail separate from memory logs."""
    
    # Update each agent's protocol
    updated_count = 0
    for agent in data.get('agents', []):
        protocol = agent.get('protocol', '')
        role = agent.get('role', 'Unknown')
        
        # Find and replace P8 protocol
        # Pattern to match P8 protocol (from P8: to P9: or end of protocol section)
        # Handle escaped newlines
        p8_pattern = r'P8: MEETING ACCEPTANCE ACKNOWLEDGMENT\\n[^P]*(?=P9:|P10:|P11:|P12:|$)'
        
        if 'P8: MEETING ACCEPTANCE ACKNOWLEDGMENT' in protocol:
            # Replace existing P8 - find the section and replace it
            # Match from P8: to just before P9: (or end)
            old_p8_match = re.search(r'(P8: MEETING ACCEPTANCE ACKNOWLEDGMENT\\n[^P]*(?=P9:|P10:|P11:|P12:|$))', protocol, re.DOTALL)
            if old_p8_match:
                protocol = protocol.replace(old_p8_match.group(1), new_p8_protocol + '\\n')
                agent['protocol'] = protocol
                updated_count += 1
                print(f"✅ Updated P8 for: {role}")
            else:
                # Try a simpler replacement
                if 'P8: MEETING ACCEPTANCE ACKNOWLEDGMENT' in protocol and '2. EMAIL CONFIRMATION:' in protocol:
                    # Find the section between P8: and P9:
                    parts = protocol.split('P8: MEETING ACCEPTANCE ACKNOWLEDGMENT')
                    if len(parts) > 1:
                        remaining = parts[1]
                        # Find where P9: starts
                        p9_index = remaining.find('P9:')
                        if p9_index > 0:
                            # Replace the P8 section
                            protocol = parts[0] + 'P8: MEETING ACCEPTANCE ACKNOWLEDGMENT' + new_p8_protocol + '\\n' + remaining[p9_index:]
                            agent['protocol'] = protocol
                            updated_count += 1
                            print(f"✅ Updated P8 for: {role}")
                        else:
                            print(f"⚠️  Could not find P9: boundary for: {role}")
                    else:
                        print(f"⚠️  Could not split P8 for: {role}")
                else:
                    print(f"⚠️  P8 format not recognized for: {role}")
        else:
            print(f"⚠️  P8 not found for: {role}")
    
    # Write back to file
    with open('agents.yaml', 'w') as f:
        yaml.dump(data, f, default_flow_style=False, allow_unicode=True, sort_keys=False)
    
    print(f"\n✅ Updated P8 protocol for {updated_count} agents")
    print("="*80)
    return updated_count

if __name__ == "__main__":
    update_p8_protocol()

