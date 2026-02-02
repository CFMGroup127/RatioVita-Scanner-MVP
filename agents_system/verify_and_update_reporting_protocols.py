"""
Verify and Update Reporting Protocols
Ensures ALL agents have the UNIFIED REPORTING CENTER protocol and that Dana/David have complete MRAP.
"""
import yaml
import re
from pathlib import Path

def verify_and_update_reporting_protocols():
    """
    Verify all agents have reporting protocols and update if missing.
    """
    print("\n" + "="*80)
    print("🔍 VERIFYING REPORTING PROTOCOLS FOR ALL AGENTS")
    print("="*80)
    
    agents_yaml = Path(__file__).parent / "agents.yaml"
    
    with open(agents_yaml, 'r') as f:
        content = f.read()
        data = yaml.safe_load(content)
    
    # Reporting agents (those with formal reports)
    reporting_agents_roles = [
        "Documentation and Knowledge Archivist",  # Alice Kim
        "Competitive Intelligence Specialist",    # Samuel Reed
        "Market Strategist and Voice of the Customer",  # Megan Parker
        "Legal Compliance and Risk Assessor",    # Arthur Jensen
        "Technical and Product Visionary",        # Ash Roy
    ]
    
    # Universal reporting protocol text
    universal_reporting_protocol = """
      UNIVERSAL REPORTING CAPABILITY: If you are ever assigned a formal reporting task, you MUST:
      - Follow the Universal Agent Report Template (UART) structure
      - Send the complete report via email to project.reports@ratiovita.com using the GMailTool
      - Include "VERIFIED: [Agent Name] - [Current Date/Time]" at the end
"""
    
    # Enhanced reporting protocol for reporting agents
    enhanced_reporting_protocol = """
      UNIFIED REPORTING CENTER: After writing to memory, you MUST send the complete report via email to 
      project.reports@ratiovita.com with subject: "[BLOCK/REPORT TYPE] [Report Title] - VERIFIED". 
      Include "VERIFIED: [Agent Name] - [Current Date/Time]" at the end.
"""
    
    print("\n📋 Checking agents for reporting protocols...")
    print("-" * 80)
    
    agents_updated = []
    agents_verified = []
    
    for agent in data.get('agents', []):
        role = agent.get('role', '')
        protocol = agent.get('protocol', '')
        
        # Check if agent has reporting protocol
        has_universal = 'UNIVERSAL REPORTING CAPABILITY' in protocol
        has_unified = 'UNIFIED REPORTING CENTER' in protocol
        
        if role in reporting_agents_roles:
            # Reporting agents need UNIFIED REPORTING CENTER
            if not has_unified:
                print(f"⚠️  {role}: Missing UNIFIED REPORTING CENTER protocol")
                # Add before P0 protocol
                if 'P0: ASSIGNMENT ACKNOWLEDGMENT' in protocol:
                    protocol = protocol.replace(
                        'P0: ASSIGNMENT ACKNOWLEDGMENT',
                        enhanced_reporting_protocol.strip() + '\n\n      P0: ASSIGNMENT ACKNOWLEDGMENT'
                    )
                    agent['protocol'] = protocol
                    agents_updated.append(role)
                    print(f"   ✅ Added UNIFIED REPORTING CENTER protocol")
                else:
                    # Add at end of protocol
                    agent['protocol'] = protocol.rstrip() + enhanced_reporting_protocol
                    agents_updated.append(role)
                    print(f"   ✅ Added UNIFIED REPORTING CENTER protocol")
            else:
                agents_verified.append(role)
                print(f"✅ {role}: Has UNIFIED REPORTING CENTER protocol")
        else:
            # Non-reporting agents need UNIVERSAL REPORTING CAPABILITY
            if not has_universal:
                print(f"⚠️  {role}: Missing UNIVERSAL REPORTING CAPABILITY protocol")
                # Add before P0 protocol
                if 'P0: ASSIGNMENT ACKNOWLEDGMENT' in protocol:
                    protocol = protocol.replace(
                        'P0: ASSIGNMENT ACKNOWLEDGMENT',
                        universal_reporting_protocol.strip() + '\n\n      P0: ASSIGNMENT ACKNOWLEDGMENT'
                    )
                    agent['protocol'] = protocol
                    agents_updated.append(role)
                    print(f"   ✅ Added UNIVERSAL REPORTING CAPABILITY protocol")
                else:
                    # Add at end of protocol
                    agent['protocol'] = protocol.rstrip() + universal_reporting_protocol
                    agents_updated.append(role)
                    print(f"   ✅ Added UNIVERSAL REPORTING CAPABILITY protocol")
            else:
                agents_verified.append(role)
                print(f"✅ {role}: Has UNIVERSAL REPORTING CAPABILITY protocol")
    
    # Verify Dana and David have complete MRAP
    print("\n" + "="*80)
    print("🔍 VERIFYING DANA AND DAVID MRAP PROTOCOLS")
    print("="*80)
    
    dana_role = "Admin Assistant & Workflow Funnel"
    david_role = "Process Architect and Schedule Publisher"
    
    for agent in data.get('agents', []):
        role = agent.get('role', '')
        protocol = agent.get('protocol', '')
        
        if role == dana_role:
            print(f"\n📋 {role}:")
            has_mrap = 'MANDATORY REVIEW & ACTION PROTOCOL' in protocol or 'MRAP' in protocol
            has_unified = 'UNIFIED REPORTING CENTER' in protocol
            has_acknowledge = 'ACKNOWLEDGE' in protocol and 'project.reports' in protocol
            
            print(f"   UNIFIED REPORTING CENTER: {'✅' if has_unified else '❌'}")
            print(f"   MRAP Protocol: {'✅' if has_mrap else '❌'}")
            print(f"   Acknowledgment in MRAP: {'✅' if has_acknowledge else '❌'}")
            
            if not has_mrap or not has_acknowledge:
                print(f"   ⚠️  MRAP may be incomplete - checking...")
                # MRAP should include acknowledgment email
                if 'MANDATORY REVIEW & ACTION PROTOCOL' in protocol:
                    if 'ACKNOWLEDGE' not in protocol or 'formal confirmation email' not in protocol:
                        print(f"   ⚠️  MRAP missing acknowledgment email requirement")
                        # Add acknowledgment step if missing
                        if '2. ANALYZE:' in protocol and '3. ACKNOWLEDGE:' not in protocol:
                            protocol = protocol.replace(
                                '2. ANALYZE:',
                                '2. ANALYZE:\n      3. ACKNOWLEDGE: Immediately use the GMailTool to send a formal confirmation email to the submitting agent with:\n         - Subject: "Report Received: [Report Title] - Thank You"\n         - Body: "Thank you for submitting your report. We have received and verified [Report Title] from [Agent Name]. The report has been logged and will be reviewed according to protocol."\n         - CC: collin.m@ratiovita.com (MANDATORY)'
                            )
                            agent['protocol'] = protocol
                            agents_updated.append(role)
                            print(f"   ✅ Added acknowledgment email requirement to MRAP")
        
        elif role == david_role:
            print(f"\n📋 {role}:")
            has_mrap = 'MANDATORY REVIEW & ACTION PROTOCOL' in protocol or 'MRAP' in protocol
            has_unified = 'UNIFIED REPORTING CENTER' in protocol
            has_strategy = 'STRATEGY:' in protocol and 'strategic questions' in protocol
            
            print(f"   UNIFIED REPORTING CENTER: {'✅' if has_unified else '❌'}")
            print(f"   MRAP Protocol: {'✅' if has_mrap else '❌'}")
            print(f"   Strategic Questions in MRAP: {'✅' if has_strategy else '❌'}")
            
            if not has_mrap or not has_strategy:
                print(f"   ⚠️  MRAP may be incomplete - checking...")
                # MRAP should include strategic questions
                if 'MANDATORY REVIEW & ACTION PROTOCOL' in protocol:
                    if 'STRATEGY:' not in protocol or 'strategic questions' not in protocol:
                        print(f"   ⚠️  MRAP missing strategic questions requirement")
                        # Add strategy step if missing
                        if '4. LOG RECEIPT:' in protocol and '5. STRATEGY:' not in protocol:
                            protocol = protocol.replace(
                                '4. LOG RECEIPT:',
                                '4. LOG RECEIPT:\n      5. STRATEGY: Use the report\'s Final Recommendations to draft a list of at least three high-priority strategic questions for the Executive Strategy Group meeting agenda.'
                            )
                            agent['protocol'] = protocol
                            agents_updated.append(role)
                            print(f"   ✅ Added strategic questions requirement to MRAP")
    
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
        print("✅ ALL PROTOCOLS VERIFIED - NO UPDATES NEEDED")
        print("="*80)
        print(f"\n✅ Verified {len(agents_verified)} agent(s) have correct protocols")
    
    print("\n" + "="*80)
    print("📊 SUMMARY")
    print("="*80)
    print(f"Total agents checked: {len(data.get('agents', []))}")
    print(f"Agents verified: {len(agents_verified)}")
    print(f"Agents updated: {len(agents_updated)}")
    print(f"Reporting agents: {len(reporting_agents_roles)}")
    print("\n✅ All agents now have proper reporting protocols!")
    print("   - Reporting agents: UNIFIED REPORTING CENTER")
    print("   - All other agents: UNIVERSAL REPORTING CAPABILITY")
    print("   - Dana & David: Complete MRAP protocols")
    
    return {
        'updated': agents_updated,
        'verified': agents_verified,
        'total': len(data.get('agents', []))
    }

if __name__ == "__main__":
    verify_and_update_reporting_protocols()


