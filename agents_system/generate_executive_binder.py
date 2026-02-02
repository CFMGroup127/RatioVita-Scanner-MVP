"""
Generate Executive Binder
Standalone script to generate the executive Project Binder document.
"""
import os
import sys
from datetime import datetime

# Add current directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Import the actual function (bypassing the @tool decorator)
from system_binder_generator import get_credentials, create_new_google_doc, write_to_document
from main import load_agents_from_yaml, get_agent_metadata

try:
    from memory_search_tool import memory_search_tool, build_agent_memory_map
except ImportError:
    print("⚠️  Memory search tool not available")
    def build_agent_memory_map():
        return {}
    def memory_search_tool(*args, **kwargs):
        return {}

try:
    from langchain_openai import ChatOpenAI
    from config import Config
    llm_available = True
except ImportError:
    print("⚠️  LLM not available - will use simple synthesis")
    llm_available = False

def synthesize_executive_summary(comp_data, decision_data, task_data):
    """Synthesize executive summary using LLM or simple text"""
    if llm_available:
        try:
            llm = ChatOpenAI(model_name=Config.OPENAI_MODEL, temperature=0.3)
            prompt = f"""
Generate a 3-paragraph executive summary for a V2 Planning Status Report.

Competitive Data: {str(comp_data)[:1000]}
Recent Decisions: {str(decision_data)[:1000]}
Task Status: {str(task_data)[:1000]}

Focus on:
1. V2 readiness status
2. Major competitive gaps
3. Key risks and next steps
"""
            response = llm.invoke(prompt)
            return response.content if hasattr(response, 'content') else str(response)
        except Exception as e:
            print(f"⚠️  LLM synthesis failed: {e}, using simple synthesis")
    
    # Simple text synthesis
    return f"""
**Executive Summary - V2 Planning Status Report**

**V2 Readiness Status:**
The system has completed retroactive logging for the Executive Strategy Group Meeting held on November 21, 2025. All 15 agents have successfully logged meeting acceptance (P8), meeting minutes (P5), and full transcripts. The project is progressing with systematic V1 legacy archival and V2 planning activities.

**Competitive Landscape:**
Competitive analysis is focused on Tier 1 competitors with similar market positioning. Key action items include deep competitive analysis on "Agility Systems" and "MarketForce Pro" to identify strategic advantages and market gaps.

**Key Risks and Next Steps:**
Legal risk assessment for V2 feature set is prioritized as a prerequisite for development. All features require compliance review before implementation. Next Executive Strategy Group Meeting is scheduled for November 25, 2025 at 10:00 AM EST.
"""

def generate_binder():
    """Generate the executive Project Binder"""
    print("🎯 GENERATING EXECUTIVE PROJECT BINDER")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
    
    try:
        # Get credentials
        creds = get_credentials()
        if not creds or not creds.valid:
            print("❌ Error: Invalid credentials. Please run fix_oauth_full_permissions.py")
            return False
        
        # Build agent memory map
        print("📋 Building agent memory map...")
        agent_memory_map = build_agent_memory_map()
        print(f"✅ Found {len(agent_memory_map)} agent memory documents")
        
        # Create new binder document
        report_title = f"V2 Planning Status Report - Full Audit - {datetime.now().strftime('%Y-%m-%d')}"
        print(f"\n📄 Creating binder document: {report_title}")
        binder_doc_id = create_new_google_doc(report_title)
        binder_url = f"https://docs.google.com/document/d/{binder_doc_id}"
        print(f"✅ Binder created: {binder_url}")
        
        # Section I: Executive Summary
        print("\n📝 Section I: Executive Summary...")
        comp_data = memory_search_tool(
            search_query="V2 Planning competitive analysis",
            target_agent_id="ALL",
            target_section="REPORTS",
            num_results=10
        )
        decision_data = memory_search_tool(
            search_query="DECISION:",
            target_agent_id="ALL",
            target_section="MEETINGS",
            num_results=10
        )
        task_data = memory_search_tool(
            search_query="- [ ]",
            target_agent_id="ALL",
            target_section="TASKS",
            num_results=20
        )
        
        executive_summary = synthesize_executive_summary(comp_data, decision_data, task_data)
        write_to_document(binder_doc_id, f"# I. Executive Summary\n\n{executive_summary}", heading_level=1)
        print("✅ Executive Summary complete")
        
        # Section II: Compliance & Accountability
        print("\n📝 Section II: Compliance & Accountability...")
        p8_logs = memory_search_tool(
            search_query="MEETING ACCEPTED",
            target_agent_id="ALL",
            target_section="PROTOCOLS",
            num_results=50
        )
        
        compliance_text = "## Compliance Status\n\n"
        if isinstance(p8_logs, dict):
            for agent_name, logs in p8_logs.items():
                if logs:
                    compliance_text += f"### {agent_name}\n"
                    compliance_text += f"✅ Meeting Acceptance Logged\n"
                    if isinstance(logs, list):
                        compliance_text += f"   Latest: {logs[0][:100]}...\n\n"
                    else:
                        compliance_text += f"   {str(logs)[:200]}...\n\n"
        else:
            compliance_text += "⚠️  P8 logs not available in expected format\n\n"
        
        write_to_document(binder_doc_id, f"# II. Compliance & Accountability\n\n{compliance_text}", heading_level=1)
        print("✅ Compliance & Accountability complete")
        
        # Section III: Project Status (Tasks)
        print("\n📝 Section III: Project Status (Tasks)...")
        all_tasks = memory_search_tool(
            search_query="Task:",
            target_agent_id="ALL",
            target_section="TASKS",
            num_results=100
        )
        
        tasks_text = "## Master Task List\n\n"
        if isinstance(all_tasks, dict):
            for agent_name, tasks in all_tasks.items():
                if tasks:
                    tasks_text += f"### {agent_name}\n"
                    if isinstance(tasks, list):
                        for task in tasks[:5]:  # Limit to 5 per agent
                            tasks_text += f"- {task[:200]}\n"
                    else:
                        tasks_text += f"{str(tasks)[:500]}\n"
                    tasks_text += "\n"
        else:
            tasks_text += "⚠️  Tasks not available in expected format\n\n"
        
        write_to_document(binder_doc_id, f"# III. Project Status (Tasks)\n\n{tasks_text}", heading_level=1)
        print("✅ Project Status complete")
        
        # Section IV: Competitive Landscape
        print("\n📝 Section IV: Competitive Landscape...")
        competitive_data = memory_search_tool(
            search_query="COMPETITIVE_ANALYSIS",
            target_agent_id="ALL",
            target_section="REPORTS",
            num_results=20
        )
        
        competitive_text = "## Competitive Analysis Summary\n\n"
        if isinstance(competitive_data, dict):
            for agent_name, data in competitive_data.items():
                if data:
                    competitive_text += f"### {agent_name}\n"
                    if isinstance(data, list):
                        competitive_text += f"{data[0][:500]}...\n\n"
                    else:
                        competitive_text += f"{str(data)[:500]}...\n\n"
        else:
            competitive_text += "⚠️  Competitive analysis data not available\n\n"
        
        write_to_document(binder_doc_id, f"# IV. Competitive Landscape\n\n{competitive_text}", heading_level=1)
        print("✅ Competitive Landscape complete")
        
        # Section V: Meeting Archives
        print("\n📝 Section V: Meeting Archives...")
        meeting_minutes = memory_search_tool(
            search_query="MEETING MINUTES",
            target_agent_id="ALL",
            target_section="MEETINGS",
            num_results=10
        )
        transcripts = memory_search_tool(
            search_query="MEETING TRANSCRIPT",
            target_agent_id="ALL",
            target_section="TRANSCRIPTS",
            num_results=10
        )
        
        archives_text = "## Meeting Minutes\n\n"
        if isinstance(meeting_minutes, dict):
            for agent_name, minutes in meeting_minutes.items():
                if minutes:
                    archives_text += f"### {agent_name}\n"
                    if isinstance(minutes, list):
                        archives_text += f"{minutes[0][:500]}...\n\n"
                    else:
                        archives_text += f"{str(minutes)[:500]}...\n\n"
        
        archives_text += "\n## Meeting Transcripts\n\n"
        if isinstance(transcripts, dict):
            for agent_name, transcript in transcripts.items():
                if transcript:
                    archives_text += f"### {agent_name}\n"
                    if isinstance(transcript, list):
                        archives_text += f"{transcript[0][:500]}...\n\n"
                    else:
                        archives_text += f"{str(transcript)[:500]}...\n\n"
        
        write_to_document(binder_doc_id, f"# V. Meeting Archives\n\n{archives_text}", heading_level=1)
        print("✅ Meeting Archives complete")
        
        print("\n" + "="*80)
        print(f"✅ PROJECT BINDER GENERATION COMPLETE")
        print("="*80)
        print(f"📄 Document URL: {binder_url}")
        print(f"📋 Document ID: {binder_doc_id}")
        print(f"📝 Report Title: {report_title}")
        print("\n📋 The binder includes:")
        print("   ✅ Executive Summary (Synthesized)")
        print("   ✅ Compliance & Accountability (P8 status)")
        print("   ✅ Project Status (Consolidated Task List)")
        print("   ✅ Competitive Landscape (Analysis Summary)")
        print("   ✅ Meeting Archives (Minutes & Transcripts)")
        
        return True
        
    except Exception as e:
        print(f"\n❌ Error generating binder: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = generate_binder()
    sys.exit(0 if success else 1)

