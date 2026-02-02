# How to Create credentials.json

## Step-by-Step Guide

### Step 1: Access Google Cloud Console

1. **Open your web browser**
2. **Go to**: https://console.cloud.google.com/
3. **Sign in** with your Google account

### Step 2: Create or Select a Project

1. At the top of the page, click the **project dropdown** (shows current project name)
2. Click **"NEW PROJECT"** (or select an existing project)
3. Enter project name: `RatioVita Agents` (or any name you prefer)
4. Click **"CREATE"**
5. Wait for project creation, then select it from the dropdown

### Step 3: Enable Required APIs

For each API below, follow these steps:

1. In the left sidebar, click **"APIs & Services"** > **"Library"**
2. Search for the API name in the search box
3. Click on the API
4. Click the **"ENABLE"** button

**Enable these 4 APIs:**
- ✅ **Google Docs API**
- ✅ **Google Drive API**  
- ✅ **Google Calendar API**
- ✅ **Gmail API**

### Step 4: Configure OAuth Consent Screen

1. Go to **"APIs & Services"** > **"OAuth consent screen"**
2. Select **"External"** (unless you're using Google Workspace, then select "Internal")
3. Click **"CREATE"**
4. Fill in the form:
   - **App name**: `RatioVita Agent System`
   - **User support email**: Your email address
   - **Developer contact information**: Your email address
5. Click **"SAVE AND CONTINUE"**
6. **Scopes** page: Click **"ADD OR REMOVE SCOPES"**
   - In the filter box, search and add these scopes one by one:
     - `https://www.googleapis.com/auth/documents`
     - `https://www.googleapis.com/auth/documents.readonly`
     - `https://www.googleapis.com/auth/drive`
     - `https://www.googleapis.com/auth/drive.readonly`
     - `https://www.googleapis.com/auth/calendar`
     - `https://www.googleapis.com/auth/gmail.send`
   - Click **"UPDATE"**
   - Click **"SAVE AND CONTINUE"**
7. **Test users** (if External): Click **"ADD USERS"** and add your email
8. Click **"SAVE AND CONTINUE"** through remaining steps
9. Click **"BACK TO DASHBOARD"**

### Step 5: Create OAuth Client ID

1. Go to **"APIs & Services"** > **"Credentials"**
2. Click **"+ CREATE CREDENTIALS"** at the top
3. Select **"OAuth client ID"**
4. **Application type**: Select **"Desktop app"**
5. **Name**: Enter `RatioVita Agents` (or any name)
6. Click **"CREATE"**
7. A popup will appear with your credentials
8. Click **"DOWNLOAD JSON"** button
9. **Save the file** - it will be named something like `client_secret_xxxxx.json`

### Step 6: Rename and Move the File

1. **Rename** the downloaded file to: `credentials.json`
2. **Move** it to: `/Users/colliemorris/Projects 2/RatioVita_v2/agents_system/`

You can do this via:
- **Finder**: Drag and drop the file to the `agents_system` folder, then rename it
- **Terminal**: 
  ```bash
  mv ~/Downloads/client_secret_*.json "/Users/colliemorris/Projects 2/RatioVita_v2/agents_system/credentials.json"
  ```

### Step 7: Verify the File

Run this command to verify:
```bash
cd "/Users/colliemorris/Projects 2/RatioVita_v2/agents_system"
ls -la credentials.json
```

You should see the file listed.

### Step 8: Authenticate

Once `credentials.json` is in place, run:
```bash
cd "/Users/colliemorris/Projects 2/RatioVita_v2/agents_system"
source venv/bin/activate
python3 setup_google_auth.py
```

This will open a browser for authentication and create `token.json`.

## Troubleshooting

**If Google Cloud Console shows blank pages:**
- Try a different browser
- Clear browser cache
- Try incognito/private mode
- Check if you're signed into the correct Google account
- Make sure JavaScript is enabled

**If you can't find "APIs & Services":**
- Look for "☰" (hamburger menu) in the top left
- Navigate: ☰ > APIs & Services

**If the OAuth consent screen step is confusing:**
- You can skip some optional fields
- The important part is adding the scopes in Step 4

## Quick Reference: Direct URLs

Once signed into Google Cloud Console, you can go directly to:

- **APIs Library**: https://console.cloud.google.com/apis/library
- **Credentials**: https://console.cloud.google.com/apis/credentials
- **OAuth Consent Screen**: https://console.cloud.google.com/apis/credentials/consent

