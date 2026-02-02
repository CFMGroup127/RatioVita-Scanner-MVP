"""
Kimi K2: Build Leader / Schedule Optimizer
Shifts Kimi K2 from Auditor to Build Leader role for V2 timeline optimization.

This script commands Kimi K2 to:
1. Review all 15 agent memories
2. Review full RatioVita_v2 codebase
3. Review all P13 reports
4. Generate optimized master timeline
5. Compress schedule by identifying parallel execution opportunities
6. Push new tasks/deadlines via P3 Hybrid System
"""
import os
import sys
import yaml
from pathlib import Path
from datetime import datetime
from crewai import Agent, Task, Crew
from config import Config

def get_agent_metadata_local():
    """Get metadata for all agents"""
    yaml_path = Path(__file__).parent / 'agents.yaml'
    with open(yaml_path, 'r') as f:
        data = yaml.safe_load(f)
    return data.get('agents', [])

def get_credentials():
    """Get Google API credentials"""
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from google_auth_oauthlib.flow import InstalledAppFlow
    
    SCOPES = [
        'https://www.googleapis.com/auth/documents',
        'https://www.googleapis.com/auth/drive.readonly',
        'https://www.googleapis.com/auth/documents.readonly'
    ]
    
    creds = None
    if os.path.exists('token.json'):
        creds = Credentials.from_authorized_user_file('token.json', SCOPES)
    
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file('credentials.json', SCOPES)
            creds = flow.run_local_server(port=0)
        
        with open('token.json', 'w') as token:
            token.write(creds.to_json())
    
    return creds

def extract_text_from_document(doc_id, creds):
    """Extract text content from a Google Docs document"""
    from googleapiclient.discovery import build
    
    docs_service = build('docs', 'v1', credentials=creds)
    doc = docs_service.documents().get(documentId=doc_id).execute()
    
    text_content = []
    if 'body' in doc and 'content' in doc['body']:
        for element in doc['body']['content']:
            if 'paragraph' in element:
                para = element['paragraph']
                if 'elements' in para:
                    for elem in para['elements']:
                        if 'textRun' in elem:
                            text_content.append(elem['textRun'].get('content', ''))
    
    return '\n'.join(text_content)

def retrieve_all_agent_memories():
    """Retrieve memory documents from all 15 agents"""
    print("📚 RETRIEVING ALL AGENT MEMORIES...")
    
    creds = get_credentials()
    all_memories = {}
    
    for agent_data in get_agent_metadata_local():
        agent_name = agent_data.get('name', '')
        memory_doc_id = agent_data.get('memory_doc_id', '')
        
        if memory_doc_id:
            try:
                content = extract_text_from_document(memory_doc_id, creds)
                all_memories[agent_name] = {
                    'doc_id': memory_doc_id,
                    'content': content[:50000]  # Limit to 50k chars per agent
                }
                print(f"   ✅ {agent_name}: {len(content)} characters")
            except Exception as e:
                print(f"   ⚠️  {agent_name}: Error - {e}")
                all_memories[agent_name] = {'doc_id': memory_doc_id, 'content': ''}
    
    return all_memories

def retrieve_codebase_content(codebase_path=None):
    """Retrieve and index the RatioVita_v2 codebase"""
    print("📂 RETRIEVING CODEBASE CONTENT...")
    
    if codebase_path is None:
        # Assume we're in agents_system, go up one level
        codebase_path = Path(__file__).parent.parent
    
    codebase_path = Path(codebase_path)
    
    if not codebase_path.exists():
        print(f"   ⚠️  Codebase path not found: {codebase_path}")
        return None, {}
    
    # File types to include
    include_extensions = {'.py', '.swift', '.yaml', '.yml', '.json', '.md', '.txt', '.plist'}
    
    # Directories to exclude
    exclude_dirs = {
        '__pycache__', '.git', 'node_modules', 'venv', 'env', 
        '.venv', 'build', 'dist', '.pytest_cache', '.mypy_cache',
        'Pods', 'xcuserdata', '.swiftpm'
    }
    
    codebase_files = []
    security_related = []
    
    for root, dirs, files in os.walk(codebase_path):
        # Filter out excluded directories
        dirs[:] = [d for d in dirs if d not in exclude_dirs]
        
        for file in files:
            file_path = Path(root) / file
            
            # Check extension
            if file_path.suffix in include_extensions:
                codebase_files.append(file_path)
                
                # Identify security/compliance related files
                if any(keyword in str(file_path).lower() for keyword in 
                       ['security', 'auth', 'oauth', 'compliance', 'ccpa', 'gdpr', 'privacy']):
                    security_related.append(str(file_path))
    
    # Read and index files
    codebase_summary = []
    total_size = 0
    
    for file_path in codebase_files[:200]:  # Limit to 200 files
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                total_size += len(content)
                codebase_summary.append(f"File: {file_path.relative_to(codebase_path)}\nSize: {len(content)} chars\n---\n")
        except Exception as e:
            pass
    
    codebase_index = {
        'total_files': len(codebase_files),
        'indexed_files': len(codebase_summary),
        'total_size': total_size,
        'security_related': security_related
    }
    
    print(f"   ✅ Indexed {len(codebase_summary)} files ({total_size:,} characters)")
    print(f"   ✅ Security-related files: {len(security_related)}")
    
    return '\n'.join(codebase_summary[:50]), codebase_index

def retrieve_p13_reports():
    """Retrieve all P13 Executive Strategy Reports from Dana's memory"""
    print("📊 RETRIEVING P13 REPORTS...")
    
    creds = get_credentials()
    p13_reports = []
    
    # Find Dana Flores
    dana_meta = None
    for agent_data in get_agent_metadata_local():
        if "Admin Assistant" in agent_data.get('role', '') or "Workflow Funnel" in agent_data.get('role', ''):
            dana_meta = agent_data
            break
    
    if dana_meta:
        memory_doc_id = dana_meta.get('memory_doc_id', '')
        if memory_doc_id:
            try:
                content = extract_text_from_document(memory_doc_id, creds)
                # Extract P13 reports from REPORTS section
                if 'P13' in content or 'Executive Strategy Report' in content:
                    p13_reports.append({
                        'source': 'Dana Flores',
                        'content': content
                    })
                    print(f"   ✅ Found P13 reports in Dana's memory")
            except Exception as e:
                print(f"   ⚠️  Error retrieving P13 reports: {e}")
    
    return p13_reports

def kimi_k2_build_leader():
    """
    Command Kimi K2 to shift to Build Leader role and optimize V2 timeline.
    """
    print("\n" + "="*80)
    print("🚀 KIMI K2: BUILD LEADER / SCHEDULE OPTIMIZER")
    print("="*80)
    print("Role Shift: Auditor → Build Leader / Schedule Optimizer")
    print("="*80)
    print()
    
    # Validate configuration
    try:
        Config.validate()
        print("✅ Configuration validated")
    except ValueError as e:
        print(f"❌ Configuration Error: {e}")
        return None
    
    os.environ['OPENAI_API_KEY'] = Config.OPENAI_API_KEY
    
    # Step 1: Retrieve all context
    print("📋 GATHERING COMPREHENSIVE CONTEXT...")
    print()
    
    # Retrieve agent memories
    all_memories = retrieve_all_agent_memories()
    print(f"✅ Retrieved {len(all_memories)} agent memory documents")
    print()
    
    # Retrieve codebase
    codebase_summary, codebase_index = retrieve_codebase_content()
    if codebase_summary:
        print(f"✅ Codebase indexed: {codebase_index['total_files']} files")
        print()
    
    # Retrieve P13 reports
    p13_reports = retrieve_p13_reports()
    print(f"✅ Retrieved {len(p13_reports)} P13 reports")
    print()
    
    # Format context for Kimi K2
    context_string = f"""
# COMPREHENSIVE PROJECT CONTEXT FOR BUILD LEADERSHIP

## AGENT MEMORIES ({len(all_memories)} agents)
"""
    for agent_name, memory_data in all_memories.items():
        context_string += f"\n### {agent_name}\n{memory_data['content'][:5000]}\n---\n"
    
    if codebase_summary:
        context_string += f"\n## CODEBASE SUMMARY\n{codebase_summary[:20000]}\n---\n"
    
    if p13_reports:
        for report in p13_reports:
            context_string += f"\n## P13 EXECUTIVE STRATEGY REPORT\n{report['content'][:10000]}\n---\n"
    
    print(f"📊 Total Context: {len(context_string.split())} words")
    print()
    
    # Step 2: Load tools for Kimi K2
    from tools import get_gmail_tool, get_google_docs_memory_tool, get_google_tasks_tool
    
    kimi_k2_tools = []
    try:
        kimi_k2_tools.append(get_gmail_tool(agent_role="Kimi K2 - Build Leader"))
    except:
        pass
    try:
        kimi_k2_tools.append(get_google_docs_memory_tool())
    except:
        pass
    try:
        kimi_k2_tools.append(get_google_tasks_tool())
    except:
        pass
    
    # Step 3: Define Kimi K2 as Build Leader
    kimi_k2_agent = Agent(
        role="Build Leader / Schedule Optimizer",
        goal="Optimize the RatioVita V2 development timeline by identifying parallel execution opportunities, compressing deadlines, and generating an optimized master task schedule. Push updated tasks via P3 Hybrid System.",
        backstory="""You are the Build Leader for the RatioVita V2 project. Your primary responsibility is to 
optimize the development timeline by:

1. Analyzing all current tasks, dependencies, and deadlines across all 15 agents
2. Identifying opportunities for parallel execution
3. Compressing the timeline to the minimum viable schedule
4. Generating an optimized master task list with new, compressed deadlines
5. Pushing updated tasks via the P3 Hybrid System (Memory Documents + Google Tasks)

You have complete visibility into:
- All 15 agent memory documents (tasks, protocols, meetings, reports)
- The full RatioVita_v2 codebase
- All P13 Executive Strategy Reports

Your analysis must be strategic, realistic, and actionable. You must balance:
- Aggressive timeline compression
- Realistic resource constraints
- Critical path dependencies
- Risk mitigation

After generating the optimized timeline, you must:
1. Create a P13 Timeline Addendum report explaining the compression strategy
2. Send the report via email to collin.m@ratiovita.com
3. Push new tasks/deadlines via P3 Hybrid System to respective agents""",
        tools=kimi_k2_tools if kimi_k2_tools else None,
        verbose=True,
        allow_delegation=False,
        max_iter=10,
        max_execution_time=600
    )
    
    # Step 4: Define Build Leadership Task
    build_leader_task_description = f"""
**BUILD LEADERSHIP MANDATE: V2 TIMELINE OPTIMIZATION**

You are now operating as the Build Leader / Schedule Optimizer for RatioVita V2.

**YOUR MISSION:**
Generate an optimized master timeline that compresses the V2 development schedule to the minimum viable timeline while maintaining quality and addressing all critical dependencies.

**CONTEXT PROVIDED:**
{context_string[:50000]}

**REQUIRED OUTPUTS:**

## 1. OPTIMIZED MASTER TASK LIST

Create a comprehensive, prioritized task list with:
- **Task Name**: Clear, actionable task description
- **Assigned Agent**: Which agent is responsible
- **Original Deadline**: Current deadline from agent memories
- **Optimized Deadline**: New compressed deadline
- **Dependencies**: What must be completed first
- **Parallel Execution**: Tasks that can run simultaneously
- **Critical Path**: Tasks that block other work
- **Compression Strategy**: How the deadline was compressed (parallel execution, dependency optimization, etc.)

## 2. P13 TIMELINE ADDENDUM REPORT

Generate a detailed report explaining:
- **Current Timeline Analysis**: Summary of current deadlines and dependencies
- **Optimization Opportunities Identified**: Parallel execution, dependency optimization, resource reallocation
- **Compression Strategy**: How you compressed the timeline
- **Risk Assessment**: Risks introduced by compression and mitigation strategies
- **New Master Schedule**: The optimized timeline with all compressed deadlines
- **Implementation Plan**: How to roll out the new schedule

## 3. P3 HYBRID SYSTEM TASK PUSHES

After generating the optimized timeline, you MUST push updated tasks to agents via the P3 Hybrid System:

For each agent with updated deadlines:
1. **Memory Document Update**: Update the agent's TASKS section with new deadlines
2. **Google Tasks Update**: Create/update tasks in Google Tasks with new due dates

**CRITICAL:** You must use the P3 Hybrid System tools to push these updates. Do not just list them - actually execute the tool calls.

## 4. EMAIL ALERT

Send the complete P13 Timeline Addendum Report via email to:
- **To**: collin.m@ratiovita.com
- **CC**: david.chen@ratiovita.com, dana.flores@ratiovita.com
- **Subject**: [BUILD LEADER] V2 Optimized Master Timeline - {datetime.now().strftime('%B %d, %Y')}
- **Body**: Full P13 Timeline Addendum Report

**EXECUTION PRIORITY:**
1. Analyze all tasks and dependencies
2. Generate optimized master timeline
3. Create P13 Timeline Addendum Report
4. Push updated tasks via P3 Hybrid System
5. Send email alert with full report

**CRITICAL:** This is a comprehensive, computationally intensive task. Take your time to analyze all dependencies and identify the maximum compression opportunities while maintaining project quality.
"""
    
    build_leader_task = Task(
        description=build_leader_task_description,
        agent=kimi_k2_agent,
        expected_output="Optimized Master Task List with compressed deadlines, P13 Timeline Addendum Report, updated tasks pushed via P3 Hybrid System, and email alert sent to stakeholders"
    )
    
    # Step 5: Execute Build Leadership
    print("🚀 EXECUTING BUILD LEADERSHIP MANDATE...")
    print("="*80)
    print()
    
    try:
        crew = Crew(
            agents=[kimi_k2_agent],
            tasks=[build_leader_task],
            verbose=True
        )
        
        result = crew.kickoff()
        
        print("\n" + "="*80)
        print("✅ BUILD LEADERSHIP MANDATE COMPLETE")
        print("="*80)
        print(f"\nResult:\n{result}")
        print()
        
        # Step 6: Save report
        try:
            report_file = Path(__file__).parent / f"KIMI_K2_BUILD_LEADER_REPORT_{datetime.now().strftime('%Y%m%d_%H%M%S')}.md"
            with open(report_file, 'w') as f:
                f.write(f"# KIMI K2 BUILD LEADER REPORT\n")
                f.write(f"**Date:** {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
                f.write(f"**Role:** Build Leader / Schedule Optimizer\n\n")
                f.write("---\n\n")
                f.write(str(result))
            print(f"✅ Full report saved to: {report_file.name}")
        except Exception as e:
            print(f"⚠️  Warning: Could not save report to file: {e}")
        
        return result
        
    except Exception as e:
        print("\n" + "="*80)
        print("❌ BUILD LEADERSHIP MANDATE FAILED")
        print("="*80)
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    kimi_k2_build_leader()

