# Email Troubleshooting Guide

## 📧 Email Delivery Issues

If emails are not being received from Kimi K2 audits, check the following:

### 1. OAuth Token Scopes

The OAuth token must include `gmail.send` scope to send emails.

**Check scopes:**
```bash
cd agents_system
python3 -c "import json; token = json.load(open('token.json')); print('Scopes:', token.get('scopes', []))"
```

**Required scopes:**
- ✅ `https://www.googleapis.com/auth/gmail.send` - For sending emails
- ✅ `https://www.googleapis.com/auth/gmail.readonly` - For reading emails (if needed)

**If missing, re-authenticate:**
```bash
python3 fix_oauth_full_permissions.py
```

### 2. Email Recipients

**Configured recipients:**
- **To**: collin.m@ratiovita.com
- **CC**: david.chen@ratiovita.com, dana.flores@ratiovita.com

**Verify email addresses are correct:**
- Check `kimi_k2_protocol_compliance_audit.py` line 557
- Check `kimi_k2_full_codebase_analysis.py` email section

### 3. Gmail API Status

**Check if Gmail API is enabled:**
- Go to: https://console.cloud.google.com/apis/library/gmail.googleapis.com
- Verify API is enabled for your project

### 4. Spam Folder

- Check spam/junk folder in Gmail
- Check filters that might be blocking automated emails
- Look for emails from: Kimi K2 - Protocol Compliance Auditor

### 5. Email Tool Configuration

**Verify Gmail tool is working:**
```python
from tools import get_gmail_tool
gmail_tool = get_gmail_tool(agent_role="Test")
result = gmail_tool(
    to="collin.m@ratiovita.com",
    subject="Test Email",
    body="This is a test email"
)
print(result)
```

### 6. Error Logs

Check script output for email errors:
- Look for "⚠️ Warning: Could not send email" messages
- Check for Gmail API errors
- Verify OAuth token is valid

---

## 🔧 Quick Fix

If emails are not working, try:

1. **Re-authenticate OAuth:**
   ```bash
   python3 fix_oauth_full_permissions.py
   ```

2. **Test email sending:**
   ```bash
   python3 -c "from tools import get_gmail_tool; tool = get_gmail_tool('Test'); print(tool(to='collin.m@ratiovita.com', subject='Test', body='Test email'))"
   ```

3. **Check Gmail API quota:**
   - Gmail API has daily sending limits
   - Check quota usage in Google Cloud Console

---

**Last Updated**: November 24, 2025

