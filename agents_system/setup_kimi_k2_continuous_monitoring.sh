#!/bin/bash
# Setup continuous monitoring for Kimi K2
# Runs time monitor every 30 minutes and orchestrator daily

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_PATH="$SCRIPT_DIR/venv"
PYTHON_PATH="$VENV_PATH/bin/python3"

# Time monitor (every 30 minutes)
TIME_MONITOR_SCRIPT="$SCRIPT_DIR/kimi_k2_time_monitor.py"

# Orchestrator (daily at 8 AM EST)
ORCHESTRATOR_SCRIPT="$SCRIPT_DIR/kimi_k2_orchestrator.py"

echo "🔧 Setting up Kimi K2 Continuous Monitoring"
echo "=================================================================================="
echo ""

# Check if crontab exists
if ! crontab -l 2>/dev/null | grep -q "kimi_k2"; then
    echo "📝 Adding cron jobs..."
    
    # Add time monitor (every 30 minutes)
    (crontab -l 2>/dev/null; echo "*/30 * * * * cd $SCRIPT_DIR && $PYTHON_PATH $TIME_MONITOR_SCRIPT >> $SCRIPT_DIR/logs/kimi_time_monitor.log 2>&1") | crontab -
    
    # Add orchestrator (daily at 8 AM EST)
    (crontab -l 2>/dev/null; echo "0 8 * * * cd $SCRIPT_DIR && $PYTHON_PATH $ORCHESTRATOR_SCRIPT >> $SCRIPT_DIR/logs/kimi_orchestrator.log 2>&1") | crontab -
    
    echo "✅ Cron jobs added"
else
    echo "⚠️  Cron jobs already exist"
fi

# Create logs directory
mkdir -p "$SCRIPT_DIR/logs"

echo ""
echo "📋 Scheduled Jobs:"
echo "   - Time Monitor: Every 30 minutes"
echo "   - Orchestrator: Daily at 8:00 AM EST"
echo ""
echo "✅ Setup complete!"
echo ""
echo "To view scheduled jobs: crontab -l | grep kimi_k2"
echo "To remove: crontab -l | grep -v kimi_k2 | crontab -"

