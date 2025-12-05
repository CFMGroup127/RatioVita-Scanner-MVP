"""
System Binder Generator Tool
Synthesis Layer: Transforms 15 individual agent memory documents into a single,
executive-ready Project Binder document.

This tool represents the final intelligence layer, converting raw agent data
into actionable executive intelligence.
"""
import os
import re
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
import sys
import os
# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from main import load_agents_from_yaml, get_agent_metadata
try:
    from memory_search_tool import memory_search_tool, build_agent_memory_map
except ImportError:
    # Fallback if import fails
    def build_agent_memory_map():
        return {}
    def memory_search_tool(*args, **kwargs):
        return "Memory search tool not available"
from crewai.tools import tool
from langchain_openai import ChatOpenAI
from config import Config

SCOPES = [
    'https://www.googleapis.com/auth/documents',
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/documents.readonly'
]

def get_credentials():
    """Get valid user credentials"""
    creds = None
    if os.path.exists('token.json'):
        try:
            creds = Credentials.from_authorized_user_file('token.json', SCOPES)
        except:
            try:
                creds = Credentials.from_authorized_user_file('token.json', None)
                if creds.scopes:
                    has_docs = any('documents' in s or 'drive' in s for s in creds.scopes)
                    if not has_docs:
                        return None
            except:
                return None
    
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            try:
                creds.refresh(Request())
            except:
                return None
    
    return creds

def create_new_google_doc(title: str) -> str:
    """Create a new Google Doc and return its document ID"""
    try:
        creds = get_credentials()
        if not creds:
            raise Exception("Could not get credentials")
        
        docs_service = build('docs', 'v1', credentials=creds)
        drive_service = build('drive', 'v3', credentials=creds)
        
        # Create document
        doc = docs_service.documents().create(body={'title': title}).execute()
        doc_id = doc.get('documentId')
        
        # Set document permissions (make it accessible)
        drive_service.permissions().create(
            fileId=doc_id,
            body={'role': 'writer', 'type': 'user', 'emailAddress': 'collin.m@ratiovita.com'}
        ).execute()
        
        return doc_id
    except Exception as e:
        raise Exception(f"Failed to create Google Doc: {str(e)}")

def write_to_document(doc_id: str, content: str, heading_level: int = 1):
    """Write content to a Google Doc with proper formatting"""
    try:
        creds = get_credentials()
        if not creds:
            raise Exception("Could not get credentials")
        
        docs_service = build('docs', 'v1', credentials=creds)
        
        # Get current document
        doc = docs_service.documents().get(documentId=doc_id).execute()
        end_index = doc['body']['content'][-1]['endIndex'] - 1
        
        # Prepare insert request
        requests = []
        
        # Add heading if specified
        if heading_level > 0:
            heading_text = content.split('\n')[0] if '\n' in content else content[:50]
            requests.append({
                'insertText': {
                    'location': {'index': end_index},
                    'text': heading_text + '\n'
                }
            })
            # Format as heading
            requests.append({
                'updateParagraphStyle': {
                    'range': {
                        'startIndex': end_index,
                        'endIndex': end_index + len(heading_text)
                    },
                    'paragraphStyle': {
                        'namedStyleType': f'HEADING_{heading_level}'
                    }
                }
            })
            # Add remaining content
            remaining_content = content[len(heading_text):].lstrip('\n')
            if remaining_content:
                requests.append({
                    'insertText': {
                        'location': {'index': end_index + len(heading_text) + 1},
                        'text': remaining_content + '\n\n'
                    }
                })
        else:
            # Just insert text
            requests.append({
                'insertText': {
                    'location': {'index': end_index},
                    'text': content + '\n\n'
                }
            })
        
        # Execute batch update
        docs_service.documents().batchUpdate(
            documentId=doc_id,
            body={'requests': requests}
        ).execute()
        
        return True
    except Exception as e:
        raise Exception(f"Failed to write to document: {str(e)}")

def synthesize_with_llm(prompt: str, data: str, max_tokens: int = 1000) -> str:
    """Use LLM to synthesize raw data into executive summary"""
    try:
        llm = ChatOpenAI(
            model=Config.OPENAI_MODEL,
            openai_api_key=Config.OPENAI_API_KEY,
            temperature=0.3  # Lower temperature for more consistent summaries
        )
        
        full_prompt = f"""{prompt}

Raw Data:
{data}

Please provide a concise, executive-level summary based on the above data."""
        
        response = llm.invoke(full_prompt)
        return response.content if hasattr(response, 'content') else str(response)
    except Exception as e:
        # Fallback: return formatted data if LLM fails
        return f"**Data Summary:**\n{data[:500]}...\n\n*Note: LLM synthesis unavailable. Showing raw data.*"

def create_compliance_table(p8_logs: str) -> str:
    """Create a compliance table from P8 logs"""
    lines = p8_logs.split('\n')
    agents_compliant = []
    agents_missing = []
    
    agent_memory_map = build_agent_memory_map()
    all_agents = list(agent_memory_map.keys())
    
    for agent_name in all_agents:
        # Check if agent has P8 log
        agent_found = False
        for line in lines:
            if agent_name.lower() in line.lower() and ('MEETING ACCEPTED' in line.upper() or 'P8' in line.upper()):
                agents_compliant.append(agent_name)
                agent_found = True
                break
        if not agent_found:
            agents_missing.append(agent_name)
    
    table = f"""| Agent | P8 Status | Last Update |
| :--- | :--- | :--- |
"""
    for agent in agents_compliant:
        table += f"| {agent} | ✅ Compliant | Recent |\n"
    for agent in agents_missing:
        table += f"| {agent} | ⚠️ Pending | - |\n"
    
    return table

def format_tasks_by_agent(task_data: str) -> str:
    """Format tasks grouped by agent"""
    lines = task_data.split('\n')
    agent_tasks = {}
    current_agent = None
    
    for line in lines:
        # Try to identify agent from context
        agent_memory_map = build_agent_memory_map()
        for agent_name in agent_memory_map.keys():
            if agent_name.lower() in line.lower():
                current_agent = agent_name
                if current_agent not in agent_tasks:
                    agent_tasks[current_agent] = []
                break
        
        # Check if line contains a task
        if '- [ ]' in line or '- [x]' in line or 'Task:' in line:
            if current_agent:
                agent_tasks[current_agent].append(line.strip())
            else:
                if 'Unassigned' not in agent_tasks:
                    agent_tasks['Unassigned'] = []
                agent_tasks['Unassigned'].append(line.strip())
    
    formatted = ""
    for agent, tasks in agent_tasks.items():
        formatted += f"### {agent}\n"
        for task in tasks[:10]:  # Limit to 10 tasks per agent
            formatted += f"- {task}\n"
        formatted += "\n"
    
    return formatted if formatted else "No active tasks found."

@tool("System Binder Generator")
def system_binder_generator(
    report_title: str,
    time_scope: str = "ALL",
    output_format: str = "GOOGLE_DOC"
) -> str:
    """
    Retrieves, synthesizes, and formats data from all 15 agent memories
    into a single, executive-level Project Binder document.
    
    This is the Synthesis Layer that transforms raw agent data into actionable intelligence.
    
    Args:
        report_title: Title for the Project Binder (e.g., "V2 Planning Status Report")
        time_scope: Time period to include ("ALL", "WEEK", "MONTH", or specific date range)
        output_format: Output format ("GOOGLE_DOC" only currently supported)
    
    Returns:
        URL or document ID of the created Project Binder document
    """
    try:
        current_date = datetime.now().strftime("%Y-%m-%d")
        full_report_title = f"{report_title} - {current_date}"
        
        print(f"📊 Generating Project Binder: {full_report_title}")
        print("="*80)
        
        # 1. INITIALIZE: Create the new document
        print("📄 Creating new Google Doc...")
        binder_doc_id = create_new_google_doc(full_report_title)
        binder_url = f"https://docs.google.com/document/d/{binder_doc_id}/edit"
        print(f"✅ Document created: {binder_url}")
        
        # Write title and TOC
        write_to_document(binder_doc_id, f"# {full_report_title}\n\n**Generated:** {datetime.now().strftime('%B %d, %Y at %I:%M %p EST')}\n\n## Table of Contents\n\n1. Executive Summary\n2. Compliance & Accountability\n3. Project Status (Tasks)\n4. Competitive Landscape\n5. Meeting Archives\n", heading_level=0)
        
        # 2. SECTION I: Executive Summary (Requires Synthesis)
        print("\n📋 Section I: Generating Executive Summary...")
        comp_data = memory_search_tool(
            search_query="V2 Planning competitive analysis",
            target_agent="ALL",
            target_section="REPORTS",
            num_results=20
        )
        decision_data = memory_search_tool(
            search_query="DECISION:",
            target_agent="ALL",
            target_section="MEETINGS",
            num_results=10
        )
        
        raw_data = f"Competitive Data:\n{comp_data}\n\nDecision Data:\n{decision_data}"
        executive_summary = synthesize_with_llm(
            f"Generate a 3-paragraph executive summary for '{full_report_title}'. Focus on V2 readiness status, major competitive gaps, and key decisions made.",
            raw_data
        )
        write_to_document(binder_doc_id, f"# I. Executive Summary\n\n{executive_summary}", heading_level=1)
        print("✅ Executive Summary complete")
        
        # 3. SECTION II: Compliance & Accountability
        print("\n📋 Section II: Compiling Compliance & Accountability...")
        p8_logs = memory_search_tool(
            search_query="MEETING ACCEPTED P8",
            target_agent="ALL",
            target_section="PROTOCOLS",
            num_results=50
        )
        compliance_table = create_compliance_table(p8_logs)
        write_to_document(binder_doc_id, f"# II. Compliance & Accountability\n\n## P8 Meeting Acceptance Status\n\n{compliance_table}\n\n## Protocol Compliance Log\n\n{p8_logs[:2000]}...", heading_level=1)
        print("✅ Compliance section complete")
        
        # 4. SECTION III: Project Status (Tasks)
        print("\n📋 Section III: Compiling Project Status...")
        task_list = memory_search_tool(
            search_query="Task",
            target_agent="ALL",
            target_section="TASKS",
            num_results=100
        )
        master_task_list = format_tasks_by_agent(task_list)
        write_to_document(binder_doc_id, f"# III. Project Status (Tasks)\n\n## Master To-Do List\n\n{master_task_list}", heading_level=1)
        print("✅ Project Status section complete")
        
        # 5. SECTION IV: Competitive Landscape
        print("\n📋 Section IV: Compiling Competitive Landscape...")
        competitive_data = memory_search_tool(
            search_query="COMPETITIVE_ANALYSIS SWOT",
            target_agent="ALL",
            target_section="REPORTS",
            num_results=30
        )
        competitive_summary = synthesize_with_llm(
            "Consolidate all competitive analysis data into a single comparative table and SWOT summary.",
            competitive_data
        )
        write_to_document(binder_doc_id, f"# IV. Competitive Landscape\n\n{competitive_summary}\n\n## Detailed Competitive Data\n\n{competitive_data[:3000]}...", heading_level=1)
        print("✅ Competitive Landscape section complete")
        
        # 6. SECTION V: Meeting Archives
        print("\n📋 Section V: Compiling Meeting Archives...")
        meeting_minutes = memory_search_tool(
            search_query="MEETING MINUTES",
            target_agent="ALL",
            target_section="MEETINGS",
            num_results=20
        )
        transcripts = memory_search_tool(
            search_query="TRANSCRIPT",
            target_agent="ALL",
            target_section="TRANSCRIPTS",
            num_results=10
        )
        write_to_document(binder_doc_id, f"# V. Meeting Archives\n\n## Meeting Minutes\n\n{meeting_minutes[:2000]}...\n\n## Meeting Transcripts\n\n{transcripts[:2000]}...", heading_level=1)
        print("✅ Meeting Archives section complete")
        
        print("\n" + "="*80)
        print(f"✅ PROJECT BINDER GENERATION COMPLETE")
        print("="*80)
        print(f"📄 Document URL: {binder_url}")
        print(f"📋 Document ID: {binder_doc_id}")
        
        return f"SUCCESS: Project Binder created at {binder_url}\nDocument ID: {binder_doc_id}"
        
    except Exception as e:
        error_msg = f"Error generating Project Binder: {str(e)}"
        print(f"❌ {error_msg}")
        import traceback
        traceback.print_exc()
        return error_msg

def get_system_binder_generator():
    """Get the system binder generator tool instance"""
    return system_binder_generator

