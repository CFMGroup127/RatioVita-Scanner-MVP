#!/usr/bin/env python3
"""
Final cleanup of all remaining Google/GTM references
"""

import re
import sys

def clean_final_google_references(project_file):
    with open(project_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    changes_made = 0
    
    # Remove any remaining remoteInfo lines with Google/GTM
    pattern1 = r'^\s*remoteInfo\s*=\s*(GTM|Google).*?;\s*$'
    content, count = re.subn(pattern1, '', content, flags=re.MULTILINE)
    changes_made += count
    print(f"Removed {count} remaining Google/GTM remoteInfo lines")
    
    # Remove any remaining GTM/Google references in dependency lists
    pattern2 = r'[A-F0-9]{24}\s*/\*\s*(GTM|Google).*?\*/,?\s*'
    content, count = re.subn(pattern2, '', content, flags=re.MULTILINE)
    changes_made += count
    print(f"Removed {count} Google/GTM dependency references")
    
    # Remove entire target blocks that contain GTM/Google
    pattern3 = r'^\s*[A-F0-9]{24}\s*/\*\s*(GTM|Google).*?\*/\s*=\s*\{[^}]*\};?\s*$'
    content, count = re.subn(pattern3, '', content, flags=re.MULTILINE | re.DOTALL)
    changes_made += count
    print(f"Removed {count} Google/GTM target blocks")
    
    # Remove any remaining GTM/Google file references
    pattern4 = r'^\s*[A-F0-9]{24}\s*/\*\s*(GTM|Google).*?\*/\s*=\s*\{isa\s*=\s*PBXFileReference;[^}]*\};?\s*$'
    content, count = re.subn(pattern4, '', content, flags=re.MULTILINE | re.DOTALL)
    changes_made += count
    print(f"Removed {count} Google/GTM file references")
    
    # Clean up any empty lines that might have been created
    content = re.sub(r'\n\s*\n\s*\n', '\n\n', content)
    
    if changes_made > 0:
        with open(project_file, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"✅ Removed {changes_made} final Google/GTM references")
        return True
    else:
        print("ℹ️ No remaining Google/GTM references found")
        return False

if __name__ == "__main__":
    project_file = "RatioVita.xcodeproj/project.pbxproj"
    clean_final_google_references(project_file)
