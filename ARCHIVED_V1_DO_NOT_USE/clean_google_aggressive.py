#!/usr/bin/env python3
"""
Aggressive cleanup of ALL Google/GTM references from Xcode project file
"""

import re
import sys

def clean_google_aggressive(project_file):
    with open(project_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    changes_made = 0
    
    # Pattern 1: Remove ALL lines containing GTM or Google (complete lines)
    pattern1 = r'^[^}]*GTM[^}]*$'
    content, count = re.subn(pattern1, '', content, flags=re.MULTILINE)
    changes_made += count
    print(f"Removed {count} lines containing GTM")
    
    pattern2 = r'^[^}]*Google[^}]*$'
    content, count = re.subn(pattern2, '', content, flags=re.MULTILINE)
    changes_made += count
    print(f"Removed {count} lines containing Google")
    
    # Pattern 3: Remove any remaining GTM/Google references in multi-line blocks
    pattern3 = r'[A-F0-9]{24}\s*/\*\s*(GTM|Google).*?\*/,?\s*'
    content, count = re.subn(pattern3, '', content, flags=re.MULTILINE)
    changes_made += count
    print(f"Removed {count} GTM/Google references in blocks")
    
    # Pattern 4: Remove any remaining remoteInfo lines
    pattern4 = r'^\s*remoteInfo\s*=\s*(GTM|Google).*?;\s*$'
    content, count = re.subn(pattern4, '', content, flags=re.MULTILINE)
    changes_made += count
    print(f"Removed {count} remaining remoteInfo lines")
    
    # Clean up any empty lines that might have been created
    content = re.sub(r'\n\s*\n\s*\n', '\n\n', content)
    
    if changes_made > 0:
        with open(project_file, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"✅ Successfully removed {changes_made} Google/GTM references aggressively")
        return True
    else:
        print("ℹ️ No Google/GTM references found")
        return False

if __name__ == "__main__":
    project_file = "RatioVita.xcodeproj/project.pbxproj"
    clean_google_aggressive(project_file)







