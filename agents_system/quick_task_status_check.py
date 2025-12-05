"""
Quick Task Status Check
Uses orchestrator's monitoring functions to check task status.
"""
import sys
from pathlib import Path

# Add current directory to path
sys.path.insert(0, str(Path(__file__).parent))

from kimi_k2_orchestrator import (
    get_credentials,
    monitor_agent_tasks,
    get_agent_metadata_local
)
from datetime import datetime

def check_specific_tasks_status():
    """Check status of specific tasks"""
    print("\n" + "="*80)
    print("📊 TASK STATUS CHECK - SPECIFIC TASKS")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
    
    # Get credentials (with auto-fix)
    print("🔐 Getting credentials...")
    creds = get_credentials()
    if not creds:
        print("❌ Error: Could not get credentials")
        print("   Attempting OAuth auto-fix...")
        try:
            from kimi_k2_oauth_monitor import monitor_and_fix_oauth
            fix_result = monitor_and_fix_oauth(auto_fix=True, notify=True)
            if fix_result.get('status') == 'fixed':
                creds = get_credentials()
            else:
                print("❌ OAuth auto-fix failed - please run: python3 fix_oauth_full_permissions.py")
                return None
        except Exception as e:
            print(f"❌ Auto-fix error: {e}")
            return None
    
    print("✅ Credentials obtained\n")
    
    # Monitor tasks
    print("📋 Monitoring agent tasks...")
    try:
        tasks_status, google_tasks = monitor_agent_tasks(creds)
    except Exception as e:
        print(f"⚠️  Error monitoring tasks: {e}")
        print("   Attempting to continue with available data...")
        tasks_status = {}
        google_tasks = {}
    
    # Specific tasks to check
    target_tasks = [
        'Draft compliance strategy for Feature 7 (CCPA risk)',
        'URGENT FIX: Implement authenticated logging hook for Python user data handling module',
        'TEST: P3 Hybrid System Validation',
        'Draft legal risk assessment for V2 feature set, focusing on data privacy and compliance requirements'
    ]
    
    print("\n" + "="*80)
    print("🎯 SPECIFIC TASKS STATUS")
    print("="*80)
    print()
    
    results = {}
    
    for target_task in target_tasks:
        print(f"📋 Checking: {target_task}")
        print("-" * 80)
        
        found_google = False
        found_memory = False
        
        # Check Google Tasks
        for task_title, task_data in google_tasks.items():
            if target_task.lower() in task_title.lower() or task_title.lower() in target_task.lower():
                status = task_data.get('status', 'unknown')
                due = task_data.get('due', 'No due date')
                print(f"   ✅ Google Tasks: {status.upper()}")
                print(f"      Title: {task_title}")
                print(f"      Due: {due}")
                found_google = True
                break
        
        if not found_google:
            print("   ❌ Google Tasks: Not found")
        
        # Check Memory Documents
        for agent_name, agent_data in tasks_status.items():
            for task_info in agent_data.get('pending', []) + agent_data.get('completed', []):
                task_text = task_info.get('task', '')
                if target_task.lower() in task_text.lower() or task_text.lower() in target_task.lower():
                    status = task_info.get('status', 'unknown')
                    print(f"   ✅ Memory Document: {status}")
                    print(f"      Agent: {agent_name} ({agent_data.get('role', 'Unknown')})")
                    print(f"      Task: {task_text[:100]}...")
                    found_memory = True
                    break
            if found_memory:
                break
        
        if not found_memory:
            print("   ❌ Memory Document: Not found")
        
        if not found_google and not found_memory:
            print("   ⚠️  STATUS: TASK NOT FOUND IN ANY SYSTEM")
            print("   ⚠️  ACTION REQUIRED: Task may need to be assigned/reassigned")
        
        print()
        results[target_task] = {
            'found_google': found_google,
            'found_memory': found_memory,
            'status': 'FOUND' if (found_google or found_memory) else 'NOT FOUND'
        }
    
    # Summary of all tasks
    print("="*80)
    print("📊 ALL AGENT TASKS SUMMARY")
    print("="*80)
    print()
    
    total_pending = 0
    total_completed = 0
    
    for agent_name, agent_data in tasks_status.items():
        pending = agent_data.get('total_pending', 0)
        completed = agent_data.get('total_completed', 0)
        total_pending += pending
        total_completed += completed
        
        if pending > 0 or completed > 0:
            print(f"👤 {agent_name}:")
            print(f"   Pending: {pending}")
            print(f"   Completed: {completed}")
            if pending > 0:
                print("   Pending Tasks:")
                for task in agent_data.get('pending', [])[:5]:  # Limit to 5
                    print(f"      - {task.get('task', '')[:80]}...")
            print()
    
    print(f"📊 SYSTEM TOTALS:")
    print(f"   Total Pending: {total_pending}")
    print(f"   Total Completed: {total_completed}")
    print()
    
    # Google Tasks summary
    if google_tasks:
        pending_gt = [t for t in google_tasks.values() if t.get('status') != 'completed']
        completed_gt = [t for t in google_tasks.values() if t.get('status') == 'completed']
        
        print(f"📋 GOOGLE TASKS:")
        print(f"   Pending: {len(pending_gt)}")
        print(f"   Completed: {len(completed_gt)}")
        if pending_gt:
            print("   Pending Tasks:")
            for task in pending_gt[:10]:  # Limit to 10
                title = task.get('title', 'Unknown')
                due = task.get('due', 'No due date')
                print(f"      - {title[:60]}... (Due: {due[:10] if due else 'No date'})")
        print()
    
    # Specific tasks summary
    print("="*80)
    print("🎯 SPECIFIC TASKS SUMMARY")
    print("="*80)
    print()
    
    not_found = [task for task, result in results.items() if result['status'] == 'NOT FOUND']
    found = [task for task, result in results.items() if result['status'] == 'FOUND']
    
    if found:
        print(f"✅ Found: {len(found)} tasks")
        for task in found:
            print(f"   - {task[:60]}...")
        print()
    
    if not_found:
        print(f"❌ NOT FOUND: {len(not_found)} tasks")
        print("   These tasks need to be assigned/reassigned:")
        for task in not_found:
            print(f"   - {task}")
        print()
        print("⚠️  RECOMMENDED ACTIONS:")
        print("   1. Check if tasks were assigned to agents")
        print("   2. Verify agents logged tasks to memory documents")
        print("   3. Check if tasks were created in Google Tasks")
        print("   4. Re-assign tasks if needed")
        print()
    
    return results

if __name__ == "__main__":
    check_specific_tasks_status()

