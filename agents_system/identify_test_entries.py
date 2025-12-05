"""
Helper script to identify test entries in memory documents.
This helps you quickly find and clean up test data.
"""
import os
import yaml
from tools import get_google_docs_read_tool

def identify_test_entries():
    """
    Read all agent memory documents and identify test entries.
    """
    print("\n" + "="*80)
    print("🔍 IDENTIFYING TEST ENTRIES IN MEMORY DOCUMENTS")
    print("="*80)
    
    # Load agents
    try:
        with open('agents.yaml', 'r') as f:
            agents_data = yaml.safe_load(f)
        agents = agents_data.get('agents', [])
        print(f"✅ Loaded {len(agents)} agents")
    except Exception as e:
        print(f"❌ Error loading agents: {e}")
        return
    
    # Get read tool
    try:
        read_tool = get_google_docs_read_tool()
    except Exception as e:
        print(f"❌ Error loading read tool: {e}")
        return
    
    # Test keywords to identify test entries
    test_keywords = [
        "Birthday Lunch System Integration Test",
        "Birth Date:",
        "Favorite Restaurant:",
        "Birthday Lunch: Celebrating",
        "SIT",  # System Integration Test
    ]
    
    print("\n📋 Scanning memory documents for test entries...")
    print("="*80)
    
    results = {}
    
    for agent in agents:
        role = agent.get('role', 'Unknown')
        designation = agent.get('designation', role)
        memory_id = agent.get('memory_doc_id', '')
        
        if not memory_id:
            print(f"⚠️  {designation}: No memory_doc_id found")
            continue
        
        try:
            # Read the memory document
            content = read_tool.invoke({'doc_id': memory_id})
            
            if content.startswith('ERROR'):
                print(f"❌ {designation}: {content}")
                continue
            
            # Check for test keywords
            test_lines = []
            lines = content.split('\n')
            for i, line in enumerate(lines, 1):
                for keyword in test_keywords:
                    if keyword.lower() in line.lower():
                        test_lines.append((i, line.strip()))
                        break
            
            if test_lines:
                results[designation] = {
                    'memory_id': memory_id,
                    'test_lines': test_lines,
                    'total_lines': len(lines)
                }
                print(f"✅ {designation}: Found {len(test_lines)} potential test entry lines")
            else:
                print(f"✅ {designation}: No test entries found (clean)")
        
        except Exception as e:
            print(f"❌ {designation}: Error reading memory - {e}")
    
    # Print summary
    print("\n" + "="*80)
    print("📊 SUMMARY")
    print("="*80)
    
    if results:
        print(f"\n⚠️  Found test entries in {len(results)} memory documents:\n")
        for designation, data in results.items():
            print(f"📄 {designation}")
            print(f"   Memory Doc ID: {data['memory_id'][:60]}...")
            print(f"   Test entry lines: {len(data['test_lines'])} out of {data['total_lines']} total lines")
            print(f"   Line numbers with test content:")
            for line_num, line_content in data['test_lines'][:5]:  # Show first 5
                preview = line_content[:60] + "..." if len(line_content) > 60 else line_content
                print(f"      Line {line_num}: {preview}")
            if len(data['test_lines']) > 5:
                print(f"      ... and {len(data['test_lines']) - 5} more lines")
            print()
    else:
        print("\n✅ No test entries found in any memory documents!")
    
    print("="*80)
    print("\n💡 TIP: You can manually delete these test entries from the Google Docs")
    print("   or use the Google Docs Memory Tool with append=False to replace content.")

if __name__ == "__main__":
    identify_test_entries()

