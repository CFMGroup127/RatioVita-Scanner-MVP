"""
Test New Features
Comprehensive test script for TRANSCRIPTS, COMPETITIVE_ANALYSIS, and System Binder Generator.
"""
import os
import sys
from datetime import datetime
from crewai import Agent, Task, Crew
from main import load_agents_from_yaml, get_agent_metadata

def test_transcripts_feature():
    """Test TRANSCRIPTS tab and MEETING_TRANSCRIPT_ARCHIVE template"""
    print("📜 TEST 1: TRANSCRIPTS Feature")
    print("="*80)
    
    agents = load_agents_from_yaml('agents.yaml')
    
    # Select Alice Kim (Documentation and Knowledge Archivist) for transcript test
    test_agent = None
    for agent in agents:
        if agent.role == "Documentation and Knowledge Archivist":
            test_agent = agent
            break
    
    if not test_agent:
        print("❌ Test agent not found")
        return False
    
    meta = get_agent_metadata(test_agent.role)
    memory_doc_id = meta.get('memory_doc_id', '')
    agent_name = meta.get('email_address', '').split('@')[0].replace('.', ' ').title()
    
    if not memory_doc_id:
        print("❌ No memory_doc_id found")
        return False
    
    test_transcript = f"""[Speaker 1 - David Chen]: Welcome everyone. Today we're reviewing V1 legacy assets and planning V2 initiatives.

[Speaker 2 - Dana Flores]: I've prepared the initial workflow analysis. We should prioritize the archival process.

[Speaker 3 - Alice Kim]: I can begin the documentation audit immediately. The V1 codebase requires comprehensive mapping.

[Speaker 1 - David Chen]: Excellent. Alice, please coordinate with Samuel on the archival timeline.

[Speaker 4 - Samuel Reed]: I'll provide the technical specifications by end of week.

[Speaker 1 - David Chen]: Meeting adjourned. Next meeting scheduled for November 25, 2025."""
    
    task_description = f"""
**TEST: TRANSCRIPTS Feature**

You are testing the new TRANSCRIPTS tab and MEETING_TRANSCRIPT_ARCHIVE template.

**TASK:**
1. Use the **Google Docs Memory Tool** to log a test transcript:
   - doc_id: {memory_doc_id}
   - section: "TRANSCRIPTS"
   - subsection: "{datetime.now().strftime('%B %d, %Y')}"
   - template: "MEETING_TRANSCRIPT_ARCHIVE"
   - content: "{test_transcript}"

2. Verify the transcript was logged correctly by reading your memory document.

**Expected Result:** The transcript should appear in the TRANSCRIPTS section with proper formatting.
"""
    
    task = Task(
        description=task_description,
        agent=test_agent,
        expected_output="Test transcript logged successfully in TRANSCRIPTS section with MEETING_TRANSCRIPT_ARCHIVE template"
    )
    
    crew = Crew(
        agents=[test_agent],
        tasks=[task],
        verbose=True
    )
    
    try:
        print(f"📝 Testing transcript logging for {agent_name}...")
        result = crew.kickoff()
        print(f"✅ Transcript test complete: {result}")
        return True
    except Exception as e:
        print(f"❌ Transcript test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_competitive_analysis_feature():
    """Test COMPETITIVE_ANALYSIS template"""
    print("\n📊 TEST 2: COMPETITIVE_ANALYSIS Feature")
    print("="*80)
    
    agents = load_agents_from_yaml('agents.yaml')
    
    # Select Victor Alvarez (Competitive Intelligence Specialist)
    test_agent = None
    for agent in agents:
        if agent.role == "Competitive Intelligence Specialist":
            test_agent = agent
            break
    
    if not test_agent:
        print("❌ Test agent not found")
        return False
    
    meta = get_agent_metadata(test_agent.role)
    memory_doc_id = meta.get('memory_doc_id', '')
    agent_name = meta.get('email_address', '').split('@')[0].replace('.', ' ').title()
    
    if not memory_doc_id:
        print("❌ No memory_doc_id found")
        return False
    
    task_description = f"""
**TEST: COMPETITIVE_ANALYSIS Feature**

You are testing the new COMPETITIVE_ANALYSIS template for competitive research reports.

**TASK:**
1. Use the **Google Docs Memory Tool** to create a test competitive analysis report:
   - doc_id: {memory_doc_id}
   - section: "REPORTS"
   - subsection: "{datetime.now().strftime('%B %d, %Y')}"
   - template: "COMPETITIVE_ANALYSIS"
   - content: "Agility Systems - Direct competitor analysis. Key features: Advanced analytics, cloud-based. Pricing: $299/month. Market share: 15%. Strengths: Strong brand recognition. Weaknesses: Limited mobile support. Opportunities: Emerging markets. Threats: New entrants."

2. Ensure the report follows the COMPETITIVE_ANALYSIS template structure:
   - I. Competitor Profile
   - II. Comparison Benchmarking
   - III. Strategic SWOT Analysis

**Expected Result:** The competitive analysis should appear in the REPORTS section with proper SWOT structure.
"""
    
    task = Task(
        description=task_description,
        agent=test_agent,
        expected_output="Test competitive analysis report logged successfully in REPORTS section with COMPETITIVE_ANALYSIS template"
    )
    
    crew = Crew(
        agents=[test_agent],
        tasks=[task],
        verbose=True
    )
    
    try:
        print(f"📝 Testing competitive analysis for {agent_name}...")
        result = crew.kickoff()
        print(f"✅ Competitive analysis test complete: {result}")
        return True
    except Exception as e:
        print(f"❌ Competitive analysis test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_system_binder_generator():
    """Test System Binder Generator tool"""
    print("\n📑 TEST 3: System Binder Generator")
    print("="*80)
    
    agents = load_agents_from_yaml('agents.yaml')
    
    # Select David Chen (Visionary and Final Decision Maker) who has access to binder generator
    test_agent = None
    for agent in agents:
        if agent.role == "Visionary and Final Decision Maker":
            test_agent = agent
            break
    
    if not test_agent:
        print("❌ Test agent not found")
        return False
    
    agent_name = "David Chen"
    
    task_description = f"""
**TEST: System Binder Generator**

You are testing the System Binder Generator tool that synthesizes all agent data into an executive report.

**TASK:**
1. Use the **System Binder Generator** tool to create a test Project Binder:
   - report_title: "V2 System Test Report"
   - time_scope: "ALL"
   - output_format: "GOOGLE_DOC"

2. The tool should:
   - Create a new Google Doc
   - Retrieve data from all 15 agents using memory_search_tool
   - Synthesize executive summary using LLM
   - Format sections: Executive Summary, Compliance, Tasks, Competitive Landscape, Meeting Archives
   - Return the document URL

**Expected Result:** A new Google Doc should be created with a professional Table of Contents and synthesized content from all agents.
"""
    
    task = Task(
        description=task_description,
        agent=test_agent,
        expected_output="Test Project Binder created successfully with synthesized content from all 15 agents"
    )
    
    crew = Crew(
        agents=[test_agent],
        tasks=[task],
        verbose=True
    )
    
    try:
        print(f"📝 Testing System Binder Generator for {agent_name}...")
        result = crew.kickoff()
        print(f"✅ System Binder Generator test complete: {result}")
        return True
    except Exception as e:
        print(f"❌ System Binder Generator test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def run_all_tests():
    """Run all feature tests"""
    print("🧪 COMPREHENSIVE FEATURE TEST SUITE")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
    
    results = {}
    
    # Test 1: Transcripts
    results['transcripts'] = test_transcripts_feature()
    
    # Test 2: Competitive Analysis
    results['competitive_analysis'] = test_competitive_analysis_feature()
    
    # Test 3: System Binder Generator
    results['binder_generator'] = test_system_binder_generator()
    
    # Summary
    print("\n" + "="*80)
    print("📊 TEST SUMMARY")
    print("="*80)
    print(f"✅ Transcripts Feature: {'PASS' if results['transcripts'] else 'FAIL'}")
    print(f"✅ Competitive Analysis Feature: {'PASS' if results['competitive_analysis'] else 'FAIL'}")
    print(f"✅ System Binder Generator: {'PASS' if results['binder_generator'] else 'FAIL'}")
    
    all_passed = all(results.values())
    print(f"\n{'🎉 ALL TESTS PASSED' if all_passed else '❌ SOME TESTS FAILED'}")
    
    return all_passed

if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)

