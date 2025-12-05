"""
Task Time Management System
Defines time constraints, progress monitoring, and loop detection for all agent tasks
"""
from datetime import datetime, timedelta
from typing import Dict, Optional

# V2 Task Time Constraints (in hours)
TASK_TIME_CONSTRAINTS = {
    "V2-001": {
        "name": "Connect CameraCaptureView to RealScannerService",
        "estimated_hours": 8,
        "max_hours": 12,
        "checkpoints": [
            {"time": 2, "milestone": "Camera preview implemented"},
            {"time": 4, "milestone": "Capture button wired"},
            {"time": 6, "milestone": "Error handling complete"},
            {"time": 8, "milestone": "Integration tested"}
        ],
        "priority": "P0"
    },
    "V2-002": {
        "name": "Enhance RealScannerService & Add Review Screen",
        "estimated_hours": 12,
        "max_hours": 18,
        "checkpoints": [
            {"time": 3, "milestone": "Document detection enhanced"},
            {"time": 6, "milestone": "OCR parsing improved"},
            {"time": 9, "milestone": "Review screen created"},
            {"time": 12, "milestone": "Testing complete"}
        ],
        "priority": "P1"
    },
    "V2-003": {
        "name": "Data Layer Enhancements",
        "estimated_hours": 6,
        "max_hours": 10,
        "checkpoints": [
            {"time": 2, "milestone": "originalSize property added"},
            {"time": 4, "milestone": "Migration plan created"},
            {"time": 6, "milestone": "Tests written and passing"}
        ],
        "priority": "P2"
    },
    "V2-004": {
        "name": "Cross-Platform Consistency",
        "estimated_hours": 4,
        "max_hours": 8,
        "checkpoints": [
            {"time": 2, "milestone": "ImageBridge verified"},
            {"time": 4, "milestone": "Platform checks verified"}
        ],
        "priority": "P2"
    },
    "V2-005": {
        "name": "Testing Suite Expansion",
        "estimated_hours": 10,
        "max_hours": 15,
        "checkpoints": [
            {"time": 3, "milestone": "OCRParsingTests created"},
            {"time": 6, "milestone": "ImageProcessingTests created"},
            {"time": 9, "milestone": "ScannerServiceTests created"},
            {"time": 10, "milestone": "Coverage > 70% verified"}
        ],
        "priority": "P2"
    }
}

def get_task_time_constraint(task_id: str) -> Optional[Dict]:
    """Get time constraint for a task"""
    return TASK_TIME_CONSTRAINTS.get(task_id)

def calculate_checkpoint_times(task_id: str, start_time: datetime) -> list:
    """Calculate absolute times for checkpoints"""
    constraint = get_task_time_constraint(task_id)
    if not constraint:
        return []
    
    checkpoints = []
    for checkpoint in constraint['checkpoints']:
        checkpoint_time = start_time + timedelta(hours=checkpoint['time'])
        checkpoints.append({
            'time': checkpoint_time,
            'milestone': checkpoint['milestone'],
            'hours_from_start': checkpoint['time']
        })
    
    return checkpoints

def is_task_overdue(task_id: str, start_time: datetime) -> bool:
    """Check if task has exceeded max time"""
    constraint = get_task_time_constraint(task_id)
    if not constraint:
        return False
    
    max_time = start_time + timedelta(hours=constraint['max_hours'])
    return datetime.now() > max_time

def get_time_remaining(task_id: str, start_time: datetime) -> timedelta:
    """Get remaining time for task"""
    constraint = get_task_time_constraint(task_id)
    if not constraint:
        return timedelta(0)
    
    max_time = start_time + timedelta(hours=constraint['max_hours'])
    remaining = max_time - datetime.now()
    return remaining if remaining.total_seconds() > 0 else timedelta(0)

def get_next_checkpoint(task_id: str, start_time: datetime) -> Optional[Dict]:
    """Get next checkpoint that hasn't been reached"""
    checkpoints = calculate_checkpoint_times(task_id, start_time)
    now = datetime.now()
    
    for checkpoint in checkpoints:
        if now < checkpoint['time']:
            return checkpoint
    
    return None

def should_prompt_for_update(task_id: str, start_time: datetime, last_update: Optional[datetime] = None) -> bool:
    """Determine if agent should be prompted for progress update"""
    # Prompt if:
    # 1. More than 2 hours since last update
    # 2. Next checkpoint is within 30 minutes
    # 3. Task is overdue
    
    if is_task_overdue(task_id, start_time):
        return True
    
    if last_update:
        time_since_update = datetime.now() - last_update
        if time_since_update > timedelta(hours=2):
            return True
    
    next_checkpoint = get_next_checkpoint(task_id, start_time)
    if next_checkpoint:
        time_to_checkpoint = next_checkpoint['time'] - datetime.now()
        if time_to_checkpoint < timedelta(minutes=30):
            return True
    
    return False

def detect_loop(agent_name: str, task_id: str, recent_actions: list) -> bool:
    """Detect if agent is stuck in a loop"""
    if len(recent_actions) < 5:
        return False
    
    # Check for repeated identical actions
    last_5 = recent_actions[-5:]
    if len(set(last_5)) <= 2:  # Only 1-2 unique actions in last 5
        return True
    
    # Check for same error repeated
    error_count = sum(1 for action in last_5 if 'error' in str(action).lower() or 'failed' in str(action).lower())
    if error_count >= 4:
        return True
    
    return False

def generate_progress_prompt(task_id: str, start_time: datetime, agent_name: str) -> str:
    """Generate progress update prompt for agent"""
    constraint = get_task_time_constraint(task_id)
    if not constraint:
        return ""
    
    time_elapsed = datetime.now() - start_time
    time_remaining = get_time_remaining(task_id, start_time)
    next_checkpoint = get_next_checkpoint(task_id, start_time)
    
    prompt = f"""
**PROGRESS UPDATE REQUEST - {task_id}**

**Task:** {constraint['name']}
**Agent:** {agent_name}
**Time Elapsed:** {time_elapsed.total_seconds() / 3600:.1f} hours
**Time Remaining:** {time_remaining.total_seconds() / 3600:.1f} hours
**Estimated Total:** {constraint['estimated_hours']} hours
**Max Time:** {constraint['max_hours']} hours

"""
    
    if next_checkpoint:
        prompt += f"**Next Checkpoint:** {next_checkpoint['milestone']} (in {next_checkpoint['time'] - datetime.now()})\n\n"
    
    prompt += """
**REQUIRED INFORMATION:**
1. Current progress percentage (0-100%)
2. What have you completed since last update?
3. What are you working on now?
4. Any blockers or issues?
5. Updated time estimate (if different from original)
6. Expected completion time

**ACTION REQUIRED:**
- Update your memory document with progress
- Respond to this prompt with detailed status
- If time estimate changed, provide new estimate
"""
    
    return prompt

def generate_loop_recovery_prompt(task_id: str, agent_name: str, detected_loop: str) -> str:
    """Generate recovery prompt for agent stuck in loop"""
    return f"""
**LOOP DETECTION ALERT - {task_id}**

**Agent:** {agent_name}
**Issue Detected:** {detected_loop}

**RECOVERY ACTIONS REQUIRED:**

1. **STOP CURRENT ACTION** - Do not continue repeating the same action
2. **ASSESS SITUATION:**
   - What error or issue are you encountering?
   - What have you tried so far?
   - What is blocking progress?

3. **ALTERNATIVE APPROACH:**
   - Try a different method or tool
   - Break the task into smaller steps
   - Ask for help from another agent if needed

4. **UPDATE STATUS:**
   - Log the issue in your memory document
   - Request assistance if needed
   - Provide new time estimate if task complexity changed

**IMMEDIATE ACTION:** Respond with your assessment and new approach plan.
"""

