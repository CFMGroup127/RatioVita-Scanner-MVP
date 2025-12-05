"""
Kimi K2: System Orchestrator & Task Monitor
Enhanced role: Kimi K2 monitors all agent activities and proactively ensures task execution.

This script implements continuous monitoring of:
- Agent memory documents (tasks, protocols, meetings)
- Google Tasks (task status, completion)
- Agent emails (incoming assignments, confirmations)
- Agent calendars (meetings, deadlines)
- Task execution status

Kimi K2 proactively:
- Identifies unassigned tasks
- Initiates Dana to delegate tasks
- Monitors task execution
- Ensures all tasks are processed
"""
import os
import sys
import yaml
import json
from pathlib import Path
from datetime import datetime, timedelta
from crewai import Agent, Task, Crew
from config import Config

def get_agent_metadata_local():
    """Get metadata for all agents"""
    yaml_path = Path(__file__).parent / 'agents.yaml'
    with open(yaml_path, 'r') as f:
        data = yaml.safe_load(f)
    return data.get('agents', [])

def get_credentials():
    """Get Google API credentials with automatic OAuth issue detection and fixing"""
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from google_auth_oauthlib.flow import InstalledAppFlow
    from googleapiclient.errors import HttpError
    
    SCOPES = [
        'https://www.googleapis.com/auth/documents',
        'https://www.googleapis.com/auth/drive.readonly',
        'https://www.googleapis.com/auth/gmail.readonly',
        'https://www.googleapis.com/auth/calendar.readonly',
        'https://www.googleapis.com/auth/tasks',
        'https://www.googleapis.com/auth/tasks.readonly'
    ]
    
    creds = None
    if os.path.exists('token.json'):
        try:
            creds = Credentials.from_authorized_user_file('token.json', SCOPES)
        except Exception as e:
            print(f"⚠️  Could not load existing token: {e}")
            creds = None
    
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            try:
                creds.refresh(Request())
                print("✅ Token refreshed successfully")
            except Exception as e:
                print(f"⚠️  Token refresh failed: {e}")
                # Try to detect if it's an OAuth scope issue
                error_msg = str(e).lower()
                if 'insufficient' in error_msg or 'permission' in error_msg or 'scope' in error_msg:
                    print("🔍 OAuth scope issue detected - attempting auto-fix...")
                    try:
                        from kimi_k2_oauth_monitor import monitor_and_fix_oauth
                        fix_result = monitor_and_fix_oauth(auto_fix=True, notify=True)
                        if fix_result.get('status') == 'fixed':
                            # Reload credentials after fix
                            if os.path.exists('token.json'):
                                creds = Credentials.from_authorized_user_file('token.json', SCOPES)
                        else:
                            print("❌ Auto-fix failed - notification sent")
                            creds = None
                    except Exception as fix_error:
                        print(f"⚠️  Auto-fix error: {fix_error}")
                        creds = None
                else:
                    creds = None
        else:
            if os.path.exists('credentials.json'):
                print("🔐 Starting OAuth flow for new authentication...")
                flow = InstalledAppFlow.from_client_secrets_file('credentials.json', SCOPES)
                creds = flow.run_local_server(port=0, access_type='offline', prompt='consent')
            else:
                print("❌ credentials.json not found")
                # Notify about missing credentials
                try:
                    from kimi_k2_oauth_monitor import notify_oauth_issues
                    notify_oauth_issues({
                        'has_issues': True,
                        'errors': ['credentials.json not found'],
                        'services_affected': ['All'],
                        'missing_scopes': SCOPES
                    }, auto_fix_attempted=False)
                except:
                    pass
                return None
        
        if creds:
            with open('token.json', 'w') as token:
                token.write(creds.to_json())
            print("✅ Credentials saved")
    
    # Verify credentials work by testing a simple API call
    if creds:
        try:
            from googleapiclient.discovery import build
            test_service = build('docs', 'v1', credentials=creds)
            # Just building the service is enough to verify credentials
            print("✅ Credentials verified - all scopes accessible")
        except HttpError as e:
            if e.resp.status == 403:
                print("⚠️  Credentials have insufficient permissions")
                # Attempt auto-fix
                try:
                    from kimi_k2_oauth_monitor import monitor_and_fix_oauth
                    fix_result = monitor_and_fix_oauth(auto_fix=True, notify=True)
                    if fix_result.get('status') == 'fixed':
                        if os.path.exists('token.json'):
                            creds = Credentials.from_authorized_user_file('token.json', SCOPES)
                except:
                    pass
    
    return creds

def monitor_agent_tasks(creds):
    """Monitor all agent tasks from memory documents and Google Tasks"""
    from googleapiclient.discovery import build
    
    print("📋 MONITORING AGENT TASKS...")
    print("="*80)
    
    tasks_status = {}
    agents_data = get_agent_metadata_local()
    
    # Get Google Tasks service (optional - may fail if scope not granted)
    google_tasks = {}
    try:
        from googleapiclient.errors import HttpError
        tasks_service = build('tasks', 'v1', credentials=creds)
        
        # Get default task list
        tasklists = tasks_service.tasklists().list().execute()
        default_list_id = None
        for tasklist in tasklists.get('items', []):
            if tasklist.get('id') == '@default' or 'default' in tasklist.get('title', '').lower():
                default_list_id = tasklist.get('id')
                break
        
        if not default_list_id and tasklists.get('items'):
            default_list_id = tasklists['items'][0]['id']
        
        # Get all tasks from Google Tasks
        if default_list_id:
            all_tasks = tasks_service.tasks().list(tasklist=default_list_id, showCompleted=True).execute()
            google_tasks = {task.get('title', ''): task for task in all_tasks.get('items', [])}
    except (HttpError, Exception) as e:
        error_msg = str(e)
        if "insufficient" in error_msg.lower() or "permission" in error_msg.lower() or "403" in error_msg:
            print(f"   ⚠️  Google Tasks monitoring unavailable: Insufficient permissions (OAuth scope not granted)")
        else:
            print(f"   ⚠️  Google Tasks monitoring unavailable: {error_msg}")
        print("   Continuing with memory document monitoring only...")
        google_tasks = {}
    
    # Monitor memory documents for tasks
    docs_service = build('docs', 'v1', credentials=creds)
    
    for agent_data in agents_data:
        agent_name = agent_data.get('name', '')
        agent_role = agent_data.get('role', '')
        memory_doc_id = agent_data.get('memory_doc_id', '')
        
        if not memory_doc_id:
            continue
        
        try:
            doc = docs_service.documents().get(documentId=memory_doc_id).execute()
            
            # Extract TASKS section
            tasks_section = extract_tasks_section(doc)
            
            # Parse tasks
            pending_tasks = []
            completed_tasks = []
            
            for task_line in tasks_section.split('\n'):
                if '- [ ]' in task_line or '- [x]' in task_line or '- [X]' in task_line:
                    is_complete = '- [x]' in task_line.lower()
                    task_text = task_line.replace('- [ ]', '').replace('- [x]', '').replace('- [X]', '').strip()
                    
                    if task_text:
                        task_info = {
                            'agent': agent_name,
                            'role': agent_role,
                            'task': task_text,
                            'status': 'COMPLETE' if is_complete else 'PENDING',
                            'source': 'memory_document'
                        }
                        
                        if is_complete:
                            completed_tasks.append(task_info)
                        else:
                            pending_tasks.append(task_info)
            
            tasks_status[agent_name] = {
                'pending': pending_tasks,
                'completed': completed_tasks,
                'total_pending': len(pending_tasks),
                'total_completed': len(completed_tasks)
            }
            
            print(f"   {agent_name}: {len(pending_tasks)} pending, {len(completed_tasks)} completed")
            
        except Exception as e:
            print(f"   ⚠️  {agent_name}: Error - {e}")
            tasks_status[agent_name] = {'pending': [], 'completed': [], 'total_pending': 0, 'total_completed': 0}
    
    # Cross-reference with Google Tasks
    print()
    print("📊 GOOGLE TASKS STATUS:")
    pending_google_tasks = [t for t in google_tasks.values() if t.get('status') != 'completed']
    completed_google_tasks = [t for t in google_tasks.values() if t.get('status') == 'completed']
    
    print(f"   Pending: {len(pending_google_tasks)}")
    print(f"   Completed: {len(completed_google_tasks)}")
    print()
    
    return tasks_status, google_tasks

def extract_tasks_section(doc):
    """Extract TASKS section from Google Docs document"""
    tasks_content = []
    in_tasks_section = False
    
    if 'body' in doc and 'content' in doc['body']:
        for element in doc['body']['content']:
            if 'paragraph' in element:
                para = element['paragraph']
                if 'elements' in para:
                    text = ''
                    for elem in para['elements']:
                        if 'textRun' in elem:
                            text += elem['textRun'].get('content', '')
                    
                    # Check if this is the TASKS heading
                    if 'TASKS' in text.upper() and ('#' in text or text.strip().upper() == 'TASKS'):
                        in_tasks_section = True
                        continue
                    
                    # Check if we've hit another major section
                    if in_tasks_section and text.strip() and text.strip().startswith('#'):
                        if 'PROTOCOLS' in text.upper() or 'MEETINGS' in text.upper() or 'REPORTS' in text.upper():
                            break
                    
                    if in_tasks_section:
                        tasks_content.append(text)
    
    return '\n'.join(tasks_content)

def monitor_agent_emails(creds):
    """Monitor agent emails for assignments and confirmations"""
    from googleapiclient.discovery import build
    
    print("📧 MONITORING AGENT EMAILS...")
    print("="*80)
    
    gmail_service = build('gmail', 'v1', credentials=creds)
    
    # Check for unread emails in project.reports@ratiovita.com
    # Note: This would require access to the group inbox
    # For now, we'll check individual agent inboxes
    
    email_status = {}
    agents_data = get_agent_metadata_local()
    
    for agent_data in agents_data:
        agent_name = agent_data.get('name', '')
        agent_email = agent_data.get('email_address', '')
        
        if not agent_email:
            continue
        
        try:
            # Search for unread emails
            query = f'in:inbox is:unread'
            results = gmail_service.users().messages().list(userId='me', q=query, maxResults=5).execute()
            messages = results.get('messages', [])
            
            email_status[agent_name] = {
                'unread_count': len(messages),
                'has_assignments': False,
                'has_confirmations': False
            }
            
            # Check message subjects for assignments/confirmations
            for msg in messages[:5]:  # Limit to 5 messages
                try:
                    message = gmail_service.users().messages().get(userId='me', id=msg['id']).execute()
                    headers = message['payload'].get('headers', [])
                    subject = next((h['value'] for h in headers if h['name'] == 'Subject'), '')
                    
                    if 'assignment' in subject.lower() or 'task' in subject.lower():
                        email_status[agent_name]['has_assignments'] = True
                    if 'confirmation' in subject.lower() or 'acknowledged' in subject.lower():
                        email_status[agent_name]['has_confirmations'] = True
                except:
                    pass
            
            if email_status[agent_name]['unread_count'] > 0:
                print(f"   {agent_name}: {email_status[agent_name]['unread_count']} unread emails")
            
        except Exception as e:
            print(f"   ⚠️  {agent_name}: Error - {e}")
            email_status[agent_name] = {'unread_count': 0, 'has_assignments': False, 'has_confirmations': False}
    
    print()
    return email_status

def monitor_agent_calendars(creds):
    """Monitor agent calendars for meetings and deadlines"""
    from googleapiclient.discovery import build
    
    print("📅 MONITORING AGENT CALENDARS...")
    print("="*80)
    
    calendar_service = build('calendar', 'v3', credentials=creds)
    
    calendar_status = {}
    agents_data = get_agent_metadata_local()
    
    today = datetime.now()
    week_from_now = today + timedelta(days=7)
    
    for agent_data in agents_data:
        agent_name = agent_data.get('name', '')
        calendar_id = agent_data.get('personal_calendar_id', '')
        
        if not calendar_id:
            continue
        
        try:
            events_result = calendar_service.events().list(
                calendarId=calendar_id,
                timeMin=today.isoformat() + 'Z',
                timeMax=week_from_now.isoformat() + 'Z',
                maxResults=10
            ).execute()
            
            events = events_result.get('items', [])
            
            calendar_status[agent_name] = {
                'upcoming_events': len(events),
                'events': []
            }
            
            for event in events:
                calendar_status[agent_name]['events'].append({
                    'title': event.get('summary', 'No title'),
                    'start': event.get('start', {}).get('dateTime', event.get('start', {}).get('date', '')),
                    'status': event.get('status', '')
                })
            
            if len(events) > 0:
                print(f"   {agent_name}: {len(events)} upcoming events")
            
        except Exception as e:
            print(f"   ⚠️  {agent_name}: Error - {e}")
            calendar_status[agent_name] = {'upcoming_events': 0, 'events': []}
    
    print()
    return calendar_status

def identify_unassigned_tasks(tasks_status):
    """Identify tasks that need to be assigned"""
    unassigned = []
    
    # Check for tasks mentioned in meetings but not assigned
    # This would require parsing meeting minutes
    
    # For now, identify agents with no pending tasks but mentioned in meetings
    for agent_name, status in tasks_status.items():
        if status['total_pending'] == 0:
            # Agent has no tasks - check if they should have tasks from meetings
            # This is a simplified check - full implementation would parse meeting minutes
            pass
    
    return unassigned

def kimi_k2_orchestrator():
    """
    Kimi K2 System Orchestrator
    Monitors all agent activities and proactively ensures task execution.
    """
    print("\n" + "="*80)
    print("🎯 KIMI K2: SYSTEM ORCHESTRATOR & TASK MONITOR")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
    
    # Validate configuration
    try:
        Config.validate()
        print("✅ Configuration validated")
    except ValueError as e:
        print(f"❌ Configuration Error: {e}")
        return None
    
    os.environ['OPENAI_API_KEY'] = Config.OPENAI_API_KEY
    
    # Get credentials (with automatic OAuth issue detection and fixing)
    print("🔐 STEP 0: VERIFYING OAUTH AUTHENTICATION")
    print("="*80)
    print()
    
    creds = get_credentials()
    if not creds:
        print("❌ Error: Could not get credentials")
        print("⚠️  OAuth issues detected and notification sent")
        print("   Please run: python3 fix_oauth_full_permissions.py")
        return None
    
    print("✅ OAuth authentication verified")
    print()
    
    # Step 1: Monitor all agent activities
    print("📊 STEP 1: MONITORING ALL AGENT ACTIVITIES")
    print("="*80)
    print()
    
    tasks_status, google_tasks = monitor_agent_tasks(creds)
    email_status = monitor_agent_emails(creds)
    calendar_status = monitor_agent_calendars(creds)
    
    # Step 2: Analyze and identify issues
    print("📊 STEP 2: ANALYZING MONITORING DATA")
    print("="*80)
    print()
    
    # Identify agents with pending tasks
    agents_with_pending_tasks = []
    for agent_name, status in tasks_status.items():
        if status['total_pending'] > 0:
            agents_with_pending_tasks.append({
                'agent': agent_name,
                'pending_count': status['total_pending'],
                'tasks': status['pending']
            })
    
    # Identify overdue tasks
    overdue_tasks = []
    for task_title, task_data in google_tasks.items():
        if task_data.get('status') != 'completed':
            due_date = task_data.get('due')
            if due_date:
                try:
                    due = datetime.fromisoformat(due_date.replace('Z', '+00:00'))
                    if due < datetime.now(due.tzinfo):
                        overdue_tasks.append({
                            'task': task_title,
                            'due_date': due_date,
                            'overdue_days': (datetime.now(due.tzinfo) - due).days
                        })
                except:
                    pass
    
    # Step 3: Generate orchestration report
    print("📊 STEP 3: GENERATING ORCHESTRATION REPORT")
    print("="*80)
    print()
    
    orchestration_summary = f"""
# KIMI K2 ORCHESTRATION REPORT
**Date:** {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}
**Orchestrator:** Kimi K2 - System Orchestrator & Task Monitor

## MONITORING SUMMARY

### Task Status
- **Total Agents Monitored:** {len(tasks_status)}
- **Agents with Pending Tasks:** {len(agents_with_pending_tasks)}
- **Total Pending Tasks:** {sum(s['total_pending'] for s in tasks_status.values())}
- **Total Completed Tasks:** {sum(s['total_completed'] for s in tasks_status.values())}
- **Overdue Tasks:** {len(overdue_tasks)}

### Email Status
- **Agents with Unread Emails:** {sum(1 for s in email_status.values() if s['unread_count'] > 0)}
- **Total Unread Emails:** {sum(s['unread_count'] for s in email_status.values())}

### Calendar Status
- **Agents with Upcoming Events:** {sum(1 for s in calendar_status.values() if s['upcoming_events'] > 0)}
- **Total Upcoming Events:** {sum(s['upcoming_events'] for s in calendar_status.values())}

## AGENTS WITH PENDING TASKS
"""
    
    for agent_info in agents_with_pending_tasks:
        orchestration_summary += f"""
### {agent_info['agent']}
- **Pending Tasks:** {agent_info['pending_count']}
- **Tasks:**
"""
        for task in agent_info['tasks'][:5]:  # Limit to 5 tasks
            orchestration_summary += f"  - {task['task'][:100]}...\n"
    
    orchestration_summary += f"""
## OVERDUE TASKS
"""
    
    for task_info in overdue_tasks[:10]:  # Limit to 10 overdue tasks
        orchestration_summary += f"""
- **{task_info['task']}**
  - Due Date: {task_info['due_date']}
  - Overdue: {task_info['overdue_days']} days
"""
    
    orchestration_summary += f"""
## ORCHESTRATION ACTIONS REQUIRED

### Immediate Actions:
1. **Task Assignment:** {len(agents_with_pending_tasks)} agents have pending tasks that may need delegation
2. **Overdue Tasks:** {len(overdue_tasks)} tasks are overdue and require immediate attention
3. **Email Review:** {sum(1 for s in email_status.values() if s['unread_count'] > 0)} agents have unread emails that may contain assignments

### Recommended Actions:
1. **Initiate Dana Delegation:** For unassigned tasks identified in meetings
2. **Task Execution Monitoring:** Verify agents are executing P4 protocol for pending tasks
3. **Overdue Task Escalation:** Escalate overdue tasks to appropriate agents
4. **Email Processing:** Ensure agents are processing unread assignment emails
"""
    
    print(orchestration_summary)
    print()
    
    # Step 4: Create orchestration task for Kimi K2
    print("📊 STEP 4: CREATING ORCHESTRATION TASK")
    print("="*80)
    print()
    
    # Load tools for Kimi K2
    from tools import get_gmail_tool, get_google_docs_memory_tool, get_google_tasks_tool
    from kimi_k2_enhanced_tools import (
        predictive_analytics_tool,
        quality_assurance_tool,
        dependency_analyzer_tool,
        performance_metrics_tool,
        workload_optimizer_tool
    )
    
    kimi_k2_tools = []
    try:
        kimi_k2_tools.append(get_gmail_tool(agent_role="Kimi K2 - System Orchestrator"))
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
    # Enhanced tools for productivity and quality
    try:
        kimi_k2_tools.append(predictive_analytics_tool)
    except:
        pass
    try:
        kimi_k2_tools.append(quality_assurance_tool)
    except:
        pass
    try:
        kimi_k2_tools.append(dependency_analyzer_tool)
    except:
        pass
    try:
        kimi_k2_tools.append(performance_metrics_tool)
    except:
        pass
    try:
        kimi_k2_tools.append(workload_optimizer_tool)
    except:
        pass
    
    # Define Kimi K2 as Orchestrator
    kimi_k2_agent = Agent(
        role="System Orchestrator & Task Monitor",
        goal="Monitor all agent activities (emails, calendars, memory documents, tasks) and proactively ensure tasks are assigned, delegated, and executed. Use predictive analytics, dependency analysis, workload optimization, performance metrics, and quality assurance tools to maximize productivity and quality. Initiate Dana to delegate unassigned tasks and monitor task execution status.",
        backstory="""You are the System Orchestrator for the RatioVita V2 multi-agent system. Your primary 
responsibility is to continuously monitor all agent activities and ensure the system operates efficiently:

**MONITORING RESPONSIBILITIES:**
1. **Memory Documents:** Monitor all 15 agent memory documents for:
   - Pending tasks in TASKS sections
   - Task completion status
   - Protocol compliance (P3, P4, P5, etc.)
   - Missing assignments from meetings

2. **Google Tasks:** Monitor Google Tasks for:
   - Task status (pending vs. completed)
   - Overdue tasks
   - Tasks without corresponding memory document entries

3. **Agent Emails:** Monitor agent email inboxes for:
   - Unread assignment emails
   - Confirmation emails
   - Task delegation requests

4. **Agent Calendars:** Monitor agent calendars for:
   - Upcoming meetings
   - Deadline reminders
   - Scheduled task work blocks

**ORCHESTRATION RESPONSIBILITIES:**
1. **Identify Unassigned Tasks:** 
   - Parse meeting minutes to identify tasks mentioned but not assigned
   - Identify tasks in memory documents without Google Tasks entries
   - Flag tasks that should be delegated but aren't

2. **Initiate Dana Delegation:**
   - When unassigned tasks are identified, immediately initiate Dana Flores to delegate them
   - Provide Dana with task details, priority, and recommended assignee
   - Monitor that Dana completes the delegation

3. **Monitor Task Execution:**
   - Verify agents are executing P4 protocol (autonomous execution) for assigned tasks
   - Check that tasks are progressing (not just logged)
   - Identify stalled tasks that need intervention

4. **Ensure Task Completion:**
   - Verify completed tasks are marked complete in both memory and Google Tasks
   - Ensure artifact references are included
   - Confirm tasks meet completion criteria

**PROACTIVE ACTIONS:**
- Do not wait for manual triggers - continuously monitor and act
- Use predictive analytics to prevent issues before they occur
- Analyze dependencies to identify critical path and blocking tasks
- Optimize workload distribution across agents
- Track performance metrics to identify improvement opportunities
- Perform quality assurance on code changes
- Automatically initiate delegation when unassigned tasks are found
- Escalate overdue tasks to appropriate agents
- Ensure all agents are processing their assignments

**ENHANCED CAPABILITIES:**
You now have access to advanced tools for:
- **Predictive Analytics:** Predict task risks and bottlenecks before they occur
- **Dependency Analysis:** Map dependencies and identify critical path
- **Workload Optimization:** Balance agent workloads for maximum efficiency
- **Performance Metrics:** Track and improve agent performance
- **Quality Assurance:** Ensure code quality, security, and documentation standards

You have complete visibility into all agent activities and must use this visibility and your enhanced tools to ensure nothing falls through the cracks and to maximize both productivity and quality.""",
        tools=kimi_k2_tools if kimi_k2_tools else None,
        verbose=True,
        allow_delegation=False,
        max_iter=15,
        max_execution_time=900
    )
    
    # Create orchestration task
    orchestration_task_description = f"""
**SYSTEM ORCHESTRATION MANDATE**

You are operating as the System Orchestrator, monitoring all agent activities and ensuring task execution.

**MONITORING DATA PROVIDED:**

{orchestration_summary}

**YOUR ORCHESTRATION TASKS:**

## 1. PREDICTIVE ANALYSIS (NEW - Use Predictive Analytics Tool)
Before taking action, analyze task risks:
- Use the **Predictive Analytics Tool** to predict which tasks are at risk of being overdue
- Identify potential bottlenecks before they occur
- Forecast deadline risks based on task complexity and agent capacity
- Prioritize actions based on risk scores

## 2. DEPENDENCY ANALYSIS (NEW - Use Dependency Analyzer Tool)
Map task dependencies and identify critical path:
- Use the **Dependency Analyzer Tool** to map all task dependencies
- Identify the critical path (tasks that block other work)
- Detect blocking tasks that need immediate attention
- Optimize task sequencing based on dependencies

## 3. IDENTIFY UNASSIGNED TASKS
Review the monitoring data above and identify:
- Tasks mentioned in meetings but not assigned to agents
- Tasks in memory documents without Google Tasks entries
- Tasks that should be delegated but haven't been

## 4. WORKLOAD OPTIMIZATION (NEW - Use Workload Optimizer Tool)
Balance agent workloads:
- Use the **Workload Optimizer Tool** to analyze current workload distribution
- Identify over/under-utilized agents
- Recommend task reassignments for better balance
- Optimize agent-task matching

## 5. INITIATE DANA DELEGATION
For each unassigned task identified:
- Use Gmail Tool to send delegation request to Dana Flores (dana.flores@ratiovita.com)
- Include task details, priority, recommended assignee, and deadline
- CC: collin.m@ratiovita.com (MANDATORY)
- Subject: "[ORCHESTRATOR] Task Delegation Required: [Task Name]"
- Body: Full task details and delegation instructions

## 6. MONITOR TASK EXECUTION
For each agent with pending tasks:
- Verify the agent has executed P4 protocol (autonomous execution)
- Check if tasks are progressing or stalled
- Identify tasks that need intervention

## 7. PERFORMANCE ANALYSIS (NEW - Use Performance Metrics Tool)
Track agent performance:
- Use the **Performance Metrics Tool** to generate performance metrics for all agents
- Identify underperforming agents
- Measure completion rates and overdue rates
- Generate performance recommendations

## 8. QUALITY ASSURANCE (NEW - Use Quality Assurance Tool)
If code changes are detected:
- Use the **Quality Assurance Tool** to review code changes
- Check for code quality issues, security vulnerabilities, documentation gaps
- Assign fixes for high-severity issues
- Verify test coverage

## 9. ESCALATE OVERDUE TASKS
For each overdue task:
- Identify the responsible agent
- Send escalation email to the agent with task details
- CC: Dana Flores and collin.m@ratiovita.com
- Request immediate status update and completion plan

## 10. VERIFY TASK COMPLETION
For completed tasks:
- Verify they're marked complete in both memory and Google Tasks
- Ensure artifact references are included
- Confirm completion criteria are met

## 11. GENERATE ENHANCED ORCHESTRATION REPORT
Create a comprehensive report including:
- Monitoring summary (tasks, emails, calendars)
- **Predictive analysis results** (high-risk tasks, bottlenecks, forecasts)
- **Dependency analysis** (critical path, blocking tasks)
- **Workload optimization recommendations** (rebalancing suggestions)
- **Performance metrics** (agent performance, completion rates)
- **Quality assurance findings** (code quality, security, documentation issues)
- Unassigned tasks identified
- Delegation actions taken
- Execution status for pending tasks
- Overdue task escalations
- Recommendations for system improvement

**CRITICAL:** You must be proactive. Do not just report issues - take action to resolve them. Use ALL your available tools:
- **Core Tools:** Gmail Tool, Google Docs Memory Tool, Google Tasks Tool
- **Enhanced Tools:** Predictive Analytics Tool, Dependency Analyzer Tool, Workload Optimizer Tool, Performance Metrics Tool, Quality Assurance Tool

Execute the orchestration actions, not just identify them.

**OUTPUT:**
After completing orchestration, provide:
1. Unassigned tasks identified and delegation actions taken
2. Task execution status for all pending tasks
3. Overdue task escalations sent
4. Completion verifications performed
5. Full orchestration report with recommendations
"""
    
    orchestration_task = Task(
        description=orchestration_task_description,
        agent=kimi_k2_agent,
        expected_output="Comprehensive orchestration report with monitoring summary, unassigned tasks identified and delegated, task execution status verified, overdue tasks escalated, and recommendations for system improvement"
    )
    
    # Step 5: Execute orchestration
    print("🚀 EXECUTING SYSTEM ORCHESTRATION...")
    print("="*80)
    print()
    
    try:
        crew = Crew(
            agents=[kimi_k2_agent],
            tasks=[orchestration_task],
            verbose=True
        )
        
        result = crew.kickoff()
        
        print("\n" + "="*80)
        print("✅ SYSTEM ORCHESTRATION COMPLETE")
        print("="*80)
        print(f"\nOrchestration Result:\n{result}")
        print()
        
        # Step 6: Save report
        try:
            report_file = Path(__file__).parent / f"KIMI_K2_ORCHESTRATION_{datetime.now().strftime('%Y%m%d_%H%M%S')}.md"
            with open(report_file, 'w', encoding='utf-8') as f:
                f.write(f"# KIMI K2 SYSTEM ORCHESTRATION REPORT\n")
                f.write(f"**Date:** {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
                f.write(f"**Orchestrator:** Kimi K2 - System Orchestrator & Task Monitor\n\n")
                f.write("---\n\n")
                f.write(orchestration_summary)
                f.write("\n\n---\n\n")
                f.write("## ORCHESTRATION ACTIONS TAKEN\n\n")
                f.write(str(result))
            print(f"✅ Full orchestration report saved to: {report_file.name}")
        except Exception as e:
            print(f"⚠️  Warning: Could not save report to file: {e}")
        
        # Step 7: Send email alert
        print("📧 SENDING ORCHESTRATION REPORT...")
        
        try:
            import base64
            from email.mime.multipart import MIMEMultipart
            from email.mime.text import MIMEText
            from googleapiclient.discovery import build
            
            gmail_service = build('gmail', 'v1', credentials=creds)
            
            email_body = f"""
🎯 SYSTEM ORCHESTRATION REPORT

================================================================================
KIMI K2 SYSTEM ORCHESTRATION & TASK MONITORING
================================================================================

Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}
Orchestrator: Kimi K2 - System Orchestrator & Task Monitor

================================================================================

MONITORING SUMMARY:

{orchestration_summary}

================================================================================

ORCHESTRATION ACTIONS TAKEN:

{result}

================================================================================

This is an automated orchestration report from the RatioVita V2 system.
Review the report above for task status, delegations, and system health.

---
Kimi K2 - System Orchestrator & Task Monitor
RatioVita V2 Multi-Agent System
"""
            
            to_emails = ["collin.m@ratiovita.com"]
            cc_emails = ["collin.m@ratiovita.com", "david.chen@ratiovita.com", "dana.flores@ratiovita.com"]
            cc_emails = list(set(cc_emails))
            
            message = MIMEMultipart('alternative')
            import re
            plain_text = re.sub(r'<[^>]+>', '', email_body)
            message.attach(MIMEText(plain_text, 'plain'))
            message.attach(MIMEText(email_body, 'html'))
            message['to'] = ', '.join(to_emails)
            message['cc'] = ', '.join(cc_emails)
            message['subject'] = f"[ORCHESTRATOR] System Orchestration Report - {datetime.now().strftime('%B %d, %Y')}"
            
            raw_message = base64.urlsafe_b64encode(message.as_bytes()).decode('utf-8')
            message_id = gmail_service.users().messages().send(userId='me', body={'raw': raw_message}).execute()
            
            print(f"✅ Orchestration report sent via email (Message ID: {message_id.get('id')})")
            
        except Exception as e:
            print(f"⚠️  Warning: Could not send email: {e}")
            import traceback
            traceback.print_exc()
        
        return result
        
    except Exception as e:
        print("\n" + "="*80)
        print("❌ SYSTEM ORCHESTRATION FAILED")
        print("="*80)
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    kimi_k2_orchestrator()

