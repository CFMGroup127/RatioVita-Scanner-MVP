#!/bin/bash
# Setup script for Kimi K2 Autonomous Scheduler
# This script installs cron jobs to run Kimi K2 audits automatically

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
WRAPPER_SCRIPT="$SCRIPT_DIR/kimi_k2_autonomous_wrapper.sh"

# Make wrapper script executable
chmod +x "$WRAPPER_SCRIPT"

# Create logs directory
mkdir -p "$SCRIPT_DIR/logs"

echo "🏗️  KIMI K2 AUTONOMOUS SCHEDULER SETUP"
echo "=================================================================================="
echo ""

# Check if running on macOS or Linux
if [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "✅ Detected Unix-like system (macOS/Linux)"
    echo ""
    
    # Cron job for daily audit at 8:00 AM EST
    # Note: Cron uses system timezone, so we need to account for EST (UTC-5) or EDT (UTC-4)
    # 8:00 AM EST = 13:00 UTC (during EST) or 12:00 UTC (during EDT)
    # For simplicity, we'll use 8:00 AM in the system's local timezone
    # User should adjust based on their timezone
    
    CRON_JOB_DAILY="0 8 * * * $WRAPPER_SCRIPT"
    CRON_JOB_WEEKLY="0 9 * * 1 $WRAPPER_SCRIPT"
    
    # Check if cron job already exists
    if crontab -l 2>/dev/null | grep -q "kimi_k2_autonomous_wrapper.sh"; then
        echo "⚠️  Cron job already exists. Current crontab entries:"
        crontab -l 2>/dev/null | grep "kimi_k2_autonomous_wrapper.sh"
        echo ""
        read -p "Do you want to replace the existing cron job? (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Remove existing entries
            crontab -l 2>/dev/null | grep -v "kimi_k2_autonomous_wrapper.sh" | crontab -
            echo "✅ Removed existing cron job"
        else
            echo "❌ Keeping existing cron job. Exiting."
            exit 0
        fi
    fi
    
    # Add new cron jobs
    (crontab -l 2>/dev/null; echo ""; echo "# Kimi K2 Autonomous Audit - Daily at 8:00 AM EST"; echo "$CRON_JOB_DAILY") | crontab -
    (crontab -l 2>/dev/null; echo "# Kimi K2 Autonomous Audit - Weekly on Mondays at 9:00 AM EST (Before Executive Meeting)"; echo "$CRON_JOB_WEEKLY") | crontab -
    
    echo "✅ Cron jobs installed successfully!"
    echo ""
    echo "📋 Installed Schedule:"
    echo "   - Daily Audit: 8:00 AM EST (every day)"
    echo "   - Weekly Audit: 9:00 AM EST (every Monday, before Executive Meeting)"
    echo ""
    echo "📝 Current crontab entries:"
    crontab -l 2>/dev/null | grep -A 1 "Kimi K2"
    echo ""
    echo "📁 Log files will be saved to: $SCRIPT_DIR/logs/"
    echo ""
    echo "🔍 To view scheduled jobs:"
    echo "   crontab -l"
    echo ""
    echo "🗑️  To remove scheduled jobs:"
    echo "   crontab -l | grep -v 'kimi_k2_autonomous_wrapper.sh' | crontab -"
    echo ""
    
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    echo "✅ Detected Windows system"
    echo ""
    echo "📋 Windows Task Scheduler Setup:"
    echo ""
    echo "To set up Kimi K2 on Windows, you need to create a scheduled task:"
    echo ""
    echo "1. Open Task Scheduler (taskschd.msc)"
    echo "2. Create Basic Task:"
    echo "   - Name: 'Kimi K2 Daily Audit'"
    echo "   - Trigger: Daily at 8:00 AM"
    echo "   - Action: Start a program"
    echo "   - Program: $WRAPPER_SCRIPT"
    echo ""
    echo "Alternatively, use PowerShell to create the task:"
    echo ""
    echo '   $action = New-ScheduledTaskAction -Execute "bash" -Argument "$WRAPPER_SCRIPT"'
    echo '   $trigger = New-ScheduledTaskTrigger -Daily -At "8:00AM"'
    echo '   Register-ScheduledTask -TaskName "Kimi K2 Daily Audit" -Action $action -Trigger $trigger'
    echo ""
    
else
    echo "⚠️  Unknown operating system: $OSTYPE"
    echo "Please set up the scheduler manually using your system's task scheduler."
    echo ""
fi

echo "✅ Setup complete!"
echo ""
echo "🚀 Kimi K2 is now configured for autonomous operation!"
echo "   The audit will run automatically at the scheduled times."
echo ""

