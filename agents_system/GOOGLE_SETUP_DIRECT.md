# Direct Google API Setup Guide

## Quick Setup Steps

### Step 1: Get Your Credentials File

If you already have a `credentials.json` file from a previous Google API setup:
1. Copy it to: `/Users/colliemorris/Projects 2/RatioVita_v2/agents_system/credentials.json`

### Step 2: Run the Authentication Script

```bash
cd "/Users/colliemorris/Projects 2/RatioVita_v2/agents_system"
source venv/bin/activate
python3 setup_google_auth.py
```

This will:
- Check for `credentials.json`
- Open a browser for OAuth authentication
- Save `token.json` for future use

### Step 3: If You Don't Have credentials.json

You need to create one in Google Cloud Console:

1. **Go to Google Cloud Console** (you may need to sign in)
   - URL: `console.cloud.google.com`

2. **Create or Select a Project**
   - Click the project dropdown at the top
   - Create new project or select existing

3. **Enable Required APIs**
   - Go to "APIs & Services" > "Library"
   - Search and enable each of these:
     - **Google Docs API** - Click "Enable"
     - **Google Drive API** - Click "Enable"
     - **Google Calendar API** - Click "Enable"
     - **Gmail API** - Click "Enable"

4. **Create OAuth Credentials**
   - Go to "APIs & Services" > "Credentials"
   - Click "+ CREATE CREDENTIALS" > "OAuth client ID"
   - If prompted, configure OAuth consent screen first:
     - User Type: External (or Internal if using Google Workspace)
     - App name: "RatioVita Agent System"
     - User support email: Your email
     - Developer contact: Your email
     - Click "Save and Continue"
     - Scopes: Click "Add or Remove Scopes"
       - Add all these scopes:
         - `https://www.googleapis.com/auth/documents`
         - `https://www.googleapis.com/auth/documents.readonly`
         - `https://www.googleapis.com/auth/drive`
         - `https://www.googleapis.com/auth/drive.readonly`
         - `https://www.googleapis.com/auth/calendar`
         - `https://www.googleapis.com/auth/gmail.send`
     - Click "Save and Continue" through test users (if needed)
     - Click "Back to Dashboard"
   - Now create OAuth client ID:
     - Application type: **Desktop app**
     - Name: "RatioVita Agents"
     - Click "Create"
   - Download the JSON file
   - Rename it to `credentials.json`
   - Move it to: `/Users/colliemorris/Projects 2/RatioVita_v2/agents_system/`

5. **Run Authentication**
   ```bash
   python3 setup_google_auth.py
   ```

## Alternative: Use Existing Credentials

If you have Google API credentials from another project:
1. Copy the `credentials.json` file to the agents_system directory
2. Run `python3 setup_google_auth.py` to authenticate
3. The script will handle token generation

## Verify Setup

After running `setup_google_auth.py`, you should have:
- ✅ `credentials.json` in agents_system directory
- ✅ `token.json` in agents_system directory

Then you can run the agent introduction test:
```bash
python3 main.py
```

