"""
Verify Protocol Execution - Comprehensive Check
Reads all agent memory documents and verifies P8, P3, and MRAP protocol execution.
"""
import os
import yaml
from datetime import datetime
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build

def get_credentials():
    """Get valid user credentials."""
    creds = None
    if os.path.exists('token.json'):
        creds = Credentials.from_authorized_user_file('token.json', ['https://www.googleapis.com/auth/documents.readonly'])
        if not creds.valid:
            if creds.expired and creds.refresh_token:
                creds.refresh(Request())
    return creds

def read_google_doc(doc_id, creds):
    """Read content from a Google Doc."""
    try:
        service = build('docs', 'v1', credentials=creds)
        doc = service.documents().get(documentId=doc_id).execute()
        content = doc.get('body', {}).get('content', [])
        text_content = []
        for element in content:
            if 'paragraph' in element:
                para = element['paragraph']
                for text_elem in para.get('elements', []):
                    if 'textRun' in text_elem:
                        text_content.append(text_elem['textRun'].get('content', ''))
        return ''.join(text_content)
    except Exception as e:
        return f"Error: {e}"

def verify_protocol_execution():
    """
    Verify protocol execution across all agents.
    """
    print("\n" + "="*80)
    print("🔍 COMPREHENSIVE PROTOCOL EXECUTION VERIFICATION")
    print("="*80)
    print(f"Verification Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}")
    print("="*80)
    
    creds = get_credentials()
    if not creds:
        print("❌ Could not get credentials")
        return None
    
    # Read agents.yaml
    with open('agents.yaml', 'r') as f:
        data = yaml.safe_load(f)
    
    # Define agent categories
    reporting_agents = {
        'Alice Kim': 'Documentation and Knowledge Archivist',
        'Samuel Reed': 'Competitive Intelligence Specialist',
        'Megan Parker': 'Market Strategist and Voice of the Customer',
        'Arthur Jensen': 'Legal Compliance and Risk Assessor',
        'Ash Roy': 'Technical and Product Visionary'
    }
    
    coordinators = {
        'Dana Flores': 'Admin Assistant & Workflow Funnel',
        'David Chen': 'Process Architect and Schedule Publisher'
    }
    
    all_agents = {**reporting_agents, **coordinators}
    
    results = {}
    
    print("\n📋 VERIFYING AGENT MEMORY DOCUMENTS")
    print("="*80)
    
    for name, role in all_agents.items():
        for agent in data.get('agents', []):
            if agent.get('role') == role:
                doc_id = agent.get('memory_doc_id', '')
                email = agent.get('email_address', '')
                
                if not doc_id:
                    results[name] = {'error': 'No memory doc ID'}
                    continue
                
                print(f"\n👤 {name} ({role})")
                print(f"   Email: {email}")
                print(f"   Doc ID: {doc_id}")
                
                memory = read_google_doc(doc_id, creds)
                
                if "Error:" in memory:
                    results[name] = {'error': memory}
                    print(f"   ❌ {memory}")
                    continue
                
                # Check protocols
                protocol_checks = {
                    'P8 (Meeting Acceptance)': any(indicator in memory for indicator in [
                        'MEETING ACCEPTED', 'P8', '9:15 PM EST', '9:15 PM', 
                        'Executive Strategy Group Meeting - November 17, 2025'
                    ]),
                    'P3 (Report Submission)' if name in reporting_agents else 'N/A': 
                        any(indicator in memory for indicator in [
                            'P3', 'TASK COMPLETE', 'VERIFIED', 'project.reports', 
                            'REPORT SUBMISSION', 'UNIFIED REPORTING'
                        ]) if name in reporting_agents else None,
                    'MRAP (Report Review)' if name in coordinators else 'N/A':
                        any(indicator in memory for indicator in [
                            'MRAP', 'REPORT RECEIPT', 'report received', 
                            'strategic questions', 'ACKNOWLEDGE'
                        ]) if name in coordinators else None
                }
                
                results[name] = {
                    'doc_length': len(memory),
                    'protocols': protocol_checks,
                    'recent_activity': memory[-300:] if len(memory) > 300 else memory
                }
                
                print(f"   Document length: {len(memory)} characters")
                for protocol, found in protocol_checks.items():
                    if protocol != 'N/A' and found is not None:
                        status = "✅ FOUND" if found else "❌ NOT FOUND"
                        print(f"   {protocol}: {status}")
                
                break
    
    # Summary
    print("\n" + "="*80)
    print("📊 PROTOCOL EXECUTION SUMMARY")
    print("="*80)
    
    print("\n📧 REPORTING AGENTS (P8 + P3):")
    print("-" * 80)
    for name in reporting_agents.keys():
        if name in results and 'error' not in results[name]:
            p8 = results[name]['protocols'].get('P8 (Meeting Acceptance)', False)
            p3 = results[name]['protocols'].get('P3 (Report Submission)', False)
            status_p8 = "✅" if p8 else "❌"
            status_p3 = "✅" if p3 else "❌"
            print(f"  {status_p8} P8  {status_p3} P3  {name}")
        else:
            print(f"  ❌ ERROR  {name}")
    
    print("\n👥 COORDINATORS (P8 + MRAP):")
    print("-" * 80)
    for name in coordinators.keys():
        if name in results and 'error' not in results[name]:
            p8 = results[name]['protocols'].get('P8 (Meeting Acceptance)', False)
            mrap = results[name]['protocols'].get('MRAP (Report Review)', False)
            status_p8 = "✅" if p8 else "❌"
            status_mrap = "✅" if mrap else "❌"
            print(f"  {status_p8} P8  {status_mrap} MRAP  {name}")
        else:
            print(f"  ❌ ERROR  {name}")
    
    # Overall status
    print("\n" + "="*80)
    print("🎯 OVERALL STATUS")
    print("="*80)
    
    total_agents = len(all_agents)
    p8_count = sum(1 for name in all_agents.keys() 
                   if name in results and 'error' not in results[name] 
                   and results[name]['protocols'].get('P8 (Meeting Acceptance)', False))
    p3_count = sum(1 for name in reporting_agents.keys() 
                   if name in results and 'error' not in results[name] 
                   and results[name]['protocols'].get('P3 (Report Submission)', False))
    mrap_count = sum(1 for name in coordinators.keys() 
                    if name in results and 'error' not in results[name] 
                    and results[name]['protocols'].get('MRAP (Report Review)', False))
    
    print(f"\nTotal agents checked: {total_agents}")
    print(f"P8 (Meeting Acceptance): {p8_count}/{total_agents} agents")
    print(f"P3 (Report Submission): {p3_count}/{len(reporting_agents)} reporting agents")
    print(f"MRAP (Report Review): {mrap_count}/{len(coordinators)} coordinators")
    
    if p8_count == total_agents and p3_count == len(reporting_agents) and mrap_count == len(coordinators):
        print("\n✅ ALL PROTOCOLS EXECUTED SUCCESSFULLY!")
    else:
        print("\n⚠️  SOME PROTOCOLS NOT YET EXECUTED")
        print("   This is normal if:")
        print("   - Meeting just started or agents are still processing")
        print("   - Reports are still being generated")
        print("   - Agents are working through their protocols")
    
    return results

if __name__ == "__main__":
    verify_protocol_execution()


