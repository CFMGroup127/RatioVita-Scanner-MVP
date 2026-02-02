#!/usr/bin/env python3
"""
Remove remaining Google/GTM references from Xcode project file
"""

import re
import sys

def clean_remaining_google_references(project_file):
    with open(project_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    changes_made = 0
    
    # Remove remoteInfo lines with Google/GTM
    pattern1 = r'^\s*remoteInfo\s*=\s*"(GTM|Google).*?";\s*$'
    content, count = re.subn(pattern1, '', content, flags=re.MULTILINE)
    changes_made += count
    print(f"Removed {count} Google/GTM remoteInfo lines")
    
    # Remove GTMAppAuth target definition blocks
    pattern2 = r'^\s*[A-F0-9]{24}\s*/\*\s*GTMAppAuth\s*\*/\s*=\s*\{[^}]*\};?\s*$'
    content, count = re.subn(pattern2, '', content, flags=re.MULTILINE | re.DOTALL)
    changes_made += count
    print(f"Removed {count} GTMAppAuth target blocks")
    
    # Remove GoogleSignIn target definition blocks
    pattern3 = r'^\s*[A-F0-9]{24}\s*/\*\s*GoogleSignIn\s*\*/\s*=\s*\{[^}]*\};?\s*$'
    content, count = re.subn(pattern3, '', content, flags=re.MULTILINE | re.DOTALL)
    changes_made += count
    print(f"Removed {count} GoogleSignIn target blocks")
    
    # Remove GTMSessionFetcher target definition blocks
    pattern4 = r'^\s*[A-F0-9]{24}\s*/\*\s*GTMSessionFetcher\s*\*/\s*=\s*\{[^}]*\};?\s*$'
    content, count = re.subn(pattern4, '', content, flags=re.MULTILINE | re.DOTALL)
    changes_made += count
    print(f"Removed {count} GTMSessionFetcher target blocks")
    
    if changes_made > 0:
        with open(project_file, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"✅ Removed {changes_made} remaining Google/GTM references")
        return True
    else:
        print("ℹ️ No remaining Google/GTM references found")
        return False

if __name__ == "__main__":
    project_file = "RatioVita.xcodeproj/project.pbxproj"
    clean_remaining_google_references(project_file)
