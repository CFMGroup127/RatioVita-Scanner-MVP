"""
Enhanced Tools for Kimi K2
Additional tools to maximize productivity and quality.
"""
from crewai.tools import tool
from typing import List, Dict, Optional
from datetime import datetime, timedelta
import json
import os
from pathlib import Path

# ============================================================================
# 1. PREDICTIVE ANALYTICS TOOL
# ============================================================================

@tool("Predictive Analytics Tool")
def predictive_analytics_tool(
    tasks: List[Dict],
    agent_history: Optional[Dict] = None,
    historical_data: Optional[Dict] = None
) -> str:
    """
    Predicts which tasks are at risk of being overdue and identifies potential bottlenecks.
    
    Args:
        tasks: List of tasks with details (name, due_date, assigned_agent, complexity, etc.)
        agent_history: Historical completion data per agent
        historical_data: General historical task completion patterns
    
    Returns:
        Predictive analysis report with risk scores and recommendations
    """
    risk_analysis = {
        "high_risk_tasks": [],
        "medium_risk_tasks": [],
        "bottlenecks": [],
        "recommendations": []
    }
    
    current_date = datetime.now()
    
    for task in tasks:
        due_date_str = task.get('due_date', '')
        if not due_date_str:
            continue
        
        try:
            due_date = datetime.fromisoformat(due_date_str.replace('Z', '+00:00'))
            days_until_due = (due_date - current_date.replace(tzinfo=due_date.tzinfo)).days
            
            # Calculate risk score
            complexity = task.get('complexity', 'medium')
            agent = task.get('assigned_agent', 'unknown')
            
            # Risk factors
            risk_score = 0
            if days_until_due < 3:
                risk_score += 3
            elif days_until_due < 7:
                risk_score += 2
            else:
                risk_score += 1
            
            if complexity == 'high':
                risk_score += 2
            elif complexity == 'medium':
                risk_score += 1
            
            # Agent history factor
            if agent_history and agent in agent_history:
                completion_rate = agent_history[agent].get('completion_rate', 0.8)
                if completion_rate < 0.7:
                    risk_score += 2
                elif completion_rate < 0.85:
                    risk_score += 1
            
            task_risk = {
                "task": task.get('name', 'Unknown'),
                "risk_score": risk_score,
                "days_until_due": days_until_due,
                "assigned_agent": agent,
                "recommendation": "HIGH PRIORITY" if risk_score >= 5 else "MONITOR" if risk_score >= 3 else "LOW RISK"
            }
            
            if risk_score >= 5:
                risk_analysis["high_risk_tasks"].append(task_risk)
            elif risk_score >= 3:
                risk_analysis["medium_risk_tasks"].append(task_risk)
        
        except Exception as e:
            continue
    
    # Identify bottlenecks (agents with too many high-risk tasks)
    agent_task_counts = {}
    for task in risk_analysis["high_risk_tasks"]:
        agent = task["assigned_agent"]
        agent_task_counts[agent] = agent_task_counts.get(agent, 0) + 1
    
    for agent, count in agent_task_counts.items():
        if count >= 3:
            risk_analysis["bottlenecks"].append({
                "agent": agent,
                "high_risk_task_count": count,
                "recommendation": "Consider reassigning some tasks or extending deadlines"
            })
    
    # Generate recommendations
    if risk_analysis["high_risk_tasks"]:
        risk_analysis["recommendations"].append(
            f"URGENT: {len(risk_analysis['high_risk_tasks'])} tasks at high risk. "
            "Immediate action required."
        )
    
    if risk_analysis["bottlenecks"]:
        risk_analysis["recommendations"].append(
            f"BOTTLENECK: {len(risk_analysis['bottlenecks'])} agents overloaded. "
            "Consider workload redistribution."
        )
    
    return json.dumps(risk_analysis, indent=2)


# ============================================================================
# 2. QUALITY ASSURANCE TOOL
# ============================================================================

@tool("Quality Assurance Tool")
def quality_assurance_tool(
    file_paths: List[str],
    check_types: Optional[List[str]] = None
) -> str:
    """
    Performs quality assurance checks on code files.
    
    Args:
        file_paths: List of file paths to check
        check_types: Types of checks to perform (code_quality, security, documentation, tests)
    
    Returns:
        Quality assurance report
    """
    if check_types is None:
        check_types = ["code_quality", "security", "documentation", "tests"]
    
    qa_report = {
        "files_checked": len(file_paths),
        "issues_found": [],
        "quality_scores": {},
        "recommendations": []
    }
    
    for file_path in file_paths:
        if not os.path.exists(file_path):
            continue
        
        file_issues = []
        quality_score = 100
        
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                lines = content.split('\n')
            
            # Code quality checks
            if "code_quality" in check_types:
                # Check for long functions (basic heuristic)
                if len(lines) > 200:
                    file_issues.append({
                        "type": "code_quality",
                        "severity": "medium",
                        "issue": f"File has {len(lines)} lines - consider splitting into smaller functions",
                        "line": None
                    })
                    quality_score -= 10
                
                # Check for TODO/FIXME comments
                todo_count = content.count('TODO') + content.count('FIXME')
                if todo_count > 5:
                    file_issues.append({
                        "type": "code_quality",
                        "severity": "low",
                        "issue": f"{todo_count} TODO/FIXME comments found",
                        "line": None
                    })
                    quality_score -= 5
            
            # Security checks
            if "security" in check_types:
                security_keywords = ['password', 'secret', 'api_key', 'token']
                for keyword in security_keywords:
                    if keyword in content.lower() and '#' not in content.lower().split(keyword)[0][-20:]:
                        file_issues.append({
                            "type": "security",
                            "severity": "high",
                            "issue": f"Potential security issue: '{keyword}' found - verify not hardcoded",
                            "line": None
                        })
                        quality_score -= 15
            
            # Documentation checks
            if "documentation" in check_types:
                if file_path.endswith('.py'):
                    # Check for docstrings
                    if '"""' not in content and "'''" not in content:
                        file_issues.append({
                            "type": "documentation",
                            "severity": "medium",
                            "issue": "Missing docstrings - add function/class documentation",
                            "line": None
                        })
                        quality_score -= 10
            
            # Test checks
            if "tests" in check_types:
                if file_path.endswith('.py') and 'test' not in file_path.lower():
                    # Check if corresponding test file exists
                    test_file = file_path.replace('.py', '_test.py')
                    if not os.path.exists(test_file):
                        file_issues.append({
                            "type": "tests",
                            "severity": "medium",
                            "issue": f"No corresponding test file found: {test_file}",
                            "line": None
                        })
                        quality_score -= 10
            
            qa_report["quality_scores"][file_path] = max(0, quality_score)
            qa_report["issues_found"].extend(file_issues)
        
        except Exception as e:
            qa_report["issues_found"].append({
                "type": "error",
                "severity": "high",
                "issue": f"Error checking file: {str(e)}",
                "file": file_path
            })
    
    # Generate recommendations
    high_severity_issues = [i for i in qa_report["issues_found"] if i.get("severity") == "high"]
    if high_severity_issues:
        qa_report["recommendations"].append(
            f"URGENT: {len(high_severity_issues)} high-severity issues found. "
            "Address immediately."
        )
    
    avg_quality = sum(qa_report["quality_scores"].values()) / len(qa_report["quality_scores"]) if qa_report["quality_scores"] else 0
    qa_report["average_quality_score"] = avg_quality
    
    return json.dumps(qa_report, indent=2)


# ============================================================================
# 3. DEPENDENCY ANALYZER TOOL
# ============================================================================

@tool("Dependency Analyzer Tool")
def dependency_analyzer_tool(
    tasks: List[Dict],
    parse_dependencies: bool = True
) -> str:
    """
    Analyzes task dependencies and identifies critical path.
    
    Args:
        tasks: List of tasks with details
        parse_dependencies: Whether to parse dependencies from task descriptions
    
    Returns:
        Dependency analysis report with critical path
    """
    dependency_graph = {}
    task_nodes = {}
    
    for task in tasks:
        task_name = task.get('name', '')
        task_id = task.get('id', task_name)
        task_nodes[task_id] = task
        
        # Parse dependencies from description or explicit dependencies field
        dependencies = task.get('dependencies', [])
        if parse_dependencies and not dependencies:
            # Try to parse from description
            description = task.get('description', '')
            # Look for patterns like "depends on", "after", "requires"
            # This is a simplified parser - can be enhanced
            pass
        
        dependency_graph[task_id] = dependencies
    
    # Build dependency graph
    graph = {}
    for task_id, deps in dependency_graph.items():
        graph[task_id] = {
            "dependencies": deps,
            "dependents": []
        }
    
    # Find dependents
    for task_id, deps in dependency_graph.items():
        for dep in deps:
            if dep in graph:
                graph[dep]["dependents"].append(task_id)
    
    # Identify critical path (simplified - longest path)
    critical_path = []
    visited = set()
    
    def find_longest_path(node, path):
        if node in visited:
            return path
        visited.add(node)
        path.append(node)
        
        max_path = path[:]
        for dependent in graph.get(node, {}).get("dependents", []):
            candidate_path = find_longest_path(dependent, path[:])
            if len(candidate_path) > len(max_path):
                max_path = candidate_path
        
        return max_path
    
    # Find longest path from nodes with no dependencies
    start_nodes = [node for node, data in graph.items() if not data["dependencies"]]
    for start_node in start_nodes:
        path = find_longest_path(start_node, [])
        if len(path) > len(critical_path):
            critical_path = path
    
    # Identify blocking tasks (tasks with many dependents)
    blocking_tasks = []
    for task_id, data in graph.items():
        dependent_count = len(data["dependents"])
        if dependent_count >= 3:
            blocking_tasks.append({
                "task": task_id,
                "dependent_count": dependent_count,
                "priority": "HIGH" if dependent_count >= 5 else "MEDIUM"
            })
    
    analysis = {
        "total_tasks": len(tasks),
        "dependency_graph": {k: v["dependencies"] for k, v in graph.items()},
        "critical_path": critical_path,
        "critical_path_length": len(critical_path),
        "blocking_tasks": blocking_tasks,
        "recommendations": []
    }
    
    if blocking_tasks:
        analysis["recommendations"].append(
            f"URGENT: {len(blocking_tasks)} blocking tasks identified. "
            "These tasks block multiple other tasks and should be prioritized."
        )
    
    if critical_path:
        analysis["recommendations"].append(
            f"CRITICAL PATH: {len(critical_path)} tasks in critical path. "
            "Any delay in these tasks will delay the entire project."
        )
    
    return json.dumps(analysis, indent=2)


# ============================================================================
# 4. PERFORMANCE METRICS TOOL
# ============================================================================

@tool("Performance Metrics Tool")
def performance_metrics_tool(
    agent_data: Dict,
    time_period_days: int = 30
) -> str:
    """
    Generates performance metrics for agents.
    
    Args:
        agent_data: Dictionary of agent performance data
        time_period_days: Number of days to analyze
    
    Returns:
        Performance metrics report
    """
    metrics = {
        "time_period_days": time_period_days,
        "agent_metrics": {},
        "system_metrics": {},
        "recommendations": []
    }
    
    total_tasks = 0
    total_completed = 0
    total_overdue = 0
    
    for agent_name, data in agent_data.items():
        tasks = data.get('tasks', [])
        completed = data.get('completed', 0)
        overdue = data.get('overdue', 0)
        
        task_count = len(tasks) if isinstance(tasks, list) else tasks
        
        completion_rate = (completed / task_count * 100) if task_count > 0 else 0
        overdue_rate = (overdue / task_count * 100) if task_count > 0 else 0
        
        agent_metric = {
            "total_tasks": task_count,
            "completed": completed,
            "overdue": overdue,
            "completion_rate": f"{completion_rate:.1f}%",
            "overdue_rate": f"{overdue_rate:.1f}%",
            "performance_rating": "EXCELLENT" if completion_rate >= 95 and overdue_rate < 5 else
                                 "GOOD" if completion_rate >= 85 and overdue_rate < 10 else
                                 "NEEDS_IMPROVEMENT" if completion_rate >= 70 else "POOR"
        }
        
        metrics["agent_metrics"][agent_name] = agent_metric
        
        total_tasks += task_count
        total_completed += completed
        total_overdue += overdue
    
    # System-wide metrics
    system_completion_rate = (total_completed / total_tasks * 100) if total_tasks > 0 else 0
    system_overdue_rate = (total_overdue / total_tasks * 100) if total_tasks > 0 else 0
    
    metrics["system_metrics"] = {
        "total_tasks": total_tasks,
        "total_completed": total_completed,
        "total_overdue": total_overdue,
        "system_completion_rate": f"{system_completion_rate:.1f}%",
        "system_overdue_rate": f"{system_overdue_rate:.1f}%"
    }
    
    # Generate recommendations
    if system_overdue_rate > 10:
        metrics["recommendations"].append(
            f"WARNING: System overdue rate is {system_overdue_rate:.1f}%. "
            "Review task assignments and deadlines."
        )
    
    underperformers = [name for name, metric in metrics["agent_metrics"].items() 
                      if metric["performance_rating"] in ["NEEDS_IMPROVEMENT", "POOR"]]
    if underperformers:
        metrics["recommendations"].append(
            f"ATTENTION: {len(underperformers)} agents need performance improvement: {', '.join(underperformers)}"
        )
    
    return json.dumps(metrics, indent=2)


# ============================================================================
# 5. WORKLOAD OPTIMIZER TOOL
# ============================================================================

@tool("Workload Optimizer Tool")
def workload_optimizer_tool(
    agents: List[Dict],
    tasks: List[Dict]
) -> str:
    """
    Optimizes workload distribution across agents.
    
    Args:
        agents: List of agents with capacity and current workload
        tasks: List of unassigned or reassignable tasks
    
    Returns:
        Workload optimization recommendations
    """
    # Calculate current workload per agent
    agent_workloads = {}
    for agent in agents:
        agent_name = agent.get('name', '')
        current_tasks = agent.get('current_tasks', [])
        capacity = agent.get('capacity', 10)  # Default capacity
        
        agent_workloads[agent_name] = {
            "current_tasks": len(current_tasks),
            "capacity": capacity,
            "utilization": (len(current_tasks) / capacity * 100) if capacity > 0 else 0,
            "available_capacity": max(0, capacity - len(current_tasks))
        }
    
    # Identify imbalances
    utilizations = [w["utilization"] for w in agent_workloads.values()]
    avg_utilization = sum(utilizations) / len(utilizations) if utilizations else 0
    
    overloaded = []
    underutilized = []
    
    for agent_name, workload in agent_workloads.items():
        if workload["utilization"] > avg_utilization + 20:
            overloaded.append({
                "agent": agent_name,
                "utilization": f"{workload['utilization']:.1f}%",
                "current_tasks": workload["current_tasks"],
                "capacity": workload["capacity"]
            })
        elif workload["utilization"] < avg_utilization - 20:
            underutilized.append({
                "agent": agent_name,
                "utilization": f"{workload['utilization']:.1f}%",
                "available_capacity": workload["available_capacity"]
            })
    
    # Generate reassignment recommendations
    recommendations = []
    if overloaded and underutilized and tasks:
        recommendations.append({
            "action": "REBALANCE",
            "from_agent": overloaded[0]["agent"],
            "to_agent": underutilized[0]["agent"],
            "reason": f"Rebalance workload: {overloaded[0]['agent']} is {overloaded[0]['utilization']} utilized, "
                     f"{underutilized[0]['agent']} has {underutilized[0]['available_capacity']} available capacity"
        })
    
    optimization_report = {
        "current_state": {
            "average_utilization": f"{avg_utilization:.1f}%",
            "overloaded_agents": len(overloaded),
            "underutilized_agents": len(underutilized)
        },
        "overloaded_agents": overloaded,
        "underutilized_agents": underutilized,
        "recommendations": recommendations
    }
    
    return json.dumps(optimization_report, indent=2)

