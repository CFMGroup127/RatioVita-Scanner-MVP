"""
Add CC: collin.m@ratiovita.com Protocol to All Agents
This script updates all agent protocols to require CC on all reports and replies.
"""
import yaml
from pathlib import Path

def add_cc_protocol():
    """
    Add CC: collin.m@ratiovita.com requirement to all agent protocols.
    """
    print("\n" + "="*80)
    print("📧 ADDING CC PROTOCOL TO ALL AGENTS")
    print("="*80)
    print("Requirement: All agents must CC collin.m@ratiovita.com on all reports and replies")
    print("="*80)
    
    agents_yaml = Path(__file__).parent / "agents.yaml"
    
    with open(agents_yaml, 'r') as f:
        data = yaml.safe_load(f)
    
    cc_protocol = """
      MANDATORY CC PROTOCOL: For ALL emails you send (reports, replies, acknowledgments, 
      communications), you MUST include collin.m@ratiovita.com in the CC field. This ensures 
      all communications are visible to project oversight. This applies to:
      - All report submissions to project.reports@ratiovita.com
      - All email replies and responses
      - All acknowledgment emails (P0 protocol)
      - All inter-agent communications (P6 protocol)
      - All meeting-related emails
      - Any other email communications
      The CC field must always include: collin.m@ratiovita.com
"""
    
    agents_updated = []
    
    print("\n📋 Updating agent protocols...")
    print("-" * 80)
    
    for agent in data.get('agents', []):
        role = agent.get('role', '')
        protocol = agent.get('protocol', '')
        
        # Check if CC protocol already exists
        if 'MANDATORY CC PROTOCOL' in protocol or 'collin.m@ratiovita.com' in protocol and 'CC' in protocol:
            print(f"✅ {role}: Already has CC protocol")
            continue
        
        # Add CC protocol before P0
        if 'P0: ASSIGNMENT ACKNOWLEDGMENT' in protocol:
            protocol = protocol.replace(
                'P0: ASSIGNMENT ACKNOWLEDGMENT',
                cc_protocol.strip() + '\n\n      P0: ASSIGNMENT ACKNOWLEDGMENT'
            )
            agent['protocol'] = protocol
            agents_updated.append(role)
            print(f"✅ {role}: Added CC protocol")
        else:
            # Add at end of protocol
            agent['protocol'] = protocol.rstrip() + cc_protocol
            agents_updated.append(role)
            print(f"✅ {role}: Added CC protocol")
    
    # Also update existing CC references to be more explicit
    print("\n📋 Verifying existing CC references...")
    print("-" * 80)
    
    for agent in data.get('agents', []):
        role = agent.get('role', '')
        protocol = agent.get('protocol', '')
        
        # Check if protocol mentions CC but not explicitly as mandatory
        if 'collin.m@ratiovita.com' in protocol and 'MANDATORY CC PROTOCOL' not in protocol:
            # Check if it's just in specific contexts (P0, MRAP, etc.)
            if 'CC: collin.m@ratiovita.com (MANDATORY)' in protocol:
                print(f"✅ {role}: Has explicit CC requirement in specific protocols")
            elif 'CC: collin.m@ratiovita.com' in protocol:
                print(f"⚠️  {role}: Has CC but may need universal mandate")
    
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
        print("✅ ALL AGENTS ALREADY HAVE CC PROTOCOL")
        print("="*80)
    
    print("\n" + "="*80)
    print("📊 SUMMARY")
    print("="*80)
    print(f"Total agents checked: {len(data.get('agents', []))}")
    print(f"Agents updated: {len(agents_updated)}")
    print(f"Agents already compliant: {len(data.get('agents', [])) - len(agents_updated)}")
    print("\n✅ All agents now have MANDATORY CC PROTOCOL!")
    print("   - All emails must CC: collin.m@ratiovita.com")
    print("   - Applies to reports, replies, acknowledgments, and all communications")
    
    return {
        'updated': agents_updated,
        'total': len(data.get('agents', []))
    }

if __name__ == "__main__":
    add_cc_protocol()


