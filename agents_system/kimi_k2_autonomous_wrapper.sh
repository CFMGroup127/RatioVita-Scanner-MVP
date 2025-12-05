#!/bin/bash
# Kimi K2 Autonomous Audit Wrapper Script
# This script ensures the virtual environment is activated and runs the audit
# Designed to be called by cron or Task Scheduler

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Activate virtual environment
source venv/bin/activate

# Set environment variables
export PYTHONPATH="$SCRIPT_DIR:$PYTHONPATH"
export TZ="America/New_York"  # EST/EDT timezone

# Log file for audit runs
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/kimi_k2_audit_$(date +%Y%m%d_%H%M%S).log"

# Run the audit and log output
echo "==========================================" >> "$LOG_FILE"
echo "Kimi K2 Autonomous Audit - $(date)" >> "$LOG_FILE"
echo "==========================================" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

python3 kimi_k2_architect_audit.py >> "$LOG_FILE" 2>&1

EXIT_CODE=$?

echo "" >> "$LOG_FILE"
echo "==========================================" >> "$LOG_FILE"
echo "Audit completed with exit code: $EXIT_CODE" >> "$LOG_FILE"
echo "Completed at: $(date)" >> "$LOG_FILE"
echo "==========================================" >> "$LOG_FILE"

# Exit with the same code as the Python script
exit $EXIT_CODE

