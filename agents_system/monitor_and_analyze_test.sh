#!/bin/bash
# Automatic monitoring script for test completion
# Analyzes output and runs memory read test when test completes

cd "/Users/colliemorris/Projects 2/RatioVita_v2/agents_system"

echo "🔍 Monitoring test completion..."
echo ""

# Wait for test to complete
while ps aux | grep -E "python.*test_suite.py" | grep -v grep > /dev/null; do
    sleep 30
    echo "$(date +%H:%M:%S): Test still running..."
done

echo ""
echo "✅ Test completed! Analyzing output..."
echo ""

# Find latest test log
LATEST_LOG=$(ls -t full_test_calendar_fix_*.log 2>/dev/null | head -1)

if [ -z "$LATEST_LOG" ]; then
    echo "❌ No test log found"
    exit 1
fi

echo "📊 Analyzing: $LATEST_LOG"
echo ""

# Analyze ACTION 6 results
echo "=== ACTION 6 (Memory Update) Analysis ==="
ACTION6_COUNT=$(grep -c "ACTION 6\|MEMORY UPDATE\|test completion status" "$LATEST_LOG" 2>/dev/null || echo "0")
echo "ACTION 6 references: $ACTION6_COUNT"

MEMORY_UPDATE_SUCCESS=$(grep -c "SUCCESS.*memory\|SUCCESS.*Memory\|Content.*memory document" "$LATEST_LOG" 2>/dev/null || echo "0")
echo "Memory update success messages: $MEMORY_UPDATE_SUCCESS"

echo ""
echo "=== Test Completion Summary ==="
tail -100 "$LATEST_LOG" | grep -E "COMPLETE|Final|Summary|completed successfully" -i | tail -10

echo ""
echo "=== Running Memory Read Test ==="
echo ""

# Run memory read test
if [ -d "venv" ]; then
    source venv/bin/activate
fi

python3 test_memory_read.py 2>&1 | tee memory_read_test_$(date +%Y%m%d_%H%M%S).log

echo ""
echo "✅ Monitoring and analysis complete!"

