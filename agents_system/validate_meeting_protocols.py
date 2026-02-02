"""
Validate Meeting Protocol Compliance
Checks memory documents to verify P3, P5, P11, and P13 protocol compliance.
"""
import os
import sys
from pathlib import Path
from datetime import datetime
import yaml
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build

def get_credentials():
    """Get Google API credentials"""
    SCOPES = ['https://www.googleapis.com/auth/documents.readonly']
    
    creds = None
    token_path = Path(__file__).parent / 'token.json'
    
    if token_path.exists():
        creds = Credentials.from_authorized_user_file(str(token_path), SCOPES)
    
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            return None
    
    return creds

def get_agent_metadata(role):
    """Get agent metadata"""
    yaml_path = Path(__file__).parent / 'agents.yaml'
    with open(yaml_path, 'r') as f:
        data = yaml.safe_load(f)
    for agent_data in data.get('agents', []):
        if agent_data.get('role') == role:
            return agent_data
    return {}

def extract_text_from_document(doc):
    """Extract text from Google Docs document"""
    content = ''
    if 'body' in doc and 'content' in doc['body']:
        for element in doc['body']['content']:
            if 'paragraph' in element:
                para = element['paragraph']
                if 'elements' in para:
                    for elem in para['elements']:
                        if 'textRun' in elem:
                            content += elem['textRun'].get('content', '')
    return content

def validate_meeting_protocols():
    """Validate P3, P5, P11, and P13 protocol compliance"""
    print("\n" + "="*80)
    print("🔍 MEETING PROTOCOL COMPLIANCE VALIDATION")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
    
    creds = get_credentials()
    if not creds:
        print("❌ Error: Could not get credentials")
        return False
    
    service = build('docs', 'v1', credentials=creds)
    
    # Get Dana Flores metadata
    dana_meta = get_agent_metadata("Admin Assistant & Workflow Funnel")
    dana_doc_id = dana_meta.get('memory_doc_id', '')
    
    # Get Arthur Jensen metadata
    arthur_meta = get_agent_metadata("Legal Compliance and Risk Assessor")
    arthur_doc_id = arthur_meta.get('memory_doc_id', '')
    
    print("📋 VALIDATION RESULTS")
    print("="*80)
    print()
    
    # 1. DANA FLORES - P11 VALIDATION
    print("1. DANA FLORES - P11 VALIDATION (Full Minutes/Transcript)")
    print("-"*80)
    
    if dana_doc_id:
        try:
            doc = service.documents().get(documentId=dana_doc_id).execute()
            content = extract_text_from_document(doc)
            
            # Check for full minutes
            has_full_minutes = (
                "MEETING MINUTES" in content and
                "I. Overview" in content and
                "II. Attendance" in content and
                "III. Decisions Made" in content and
                "IV. Action Items" in content
            )
            
            # Check for full transcript
            has_full_transcript = (
                "MEETING TRANSCRIPT" in content or
                "TRANSCRIPT ARCHIVE" in content
            )
            
            # Check for November 25, 2025
            has_nov_25 = "November 25, 2025" in content or "11/25/2025" in content
            
            print(f"   ✅ Memory Document ID: {dana_doc_id}")
            print(f"   {'✅' if has_full_minutes else '❌'} Full Meeting Minutes: {'Found' if has_full_minutes else 'Not Found'}")
            print(f"   {'✅' if has_full_transcript else '❌'} Full Meeting Transcript: {'Found' if has_full_transcript else 'Not Found'}")
            print(f"   {'✅' if has_nov_25 else '⚠️ '} November 25, 2025 Entry: {'Found' if has_nov_25 else 'Not Found'}")
            
            if has_full_minutes and has_full_transcript:
                print("   ✅ P11 Compliance: SUCCESS")
            else:
                print("   ❌ P11 Compliance: FAILED - Missing full minutes or transcript")
                
        except Exception as e:
            print(f"   ❌ Error reading Dana's memory document: {e}")
    else:
        print("   ❌ Error: Dana's memory_doc_id not found")
    
    print()
    
    # 2. ARTHUR JENSEN - P5 VALIDATION
    print("2. ARTHUR JENSEN - P5 VALIDATION (Brief Role-Specific Notes)")
    print("-"*80)
    
    if arthur_doc_id:
        try:
            doc = service.documents().get(documentId=arthur_doc_id).execute()
            content = extract_text_from_document(doc)
            
            # Check for brief notes (not full minutes)
            has_brief_notes = (
                "Meeting Notes" in content or
                "MEETING NOTES" in content
            ) and "I. Overview" not in content  # Should NOT have full minutes structure
            
            # Check word count (should be under 150 words for meeting notes section)
            meeting_section = ""
            if "MEETINGS" in content:
                # Extract meeting notes section
                start_idx = content.find("MEETINGS")
                if start_idx != -1:
                    end_idx = content.find("REPORTS", start_idx)
                    if end_idx == -1:
                        end_idx = content.find("TRANSCRIPTS", start_idx)
                    if end_idx != -1:
                        meeting_section = content[start_idx:end_idx]
            
            word_count = len(meeting_section.split()) if meeting_section else 0
            is_brief = word_count < 150 if word_count > 0 else False
            
            # Check for November 25, 2025
            has_nov_25 = "November 25, 2025" in content or "11/25/2025" in content
            
            print(f"   ✅ Memory Document ID: {arthur_doc_id}")
            print(f"   {'✅' if has_brief_notes else '❌'} Brief Role-Specific Notes: {'Found' if has_brief_notes else 'Not Found'}")
            print(f"   {'✅' if is_brief else '⚠️ '} Word Count: {word_count} words ({'Under 150' if is_brief else 'Over 150'})")
            print(f"   {'✅' if has_nov_25 else '⚠️ '} November 25, 2025 Entry: {'Found' if has_nov_25 else 'Not Found'}")
            
            if has_brief_notes and is_brief:
                print("   ✅ P5 Compliance: SUCCESS")
            else:
                print("   ❌ P5 Compliance: FAILED - Notes are not brief or role-specific")
                
        except Exception as e:
            print(f"   ❌ Error reading Arthur's memory document: {e}")
    else:
        print("   ❌ Error: Arthur's memory_doc_id not found")
    
    print()
    
    # 3. ARTHUR JENSEN - P3 VALIDATION
    print("3. ARTHUR JENSEN - P3 VALIDATION (Task Logging - Hybrid System)")
    print("-"*80)
    
    if arthur_doc_id:
        try:
            doc = service.documents().get(documentId=arthur_doc_id).execute()
            content = extract_text_from_document(doc)
            
            # Check for task in memory document
            has_task_in_memory = (
                "Draft compliance strategy for Feature 7" in content or
                "Feature 7" in content and "compliance" in content.lower()
            )
            
            # Check for November 25, 2025 in TASKS section
            has_task_date = "November 25, 2025" in content or "11/25/2025" in content
            
            print(f"   ✅ Memory Document ID: {arthur_doc_id}")
            print(f"   {'✅' if has_task_in_memory else '❌'} Task in Memory Document: {'Found' if has_task_in_memory else 'Not Found'}")
            print(f"   {'✅' if has_task_date else '⚠️ '} Task Date (Nov 25): {'Found' if has_task_date else 'Not Found'}")
            print(f"   ⚠️  Google Tasks: Manual verification required (check Google Tasks Sidebar)")
            
            if has_task_in_memory:
                print("   ✅ P3 Compliance (Memory): SUCCESS")
                print("   ⚠️  P3 Compliance (Google Tasks): Requires manual verification")
            else:
                print("   ❌ P3 Compliance: FAILED - Task not found in memory document")
                
        except Exception as e:
            print(f"   ❌ Error reading Arthur's memory document: {e}")
    else:
        print("   ❌ Error: Arthur's memory_doc_id not found")
    
    print()
    
    # 4. DANA FLORES - P13 VALIDATION
    print("4. DANA FLORES - P13 VALIDATION (Executive Strategy Report)")
    print("-"*80)
    
    if dana_doc_id:
        try:
            doc = service.documents().get(documentId=dana_doc_id).execute()
            content = extract_text_from_document(doc)
            
            # Check for P13 report
            has_p13_report = (
                "P13" in content or
                "Executive Strategy Report" in content or
                "EXECUTIVE STRATEGY REPORT" in content
            )
            
            # Check for report sections
            has_report_sections = (
                "Section I: Executive Summary" in content or
                "Section II: Project Status" in content or
                "Section III: Compliance" in content
            )
            
            print(f"   ✅ Memory Document ID: {dana_doc_id}")
            print(f"   {'✅' if has_p13_report else '❌'} P13 Report: {'Found' if has_p13_report else 'Not Found'}")
            print(f"   {'✅' if has_report_sections else '❌'} Report Sections: {'Found' if has_report_sections else 'Not Found'}")
            
            if has_p13_report and has_report_sections:
                print("   ✅ P13 Compliance: SUCCESS")
            else:
                print("   ⚠️  P13 Compliance: Report may need to be generated")
                print("      Run: python3 enforce_p13_reporting.py")
                
        except Exception as e:
            print(f"   ❌ Error reading Dana's memory document: {e}")
    else:
        print("   ❌ Error: Dana's memory_doc_id not found")
    
    print()
    print("="*80)
    print("✅ VALIDATION COMPLETE")
    print("="*80)
    
    return True

if __name__ == "__main__":
    validate_meeting_protocols()

