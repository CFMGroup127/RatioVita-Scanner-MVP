"""
Quick test script for Kimi K2 enhanced tools
Tests all 5 new tools to verify they work correctly.
"""
import json
from kimi_k2_enhanced_tools import (
    predictive_analytics_tool,
    quality_assurance_tool,
    dependency_analyzer_tool,
    performance_metrics_tool,
    workload_optimizer_tool
)

def test_predictive_analytics():
    """Test predictive analytics tool"""
    print("🧪 Testing Predictive Analytics Tool...")
    
    sample_tasks = [
        {
            "name": "Fix CCPA compliance issue",
            "due_date": "2025-11-26T00:00:00Z",
            "assigned_agent": "Samuel Reed",
            "complexity": "high"
        },
        {
            "name": "Update documentation",
            "due_date": "2025-12-01T00:00:00Z",
            "assigned_agent": "Alice Kim",
            "complexity": "medium"
        }
    ]
    
    agent_history = {
        "Samuel Reed": {"completion_rate": 0.75},
        "Alice Kim": {"completion_rate": 0.90}
    }
    
    result = predictive_analytics_tool(
        tasks=sample_tasks,
        agent_history=agent_history
    )
    
    print("✅ Predictive Analytics Tool Test:")
    print(result[:500] + "...")
    print()
    return True

def test_quality_assurance():
    """Test quality assurance tool"""
    print("🧪 Testing Quality Assurance Tool...")
    
    # Find a Python file to test
    test_file = "tools.py"
    if not os.path.exists(test_file):
        test_file = "../tools.py"
    
    if os.path.exists(test_file):
        result = quality_assurance_tool(
            file_paths=[test_file],
            check_types=["code_quality", "documentation"]
        )
        print("✅ Quality Assurance Tool Test:")
        print(result[:500] + "...")
        print()
        return True
    else:
        print("⚠️  Skipping QA test - no test file found")
        return False

def test_dependency_analyzer():
    """Test dependency analyzer tool"""
    print("🧪 Testing Dependency Analyzer Tool...")
    
    sample_tasks = [
        {
            "id": "task1",
            "name": "Design system",
            "dependencies": []
        },
        {
            "id": "task2",
            "name": "Implement feature",
            "dependencies": ["task1"]
        },
        {
            "id": "task3",
            "name": "Write tests",
            "dependencies": ["task2"]
        }
    ]
    
    result = dependency_analyzer_tool(
        tasks=sample_tasks,
        parse_dependencies=True
    )
    
    print("✅ Dependency Analyzer Tool Test:")
    print(result[:500] + "...")
    print()
    return True

def test_performance_metrics():
    """Test performance metrics tool"""
    print("🧪 Testing Performance Metrics Tool...")
    
    agent_data = {
        "Samuel Reed": {
            "tasks": 10,
            "completed": 8,
            "overdue": 1
        },
        "Alice Kim": {
            "tasks": 5,
            "completed": 5,
            "overdue": 0
        }
    }
    
    result = performance_metrics_tool(
        agent_data=agent_data,
        time_period_days=30
    )
    
    print("✅ Performance Metrics Tool Test:")
    print(result[:500] + "...")
    print()
    return True

def test_workload_optimizer():
    """Test workload optimizer tool"""
    print("🧪 Testing Workload Optimizer Tool...")
    
    agents = [
        {
            "name": "Samuel Reed",
            "current_tasks": [1, 2, 3, 4, 5],
            "capacity": 5
        },
        {
            "name": "Alice Kim",
            "current_tasks": [1],
            "capacity": 5
        }
    ]
    
    tasks = [
        {"name": "New task 1"},
        {"name": "New task 2"}
    ]
    
    result = workload_optimizer_tool(
        agents=agents,
        tasks=tasks
    )
    
    print("✅ Workload Optimizer Tool Test:")
    print(result[:500] + "...")
    print()
    return True

if __name__ == "__main__":
    import os
    
    print("="*80)
    print("🧪 KIMI K2 ENHANCED TOOLS - QUICK TEST")
    print("="*80)
    print()
    
    results = []
    
    try:
        results.append(("Predictive Analytics", test_predictive_analytics()))
    except Exception as e:
        print(f"❌ Predictive Analytics failed: {e}")
        results.append(("Predictive Analytics", False))
    
    try:
        results.append(("Quality Assurance", test_quality_assurance()))
    except Exception as e:
        print(f"❌ Quality Assurance failed: {e}")
        results.append(("Quality Assurance", False))
    
    try:
        results.append(("Dependency Analyzer", test_dependency_analyzer()))
    except Exception as e:
        print(f"❌ Dependency Analyzer failed: {e}")
        results.append(("Dependency Analyzer", False))
    
    try:
        results.append(("Performance Metrics", test_performance_metrics()))
    except Exception as e:
        print(f"❌ Performance Metrics failed: {e}")
        results.append(("Performance Metrics", False))
    
    try:
        results.append(("Workload Optimizer", test_workload_optimizer()))
    except Exception as e:
        print(f"❌ Workload Optimizer failed: {e}")
        results.append(("Workload Optimizer", False))
    
    print("="*80)
    print("📊 TEST RESULTS SUMMARY")
    print("="*80)
    print()
    
    for name, passed in results:
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"{status}: {name}")
    
    print()
    passed_count = sum(1 for _, p in results if p)
    print(f"Total: {passed_count}/{len(results)} tools working")
    print()
    print("="*80)

