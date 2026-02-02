"""
Implement P11 (Transcript Detail) for Dana and P12 (Corrective Acknowledgment) for all other agents
"""
import yaml
from pathlib import Path

def implement_p11_p12():
    """
    Add P11 to Dana and P12 to all other 14 agents (excluding Alice).
    """
    print("\n" + "="*80)
    print("📋 IMPLEMENTING P11 AND P12 PROTOCOLS")
    print("="*80)
    
    agents_yaml = Path(__file__).parent / "agents.yaml"
    
    with open(agents_yaml, 'r') as f:
        data = yaml.safe_load(f)
    
    # P11 for Dana
    p11_protocol = """
      P11: MANDATORY TRANSCRIPT DETAIL - The meeting transcript MUST be a comprehensive record that meets real-world 
      corporate standards. When writing meeting transcripts, you MUST include:
      - ATTENDEES: Must list all agents that executed the P8 'MEETING ACCEPTED' protocol, with their roles and 
        confirmation timestamps.
      - PRESENTATIONS: Must list which agents presented on their assigned objectives (e.g., "Alice Kim presented 
        V1 Legacy Review findings").
      - MEETING NOTES: Must include a minimum of five key discussion points, citing the agent who raised the point 
        or provided the data (e.g., "[Samuel Reed] provided data showing market saturation in the health tracking 
        sector...").
      - ACTION ITEMS: Must clearly link each action item to the specific agent assigned, the task description, 
        and its deadline (e.g., "Action Item: [Ash Roy] - Complete V2 technical baseline review by [Date]").
      This ensures the transcript serves as a complete, auditable record of the meeting.
"""
    
    # P12 for all other agents (excluding Alice)
    p12_protocol = """
      P12: CORRECTIVE ACKNOWLEDGMENT & AUDIT - Immediately upon activation, you MUST:
      1. Review all pending GMail for the audit mandate from Dana Flores (BLOCK S: System Audit & Control Refinement).
      2. If the audit mandate is found, immediately execute:
         - P0: Log the task receipt into your memory document with timestamp (Assignment Acknowledgment).
         - P1: Execute Memory Audit First - review your memory document to confirm context, protocols, and prior work.
         - P8: If a meeting invitation was received, log "MEETING ACCEPTED: [Meeting Title] - [Date/Time]" in your memory.
         - P3: If you are a reporting agent (Alice Kim, Samuel Reed, Megan Parker, Arthur Jensen, or Ash Roy), 
           immediately resubmit your report to project.reports@ratiovita.com with a 'VERIFIED' tag.
      3. If no audit mandate is found, log "P12: No pending audit mandate found - [Timestamp]" in your memory.
      This corrective protocol ensures all agents acknowledge and process the audit mandate, even if initial email 
      delivery failed.
"""
    
    dana_role = "Admin Assistant & Workflow Funnel"
    alice_role = "Documentation and Knowledge Archivist"
    
    agents_updated = []
    
    print("\n📋 Updating agent protocols...")
    print("-" * 80)
    
    for agent in data.get('agents', []):
        role = agent.get('role', '')
        protocol = agent.get('protocol', '')
        
        if role == dana_role:
            # Add P11 to Dana (after P9, before UNIVERSAL REPORTING CAPABILITY)
            if 'P11: MANDATORY TRANSCRIPT DETAIL' not in protocol:
                # Find P9 and add P11 after it
                if 'P9: MANDATORY TIME ZONE STANDARD' in protocol and 'UNIVERSAL REPORTING CAPABILITY' in protocol:
                    # Insert P11 between P9 and UNIVERSAL REPORTING CAPABILITY
                    protocol = protocol.replace(
                        'P9: MANDATORY TIME ZONE STANDARD - All time-sensitive actions, logging, note-taking, and scheduling must use \n      the **Eastern Standard Time (EST)** zone exclusively. All time stamps must reflect the local system clock\'s \n      date and time, converted to EST. When logging timestamps, always include "EST" to eliminate ambiguity. \n      This ensures consistency across the international team and prevents time zone interpretation errors.\n      \n      UNIVERSAL REPORTING CAPABILITY:',
                        'P9: MANDATORY TIME ZONE STANDARD - All time-sensitive actions, logging, note-taking, and scheduling must use \n      the **Eastern Standard Time (EST)** zone exclusively. All time stamps must reflect the local system clock\'s \n      date and time, converted to EST. When logging timestamps, always include "EST" to eliminate ambiguity. \n      This ensures consistency across the international team and prevents time zone interpretation errors.\n      \n' + p11_protocol.strip() + '\n      \n      UNIVERSAL REPORTING CAPABILITY:'
                    )
                    agent['protocol'] = protocol
                    agents_updated.append(role)
                    print(f"✅ {role}: Added P11 (Mandatory Transcript Detail)")
                else:
                    print(f"⚠️  {role}: Could not find insertion point for P11")
            else:
                print(f"✅ {role}: Already has P11 protocol")
        
        elif role != alice_role:
            # Add P12 to all other agents (excluding Alice)
            if 'P12: CORRECTIVE ACKNOWLEDGMENT & AUDIT' not in protocol:
                # Find P9 and add P12 after it
                if 'P9: MANDATORY TIME ZONE STANDARD' in protocol and 'UNIVERSAL REPORTING CAPABILITY' in protocol:
                    # Insert P12 between P9 and UNIVERSAL REPORTING CAPABILITY
                    protocol = protocol.replace(
                        'P9: MANDATORY TIME ZONE STANDARD - All time-sensitive actions, logging, note-taking, and scheduling must use \n      the **Eastern Standard Time (EST)** zone exclusively. All time stamps must reflect the local system clock\'s \n      date and time, converted to EST. When logging timestamps, always include "EST" to eliminate ambiguity. \n      This ensures consistency across the international team and prevents time zone interpretation errors.\n      \n      UNIVERSAL REPORTING CAPABILITY:',
                        'P9: MANDATORY TIME ZONE STANDARD - All time-sensitive actions, logging, note-taking, and scheduling must use \n      the **Eastern Standard Time (EST)** zone exclusively. All time stamps must reflect the local system clock\'s \n      date and time, converted to EST. When logging timestamps, always include "EST" to eliminate ambiguity. \n      This ensures consistency across the international team and prevents time zone interpretation errors.\n      \n' + p12_protocol.strip() + '\n      \n      UNIVERSAL REPORTING CAPABILITY:'
                    )
                    agent['protocol'] = protocol
                    agents_updated.append(role)
                    print(f"✅ {role}: Added P12 (Corrective Acknowledgment & Audit)")
                else:
                    print(f"⚠️  {role}: Could not find insertion point for P12")
            else:
                print(f"✅ {role}: Already has P12 protocol")
        else:
            print(f"⏭️  {role}: Skipped (Alice Kim - compliant, no P12 needed)")
    
    # Save if updates were made
    if agents_updated:
        print("\n" + "="*80)
        print("💾 SAVING UPDATES TO agents.yaml")
        print("="*80)
        
        with open(agents_yaml, 'w') as f:
            yaml.dump(data, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
        
        print(f"\n✅ Updated {len(agents_updated)} agent(s):")
        for role in agents_updated:
            print(f"   - {role}")
    else:
        print("\n" + "="*80)
        print("✅ ALL PROTOCOLS ALREADY IMPLEMENTED")
        print("="*80)
    
    print("\n" + "="*80)
    print("📊 SUMMARY")
    print("="*80)
    print(f"Total agents checked: {len(data.get('agents', []))}")
    print(f"Agents updated: {len(agents_updated)}")
    print(f"Dana (P11): {'✅ Added' if dana_role in agents_updated else '✅ Already present'}")
    print(f"Other agents (P12): {len([a for a in agents_updated if a != dana_role])} updated")
    print(f"Alice Kim: ⏭️  Skipped (compliant)")
    print("\n✅ P11 and P12 protocols successfully implemented!")
    
    return {
        'updated': agents_updated,
        'total': len(data.get('agents', []))
    }

if __name__ == "__main__":
    implement_p11_p12()


