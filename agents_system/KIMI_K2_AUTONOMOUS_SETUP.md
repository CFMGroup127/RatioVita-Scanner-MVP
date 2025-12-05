# Kimi K2 Autonomous Scheduler Setup Guide

## Overview

Kimi K2 (Architectural Assurance Layer) can now run autonomously via system task schedulers, providing continuous oversight of the entire RatioVita V2 agent system without manual intervention.

## Architecture

### Autonomous Execution Flow

```
System Scheduler (Cron/Task Scheduler)
    ↓
kimi_k2_autonomous_wrapper.sh
    ↓
Activate Virtual Environment
    ↓
kimi_k2_architect_audit.py
    ↓
1. Retrieve all 15 agent memory documents
2. Perform comprehensive audit (P3, P5, P11, P13)
3. Identify top 3 architectural risks
4. Generate system health summary
5. Log report to Dana's memory document
6. Save local log file
```

## Installation

### macOS/Linux (Cron)

1. **Run the setup script:**
   ```bash
   cd agents_system
   ./setup_kimi_k2_scheduler.sh
   ```

2. **Verify installation:**
   ```bash
   crontab -l | grep "kimi_k2"
   ```

3. **Check scheduled times:**
   - Daily Audit: 8:00 AM EST (every day)
   - Weekly Audit: 9:00 AM EST (every Monday, before Executive Meeting)

### Windows (Task Scheduler)

1. **Open Task Scheduler:**
   - Press `Win + R`, type `taskschd.msc`, press Enter

2. **Create Basic Task:**
   - Name: "Kimi K2 Daily Audit"
   - Trigger: Daily at 8:00 AM
   - Action: Start a program
   - Program: `bash` (or full path to Git Bash)
   - Arguments: `"C:\path\to\agents_system\kimi_k2_autonomous_wrapper.sh"`

3. **Alternative PowerShell Method:**
   ```powershell
   $action = New-ScheduledTaskAction -Execute "bash" -Argument "C:\path\to\agents_system\kimi_k2_autonomous_wrapper.sh"
   $trigger = New-ScheduledTaskTrigger -Daily -At "8:00AM"
   Register-ScheduledTask -TaskName "Kimi K2 Daily Audit" -Action $action -Trigger $trigger
   ```

## Schedule Configuration

### Default Schedule

| Mode | Frequency | Time (EST) | Purpose |
|------|-----------|------------|---------|
| Daily Audit | Every day | 8:00 AM | Continuous compliance monitoring |
| Weekly Audit | Every Monday | 9:00 AM | Pre-meeting strategic review |

### Customizing the Schedule

**To change the schedule, edit your crontab:**
```bash
crontab -e
```

**Cron format:** `minute hour day month weekday command`

**Examples:**
- Every 6 hours: `0 */6 * * * /path/to/wrapper.sh`
- Twice daily (8 AM and 6 PM): `0 8,18 * * * /path/to/wrapper.sh`
- Weekdays only: `0 8 * * 1-5 /path/to/wrapper.sh`

## Log Files

All audit runs are automatically logged to timestamped files:

**Location:** `agents_system/logs/`

**Format:** `kimi_k2_audit_YYYYMMDD_HHMMSS.log`

**Example:**
```
logs/
  ├── kimi_k2_audit_20251124_080000.log
  ├── kimi_k2_audit_20251125_080000.log
  └── kimi_k2_audit_20251125_090000.log
```

## Monitoring & Maintenance

### View Recent Logs

```bash
# List all audit logs
ls -lt agents_system/logs/kimi_k2_audit_*.log | head -5

# View latest log
tail -f agents_system/logs/kimi_k2_audit_$(date +%Y%m%d)_*.log

# Search for errors
grep -i "error\|failed\|warning" agents_system/logs/*.log
```

### Manual Execution

To run an audit manually (outside of schedule):

```bash
cd agents_system
./kimi_k2_autonomous_wrapper.sh
```

Or directly:

```bash
cd agents_system
source venv/bin/activate
python3 kimi_k2_architect_audit.py
```

### Removing the Scheduler

**macOS/Linux:**
```bash
crontab -l | grep -v "kimi_k2_autonomous_wrapper.sh" | crontab -
```

**Windows:**
- Open Task Scheduler
- Find "Kimi K2 Daily Audit"
- Right-click → Delete

## Audit Report Access

After each autonomous audit, the report is available in:

1. **Dana Flores's Memory Document:**
   - Section: REPORTS
   - Subsection: Current Date
   - Template: Report Archive

2. **Local Log Files:**
   - Location: `agents_system/logs/kimi_k2_audit_*.log`
   - Contains full audit output and results

3. **CrewAI Trace (if enabled):**
   - View detailed execution traces in CrewAI dashboard
   - Access code provided in log output

## Troubleshooting

### Audit Not Running

1. **Check cron service:**
   ```bash
   # macOS
   sudo launchctl list | grep cron
   
   # Linux
   systemctl status cron
   ```

2. **Verify script permissions:**
   ```bash
   chmod +x kimi_k2_autonomous_wrapper.sh
   ```

3. **Test manual execution:**
   ```bash
   ./kimi_k2_autonomous_wrapper.sh
   ```

4. **Check log files for errors:**
   ```bash
   tail -50 agents_system/logs/kimi_k2_audit_*.log
   ```

### Virtual Environment Issues

If the audit fails due to missing dependencies:

```bash
cd agents_system
source venv/bin/activate
pip install -r requirements.txt
```

### OAuth Token Expiration

If authentication fails:

```bash
cd agents_system
source venv/bin/activate
python3 fix_oauth_full_permissions.py
```

## System Requirements

- **Python 3.8+**
- **Virtual environment** with all dependencies installed
- **Google API credentials** (token.json)
- **Network access** to Google APIs
- **Sufficient disk space** for log files (logs rotate automatically)

## Security Considerations

1. **File Permissions:**
   - Wrapper script should be executable only by owner
   - Log files should be readable only by owner

2. **Credentials:**
   - `token.json` should have restricted permissions (600)
   - Never commit credentials to version control

3. **Network Security:**
   - Ensure firewall allows outbound HTTPS to Google APIs
   - Monitor for unusual API usage patterns

## Next Steps

After setting up the autonomous scheduler:

1. ✅ **Review First Audit Report:** Check Dana's memory document for the initial autonomous audit
2. ✅ **Address Identified Risks:** Implement mitigation strategies from the Top 3 Architectural Risks
3. ✅ **Monitor Compliance:** Review daily audit logs to track protocol compliance improvements
4. ✅ **Strategic Handoff:** Formally accept Kimi K2 as the autonomous build leader

---

**Status:** ✅ Autonomous scheduler ready for deployment
**Last Updated:** November 24, 2025

