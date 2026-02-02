"""
Verify all agents' memory documents for recent updates.
This checks if agents properly documented their work.
"""
import os
from datetime import datetime
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build

# All agent memory document IDs
AGENT_MEMORIES = {
    "Dana Flores": "17yHhn9sTmLTR7zUwX0s37khkv6cMPdHNXYBUNPVuQdo",
    "David Chen": "1oRSQMOvK2lfv3MhfLD-O0fMbAJE-JQmQ0dg8DqeO_XY",
    "Alice Kim": "1flDFYht_YAdcVsTcInDdgV5KPZH1Hua6cGiVXMjwdKI",
    "Samuel Reed": "1qSLYiD280jK8-T1wn2RAIMle6Y8CeJ80I6ZYkPS9xXQ",
    "Arthur Jensen": "1I-9DE02e0ECkaa7WceP-93KG9NVfTKVUbpHhj8Ou5WQ",
    "Megan Parker": "1Gg6rP0bbtxj31snJgzAjcfFVJ-8GRVelMZ4Z7YOuQBc",
    "Ash Roy": "1tObaPs12zVYpUUMrsJMPN7JUqxUaR_MSvcxZ7D36tYs"
}

def read_memory_document(doc_id):
    """Read a memory document and return its content."""
    try:
        SCOPES = ['https://www.googleapis.com/auth/documents.readonly', 'https://www.googleapis.com/auth/drive.readonly']
        creds = Credentials.from_authorized_user_file('token.json', SCOPES)
        if not creds.valid:
            creds.refresh(Request())
        
        service = build('docs', 'v1', credentials=creds)
        doc = service.documents().get(documentId=doc_id).execute()
        
        content = []
        for element in doc.get('body', {}).get('content', []):
            if 'paragraph' in element:
                para_text = ''
                for para_element in element['paragraph'].get('elements', []):
                    if 'textRun' in para_element:
                        para_text += para_element['textRun'].get('content', '')
                if para_text.strip():
                    content.append(para_text)
        
        return '\n'.join(content) if content else "Document is empty."
    except Exception as e:
        return f"Error reading document: {str(e)}"

def check_agent_memory(agent_name, doc_id, expected_keywords):
    """Check an agent's memory for expected content."""
    print(f"\n📄 {agent_name}")
    print(f"   Doc ID: {doc_id[:30]}...")
    print("-" * 80)
    
    content = read_memory_document(doc_id)
    
    if "Error" in content:
        print(f"   ❌ {content}")
        return {"status": "error", "content": content}
    
    content_lower = content.lower()
    content_length = len(content)
    
    # Check for expected keywords
    found_keywords = []
    missing_keywords = []
    
    for keyword in expected_keywords:
        if keyword.lower() in content_lower:
            found_keywords.append(keyword)
        else:
            missing_keywords.append(keyword)
    
    # Check for recent dates (2025-11-15 or 2025-11-16)
    has_recent_date = '2025-11-15' in content or '2025-11-16' in content or 'november 15' in content_lower or 'november 16' in content_lower
    
    # Show last 300 characters
    last_300 = content[-300:] if content_length > 300 else content
    
    print(f"   📊 Document length: {content_length} characters")
    print(f"   📅 Recent date: {'✅' if has_recent_date else '❌'}")
    print(f"   ✅ Found keywords: {len(found_keywords)}/{len(expected_keywords)}")
    
    if found_keywords:
        print(f"      - {', '.join(found_keywords[:5])}")
    
    if missing_keywords:
        print(f"   ⚠️  Missing keywords: {', '.join(missing_keywords[:5])}")
    
    print(f"\n   Last 300 characters:")
    print(f"   {last_300}")
    
    return {
        "status": "complete" if len(found_keywords) == len(expected_keywords) else "incomplete",
        "length": content_length,
        "found": found_keywords,
        "missing": missing_keywords,
        "has_recent_date": has_recent_date
    }

def main():
    """Check all agent memories."""
    print("\n" + "="*80)
    print("🔍 VERIFYING ALL AGENT MEMORY DOCUMENTS")
    print("="*80)
    print(f"Verification Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("="*80)
    
    # Expected keywords for each agent
    expected_content = {
        "Dana Flores": ["delegation", "block", "coordination", "completed", "status"],
        "David Chen": ["report handoff", "november 21", "pre-read", "email", "completed"],
        "Alice Kim": ["v1 legacy", "archival", "final report", "block a", "summary"],
        "Samuel Reed": ["market", "competitive", "landscape", "v2 market"],
        "Arthur Jensen": ["design token", "v2 design", "block p", "completed"],
        "Megan Parker": ["branding", "value proposition", "v2 branding", "block p", "completed"],
        "Ash Roy": ["v2 technical", "baseline", "dependencies", "quarantine", "completed"]
    }
    
    results = {}
    
    for agent_name, doc_id in AGENT_MEMORIES.items():
        expected = expected_content.get(agent_name, [])
        result = check_agent_memory(agent_name, doc_id, expected)
        results[agent_name] = result
    
    # Summary
    print("\n" + "="*80)
    print("📊 VERIFICATION SUMMARY")
    print("="*80)
    
    complete = []
    incomplete = []
    errors = []
    
    for agent_name, result in results.items():
        if result["status"] == "error":
            errors.append(agent_name)
            print(f"  ❌ {agent_name}: Error - {result.get('content', 'Unknown error')[:50]}")
        elif result["status"] == "complete":
            complete.append(agent_name)
            print(f"  ✅ {agent_name}: Complete ({result['length']} chars, {len(result['found'])} keywords found)")
        else:
            incomplete.append(agent_name)
            missing = ', '.join(result['missing'][:3])
            print(f"  ⚠️  {agent_name}: Incomplete - Missing: {missing}")
    
    print("\n" + "="*80)
    print("📋 SUMMARY")
    print("="*80)
    print(f"✅ Complete: {len(complete)}/{len(results)}")
    print(f"⚠️  Incomplete: {len(incomplete)}/{len(results)}")
    print(f"❌ Errors: {len(errors)}/{len(results)}")
    
    if incomplete:
        print(f"\n⚠️  Agents needing memory updates:")
        for agent in incomplete:
            print(f"   - {agent}")
    
    print("="*80)
    
    return results

if __name__ == "__main__":
    main()



