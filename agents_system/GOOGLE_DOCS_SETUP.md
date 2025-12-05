# Google Docs Memory Tool Setup Guide

## Overview

The Google Docs Memory Tool allows agents (Alice Kim and Dana Flores) to update their persistent memory documents stored in Google Docs after each batch is processed.

## What Was Implemented

1. **Google Docs Memory Tool** (`tools.py`)
   - Tool that writes/appends content to Google Docs using document IDs
   - Comprehensive error handling with specific HTTP error codes
   - Proper OAuth scope checking

2. **Tool Assignment** (`main.py`)
   - Assigned to Alice Kim (Documentation and Knowledge Archivist)
   - Assigned to Dana Flores (Admin Assistant & Workflow Funnel)

3. **Protocol Updates** (`agents.yaml`)
   - Alice's protocol updated to explicitly use Google Docs Memory Tool
   - Task descriptions updated to mention the tool

## Required Setup

### 1. Install Google API Libraries

```bash
cd "/Users/colliemorris/Projects 2/RatioVita_v2/agents_system"
source venv/bin/activate
pip install google-api-python-client google-auth-httplib2 google-auth-oauthlib
```

### 2. Create Google Cloud Project and Enable APIs

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project (or use existing)
3. Enable the following APIs:
   - **Google Docs API**
   - **Google Drive API**

### 3. Create OAuth 2.0 Credentials

1. In Google Cloud Console, go to **APIs & Services** > **Credentials**
2. Click **Create Credentials** > **OAuth client ID**
3. Choose **Desktop app** as application type
4. Download the credentials JSON file
5. Save it as `credentials.json` in the `agents_system/` directory

### 4. Required OAuth Scopes

The tool requires these scopes (already configured in the code):
- `https://www.googleapis.com/auth/documents` (for writing to Google Docs)
- `https://www.googleapis.com/auth/drive` (for accessing Google Drive)

### 5. Authenticate and Generate Token

On first run, the tool will prompt you to authenticate via browser. The token will be saved to `token.json`.

Alternatively, you can set environment variables:
```bash
export GOOGLE_CREDENTIALS_FILE="credentials.json"
export GOOGLE_TOKEN_FILE="token.json"
```

## Error Handling

The tool includes detailed error handling that will report:
- **403 Forbidden**: Missing or incorrect OAuth scopes
- **404 Not Found**: Document ID doesn't exist
- **401 Unauthorized**: Invalid or expired credentials
- Specific error messages for each failure point

## Usage

Agents will automatically use the tool when:
- **Alice Kim**: After validating each batch of 10 files, she saves the summary to her memory doc
- **Dana Flores**: When updating her memory document with workflow information

The tool is called with:
- `doc_id`: The agent's `memory_doc_id` from `agents.yaml`
- `content`: The summary/content to append
- `append`: `True` (default) to append, `False` to replace

## Verification

To verify the setup works:

1. Check that `credentials.json` exists in `agents_system/`
2. Run the system - it will prompt for authentication on first use
3. Check that `token.json` is created after authentication
4. The tool will report specific errors if there are permission issues

## Troubleshooting

### "ERROR: Google credentials file not found"
- Ensure `credentials.json` is in the `agents_system/` directory
- Or set `GOOGLE_CREDENTIALS_FILE` environment variable

### "ERROR: HTTP 403: Insufficient permissions"
- Check that both Google Docs API and Google Drive API are enabled
- Verify OAuth scopes include both required scopes
- Re-authenticate to get new token with correct scopes

### "ERROR: HTTP 404: Document not found"
- Verify the `memory_doc_id` in `agents.yaml` is correct
- Ensure the document exists and is accessible with the authenticated account
- Check that the document ID is clean (no URL prefixes)

### "ERROR: No valid credentials found"
- Delete `token.json` and re-authenticate
- Ensure the OAuth flow completes successfully

