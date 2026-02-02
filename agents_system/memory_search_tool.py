"""
Memory Search Tool
Searches across all agent memory documents for specific queries.
Essential for competitive analysis, reporting, and cross-agent synthesis.
"""
import os
import re
from typing import Dict, List, Optional
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from main import load_agents_from_yaml, get_agent_metadata
from crewai.tools import tool

SCOPES = ['https://www.googleapis.com/auth/documents.readonly', 'https://www.googleapis.com/auth/drive.readonly']

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

def extract_text_from_document(doc):
    """Extract all text content from a Google Docs document"""
    content = ''
    if 'body' in doc and 'content' in doc['body']:
        for element in doc['body']['content']:
            if 'paragraph' in element:
                para = element['paragraph']
                if 'elements' in para:
                    for elem in para['elements']:
                        if 'textRun' in elem:
                            content += elem['textRun'].get('content', '')
    return content

def isolate_section(content: str, section_name: str) -> str:
    """Extract content from a specific section"""
    section_upper = section_name.upper()
    lines = content.split('\n')
    
    in_section = False
    section_content = []
    
    for line in lines:
        # Check if this is the target section heading
        if section_upper in line.upper() and ('##' in line or '#' in line):
            in_section = True
            section_content.append(line)
            continue
        
        # If we're in the section and hit another section, stop
        if in_section:
            if '##' in line and section_upper not in line.upper():
                break
            section_content.append(line)
    
    return '\n'.join(section_content) if section_content else content

def extract_snippets(content: str, search_query: str, num_results: int = 5, context_chars: int = 200) -> List[str]:
    """Extract relevant snippets around search matches"""
    query_lower = search_query.lower()
    content_lower = content.lower()
    
    snippets = []
    start = 0
    
    while len(snippets) < num_results:
        # Find next occurrence
        index = content_lower.find(query_lower, start)
        if index == -1:
            break
        
        # Extract context around match
        snippet_start = max(0, index - context_chars)
        snippet_end = min(len(content), index + len(search_query) + context_chars)
        
        snippet = content[snippet_start:snippet_end]
        
        # Clean up snippet
        snippet = snippet.strip()
        if snippet and snippet not in snippets:
            snippets.append(snippet)
        
        start = index + 1
    
    return snippets

def build_agent_memory_map():
    """Build a map of agent names to their memory document IDs"""
    agents = load_agents_from_yaml('agents.yaml')
    memory_map = {}
    
    for agent in agents:
        agent_role = agent.role
        agent_meta = get_agent_metadata(agent_role)
        
        # Extract agent name from role or email
        agent_email = agent_meta.get('email_address', '')
        if agent_email:
            # Convert email to name: alice.kim@ratiovita.com -> Alice Kim
            name_parts = agent_email.split('@')[0].split('.')
            agent_name = ' '.join([part.capitalize() for part in name_parts])
        else:
            # Fallback to role
            agent_name = agent_role.split()[0] if agent_role else 'Unknown'
        
        memory_doc_id = agent_meta.get('memory_doc_id', '')
        if memory_doc_id:
            memory_map[agent_name] = memory_doc_id
            memory_map[agent_role] = memory_doc_id  # Also map by role
    
    return memory_map

@tool("Memory Search Tool")
def memory_search_tool(
    search_query: str,
    target_agent: str = "ALL",
    target_section: str = None,
    num_results: int = 5
) -> str:
    """
    Search across agent memory documents for specific content.
    Essential for competitive analysis, reporting, and cross-agent information synthesis.
    
    Args:
        search_query: The keyword or phrase to search for (e.g., "V1 Legacy Archival Report", "Q3 Financials")
        target_agent: Specific agent name (e.g., "Alice Kim", "Samuel Reed") or "ALL" to search all 15 agents
        target_section: Optional section to limit search (e.g., "REPORTS", "MEETINGS", "TASKS", "PROTOCOLS")
        num_results: Maximum number of relevant snippets to return per agent (default: 5)
    
    Returns:
        Formatted search results with agent names and matching snippets, or error message
    """
    if not GOOGLE_DOCS_AVAILABLE:
        return "Error: Google Docs API not available."
    
    try:
        # Get credentials
        creds = get_credentials()
        if not creds:
            return "Error: Could not get credentials. Please authenticate."
        
        docs_service = build('docs', 'v1', credentials=creds)
        
        # Build agent memory map
        agent_memory_map = build_agent_memory_map()
        
        # Determine which documents to search
        if target_agent.upper() == "ALL":
            target_docs = list(agent_memory_map.items())
        elif target_agent in agent_memory_map:
            target_docs = [(target_agent, agent_memory_map[target_agent])]
        else:
            # Try to find by partial match
            matching_agents = [name for name in agent_memory_map.keys() if target_agent.lower() in name.lower()]
            if matching_agents:
                target_docs = [(name, agent_memory_map[name]) for name in matching_agents]
            else:
                return f"Error: Agent '{target_agent}' not found. Available agents: {', '.join(list(agent_memory_map.keys())[:5])}..."
        
        search_results = {}
        
        # Search each target document
        for agent_name, doc_id in target_docs:
            try:
                # Fetch document
                doc = docs_service.documents().get(documentId=doc_id).execute()
                
                # Extract text content
                full_text = extract_text_from_document(doc)
                
                # Filter by section if specified
                if target_section:
                    filtered_text = isolate_section(full_text, target_section)
                else:
                    filtered_text = full_text
                
                # Extract matching snippets
                snippets = extract_snippets(filtered_text, search_query, num_results)
                
                if snippets:
                    search_results[agent_name] = snippets
                    
            except HttpError as e:
                search_results[agent_name] = f"Error accessing memory: {str(e)}"
            except Exception as e:
                search_results[agent_name] = f"Error: {str(e)}"
        
        # Format results
        if not search_results:
            return f"No results found for query: '{search_query}'"
        
        result_text = f"SEARCH RESULTS for '{search_query}':\n"
        result_text += "=" * 80 + "\n\n"
        
        for agent_name, snippets in search_results.items():
            if isinstance(snippets, str) and snippets.startswith("Error"):
                result_text += f"❌ {agent_name}: {snippets}\n\n"
            else:
                result_text += f"📋 {agent_name}:\n"
                for i, snippet in enumerate(snippets, 1):
                    result_text += f"  [{i}] {snippet[:300]}...\n"
                result_text += "\n"
        
        return result_text
        
    except Exception as e:
        return f"Error: Failed to search memory documents - {str(e)}"

# Import GOOGLE_DOCS_AVAILABLE from tools
try:
    from tools import GOOGLE_DOCS_AVAILABLE
except:
    GOOGLE_DOCS_AVAILABLE = True

def get_memory_search_tool():
    """Get the memory search tool instance"""
    return memory_search_tool

