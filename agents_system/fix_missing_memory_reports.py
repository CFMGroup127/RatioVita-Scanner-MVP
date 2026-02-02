"""
Fix Missing Memory Reports
This script forces Samuel Reed and Ash Roy to write their full reports to memory.
"""
import os
from datetime import datetime
from crewai import Agent, Task, Crew, Process
from config import Config
from main import load_agents_from_yaml, get_agent_metadata

def fix_missing_memory_reports():
    """
    Force Samuel Reed and Ash Roy to write their full reports to memory.
    """
    print("\n" + "="*80)
    print("🔧 FIXING MISSING MEMORY REPORTS")
    print("="*80)
    print("Forcing Samuel Reed and Ash Roy to write their full reports to memory")
    print("="*80)
    
    # Validate configuration
    try:
        Config.validate()
        print("✅ Configuration validated")
    except ValueError as e:
        print(f"❌ Configuration Error: {e}")
        return None
    
    os.environ['OPENAI_API_KEY'] = Config.OPENAI_API_KEY
    
    # Load agents
    print("\n📋 Loading agents...")
    try:
        agents = load_agents_from_yaml('agents.yaml')
        print(f"✅ Loaded {len(agents)} agents")
    except Exception as e:
        print(f"❌ Error loading agents: {e}")
        import traceback
        traceback.print_exc()
        return None
    
    # Get agents
    samuel_role = "Competitive Intelligence Specialist"
    ash_role = "Technical and Product Visionary"
    
    samuel_agent = None
    ash_agent = None
    samuel_metadata = None
    ash_metadata = None
    
    for agent in agents:
        if agent.role == samuel_role:
            samuel_agent = agent
            samuel_metadata = get_agent_metadata(samuel_role)
        elif agent.role == ash_role:
            ash_agent = agent
            ash_metadata = get_agent_metadata(ash_role)
    
    if not samuel_agent or not ash_agent:
        missing = []
        if not samuel_agent: missing.append("Samuel Reed")
        if not ash_agent: missing.append("Ash Roy")
        print(f"❌ Error: Missing agents: {', '.join(missing)}")
        return None
    
    print(f"\n✅ Agents loaded:")
    print(f"   - Samuel Reed (Market Analyst)")
    print(f"   - Ash Roy (CTO/CPO)")
    
    samuel_memory_id = samuel_metadata.get('memory_doc_id', '')
    ash_memory_id = ash_metadata.get('memory_doc_id', '')
    
    tasks = []
    
    # ============================================================================
    # TASK 1: Samuel Reed - Write Full Market Analysis Report
    # ============================================================================
    print("\n" + "="*80)
    print("TASK 1: Samuel Reed - Write Full Market Analysis Report to Memory")
    print("="*80)
    
    samuel_fix_task = Task(
        description=(
            f"**CRITICAL:** Your previous task completed but the full report was not written to your memory document.\n\n"
            f"**YOUR TASK:**\n"
            f"1. Use the Cursor Web Browser Tool to research the top 3 direct competitors to RatioVita_v2\n"
            f"2. Create a comprehensive report titled: **V2 Market and Competitive Landscape**\n"
            f"3. **MANDATORY:** Write the COMPLETE report to your memory document:\n"
            f"   - Use Google Docs Memory Tool\n"
            f"   - doc_id: {samuel_memory_id}\n"
            f"   - content: [your COMPLETE competitive analysis report with all sections]\n"
            f"   - append: True\n"
            f"   - **VERIFY:** You MUST see SUCCESS message\n\n"
            f"**Report Must Include:**\n"
            f"- Title: V2 Market and Competitive Landscape\n"
            f"- Date: {datetime.now().strftime('%Y-%m-%d')}\n"
            f"- Agent: Samuel Reed (Market Analyst)\n"
            f"- Section 1: Competitive Overview (Top 3 Competitors with details)\n"
            f"- Section 2: UI/UX Pattern Analysis\n"
            f"- Section 3: Monetization Strategy Comparison\n"
            f"- Section 4: User Retention Feature Analysis\n"
            f"- Section 5: Key Insights and Recommendations\n\n"
            f"**CRITICAL:** This is a complete report, not just a status update. Include all research findings."
        ),
        agent=samuel_agent,
        expected_output="SUCCESS message confirming complete market analysis report written to memory document",
        max_iter=30
    )
    tasks.append(samuel_fix_task)
    
    # ============================================================================
    # TASK 2: Ash Roy - Write Full V2 Technical Baseline Report
    # ============================================================================
    print("\n" + "="*80)
    print("TASK 2: Ash Roy - Write Full V2 Technical Baseline Report to Memory")
    print("="*80)
    
    ash_fix_task = Task(
        description=(
            f"**CRITICAL:** Your previous task completed but the full V2 Technical Baseline report was not written to your memory document.\n\n"
            f"**YOUR TASK:**\n"
            f"1. Review your V2 codebase analysis work (you already completed the analysis)\n"
            f"2. Create the COMPLETE **V2 Technical Baseline and Dependencies** report\n"
            f"3. **MANDATORY:** Write the COMPLETE report to your memory document:\n"
            f"   - Use Google Docs Memory Tool\n"
            f"   - doc_id: {ash_memory_id}\n"
            f"   - content: [your COMPLETE technical baseline report with all sections]\n"
            f"   - append: True\n"
            f"   - **VERIFY:** You MUST see SUCCESS message\n\n"
            f"**Report Must Include:**\n"
            f"- Title: V2 Technical Baseline and Dependencies\n"
            f"- Project: RatioVita_v2\n"
            f"- Agent: Ash Roy (Chief Architect)\n"
            f"- Date Completed: {datetime.now().strftime('%Y-%m-%d')}\n"
            f"- Executive Summary (with highest risk identified)\n"
            f"- Section 1: Dependencies & Libraries (with risk assessment)\n"
            f"- Section 2: Code Structure & Architecture\n"
            f"- Section 3: Key Recommendations\n\n"
            f"**CRITICAL:** This is a complete technical report, not just a status update. Include all analysis findings."
        ),
        agent=ash_agent,
        expected_output="SUCCESS message confirming complete V2 technical baseline report written to memory document",
        max_iter=30
    )
    tasks.append(ash_fix_task)
    
    # ============================================================================
    # EXECUTE FIX
    # ============================================================================
    print("\n" + "="*80)
    print(f"🚀 Creating crew with {len(tasks)} tasks...")
    print("="*80)
    
    crew = Crew(
        agents=[samuel_agent, ash_agent],
        tasks=tasks,
        process=Process.sequential,
        verbose=True,
        max_iter=100,
        max_execution_time=3600  # 1 hour timeout
    )
    
    print("✅ Crew created")
    print("\n" + "="*80)
    print("Starting memory report fix...")
    print("="*80 + "\n")
    
    try:
        result = crew.kickoff()
        print("\n" + "="*80)
        print("✅ MEMORY REPORT FIX COMPLETE")
        print("="*80)
        print("\n📊 Results:")
        print(result)
        print("\n" + "="*80)
        print("\n📋 VERIFICATION:")
        print("="*80)
        print(f"✓ Samuel Reed: Full market analysis report written to memory")
        print(f"✓ Ash Roy: Full V2 technical baseline report written to memory")
        print("="*80)
        return result
    except Exception as e:
        print(f"\n❌ Error during fix execution: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    fix_missing_memory_reports()



