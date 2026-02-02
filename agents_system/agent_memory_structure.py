"""
Agent Memory Document Structure
Standardized organization system using Google Docs headings, sections, and templates
"""
from datetime import datetime

# Universal tabs (all agents use these)
UNIVERSAL_TABS = {
    "Introduction": {
        "description": "Agent profile, role, and basic information",
        "template": "Profile",
        "subsections": []
    },
    "Tasks": {
        "description": "Daily task tracking with date-based subtabs",
        "template": "Task Tracker",
        "subsections": "daily"  # Dynamic - creates date-based subtabs
    },
    "Protocols": {
        "description": "Protocol compliance logs (P0-P12)",
        "template": "Compliance Log",
        "subsections": []
    },
    "Meetings": {
        "description": "Meeting notes, acceptances, and participation",
        "template": "Meeting Notes",
        "subsections": []
    },
    "Reports": {
        "description": "Formal reports and submissions",
        "template": "Report Archive",
        "subsections": []
    }
}

# Role-specific tabs and templates
ROLE_SPECIFIC_TABS = {
    "Admin Assistant & Workflow Funnel": {
        "tabs": ["Workflow Management", "Delegation Log", "Email Archive"],
        "templates": ["Admin", "Task Tracker", "Meeting Notes", "Email Template"]
    },
    "Visionary and Final Decision Maker": {
        "tabs": ["Strategic Vision", "Decision Log", "Executive Summary"],
        "templates": ["Executive", "Strategic Planning", "Decision Matrix"]
    },
    "Process Architect and Schedule Publisher": {
        "tabs": ["Process Documentation", "Schedule Management", "Calendar Events"],
        "templates": ["Process Flow", "Calendar", "Project Timeline"]
    },
    "Technical and Product Visionary": {
        "tabs": ["Technical Architecture", "Product Roadmap", "Engineering Notes"],
        "templates": ["Engineering", "Technical Spec", "Product Requirements"]
    },
    "Financial Guardian and Strategy Modeler": {
        "tabs": ["Financial Analysis", "Budget Tracking", "Financial Reports"],
        "templates": ["Financial", "Budget", "Financial Analysis"]
    },
    "Market Strategist and Voice of the Customer": {
        "tabs": ["Market Research", "Customer Insights", "Competitive Analysis"],
        "templates": ["Marketing", "Market Research", "Customer Analysis"]
    },
    "Legal Compliance and Risk Assessor": {
        "tabs": ["Legal Review", "Compliance Log", "Risk Assessment"],
        "templates": ["Legal", "Compliance", "Risk Matrix"]
    },
    "Lead Code Execution and V2 Development": {
        "tabs": ["Development Log", "Code Review", "Technical Implementation"],
        "templates": ["Engineering", "Code Review", "Technical Spec"]
    },
    "Process and Factual Integrity Auditor": {
        "tabs": ["Audit Log", "Fact Verification", "Quality Assurance"],
        "templates": ["Audit", "Quality Control", "Verification"]
    },
    "Competitive Intelligence Specialist": {
        "tabs": ["Competitive Analysis", "Market Intelligence", "Research Notes"],
        "templates": ["Marketing", "Market Research", "Competitive Analysis"]
    },
    "Documentation and Knowledge Archivist": {
        "tabs": ["Archival Log", "Knowledge Base", "Documentation Index"],
        "templates": ["Documentation", "Archive", "Knowledge Management"]
    },
    "Go-to-Market Strategy": {
        "tabs": ["GTM Planning", "Launch Strategy", "Market Entry"],
        "templates": ["Marketing", "Strategic Planning", "Launch Plan"]
    },
    "Budget and Conflict Guardrail": {
        "tabs": ["Budget Oversight", "Conflict Resolution", "Guardrail Log"],
        "templates": ["Financial", "Budget", "Conflict Management"]
    },
    "Collateral Support and Lead Qualification": {
        "tabs": ["Lead Tracking", "Collateral Management", "Sales Support"],
        "templates": ["Marketing", "Sales", "Lead Management"]
    },
    "External Communication and Trust Builder": {
        "tabs": ["Communication Log", "Trust Building", "External Relations"],
        "templates": ["Marketing", "Communication", "Public Relations"]
    }
}

def get_agent_structure(agent_role: str) -> dict:
    """
    Get the complete tab structure for a specific agent.
    
    Args:
        agent_role: The agent's role name
        
    Returns:
        Dictionary with complete tab structure
    """
    structure = {
        "universal_tabs": UNIVERSAL_TABS.copy(),
        "role_specific_tabs": {}
    }
    
    if agent_role in ROLE_SPECIFIC_TABS:
        role_config = ROLE_SPECIFIC_TABS[agent_role]
        for tab_name in role_config["tabs"]:
            structure["role_specific_tabs"][tab_name] = {
                "description": f"{tab_name} for {agent_role}",
                "template": role_config["templates"][0] if role_config["templates"] else "General",
                "subsections": []
            }
    
    return structure

def generate_document_structure(agent_role: str, agent_name: str, agent_email: str) -> str:
    """
    Generate the initial document structure with all tabs and templates.
    
    Args:
        agent_role: The agent's role
        agent_name: The agent's name
        agent_email: The agent's email
        
    Returns:
        Formatted document structure as string
    """
    structure = get_agent_structure(agent_role)
    today = datetime.now().strftime('%Y-%m-%d')
    
    doc_content = f"""
# {agent_name} - {agent_role}
## Memory Document
**Email:** {agent_email}
**Created:** {datetime.now().strftime('%B %d, %Y')}
**Last Updated:** {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}

---

## 📋 INTRODUCTION
**Template: Profile**

### Agent Profile
- **Name:** {agent_name}
- **Role:** {agent_role}
- **Email:** {agent_email}
- **Status:** Active

### Role Description
[Agent role description and responsibilities]

---

## 📝 TASKS
**Template: Task Tracker**

### {today}
**Date:** {datetime.now().strftime('%B %d, %Y')}

#### Today's Tasks
- [ ] Task 1
- [ ] Task 2

#### Completed Tasks
- [x] Initial setup

#### Notes
[Daily task notes and observations]

---

## 📋 PROTOCOLS
**Template: Compliance Log**

### Protocol Compliance
- **P0:** Assignment Acknowledgment
- **P1:** Memory Audit First
- **P2:** Task Logging & Checkpoint
- **P3:** Task Sign-Off
- **P4:** Pre-Meeting Memory Review
- **P5:** Active Note-Taking & Logging
- **P6:** Formal Inter-Office Request
- **P7:** Collaboration Checkpoint
- **P8:** Meeting Acceptance Acknowledgment
- **P9:** Mandatory Time Zone Standard (EST)
- **P10:** [If applicable]
- **P11:** [If applicable - Dana only]
- **P12:** [If applicable]

### Protocol Log
[Protocol compliance entries will be logged here chronologically]

---

## 🤝 MEETINGS
**Template: Meeting Notes**

### Meeting Log
[Meeting acceptances, notes, and participation will be logged here]

### Meeting Notes
[P5 protocol notes from meetings]

---

## 📊 REPORTS
**Template: Report Archive**

### Submitted Reports
[Formal reports submitted to project.reports@ratiovita.com]

### Report Status
[Report submission and acknowledgment status]

---
"""
    
    # Add role-specific tabs
    if agent_role in ROLE_SPECIFIC_TABS:
        role_config = ROLE_SPECIFIC_TABS[agent_role]
        for tab_name in role_config["tabs"]:
            template = role_config["templates"][0] if role_config["templates"] else "General"
            doc_content += f"""
## {tab_name.upper()}
**Template: {template}**

### {tab_name} Content
[Role-specific content for {tab_name}]

---

"""
    
    return doc_content

def get_section_heading(tab_name: str, subsection: str = None) -> str:
    """
    Get the heading format for a section.
    
    Args:
        tab_name: Main tab name
        subsection: Optional subsection (e.g., date)
        
    Returns:
        Formatted heading string
    """
    if subsection:
        return f"## {tab_name.upper()}\n### {subsection}\n"
    return f"## {tab_name.upper()}\n"

# Template mappings for content formatting
TEMPLATE_FORMATS = {
    "Task Tracker": {
        "format": "### {date}\n#### Today's Tasks\n- [ ] Task\n#### Completed Tasks\n- [x] Task\n#### Notes\n",
        "date_format": "%B %d, %Y"
    },
    "Meeting Notes": {
        "format": "### {meeting_title}\n**Date:** {date}\n**Time:** {time}\n**Status:** {status}\n\n**Notes:**\n",
        "date_format": "%B %d, %Y"
    },
    "Compliance Log": {
        "format": "### {protocol}\n**Date:** {date}\n**Status:** {status}\n**Details:** {details}\n",
        "date_format": "%Y-%m-%d %H:%M:%S EST"
    },
    "Report Archive": {
        "format": "### {report_title}\n**Date:** {date}\n**Status:** {status}\n**Recipient:** {recipient}\n\n**Summary:**\n",
        "date_format": "%B %d, %Y"
    }
}

def format_content_for_template(template_name: str, **kwargs) -> str:
    """
    Format content according to a specific template.
    
    Args:
        template_name: Name of the template
        **kwargs: Template-specific parameters
        
    Returns:
        Formatted content string
    """
    if template_name in TEMPLATE_FORMATS:
        template = TEMPLATE_FORMATS[template_name]
        return template["format"].format(**kwargs)
    return f"{kwargs.get('content', '')}\n"

if __name__ == "__main__":
    # Example usage
    print("Agent Memory Document Structure System")
    print("="*80)
    
    # Test with Alice Kim
    alice_structure = get_agent_structure("Documentation and Knowledge Archivist")
    print("\nAlice Kim Structure:")
    print(f"Universal Tabs: {list(alice_structure['universal_tabs'].keys())}")
    print(f"Role-Specific Tabs: {list(alice_structure['role_specific_tabs'].keys())}")
    
    # Generate document structure
    alice_doc = generate_document_structure(
        "Documentation and Knowledge Archivist",
        "Alice Kim",
        "alice.kim@ratiovita.com"
    )
    print("\n" + "="*80)
    print("Generated Document Structure (first 1000 chars):")
    print("="*80)
    print(alice_doc[:1000])

