"""
Direct Fix for Samuel Reed's Market Analysis Report
This script directly writes a market analysis report to Samuel's memory document.
"""
import os
from datetime import datetime
from crewai import Agent, Task, Crew, Process
from config import Config
from main import load_agents_from_yaml, get_agent_metadata

def fix_samuel_direct():
    """
    Force Samuel Reed to write his market analysis report directly to memory.
    Uses a simpler, more direct approach.
    """
    print("\n" + "="*80)
    print("🔧 DIRECT FIX: SAMUEL REED'S MARKET ANALYSIS REPORT")
    print("="*80)
    print("Using simplified approach to write report directly to memory")
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
    
    print(f"\n✅ Agent loaded: Samuel Reed (Market Analyst)")
    
    samuel_memory_id = samuel_metadata.get('memory_doc_id', '')
    
    if not samuel_memory_id:
        print("❌ Error: Samuel's memory_doc_id not found")
        return None
    
    print(f"   Memory Doc ID: {samuel_memory_id}")
    
    # ============================================================================
    # SIMPLIFIED TASK: Write Report Directly
    # ============================================================================
    print("\n" + "="*80)
    print("TASK: Write Market Analysis Report")
    print("="*80)
    
    samuel_task = Task(
        description=(
            f"**YOUR ONLY TASK:** Write a complete Market Analysis and Competitive Landscape report to your memory document.\n\n"
            f"**STEP 1: Research (Use Cursor Web Browser Tool - MAX 5 searches)**\n"
            f"- Search for: 'top health wellness apps 2024 competitors'\n"
            f"- Search for: 'health app monetization strategies'\n"
            f"- Search for: 'wellness app user retention features'\n"
            f"- Focus on 3 main competitors\n\n"
            f"**STEP 2: Write Report to Memory (MANDATORY - THIS IS THE CRITICAL STEP)**\n"
            f"You MUST use the Google Docs Memory Tool to write your complete report.\n\n"
            f"**Report Format (Write ALL of this):**\n\n"
            f"Title: V2 Market and Competitive Landscape\n"
            f"Date: {datetime.now().strftime('%Y-%m-%d')}\n"
            f"Agent: Samuel Reed (Market Analyst)\n\n"
            f"Section 1: Competitive Overview\n"
            f"[Describe the top 3 competitors, their market position, target audience, and key strengths/weaknesses]\n\n"
            f"Section 2: UI/UX Pattern Analysis\n"
            f"[Describe design approaches, user experience patterns, and navigation trends]\n\n"
            f"Section 3: Monetization Strategy Comparison\n"
            f"[Describe pricing models, revenue streams, and value propositions]\n\n"
            f"Section 4: User Retention Feature Analysis\n"
            f"[Describe engagement tactics, retention mechanisms, and community features]\n\n"
            f"Section 5: Key Insights and Recommendations\n"
            f"[Describe opportunities for V2, competitive advantages, and market gaps]\n\n"
            f"**CRITICAL INSTRUCTIONS:**\n"
            f"1. Use Google Docs Memory Tool\n"
            f"2. doc_id: {samuel_memory_id}\n"
            f"3. content: [Write the ENTIRE report above with all 5 sections filled in]\n"
            f"4. append: True\n"
            f"5. **YOU MUST SEE A SUCCESS MESSAGE** before you are done\n"
            f"6. If you don't see SUCCESS, try again\n"
            f"7. The report must be at least 2000 characters long\n"
            f"8. Do NOT finish until you see: 'SUCCESS: Content appended to Google Doc'\n\n"
            f"**THIS IS YOUR PRIMARY OBJECTIVE - WRITING THE REPORT TO MEMORY IS MANDATORY**"
        ),
        agent=samuel_agent,
        expected_output="SUCCESS message: 'SUCCESS: Content appended to Google Doc (ID: [doc_id]). Document updated successfully.' - The report must be written to memory.",
        max_iter=30
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
        max_iter=50,
        max_execution_time=3600  # 1 hour timeout
    )
    
    print("✅ Crew created")
    print("\n" + "="*80)
    print("Starting direct report write...")
    print("="*80 + "\n")
    
    try:
        result = crew.kickoff()
        print("\n" + "="*80)
        print("✅ SAMUEL'S DIRECT REPORT FIX COMPLETE")
        print("="*80)
        print("\n📊 Results:")
        print(result)
        print("\n" + "="*80)
        return result
    except Exception as e:
        print(f"\n❌ Error during execution: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    fix_samuel_direct()



