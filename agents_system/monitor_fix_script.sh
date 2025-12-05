#!/bin/bash

# Monitor the fix_memory_reports script and notify when complete

LOG_DIR="/Users/colliemorris/Projects 2/RatioVita_v2/agents_system"
LOG_FILE=$(ls -t "$LOG_DIR"/fix_memory_reports_*.log 2>/dev/null | head -1)

if [ -z "$LOG_FILE" ]; then
    echo "❌ No log file found"
    exit 1
fi

echo "📊 Monitoring fix script: $LOG_FILE"
echo "Press Ctrl+C to stop monitoring"
echo ""

CHECK_INTERVAL=30  # Check every 30 seconds
MAX_CHECKS=120     # Max 60 minutes (120 * 30s)

check_count=0

while [ $check_count -lt $MAX_CHECKS ]; do
    # Check if process is still running
    if ! ps aux | grep -E "fix_missing_memory_reports\.py" | grep -v grep > /dev/null; then
        echo ""
        echo "✅ Process has completed"
        break
    fi
    
    # Check log for completion indicators
    if tail -20 "$LOG_FILE" 2>/dev/null | grep -q "MEMORY REPORT FIX COMPLETE\|✅.*COMPLETE"; then
        echo ""
        echo "✅ Script completed successfully!"
        tail -30 "$LOG_FILE" | grep -E "COMPLETE|SUCCESS|✅|📋|📊" | tail -10
        exit 0
    fi
    
    # Check for errors
    if tail -20 "$LOG_FILE" 2>/dev/null | grep -q "❌.*Error\|Exception\|Traceback"; then
        echo ""
        echo "❌ Error detected in script"
        tail -30 "$LOG_FILE" | grep -E "Error|Exception|Traceback" | tail -10
        exit 1
    fi
    
    # Show progress
    if [ $((check_count % 4)) -eq 0 ]; then
        LINES=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
        LAST_ACTIVITY=$(tail -3 "$LOG_FILE" 2>/dev/null | grep -E "Agent|Tool|Task" | tail -1 | cut -c1-60)
        echo "[$(date +%H:%M:%S)] Still running... ($LINES lines) - $LAST_ACTIVITY"
    fi
    
    sleep $CHECK_INTERVAL
    check_count=$((check_count + 1))
done

if [ $check_count -ge $MAX_CHECKS ]; then
    echo ""
    echo "⏱️  Monitoring timeout reached. Checking final status..."
fi

# Final status check
echo ""
echo "📊 Final Status:"
echo "=================="
tail -50 "$LOG_FILE" | grep -E "COMPLETE|SUCCESS|ERROR|✅|❌|📋|📊" | tail -15



