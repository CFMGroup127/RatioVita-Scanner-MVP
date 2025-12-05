"""
Google Tasks Tool
Integrates Google Tasks API for P3 protocol compliance.
Makes tasks visible in Google Tasks Sidebar for human interaction.
"""
from crewai.tools import tool
from typing import Optional
from datetime import datetime
import os
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

SCOPES = ['https://www.googleapis.com/auth/tasks']

def get_credentials():
    """Get valid user credentials for Google Tasks API"""
    creds = None
    if os.path.exists('token.json'):
        try:
            creds = Credentials.from_authorized_user_file('token.json', SCOPES)
        except:
            try:
                creds = Credentials.from_authorized_user_file('token.json', None)
                if creds.scopes:
                    # Add Tasks scope if not present
                    if 'https://www.googleapis.com/auth/tasks' not in creds.scopes:
                        creds = creds.with_scopes(creds.scopes + SCOPES)
            except:
                pass
    
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            try:
                creds.refresh(Request())
            except:
                return None
        else:
            return None
    
    return creds

@tool("Google Tasks Tool")
def google_tasks_tool(
    task_title: str,
    task_notes: str = None,
    due_date: str = None,
    task_list_id: str = "@default"
) -> str:
    """
    Create a task in Google Tasks for P3 protocol compliance.
    This makes tasks visible in the Google Tasks Sidebar for human interaction.
    
    Args:
        task_title: The title of the task (required)
        task_notes: Additional notes or description for the task
        due_date: Due date in format "YYYY-MM-DD" or "YYYY-MM-DD HH:MM"
        task_list_id: The task list ID (default: "@default" for default list)
    
    Returns:
        Success message with task ID and URL
    """
    try:
        creds = get_credentials()
        if not creds:
            return "ERROR: Could not get credentials for Google Tasks API. Please run fix_oauth_full_permissions.py with Tasks scope."
        
        service = build('tasks', 'v1', credentials=creds)
        
        # Build task body
        task_body = {
            'title': task_title,
            'status': 'needsAction'  # Task is not completed
        }
        
        if task_notes:
            task_body['notes'] = task_notes
        
        if due_date:
            # Parse due date
            try:
                # Try parsing as datetime
                if ' ' in due_date:
                    due_dt = datetime.strptime(due_date, '%Y-%m-%d %H:%M')
                else:
                    due_dt = datetime.strptime(due_date, '%Y-%m-%d')
                
                # Google Tasks API expects RFC 3339 format
                task_body['due'] = due_dt.strftime('%Y-%m-%dT%H:%M:%S.000Z')
            except ValueError:
                # If parsing fails, try to use as-is
                task_body['due'] = due_date
        
        # Insert task
        result = service.tasks().insert(
            tasklist=task_list_id,
            body=task_body
        ).execute()
        
        task_id = result.get('id')
        task_url = f"https://tasks.google.com/embed/list/{task_list_id}/tasks/{task_id}"
        
        return f"SUCCESS: Task '{task_title}' created in Google Tasks (ID: {task_id}). Visible in Tasks Sidebar. URL: {task_url}"
        
    except HttpError as e:
        return f"ERROR: Google Tasks API error: {str(e)}"
    except Exception as e:
        return f"ERROR: Failed to create task: {str(e)}"

def get_default_task_list_id():
    """Get the default task list ID for the user"""
    try:
        creds = get_credentials()
        if not creds:
            return "@default"
        
        service = build('tasks', 'v1', credentials=creds)
        task_lists = service.tasklists().list().execute()
        
        # Find default list or first list
        for task_list in task_lists.get('items', []):
            if task_list.get('id') == '@default' or task_list.get('title') == 'My Tasks':
                return task_list.get('id')
        
        # Return first list if no default found
        if task_lists.get('items'):
            return task_lists['items'][0].get('id')
        
        return "@default"
    except:
        return "@default"

