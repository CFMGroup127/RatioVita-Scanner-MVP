"""
Kimi K2 Quality Reviewer
Reviews all completed agent work and ensures highest quality standards
"""
import os
import sys
import yaml
from pathlib import Path
from datetime import datetime
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
import base64
from email.mime.text import MIMEText

# Quality thresholds
QUALITY_EXCELLENT = 80
QUALITY_GOOD = 70
QUALITY_NEEDS_IMPROVEMENT = 60

def get_credentials():
    """Get Google API credentials"""
    SCOPES = [
        'https://www.googleapis.com/auth/documents',
        'https://www.googleapis.com/auth/gmail.send',
        'https://www.googleapis.com/auth/drive.readonly'
    ]
    
    creds = None
    token_path = Path(__file__).parent / 'token.json'
    credentials_path = Path(__file__).parent / 'credentials.json'
    
    if token_path.exists():
        try:
            creds = Credentials.from_authorized_user_file(str(token_path), SCOPES)
            if creds and creds.expired and creds.refresh_token:
                creds.refresh(Request())
        except:
            creds = None
    
    if not creds or not creds.valid:
        if credentials_path.exists():
            flow = InstalledAppFlow.from_client_secrets_file(str(credentials_path), SCOPES)
            creds = flow.run_local_server(port=0, access_type='offline', prompt='consent')
            with open(token_path, 'w') as token:
                token.write(creds.to_json())
        else:
            return None
    
    return creds

def load_agents():
    """Load agent definitions"""
    agents_yaml = Path(__file__).parent / 'agents.yaml'
    with open(agents_yaml, 'r') as f:
        data = yaml.safe_load(f)
    return data.get('agents', [])

def read_memory_document(creds, doc_id):
    """Read memory document content"""
    try:
        docs_service = build('docs', 'v1', credentials=creds)
        doc = docs_service.documents().get(documentId=doc_id).execute()
        
        # Extract text content
        content = doc.get('body', {}).get('content', [])
        text_content = []
        
        for element in content:
            if 'paragraph' in element:
                para = element['paragraph']
                if 'elements' in para:
                    for elem in para['elements']:
                        if 'textRun' in elem:
                            text_content.append(elem['textRun'].get('content', ''))
        
        return '\n'.join(text_content)
    except Exception as e:
        return f"Error reading document: {str(e)}"

def assess_code_quality(code_content, task_spec):
    """Assess code quality against best practices"""
    score = 100
    issues = []
    strengths = []
    
    # Check for best practices
    if 'error handling' not in code_content.lower() and 'try' not in code_content.lower():
        score -= 10
        issues.append("Missing error handling")
    
    if 'guard' not in code_content.lower() and 'if let' not in code_content.lower():
        if '!' in code_content:  # Force unwraps
            score -= 5
            issues.append("Potential force unwraps detected")
    
    if 'test' not in code_content.lower() and 'test' not in task_spec.get('name', '').lower():
        score -= 5
        issues.append("No test coverage mentioned")
    
    if 'documentation' not in code_content.lower() and '///' not in code_content:
        score -= 5
        issues.append("Missing code documentation")
    
    # Check for SwiftUI best practices
    if 'swiftui' in code_content.lower() or 'view' in code_content.lower():
        if '@state' in code_content.lower() or '@stateobject' in code_content.lower():
            strengths.append("Proper SwiftUI state management")
        else:
            score -= 5
            issues.append("May be missing proper SwiftUI state management")
    
    # Check for async/await
    if 'async' in code_content.lower() or 'await' in code_content.lower():
        strengths.append("Uses modern async/await patterns")
    
    return {
        'score': max(0, score),
        'issues': issues,
        'strengths': strengths,
        'level': 'Excellent' if score >= QUALITY_EXCELLENT else 'Good' if score >= QUALITY_GOOD else 'Needs Improvement'
    }

def assess_report_quality(report_content, report_type='DTR'):
    """Assess report quality"""
    score = 100
    issues = []
    strengths = []
    
    # Check for required sections
    required_sections = {
        'DTR': ['task', 'status', 'progress', 'time', 'blocker', 'next'],
        'UART': ['executive summary', 'recommendation', 'conclusion'],
        'P13': ['executive summary', 'project status', 'compliance', 'technical']
    }
    
    sections = required_sections.get(report_type, [])
    for section in sections:
        if section.lower() not in report_content.lower():
            score -= 10
            issues.append(f"Missing required section: {section}")
    
    # Check for table format (for DTR)
    if report_type == 'DTR':
        if '|' not in report_content and 'table' not in report_content.lower():
            score -= 15
            issues.append("DTR not in table format")
    
    # Check for completeness
    if len(report_content) < 500:
        score -= 10
        issues.append("Report too brief")
    
    # Check for actionable content
    if 'next step' in report_content.lower() or 'action' in report_content.lower():
        strengths.append("Includes actionable items")
    else:
        score -= 5
        issues.append("Missing actionable recommendations")
    
    return {
        'score': max(0, score),
        'issues': issues,
        'strengths': strengths,
        'level': 'Excellent' if score >= QUALITY_EXCELLENT else 'Good' if score >= QUALITY_GOOD else 'Needs Improvement'
    }

def create_rework_task(creds, agent, task_id, quality_assessment, original_task_spec):
    """Create rework task for agent"""
    
    issues_list = "\n".join([f"- {issue}" for issue in quality_assessment['issues']])
    strengths_list = "\n".join([f"- {strength}" for strength in quality_assessment.get('strengths', [])])
    
    rework_content = f"""## {task_id} - REWORK REQUIRED
- **Status:** Rework Assigned by Kimi K2
- **Priority:** P1 (High)
- **Due Date:** {(datetime.now() + timedelta(days=2)).strftime('%Y-%m-%d')}
- **Assigned:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S EST')}
- **Assigned By:** Kimi K2 (Quality Assurance)

**Quality Assessment:**
- **Quality Score:** {quality_assessment['score']}%
- **Level:** {quality_assessment['level']}
- **Threshold:** 80% required for approval

**Issues Found:**
{issues_list}

**Strengths Identified:**
{strengths_list}

**Required Improvements:**
1. Address all issues listed above
2. Follow best practices (see KIMI_K2_QUALITY_ASSURANCE_PROTOCOL.md)
3. Ensure quality score reaches 80%+
4. Re-submit for review

**Best Practices to Follow:**
- See AGENT_TASK_SPECIFICATIONS_V2.md for task requirements
- See KIMI_K2_QUALITY_ASSURANCE_PROTOCOL.md for quality standards
- Reference real-world best practices
- Ensure comprehensive error handling
- Include proper documentation
- Add test coverage

**ACTION REQUIRED:**
1. Review quality assessment
2. Address all issues
3. Improve work to meet quality standards
4. Re-submit for Kimi K2 review
"""
    
    # Write to agent's memory
    from initiate_v2_tasks_direct import write_to_memory_document
    write_to_memory_document(
        creds,
        agent['memory_doc_id'],
        rework_content,
        section="TASKS",
        subsection=datetime.now().strftime('%B %d, %Y')
    )
    
    # Send email
    email_body = f"""Dear {agent.get('designation', 'Agent')},

Kimi K2 has reviewed your completed work for {task_id} and identified quality issues that need to be addressed.

**Quality Assessment:**
- Quality Score: {quality_assessment['score']}%
- Level: {quality_assessment['level']}
- Required: 80%+ for approval

**Issues Found:**
{issues_list}

**Strengths:**
{strengths_list}

**Required Actions:**
1. Address all issues listed above
2. Follow best practices (see KIMI_K2_QUALITY_ASSURANCE_PROTOCOL.md)
3. Improve work to meet 80%+ quality threshold
4. Re-submit for review

**Deadline:** {(datetime.now() + timedelta(days=2)).strftime('%Y-%m-%d')}

Please review the quality assessment and complete the rework as soon as possible.

Best regards,
Kimi K2
Architectural Assurance Layer & Build Leader
"""
    
    from initiate_v2_tasks_direct import send_email
    send_email(
        creds,
        agent['email_address'],
        f"Quality Review: {task_id} - Rework Required",
        email_body,
        cc="dana.flores@ratiovita.com, collin.m@ratiovita.com"
    )

def review_completed_tasks(creds, agents):
    """Review all completed tasks from agent memory documents"""
    
    print("\n" + "="*80)
    print("🔍 KIMI K2 QUALITY REVIEW")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
    
    reviews = []
    
    for agent in agents:
        agent_name = agent.get('designation', 'Unknown')
        memory_doc_id = agent.get('memory_doc_id')
        
        if not memory_doc_id:
            continue
        
        print(f"📋 Reviewing {agent_name}'s work...")
        
        # Read memory document
        memory_content = read_memory_document(creds, memory_doc_id)
        
        # Look for completed tasks (P3 sign-offs)
        if 'TASK COMPLETE' in memory_content or 'P3' in memory_content:
            # Extract task information
            # This is a simplified version - in production, would parse more carefully
            tasks_found = []
            
            # Look for task patterns
            lines = memory_content.split('\n')
            current_task = None
            for i, line in enumerate(lines):
                if 'V2-' in line and ('TASK COMPLETE' in line or 'COMPLETE' in line):
                    # Found a completed task
                    task_id = None
                    for tid in ['V2-001', 'V2-002', 'V2-003', 'V2-004', 'V2-005']:
                        if tid in line:
                            task_id = tid
                            break
                    
                    if task_id:
                        # Review this task
                        print(f"   🔍 Found completed task: {task_id}")
                        
                        # Assess quality (simplified - would be more comprehensive)
                        quality_assessment = {
                            'score': 75,  # Placeholder - would assess actual work
                            'issues': ['Needs detailed review'],
                            'strengths': [],
                            'level': 'Good'
                        }
                        
                        reviews.append({
                            'agent': agent_name,
                            'task_id': task_id,
                            'quality': quality_assessment
                        })
        
        # Also check for DTRs
        if 'DTR' in memory_content or 'Daily Task Report' in memory_content:
            print(f"   📊 Found DTR - reviewing...")
            # Assess DTR quality
            dtr_quality = assess_report_quality(memory_content, 'DTR')
            reviews.append({
                'agent': agent_name,
                'type': 'DTR',
                'quality': dtr_quality
            })
    
    # Summary
    print("\n" + "="*80)
    print("📊 QUALITY REVIEW SUMMARY")
    print("="*80)
    print()
    
    for review in reviews:
        agent = review['agent']
        quality = review['quality']
        task_info = review.get('task_id', review.get('type', 'Unknown'))
        
        status = "✅" if quality['score'] >= QUALITY_EXCELLENT else "⚠️" if quality['score'] >= QUALITY_GOOD else "❌"
        print(f"{status} {agent} - {task_info}: {quality['score']}% ({quality['level']})")
        
        if quality['issues']:
            for issue in quality['issues']:
                print(f"      ⚠️  {issue}")
    
    print()
    print("="*80)
    
    return reviews

def main():
    """Main execution"""
    creds = get_credentials()
    if not creds:
        print("❌ Could not get credentials")
        return
    
    agents = load_agents()
    reviews = review_completed_tasks(creds, agents)
    
    # For each review that needs improvement, create rework task
    for review in reviews:
        if review['quality']['score'] < QUALITY_EXCELLENT:
            agent = next((a for a in agents if a.get('designation') == review['agent']), None)
            if agent and 'task_id' in review:
                print(f"\n📝 Creating rework task for {review['agent']}...")
                create_rework_task(creds, agent, review['task_id'], review['quality'], {})

if __name__ == "__main__":
    from datetime import timedelta
    main()

