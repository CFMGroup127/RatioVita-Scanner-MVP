"""
Fix Samuel Reed's Missing Market Analysis Report
This script forces Samuel Reed to write his complete market analysis report to memory.
"""
import os
from datetime import datetime
from crewai import Agent, Task, Crew, Process
from config import Config
from main import load_agents_from_yaml, get_agent_metadata

def fix_samuel_report():
    """
    Force Samuel Reed to write his complete market analysis report to memory.
    """
    print("\n" + "="*80)
    print("🔧 FIXING SAMUEL REED'S MARKET ANALYSIS REPORT")
    print("="*80)
    print("Writing complete market analysis report to Samuel's memory document")
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
    
    # Get Samuel Reed
    samuel_role = "Competitive Intelligence Specialist"
    
    samuel_agent = None
    samuel_metadata = None
    
    for agent in agents:
        if agent.role == samuel_role:
            samuel_agent = agent
            samuel_metadata = get_agent_metadata(samuel_role)
            break
    
    if not samuel_agent:
        print(f"❌ Error: Samuel Reed (Market Analyst) not found")
        return None
    
    print(f"\n✅ Agent loaded:")
    print(f"   - Samuel Reed (Market Analyst)")
    
    samuel_memory_id = samuel_metadata.get('memory_doc_id', '')
    
    if not samuel_memory_id:
        print("❌ Error: Samuel's memory_doc_id not found")
        return None
    
    print(f"   Memory Doc ID: {samuel_memory_id}")
    
    # ============================================================================
    # TASK: Samuel Reed - Write Complete Market Analysis Report
    # ============================================================================
    print("\n" + "="*80)
    print("TASK: Samuel Reed - Write Complete Market Analysis Report")
    print("="*80)
    
    samuel_task = Task(
        description=(
            f"**CRITICAL TASK:** Write your complete Market Analysis and Competitive Landscape report to your memory document.\n\n"
            f"**YOUR TASK:**\n"
            f"1. Use the Cursor Web Browser Tool to research the top 3 direct competitors to RatioVita_v2\n"
            f"   - Focus on health/wellness apps similar to RatioVita\n"
            f"   - Research their UI/UX patterns, monetization strategies, and retention features\n\n"
            f"2. Create a comprehensive report with the following structure:\n\n"
            f"**REPORT TITLE:** V2 Market and Competitive Landscape\n\n"
            f"**Report Sections (MUST INCLUDE ALL):**\n"
            f"- **Section 1: Competitive Overview**\n"
            f"  * List and describe the top 3 competitors\n"
            f"  * Include their market position and target audience\n"
            f"  * Key strengths and weaknesses for each\n\n"
            f"- **Section 2: UI/UX Pattern Analysis**\n"
            f"  * Design approaches used by competitors\n"
            f"  * User experience patterns\n"
            f"  * Navigation and interface trends\n\n"
            f"- **Section 3: Monetization Strategy Comparison**\n"
            f"  * Pricing models (subscription, freemium, one-time, etc.)\n"
            f"  * Revenue streams\n"
            f"  * Value proposition for paid features\n\n"
            f"- **Section 4: User Retention Feature Analysis**\n"
            f"  * Engagement tactics used by competitors\n"
            f"  * Retention mechanisms (notifications, gamification, etc.)\n"
            f"  * Community features\n\n"
            f"- **Section 5: Key Insights and Recommendations**\n"
            f"  * Opportunities for V2\n"
            f"  * Competitive advantages to leverage\n"
            f"  * Market gaps to address\n\n"
            f"3. **MANDATORY:** Write the COMPLETE report to your memory document:\n"
            f"   - Use Google Docs Memory Tool\n"
            f"   - doc_id: {samuel_memory_id}\n"
            f"   - content: [your COMPLETE report with ALL sections above]\n"
            f"   - append: True\n"
            f"   - **VERIFY:** You MUST see SUCCESS message before considering task complete\n\n"
            f"**CRITICAL REQUIREMENTS:**\n"
            f"- This must be a COMPLETE, DETAILED report (not just a summary)\n"
            f"- Include all 5 sections listed above\n"
            f"- Each section should have substantial content (multiple paragraphs)\n"
            f"- The report should be comprehensive enough for strategic decision-making\n"
            f"- You MUST see a SUCCESS message confirming the report was written\n"
            f"- Do NOT mark the task as complete until you see SUCCESS"
        ),
        agent=samuel_agent,
        expected_output="SUCCESS message confirming complete market analysis report written to memory document with all 5 sections",
        max_iter=50
    )
    
    # ============================================================================
    # EXECUTE
    # ============================================================================
    print("\n" + "="*80)
    print(f"🚀 Creating crew with 1 task...")
    print("="*80)
    
    crew = Crew(
        agents=[samuel_agent],
        tasks=[samuel_task],
        process=Process.sequential,
        verbose=True,
        max_iter=100,
        max_execution_time=3600  # 1 hour timeout
    )
    
    print("✅ Crew created")
    print("\n" + "="*80)
    print("Starting Samuel's market analysis report fix...")
    print("="*80 + "\n")
    
    try:
        result = crew.kickoff()
        print("\n" + "="*80)
        print("✅ SAMUEL'S REPORT FIX COMPLETE")
        print("="*80)
        print("\n📊 Results:")
        print(result)
        print("\n" + "="*80)
        print("\n📋 VERIFICATION:")
        print("="*80)
        print(f"✓ Samuel Reed: Complete market analysis report written to memory")
        print("="*80)
        return result
    except Exception as e:
        print(f"\n❌ Error during execution: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    fix_samuel_report()



