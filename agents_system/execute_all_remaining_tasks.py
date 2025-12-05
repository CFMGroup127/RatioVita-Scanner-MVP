"""Execute all remaining V2 tasks for assigned agents"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from start_agent_work import start_agent_work

def main():
    """Execute all remaining V2 tasks"""
    print("\n" + "="*80)
    print("🚀 EXECUTING ALL REMAINING V2 TASKS")
    print("="*80)
    print()
    
    # V2 tasks in priority order
    tasks = [
        ("Ethan Hayes", "V2-001"),  # P0 - Highest priority
        ("Ethan Hayes", "V2-002"),  # P1
        ("Ethan Hayes", "V2-003"),  # P2
        ("Ethan Hayes", "V2-004"),  # P2
        ("Tyler Cobb", "V2-005"),   # P2
    ]
    
    print(f"📋 Executing {len(tasks)} tasks in priority order...")
    print()
    
    results = {}
    
    for agent_name, task_id in tasks:
        print(f"\n{'='*80}")
        print(f"🚀 Starting: {agent_name} - {task_id}")
        print(f"{'='*80}\n")
        
        result = start_agent_work(agent_name, task_id)
        results[f"{agent_name}-{task_id}"] = result
        
        if result:
            print(f"✅ {task_id} execution completed\n")
        else:
            print(f"❌ {task_id} execution failed\n")
    
    # Summary
    print("="*80)
    print("📊 EXECUTION SUMMARY")
    print("="*80)
    print()
    
    success_count = sum(1 for v in results.values() if v)
    print(f"✅ Successfully executed: {success_count}/{len(tasks)} tasks")
    print()
    
    for key, result in results.items():
        status = "✅" if result else "❌"
        print(f"{status} {key}")
    
    print()
    print("="*80)
    print("✅ ALL TASKS EXECUTION COMPLETE")
    print("="*80)
    print()

if __name__ == "__main__":
    main()

