#!/usr/bin/env python3
"""
Comprehensive GTM/Google cleanup script for RatioVita project.pbxproj
Removes all GTM and Google-related references that are causing build failures
"""

import re
import sys
import os

def clean_gtm_references(file_path):
    """Remove all GTM and Google-related references from project.pbxproj"""
    
    # Read the file
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Patterns to remove - GTM and Google-related references
    patterns_to_remove = [
        # GTM file references
        r'[^\n]*GTM[^\n]*\.m in Sources[^\n]*\n',
        r'[^\n]*GTM[^\n]*\.h in Headers[^\n]*\n',
        r'[^\n]*GTM[^\n]*\.m in Sources[^\n]*\n',
        
        # GTM file references (PBXBuildFile)
        r'[^\n]*GTM[^\n]*\.m[^\n]*= \{isa = PBXBuildFile;[^\n]*\n',
        r'[^\n]*GTM[^\n]*\.h[^\n]*= \{isa = PBXBuildFile;[^\n]*\n',
        
        # GTM file references (PBXFileReference)
        r'[^\n]*GTM[^\n]*\.m[^\n]*= \{isa = PBXFileReference;[^\n]*\n',
        r'[^\n]*GTM[^\n]*\.h[^\n]*= \{isa = PBXFileReference;[^\n]*\n',
        
        # GTM groups
        r'[^\n]*GTM[^\n]*= \{isa = PBXGroup;[^\n]*\n',
        
        # GTM frameworks
        r'[^\n]*GTM[^\n]*\.framework[^\n]*\n',
        
        # Google references
        r'[^\n]*Google[^\n]*\.m in Sources[^\n]*\n',
        r'[^\n]*Google[^\n]*\.h in Headers[^\n]*\n',
        r'[^\n]*Google[^\n]*\.m[^\n]*= \{isa = PBXBuildFile;[^\n]*\n',
        r'[^\n]*Google[^\n]*\.h[^\n]*= \{isa = PBXBuildFile;[^\n]*\n',
        r'[^\n]*Google[^\n]*\.m[^\n]*= \{isa = PBXFileReference;[^\n]*\n',
        r'[^\n]*Google[^\n]*\.h[^\n]*= \{isa = PBXFileReference;[^\n]*\n',
        r'[^\n]*Google[^\n]*= \{isa = PBXGroup;[^\n]*\n',
        r'[^\n]*Google[^\n]*\.framework[^\n]*\n',
    ]
    
    # Remove patterns
    for pattern in patterns_to_remove:
        content = re.sub(pattern, '', content, flags=re.MULTILINE)
    
    # Remove GTM-related UUIDs from children arrays
    gtm_uuids = [
        '045D6F93DD95F483B6DFF1BC',
        '4E472506F16E8EB510DC7FED',
        '150ED36E6A402391E86AAC40',
        '673F7CFB7629444209D0A451',
        '2BDE2A05B40923AD93765803',
        '305D761A9F47BD1630C84B48',
        '14FC544F610914E2C2AAC114',
        '39E954F20DD2359247AAD8BE',
        '2F517D7A39347516D5D57054',
        '9562D13A82F8DC6AEABA2746',
        'A841BB8A22CD62473D12B136',
        '60E7CE84210D29C87077AE05',
        'A8F830BD9917B4576D6BAB44',
        'AFDE1393DD8FA007A442F868',
        '5BCE4F55EF1BD81E7C9399C8',
        'C5CA1FF1D569F27F28C2296E',
    ]
    
    # Remove UUIDs from children arrays
    for uuid in gtm_uuids:
        # Remove UUID from children arrays
        content = re.sub(rf'(\s*children = \(\s*)([^)]*{uuid}[^)]*)(\s*\);)', 
                        lambda m: m.group(1) + re.sub(rf'\s*{uuid}\s*,?\s*', '', m.group(2)) + m.group(3), 
                        content, flags=re.MULTILINE | re.DOTALL)
    
    # Clean up empty children arrays
    content = re.sub(r'(\s*children = \(\s*\);)', '', content, flags=re.MULTILINE)
    
    # Clean up trailing commas in children arrays
    content = re.sub(r',(\s*\);)', r'\1', content, flags=re.MULTILINE)
    
    # Write the cleaned content back
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    # Count changes
    original_lines = original_content.count('\n')
    new_lines = content.count('\n')
    removed_lines = original_lines - new_lines
    
    print(f"Cleaned {removed_lines} lines containing GTM/Google references")
    return removed_lines > 0

if __name__ == "__main__":
    project_file = "RatioVita.xcodeproj/project.pbxproj"
    
    if not os.path.exists(project_file):
        print(f"Error: {project_file} not found")
        sys.exit(1)
    
    print("Cleaning GTM/Google references from project.pbxproj...")
    if clean_gtm_references(project_file):
        print("✅ GTM/Google references cleaned successfully")
    else:
        print("ℹ️  No GTM/Google references found to clean")
