#!/usr/bin/env python3

import re

# Files to remove from build
disabled_files = [
    'GmailProvider.swift',
    'GoogleCalendarProvider.swift', 
    'GoogleDriveProvider.swift',
    'ViewImports.swift'
]

# Read the project file
with open('RatioVita/RatioVita.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# Track changes
changes_made = 0

for file_name in disabled_files:
    print(f"Processing {file_name}...")
    
    # Replace build file entries
    pattern1 = r'\t\t[A-F0-9]+ /\* ' + re.escape(file_name) + r' in Sources \*/ = \{isa = PBXBuildFile; fileRef = [A-F0-9]+ /\* ' + re.escape(file_name) + r' \*/; \};'
    replacement1 = f'\t\t/* {file_name} DISABLED per Microsoft-first strategy */'
    content = re.sub(pattern1, replacement1, content)
    
    # Replace file reference entries
    pattern2 = r'\t\t[A-F0-9]+ /\* ' + re.escape(file_name) + r' \*/ = \{isa = PBXFileReference; lastKnownFileType = sourcecode\.swift; path = ' + re.escape(file_name) + r'; sourceTree = "<group>"; \};'
    replacement2 = f'\t\t/* {file_name} DISABLED per Microsoft-first strategy */'
    content = re.sub(pattern2, replacement2, content)
    
    # Replace group entries
    pattern3 = r'\t\t\t\t[A-F0-9]+ /\* ' + re.escape(file_name) + r' \*/,'
    replacement3 = f'\t\t\t\t/* {file_name} DISABLED */,'
    content = re.sub(pattern3, replacement3, content)
    
    # Replace build phase entries
    pattern4 = r'\t\t\t\t[A-F0-9]+ /\* ' + re.escape(file_name) + r' in Sources \*/,'
    replacement4 = f'\t\t\t\t/* {file_name} DISABLED */,'
    content = re.sub(pattern4, replacement4, content)
    
    changes_made += 1

# Write back the file
with open('RatioVita/RatioVita.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)

print(f"Fixed {changes_made} disabled files in project.pbxproj")

