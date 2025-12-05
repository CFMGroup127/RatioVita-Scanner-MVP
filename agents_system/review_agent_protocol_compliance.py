"""
Review Agent Protocol Compliance
This script reviews memory documents for all agents that had tasks assigned to confirm protocol compliance.
"""
import os
from datetime import datetime
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from main import load_agents_from_yaml, get_agent_metadata

def review_protocol_compliance():
    """
    Review memory documents for protocol compliance.
    """
    print("\n" + "="*80)
    print("📋 REVIEWING AGENT PROTOCOL COMPLIANCE")
    print("="*80)
    print(f"Review Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}")
    print("="*80)
    
    # Get credentials
    creds = None
    if os.path.exists('token.json'):
        creds = Credentials.from_authorized_user_file('token.json', [
            'https://www.googleapis.com/auth/documents.readonly'
        ])
        if not creds.valid:
            if creds.expired and creds.refresh_token:
                creds.refresh(Request())
    
    if not creds:
        print("❌ Could not get credentials")
        return None
    
    # Load agents
    agents = load_agents_from_yaml('agents.yaml')
    
    # Agents that had tasks assigned
    task_assigned_agents = {
        'Alice Kim': 'Documentation and Knowledge Archivist',
        'Samuel Reed': 'Competitive Intelligence Specialist',
        'Megan Parker': 'Market Strategist and Voice of the Customer',
        'Arthur Jensen': 'Legal Compliance and Risk Assessor',
        'Ash Roy': 'Technical and Product Visionary',
        'Dana Flores': 'Admin Assistant & Workflow Funnel',
        'David Chen': 'Process Architect and Schedule Publisher'
    }
    
    docs_service = build('docs', 'v1', credentials=creds)
    
    print(f"\n📋 Reviewing {len(task_assigned_agents)} agents with assigned tasks...")
    print("-" * 80)
    
    compliance_results = {}
    
    for name, role in task_assigned_agents.items():
        for agent in agents:
            if agent.role == role:
                agent_meta = get_agent_metadata(role)
                memory_doc_id = agent_meta.get('memory_doc_id', '')
                email = agent_meta.get('email_address', '')
                
                print(f"\n👤 {name} ({role})")
                print(f"   Email: {email}")
                print(f"   Memory Doc ID: {memory_doc_id[:50]}...")
                
                if not memory_doc_id:
                    print(f"   ❌ No memory document configured")
                    compliance_results[name] = {'error': 'No memory doc ID'}
                    continue
                
                try:
                    doc = docs_service.documents().get(documentId=memory_doc_id).execute()
                    content = doc.get('body', {}).get('content', [])
                    text_content = []
                    for element in content:
                        if 'paragraph' in element:
                            para = element['paragraph']
                            for text_elem in para.get('elements', []):
                                if 'textRun' in text_elem:
                                    text_content.append(text_elem['textRun'].get('content', ''))
                    full_text = ''.join(text_content)
                    
                    # Check protocols
                    protocol_checks = {
                        'P0 (Assignment Acknowledgment)': any(indicator in full_text for indicator in [
                            'P0', 'ASSIGNMENT ACKNOWLEDGMENT', 'Assignment Acknowledged', 'task receipt', 'acknowledged the assignment'
                        ]),
                        'P1 (Memory Audit First)': any(indicator in full_text for indicator in [
                            'P1', 'MEMORY AUDIT FIRST', 'Memory Audit', 'reviewed memory document'
                        ]),
                        'P2 (Task Logging)': any(indicator in full_text for indicator in [
                            'P2', 'TASK LOGGING', 'Task logged', 'task description', 'assignment source'
                        ]),
                        'P3 (Task Sign-Off)': any(indicator in full_text for indicator in [
                            'P3', 'TASK COMPLETE', 'VERIFIED BY AGENT', 'TASK SIGN-OFF', 'VERIFIED'
                        ]),
                        'P8 (Meeting Acceptance)': any(indicator in full_text for indicator in [
                            'P8', 'MEETING ACCEPTED', 'MEETING ACCEPTANCE', 'meeting invite', 'Executive Strategy Group Meeting'
                        ]),
                        'P12 (Corrective Acknowledgment)': any(indicator in full_text for indicator in [
                            'P12', 'CORRECTIVE ACKNOWLEDGMENT', 'audit mandate', 'BLOCK S'
                        ])
                    }
                    
                    compliance_results[name] = {
                        'doc_length': len(full_text),
                        'protocols': protocol_checks,
                        'has_content': len(full_text) > 100
                    }
                    
                    print(f"   Document length: {len(full_text)} characters")
                    print(f"   Has content: {'✅ Yes' if len(full_text) > 100 else '❌ No (blank or minimal)'}")
                    
                    print(f"\n   Protocol Compliance:")
                    for protocol, found in protocol_checks.items():
                        status = "✅" if found else "❌"
                        print(f"      {status} {protocol}")
                    
                    # Show recent activity
                    if len(full_text) > 0:
                        recent = full_text[-300:] if len(full_text) > 300 else full_text
                        print(f"\n   Recent activity (last 300 chars):")
                        print(f"      {recent.replace(chr(10), ' ')[:200]}...")
                    
                except Exception as e:
                    print(f"   ❌ Error reading memory: {e}")
                    compliance_results[name] = {'error': str(e)}
                
                break
    
    # Summary
    print("\n" + "="*80)
    print("📊 PROTOCOL COMPLIANCE SUMMARY")
    print("="*80)
    
    compliant_agents = []
    non_compliant_agents = []
    
    for name, result in compliance_results.items():
        if 'error' in result:
            non_compliant_agents.append((name, 'Error accessing memory'))
        elif not result.get('has_content', False):
            non_compliant_agents.append((name, 'Blank or minimal memory'))
        else:
            protocols = result.get('protocols', {})
            # Check if key protocols are present
            key_protocols = ['P0 (Assignment Acknowledgment)', 'P1 (Memory Audit First)', 'P2 (Task Logging)']
            has_key_protocols = any(protocols.get(p, False) for p in key_protocols)
            
            if has_key_protocols:
                compliant_agents.append(name)
            else:
                non_compliant_agents.append((name, 'Missing key protocols'))
    
    print(f"\n✅ Compliant Agents ({len(compliant_agents)}):")
    for name in compliant_agents:
        print(f"   - {name}")
    
    print(f"\n❌ Non-Compliant Agents ({len(non_compliant_agents)}):")
    for name, reason in non_compliant_agents:
        print(f"   - {name}: {reason}")
    
    print(f"\n📊 Overall Compliance: {len(compliant_agents)}/{len(task_assigned_agents)} agents compliant")
    
    if len(non_compliant_agents) > 0:
        print(f"\n⚠️  RECOMMENDATION: Re-run BLOCK S to trigger P12 for non-compliant agents")
    
    return compliance_results

if __name__ == "__main__":
    review_protocol_compliance()


