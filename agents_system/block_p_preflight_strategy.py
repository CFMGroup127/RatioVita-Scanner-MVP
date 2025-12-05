"""
BLOCK P: Pre-Flight Strategy (Concurrent Execution)
This script launches concurrent strategy tasks that run simultaneously with BLOCK A (Archival)
to maximize agent efficiency by gathering non-dependent, external context.
"""
import os
from datetime import datetime
from crewai import Agent, Task, Crew, Process
from config import Config
from main import load_agents_from_yaml, get_agent_metadata

# V2 Design folder path
V2_DESIGN_FOLDER = "/Users/colliemorris/Projects 2/RatioVita_v2/design"

def block_p_preflight_strategy():
    """
    Execute BLOCK P: Pre-Flight Strategy (Concurrent Execution)
    
    This block runs simultaneously with BLOCK A to gather:
    1. Market Analysis & Competitive Audit (Samuel Reed)
    2. Design System Foundation Definition (Arthur Jensen)
    3. V2 Branding & Core Value Proposition (Megan Parker)
    """
    print("\n" + "="*80)
    print("🚀 BLOCK P: PRE-FLIGHT STRATEGY (CONCURRENT EXECUTION)")
    print("="*80)
    print("Running simultaneously with BLOCK A to maximize efficiency")
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
    
    # Get key agents (including Dana for delegation)
    dana_role = "Admin Assistant & Workflow Funnel"
    samuel_role = "Competitive Intelligence Specialist"
    arthur_role = "Legal Compliance and Risk Assessor"  # Note: Arthur is CLO, but user wants him as Design System Architect
    megan_role = "Market Strategist and Voice of the Customer"
    
    dana_agent = None
    samuel_agent = None
    arthur_agent = None
    megan_agent = None
    dana_metadata = None
    samuel_metadata = None
    arthur_metadata = None
    megan_metadata = None
    
    for agent in agents:
        if agent.role == dana_role:
            dana_agent = agent
            dana_metadata = get_agent_metadata(dana_role)
        elif agent.role == samuel_role:
            samuel_agent = agent
            samuel_metadata = get_agent_metadata(samuel_role)
        elif agent.role == arthur_role:
            arthur_agent = agent
            arthur_metadata = get_agent_metadata(arthur_role)
        elif agent.role == megan_role:
            megan_agent = agent
            megan_metadata = get_agent_metadata(megan_role)
    
    if not dana_agent or not samuel_agent or not arthur_agent or not megan_agent:
        missing = []
        if not dana_agent: missing.append("Dana Flores")
        if not samuel_agent: missing.append("Samuel Reed")
        if not arthur_agent: missing.append("Arthur Jensen")
        if not megan_agent: missing.append("Megan Parker")
        print(f"❌ Error: Missing required agents: {', '.join(missing)}")
        return None
    
    print(f"\n✅ Key agents loaded:")
    print(f"   - Dana Flores (Admin Assistant - Coordinator)")
    print(f"   - Samuel Reed (Market Analyst)")
    print(f"   - Arthur Jensen (CLO - acting as Design System Architect)")
    print(f"   - Megan Parker (CMO)")
    
    tasks = []
    
    # Get memory IDs
    dana_memory_id = dana_metadata.get('memory_doc_id', '')
    
    # ============================================================================
    # TASK 0: Dana Flores - Initial Delegation
    # ============================================================================
    print("\n" + "="*80)
    print("TASK 0: Dana Flores - Initial Delegation for BLOCK P")
    print("="*80)
    
    dana_delegation_task = Task(
        description=(
            f"Execute your **WORKFLOW FUNNEL** role by formally delegating BLOCK P: Pre-Flight Strategy tasks.\n\n"
            f"**Your Delegation Task:**\n"
            f"1. Formally delegate the following concurrent strategy tasks:\n"
            f"   - Samuel Reed: Market Analysis & Competitive Audit\n"
            f"   - Arthur Jensen: Design System Foundation Definition\n"
            f"   - Megan Parker: V2 Branding & Core Value Proposition\n"
            f"2. Ensure all three agents understand their tasks and deliverables\n"
            f"3. Confirm that these tasks will run concurrently for efficiency\n"
            f"4. Document the delegation in your memory document\n\n"
            f"**Important:** This delegation ensures proper workflow management and task tracking."
        ),
        agent=dana_agent,
        expected_output="Confirmation that BLOCK P tasks have been formally delegated",
        max_iter=5
    )
    tasks.append(dana_delegation_task)
    
    # Get memory IDs
    samuel_memory_id = samuel_metadata.get('memory_doc_id', '')
    arthur_memory_id = arthur_metadata.get('memory_doc_id', '')
    megan_memory_id = megan_metadata.get('memory_doc_id', '')
    
    # ============================================================================
    # TASK 1: Samuel Reed - Market Analysis & Competitive Audit
    # ============================================================================
    print("\n" + "="*80)
    print("TASK 1: Samuel Reed - Market Analysis & Competitive Audit")
    print("="*80)
    
    samuel_read_memory_task = Task(
        description=(
            f"Before starting your market analysis, read your memory document to understand your current context.\n\n"
            f"**MANDATORY FIRST STEP:**\n"
            f"1. Use the Google Docs Read Tool with your memory_doc_id: {samuel_memory_id}\n"
            f"2. Review the contents of your memory document\n"
            f"3. Note any relevant context or prior research\n\n"
            f"This ensures you have full context before beginning the competitive analysis."
        ),
        agent=samuel_agent,
        expected_output="Confirmation that memory document has been read and context understood",
        context=[dana_delegation_task],
        max_iter=3
    )
    tasks.append(samuel_read_memory_task)
    
    samuel_task_description = (
        f"Conduct a Targeted Competitive Analysis of the top three direct competitors to the intended V2 application.\n\n"
        f"**Your Task:**\n"
        f"1. Use the Cursor Web Browser Tool to research the top 3 direct competitors to RatioVita_v2\n"
        f"2. Document each competitor's:\n"
        f"   - Current UI/UX patterns and design approaches\n"
        f"   - Monetization strategies and pricing models\n"
        f"   - User retention features and engagement tactics\n"
        f"   - Key strengths and weaknesses\n"
        f"3. Create a comprehensive report titled: **V2 Market and Competitive Landscape**\n"
        f"4. **MANDATORY:** Write the report to your memory document:\n"
        f"   - Use Google Docs Memory Tool\n"
        f"   - doc_id: {samuel_memory_id}\n"
        f"   - content: [your complete competitive analysis report]\n"
        f"   - append: True\n"
        f"   - **VERIFY:** You must see SUCCESS message\n\n"
        f"**Report Format:**\n"
        f"- Title: V2 Market and Competitive Landscape\n"
        f"- Date: {datetime.now().strftime('%Y-%m-%d')}\n"
        f"- Agent: Samuel Reed (Market Analyst)\n"
        f"- Section 1: Competitive Overview (Top 3 Competitors)\n"
        f"- Section 2: UI/UX Pattern Analysis\n"
        f"- Section 3: Monetization Strategy Comparison\n"
        f"- Section 4: User Retention Feature Analysis\n"
        f"- Section 5: Key Insights and Recommendations\n\n"
        f"**Important:**\n"
        f"- Use Cursor Web Browser Tool for real-time web access (per your protocol)\n"
        f"- Focus on actionable insights for V2 strategy\n"
        f"- Report must be ready for Executive Strategy Group meeting"
    )
    
    samuel_task = Task(
        description=samuel_task_description,
        agent=samuel_agent,
        expected_output="Confirmation that competitive analysis report has been written to memory document",
        context=[samuel_read_memory_task],
        max_iter=30
    )
    tasks.append(samuel_task)
    
    samuel_write_memory_task = Task(
        description=(
            f"After completing the competitive analysis, update your memory document with the completion status.\n\n"
            f"**MANDATORY FINAL STEP:**\n"
            f"1. Use the Google Docs Memory Tool\n"
            f"2. doc_id: {samuel_memory_id}\n"
            f"3. content: 'BLOCK P Market Analysis Task Completed - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}. "
            f"V2 Market and Competitive Landscape report has been written to this memory document. Status: COMPLETED.'\n"
            f"4. append: True\n"
            f"5. Verify you receive SUCCESS message\n\n"
            f"**IMPORTANT:** You must see a SUCCESS message confirming the update was written."
        ),
        agent=samuel_agent,
        expected_output="SUCCESS message confirming completion status written to memory document",
        context=[samuel_task],
        max_iter=3
    )
    tasks.append(samuel_write_memory_task)
    
    # ============================================================================
    # TASK 2: Arthur Jensen - Design System Foundation Definition
    # ============================================================================
    print("\n" + "="*80)
    print("TASK 2: Arthur Jensen - Design System Foundation Definition")
    print("="*80)
    
    arthur_read_memory_task = Task(
        description=(
            f"Before starting the design system definition, read your memory document to understand your current context.\n\n"
            f"**MANDATORY FIRST STEP:**\n"
            f"1. Use the Google Docs Read Tool with your memory_doc_id: {arthur_memory_id}\n"
            f"2. Review the contents of your memory document\n"
            f"3. Note any relevant context or prior design work\n\n"
            f"This ensures you have full context before beginning the design system definition."
        ),
        agent=arthur_agent,
        expected_output="Confirmation that memory document has been read and context understood",
        max_iter=3
    )
    tasks.append(arthur_read_memory_task)
    
    arthur_task_description = (
        f"Define the Design System Foundation for RatioVita_v2.\n\n"
        f"**Your Task:**\n"
        f"1. Use the Cursor Web Browser Tool to research best practices for modern mobile application design systems:\n"
        f"   - Typography standards and accessibility\n"
        f"   - Color palette accessibility standards (WCAG compliance)\n"
        f"   - Component hierarchy and spacing systems\n"
        f"   - Modern design token strategies\n"
        f"2. Create a comprehensive V2 Token Strategy document covering:\n"
        f"   - Color palette (primary, secondary, semantic colors)\n"
        f"   - Typography scale (headings, body, captions)\n"
        f"   - Spacing system (margins, padding, grid)\n"
        f"   - Component hierarchy principles\n"
        f"3. **MANDATORY:** Write the design system document to the V2 Design folder:\n"
        f"   - Use FileWriteTool\n"
        f"   - Path: {V2_DESIGN_FOLDER}/v2_design_token_strategy.md\n"
        f"   - Content: [your complete design system definition]\n"
        f"4. **ALSO MANDATORY:** Write a summary to your memory document:\n"
        f"   - Use Google Docs Memory Tool\n"
        f"   - doc_id: {arthur_memory_id}\n"
        f"   - content: 'V2 Design System Foundation - Summary\\n\\n[summary of key design tokens and principles]'\n"
        f"   - append: True\n"
        f"   - **VERIFY:** You must see SUCCESS message\n\n"
        f"**Document Format:**\n"
        f"- Title: V2 Design Token Strategy\n"
        f"- Date: {datetime.now().strftime('%Y-%m-%d')}\n"
        f"- Agent: Arthur Jensen (Design System Architect)\n"
        f"- Section 1: Color Palette (with accessibility notes)\n"
        f"- Section 2: Typography Scale\n"
        f"- Section 3: Spacing System\n"
        f"- Section 4: Component Hierarchy\n"
        f"- Section 5: Implementation Guidelines\n\n"
        f"**Important:**\n"
        f"- Focus on accessibility and modern best practices\n"
        f"- Design system must be ready for V2 implementation\n"
        f"- Both file and memory document must be updated"
    )
    
    arthur_task = Task(
        description=arthur_task_description,
        agent=arthur_agent,
        expected_output="Confirmation that design system document has been created and summary written to memory",
        context=[arthur_read_memory_task],
        max_iter=30
    )
    tasks.append(arthur_task)
    
    arthur_write_memory_task = Task(
        description=(
            f"After completing the design system definition, update your memory document with the completion status.\n\n"
            f"**MANDATORY FINAL STEP:**\n"
            f"1. Use the Google Docs Memory Tool\n"
            f"2. doc_id: {arthur_memory_id}\n"
            f"3. content: 'BLOCK P Design System Task Completed - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}. "
            f"V2 Design Token Strategy document created at {V2_DESIGN_FOLDER}/v2_design_token_strategy.md. Status: COMPLETED.'\n"
            f"4. append: True\n"
            f"5. Verify you receive SUCCESS message\n\n"
            f"**IMPORTANT:** You must see a SUCCESS message confirming the update was written."
        ),
        agent=arthur_agent,
        expected_output="SUCCESS message confirming completion status written to memory document",
        context=[arthur_task],
        max_iter=3
    )
    tasks.append(arthur_write_memory_task)
    
    # ============================================================================
    # TASK 3: Megan Parker - V2 Branding & Core Value Proposition
    # ============================================================================
    print("\n" + "="*80)
    print("TASK 3: Megan Parker - V2 Branding & Core Value Proposition")
    print("="*80)
    
    megan_read_memory_task = Task(
        description=(
            f"Before starting the branding work, read your memory document to understand your current context.\n\n"
            f"**MANDATORY FIRST STEP:**\n"
            f"1. Use the Google Docs Read Tool with your memory_doc_id: {megan_memory_id}\n"
            f"2. Review the contents of your memory document\n"
            f"3. Note any relevant context or prior branding work\n\n"
            f"This ensures you have full context before beginning the branding task."
        ),
        agent=megan_agent,
        expected_output="Confirmation that memory document has been read and context understood",
        max_iter=3
    )
    tasks.append(megan_read_memory_task)
    
    megan_task_description = (
        f"Develop the V2 Branding Persona and Core Value Proposition.\n\n"
        f"**Your Task:**\n"
        f"1. Based on the intended use and criteria of V2, define the primary target user persona:\n"
        f"   - Demographics and psychographics\n"
        f"   - Pain points and needs\n"
        f"   - User goals and motivations\n"
        f"2. Draft three distinct, testable taglines that clearly articulate the V2 product's core value:\n"
        f"   - Each tagline should target a different aspect of the value proposition\n"
        f"   - Taglines must be clear, memorable, and actionable\n"
        f"   - Include rationale for each tagline\n"
        f"3. Create a comprehensive report titled: **V2 Branding & Value Propositions**\n"
        f"4. **MANDATORY:** Write the report to your memory document:\n"
        f"   - Use Google Docs Memory Tool\n"
        f"   - doc_id: {megan_memory_id}\n"
        f"   - content: [your complete branding and value proposition report]\n"
        f"   - append: True\n"
        f"   - **VERIFY:** You must see SUCCESS message\n\n"
        f"**Report Format:**\n"
        f"- Title: V2 Branding & Value Propositions\n"
        f"- Date: {datetime.now().strftime('%Y-%m-%d')}\n"
        f"- Agent: Megan Parker (CMO)\n"
        f"- Section 1: Primary Target User Persona\n"
        f"- Section 2: Core Value Proposition\n"
        f"- Section 3: Three Testable Taglines (with rationale)\n"
        f"- Section 4: Brand Positioning Strategy\n"
        f"- Section 5: Implementation Recommendations\n\n"
        f"**Important:**\n"
        f"- Focus on clarity and testability\n"
        f"- Taglines must be distinct and actionable\n"
        f"- Report must be ready for Executive Strategy Group meeting"
    )
    
    megan_task = Task(
        description=megan_task_description,
        agent=megan_agent,
        expected_output="Confirmation that branding and value proposition report has been written to memory document",
        context=[megan_read_memory_task],
        max_iter=30
    )
    tasks.append(megan_task)
    
    megan_write_memory_task = Task(
        description=(
            f"After completing the branding work, update your memory document with the completion status.\n\n"
            f"**MANDATORY FINAL STEP:**\n"
            f"1. Use the Google Docs Memory Tool\n"
            f"2. doc_id: {megan_memory_id}\n"
            f"3. content: 'BLOCK P Branding Task Completed - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}. "
            f"V2 Branding & Value Propositions report has been written to this memory document. Status: COMPLETED.'\n"
            f"4. append: True\n"
            f"5. Verify you receive SUCCESS message\n\n"
            f"**IMPORTANT:** You must see a SUCCESS message confirming the update was written."
        ),
        agent=megan_agent,
        expected_output="SUCCESS message confirming completion status written to memory document",
        context=[megan_task],
        max_iter=3
    )
    tasks.append(megan_write_memory_task)
    
    # ============================================================================
    # EXECUTE BLOCK P (CONCURRENT)
    # ============================================================================
    print("\n" + "="*80)
    print(f"🚀 Creating crew with {len(tasks)} tasks (CONCURRENT EXECUTION)...")
    print("="*80)
    
    # Create separate crews for each agent to enable true concurrency
    # Or use Process.hierarchical with independent task groups
    
    # For now, we'll use sequential but with independent task groups
    # In a true concurrent setup, these would run in parallel processes
    
    crew = Crew(
        agents=[dana_agent, samuel_agent, arthur_agent, megan_agent],
        tasks=tasks,
        process=Process.sequential,  # Note: CrewAI sequential, but tasks are independent
        verbose=True,
        max_iter=200,
        max_execution_time=3600  # 1 hour timeout
    )
    
    print("✅ Crew created")
    print("\n" + "="*80)
    print("Starting BLOCK P execution (running concurrently with BLOCK A)...")
    print("="*80 + "\n")
    
    try:
        result = crew.kickoff()
        print("\n" + "="*80)
        print("✅ BLOCK P COMPLETE")
        print("="*80)
        print("\n📊 Results:")
        print(result)
        print("\n" + "="*80)
        print("\n📋 DELIVERABLES:")
        print("="*80)
        print(f"✓ Samuel Reed: V2 Market and Competitive Landscape (in memory: {samuel_memory_id})")
        print(f"✓ Arthur Jensen: V2 Design Token Strategy (file: {V2_DESIGN_FOLDER}/v2_design_token_strategy.md)")
        print(f"✓ Megan Parker: V2 Branding & Value Propositions (in memory: {megan_memory_id})")
        print("="*80)
        print("\n📋 NEXT STEP: David Chen will merge these with Alice's archival report")
        print("="*80)
        return result
    except Exception as e:
        print(f"\n❌ Error during BLOCK P execution: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    block_p_preflight_strategy()

