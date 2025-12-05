"""
Fix P11 and P12 Implementation - Handle YAML escaped newlines properly
"""
import re

def fix_p11_p12():
    """
    Add P11 to Dana and P12 to all other agents (excluding Alice) in the YAML file.
    """
    print("\n" + "="*80)
    print("📋 FIXING P11 AND P12 PROTOCOL IMPLEMENTATION")
    print("="*80)
    
    with open('agents.yaml', 'r') as f:
        content = f.read()
    
    # P11 text (with escaped newlines for YAML)
    p11_text = "\\n\\nP11: MANDATORY TRANSCRIPT DETAIL - The meeting transcript MUST be a comprehensive record that meets real-world corporate standards. When writing meeting transcripts, you MUST include:\\n      - ATTENDEES: Must list all agents that executed the P8 'MEETING ACCEPTED' protocol, with their roles and confirmation timestamps.\\n      - PRESENTATIONS: Must list which agents presented on their assigned objectives (e.g., \\\"Alice Kim presented V1 Legacy Review findings\\\").\\n      - MEETING NOTES: Must include a minimum of five key discussion points, citing the agent who raised the point or provided the data (e.g., \\\"[Samuel Reed] provided data showing market saturation in the health tracking sector...\\\").\\n      - ACTION ITEMS: Must clearly link each action item to the specific agent assigned, the task description, and its deadline (e.g., \\\"Action Item: [Ash Roy] - Complete V2 technical baseline review by [Date]\\\").\\n      This ensures the transcript serves as a complete, auditable record of the meeting.\\n"
    
    # P12 text (with escaped newlines for YAML)
    p12_text = "\\n\\nP12: CORRECTIVE ACKNOWLEDGMENT & AUDIT - Immediately upon activation, you MUST:\\n      1. Review all pending GMail for the audit mandate from Dana Flores (BLOCK S: System Audit & Control Refinement).\\n      2. If the audit mandate is found, immediately execute:\\n         - P0: Log the task receipt into your memory document with timestamp (Assignment Acknowledgment).\\n         - P1: Execute Memory Audit First - review your memory document to confirm context, protocols, and prior work.\\n         - P8: If a meeting invitation was received, log \\\"MEETING ACCEPTED: [Meeting Title] - [Date/Time]\\\" in your memory.\\n         - P3: If you are a reporting agent (Alice Kim, Samuel Reed, Megan Parker, Arthur Jensen, or Ash Roy), immediately resubmit your report to project.reports@ratiovita.com with a 'VERIFIED' tag.\\n      3. If no audit mandate is found, log \\\"P12: No pending audit mandate found - [Timestamp]\\\" in your memory.\\n      This corrective protocol ensures all agents acknowledge and process the audit mandate, even if initial email delivery failed.\\n"
    
    # Add P11 to Dana (Admin Assistant & Workflow Funnel)
    # Find the pattern: P9...UNIVERSAL REPORTING CAPABILITY in Dana's section
    dana_pattern = r'(role: Admin Assistant & Workflow Funnel[^\"]*P9: MANDATORY TIME ZONE STANDARD[^\"]*time zone interpretation errors\.)\\n\\nUNIVERSAL REPORTING CAPABILITY'
    
    if re.search(dana_pattern, content):
        content = re.sub(
            dana_pattern,
            r'\1' + p11_text + 'UNIVERSAL REPORTING CAPABILITY',
            content,
            flags=re.DOTALL
        )
        print("✅ Added P11 to Dana Flores (Admin Assistant & Workflow Funnel)")
    else:
        print("⚠️  Could not find insertion point for P11 in Dana's protocol")
    
    # Add P12 to all agents except Alice (Documentation and Knowledge Archivist)
    # List of agent roles to update (excluding Alice)
    roles_to_update = [
        "Visionary and Final Decision Maker",
        "Process Architect and Schedule Publisher",
        "Technical and Product Visionary",
        "Financial Guardian and Strategy Modeler",
        "Market Strategist and Voice of the Customer",
        "Legal Compliance and Risk Assessor",
        "Lead Code Execution and V2 Development",
        "Process and Factual Integrity Auditor",
        "Competitive Intelligence Specialist",
        "Go-to-Market Strategy",
        "Budget and Conflict Guardrail",
        "Collateral Support and Lead Qualification",
        "External Communication and Trust Builder"
    ]
    
    updated_count = 0
    for role in roles_to_update:
        # Escape special characters in role name for regex
        role_escaped = re.escape(role)
        pattern = rf'(role: {role_escaped}[^"]*P9: MANDATORY TIME ZONE STANDARD[^"]*time zone interpretation errors\.)\\n\\nUNIVERSAL REPORTING CAPABILITY'
        
        if re.search(pattern, content):
            content = re.sub(
                pattern,
                r'\1' + p12_text + 'UNIVERSAL REPORTING CAPABILITY',
                content,
                flags=re.DOTALL
            )
            updated_count += 1
            print(f"✅ Added P12 to {role}")
        else:
            print(f"⚠️  Could not find insertion point for P12 in {role}")
    
    # Save the updated content
    with open('agents.yaml', 'w') as f:
        f.write(content)
    
    print("\n" + "="*80)
    print("📊 SUMMARY")
    print("="*80)
    print(f"P11 added: 1 (Dana Flores)")
    print(f"P12 added: {updated_count} agents")
    print(f"Total agents updated: {updated_count + 1}")
    print("\n✅ Protocols successfully implemented!")
    
    return updated_count + 1

if __name__ == "__main__":
    fix_p11_p12()


