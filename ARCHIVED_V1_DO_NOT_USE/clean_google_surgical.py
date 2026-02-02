#!/usr/bin/env python3
"""
Surgical removal of Google/GTM references from Xcode project file
This script carefully removes Google references while preserving the file structure
"""

import re
import sys

def clean_google_surgically(project_file):
    with open(project_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    changes_made = 0
    
    # Pattern 1: Remove Google/GTM build file references (complete lines)
    pattern1 = r'^\s*[A-F0-9]{24}\s*/\*\s*(GTM|Google).*?\*/\s*=\s*\{isa\s*=\s*PBXBuildFile;[^}]*\};?\s*$'
    content, count = re.subn(pattern1, '', content, flags=re.MULTILINE | re.DOTALL)
    changes_made += count
    print(f"Removed {count} Google/GTM build file references")
    
    # Pattern 2: Remove Google/GTM file references (complete lines)
    pattern2 = r'^\s*[A-F0-9]{24}\s*/\*\s*(GTM|Google).*?\*/\s*=\s*\{isa\s*=\s*PBXFileReference;[^}]*\};?\s*$'
    content, count = re.subn(pattern2, '', content, flags=re.MULTILINE | re.DOTALL)
    changes_made += count
    print(f"Removed {count} Google/GTM file references")
    
    # Pattern 3: Remove Google/GTM target dependencies (complete lines)
    pattern3 = r'^\s*[A-F0-9]{24}\s*/\*\s*(GTM|Google).*?\*/\s*=\s*\{isa\s*=\s*PBXTargetDependency;[^}]*\};?\s*$'
    content, count = re.subn(pattern3, '', content, flags=re.MULTILINE | re.DOTALL)
    changes_made += count
    print(f"Removed {count} Google/GTM target dependencies")
    
    # Pattern 4: Remove Google/GTM from remoteInfo lines
    pattern4 = r'^\s*remoteInfo\s*=\s*"(GTM|Google).*?";\s*$'
    content, count = re.subn(pattern4, '', content, flags=re.MULTILINE)
    changes_made += count
    print(f"Removed {count} Google/GTM remoteInfo lines")
    
    # Pattern 5: Remove Google/GTM from dependency lists (but preserve the list structure)
    pattern5 = r'([A-F0-9]{24}\s*/\*\s*(GTM|Google).*?\*/,?\s*)'
    content, count = re.subn(pattern5, '', content, flags=re.MULTILINE)
    changes_made += count
    print(f"Removed {count} Google/GTM dependency list entries")
    
    # Clean up any empty lines that might have been created
    content = re.sub(r'\n\s*\n\s*\n', '\n\n', content)
    
    if changes_made > 0:
        with open(project_file, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"✅ Successfully removed {changes_made} Google/GTM references surgically")
        return True
    else:
        print("ℹ️ No Google/GTM references found")
        return False

if __name__ == "__main__":
    project_file = "RatioVita.xcodeproj/project.pbxproj"
    clean_google_surgically(project_file)
