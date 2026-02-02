#!/usr/bin/env python3
"""
Clean Google and GTM references from Xcode project file
This script removes all Google-related build file references, file references, and target dependencies
"""

import re
import sys
from pathlib import Path

def clean_google_references(project_file):
    """Remove all Google and GTM references from the project file"""
    
    # Read the project file
    with open(project_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    changes_made = 0
    
    # Pattern 1: Remove Google/GTM build file references
    # Lines like: 045D6F93DD95F483B6DFF1BC /* GTMGatherInputStream.m in Sources */ = {isa = PBXBuildFile; fileRef = 4E472506F16E8EB510DC7FED /* GTMGatherInputStream.m */; };
    google_build_pattern = r'^\s*[A-F0-9]{24}\s*/\*\s*(GTM|Google).*?\*/\s*=\s*\{isa\s*=\s*PBXBuildFile;[^}]*\};?\s*$'
    content, count = re.subn(google_build_pattern, '', content, flags=re.MULTILINE | re.DOTALL)
    changes_made += count
    print(f"Removed {count} Google/GTM build file references")
    
    # Pattern 2: Remove Google/GTM file references
    # Lines like: 4E472506F16E8EB510DC7FED /* GTMGatherInputStream.m */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.objc; name = GTMGatherInputStream.m; path = ../../Pods/GTMSessionFetcher/Source/GTMSessionFetcher/GTMGatherInputStream.m; sourceTree = "<group>"; };
    google_file_pattern = r'^\s*[A-F0-9]{24}\s*/\*\s*(GTM|Google).*?\*/\s*=\s*\{isa\s*=\s*PBXFileReference;[^}]*\};?\s*$'
    content, count = re.subn(google_file_pattern, '', content, flags=re.MULTILINE | re.DOTALL)
    changes_made += count
    print(f"Removed {count} Google/GTM file references")
    
    # Pattern 3: Remove Google/GTM target dependencies
    # Lines like: 5BCE4F55EF1BD81E7C9399C8 /* GTMOAuth2KeychainCompatibility.m */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.objc; name = GTMOAuth2KeychainCompatibility.m; path = ../../Pods/GTMAppAuth/Source/GTMAppAuth/GTMOAuth2KeychainCompatibility.m; sourceTree = "<group>"; };
    google_target_pattern = r'^\s*[A-F0-9]{24}\s*/\*\s*(GTM|Google).*?\*/\s*=\s*\{isa\s*=\s*PBXTargetDependency;[^}]*\};?\s*$'
    content, count = re.subn(google_target_pattern, '', content, flags=re.MULTILINE | re.DOTALL)
    changes_made += count
    print(f"Removed {count} Google/GTM target dependencies")
    
    # Pattern 4: Remove Google/GTM from build phases
    # Remove lines containing GTM or Google from build phases
    google_build_phase_pattern = r'^\s*[A-F0-9]{24}\s*/\*\s*(GTM|Google).*?\*/\s*/\* Sources \*/,\s*$'
    content, count = re.subn(google_build_phase_pattern, '', content, flags=re.MULTILINE)
    changes_made += count
    print(f"Removed {count} Google/GTM build phase entries")
    
    # Pattern 5: Remove Google/GTM from frameworks
    google_framework_pattern = r'^\s*[A-F0-9]{24}\s*/\*\s*(GTM|Google).*?\*/\s*/\* Frameworks \*/,\s*$'
    content, count = re.subn(google_framework_pattern, '', content, flags=re.MULTILINE)
    changes_made += count
    print(f"Removed {count} Google/GTM framework entries")
    
    # Pattern 6: Remove Google/GTM from resources
    google_resource_pattern = r'^\s*[A-F0-9]{24}\s*/\*\s*(GTM|Google).*?\*/\s*/\* Resources \*/,\s*$'
    content, count = re.subn(google_resource_pattern, '', content, flags=re.MULTILINE)
    changes_made += count
    print(f"Removed {count} Google/GTM resource entries")
    
    # Pattern 7: Remove Google/GTM from embed frameworks
    google_embed_pattern = r'^\s*[A-F0-9]{24}\s*/\*\s*(GTM|Google).*?\*/\s*/\* Embed Frameworks \*/,\s*$'
    content, count = re.subn(google_embed_pattern, '', content, flags=re.MULTILINE)
    changes_made += count
    print(f"Removed {count} Google/GTM embed framework entries")
    
    # Pattern 8: Remove Google/GTM from copy files
    google_copy_pattern = r'^\s*[A-F0-9]{24}\s*/\*\s*(GTM|Google).*?\*/\s*/\* Copy Files \*/,\s*$'
    content, count = re.subn(google_copy_pattern, '', content, flags=re.MULTILINE)
    changes_made += count
    print(f"Removed {count} Google/GTM copy file entries")
    
    # Pattern 9: Remove Google/GTM from shell scripts
    google_script_pattern = r'^\s*[A-F0-9]{24}\s*/\*\s*(GTM|Google).*?\*/\s*/\* ShellScript \*/,\s*$'
    content, count = re.subn(google_script_pattern, '', content, flags=re.MULTILINE)
    changes_made += count
    print(f"Removed {count} Google/GTM script entries")
    
    # Pattern 10: Remove Google/GTM from headers
    google_header_pattern = r'^\s*[A-F0-9]{24}\s*/\*\s*(GTM|Google).*?\*/\s*/\* Headers \*/,\s*$'
    content, count = re.subn(google_header_pattern, '', content, flags=re.MULTILINE)
    changes_made += count
    print(f"Removed {count} Google/GTM header entries")
    
    # Pattern 11: Remove Google/GTM from libraries
    google_library_pattern = r'^\s*[A-F0-9]{24}\s*/\*\s*(GTM|Google).*?\*/\s*/\* Libraries \*/,\s*$'
    content, count = re.subn(google_library_pattern, '', content, flags=re.MULTILINE)
    changes_made += count
    print(f"Removed {count} Google/GTM library entries")
    
    # Pattern 12: Remove Google/GTM from bundle resources
    google_bundle_pattern = r'^\s*[A-F0-9]{24}\s*/\*\s*(GTM|Google).*?\*/\s*/\* Bundle Resources \*/,\s*$'
    content, count = re.subn(google_bundle_pattern, '', content, flags=re.MULTILINE)
    changes_made += count
    print(f"Removed {count} Google/GTM bundle resource entries")
    
    # Pattern 13: Remove Google/GTM from compile sources
    google_compile_pattern = r'^\s*[A-F0-9]{24}\s*/\*\s*(GTM|Google).*?\*/\s*/\* Compile Sources \*/,\s*$'
    content, count = re.subn(google_compile_pattern, '', content, flags=re.MULTILINE)
    changes_made += count
    print(f"Removed {count} Google/GTM compile source entries")
    
    # Pattern 14: Remove Google/GTM from link binary with libraries
    google_link_pattern = r'^\s*[A-F0-9]{24}\s*/\*\s*(GTM|Google).*?\*/\s*/\* Link Binary With Libraries \*/,\s*$'
    content, count = re.subn(google_link_pattern, '', content, flags=re.MULTILINE)
    changes_made += count
    print(f"Removed {count} Google/GTM link library entries")
    
    # Pattern 15: Remove Google/GTM from embed app extensions
    google_embed_ext_pattern = r'^\s*[A-F0-9]{24}\s*/\*\s*(GTM|Google).*?\*/\s*/\* Embed App Extensions \*/,\s*$'
    content, count = re.subn(google_embed_ext_pattern, '', content, flags=re.MULTILINE)
    changes_made += count
    print(f"Removed {count} Google/GTM embed app extension entries")
    
    # Pattern 16: Remove Google/GTM from embed watch content
    google_embed_watch_pattern = r'^\s*[A-F0-9]{24}\s*/\*\s*(GTM|Google).*?\*/\s*/\* Embed Watch Content \*/,\s*$'
    content, count = re.subn(google_embed_watch_pattern, '', content, flags=re.MULTILINE)
    changes_made += count
    print(f"Removed {count} Google/GTM embed watch content entries")
    
    # Pattern 17: Remove Google/GTM from embed frameworks (alternative pattern)
    google_embed_alt_pattern = r'^\s*[A-F0-9]{24}\s*/\*\s*(GTM|Google).*?\*/\s*/\* Embed Frameworks \*/,\s*$'
    content, count = re.subn(google_embed_alt_pattern, '', content, flags=re.MULTILINE)
    changes_made += count
    print(f"Removed {count} Google/GTM embed frameworks (alt) entries")
    
    # Pattern 18: Remove Google/GTM from embed app clips
    google_embed_clip_pattern = r'^\s*[A-F0-9]{24}\s*/\*\s*(GTM|Google).*?\*/\s*/\* Embed App Clips \*/,\s*$'
    content, count = re.subn(google_embed_clip_pattern, '', content, flags=re.MULTILINE)
    changes_made += count
    print(f"Removed {count} Google/GTM embed app clip entries")
    
    # Pattern 19: Remove Google/GTM from embed watch content (alternative pattern)
    google_embed_watch_alt_pattern = r'^\s*[A-F0-9]{24}\s*/\*\s*(GTM|Google).*?\*/\s*/\* Embed Watch Content \*/,\s*$'
    content, count = re.subn(google_embed_watch_alt_pattern, '', content, flags=re.MULTILINE)
    changes_made += count
    print(f"Removed {count} Google/GTM embed watch content (alt) entries")
    
    # Pattern 20: Remove Google/GTM from embed app extensions (alternative pattern)
    google_embed_ext_alt_pattern = r'^\s*[A-F0-9]{24}\s*/\*\s*(GTM|Google).*?\*/\s*/\* Embed App Extensions \*/,\s*$'
    content, count = re.subn(google_embed_ext_alt_pattern, '', content, flags=re.MULTILINE)
    changes_made += count
    print(f"Removed {count} Google/GTM embed app extensions (alt) entries")
    
    # Clean up any empty lines that might have been created
    content = re.sub(r'\n\s*\n\s*\n', '\n\n', content)
    
    # Write the cleaned content back
    if changes_made > 0:
        with open(project_file, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"\n✅ Successfully removed {changes_made} Google/GTM references from {project_file}")
        return True
    else:
        print(f"\nℹ️  No Google/GTM references found in {project_file}")
        return False

if __name__ == "__main__":
    project_file = "RatioVita.xcodeproj/project.pbxproj"
    
    if not Path(project_file).exists():
        print(f"❌ Project file not found: {project_file}")
        sys.exit(1)
    
    print(f"🧹 Cleaning Google/GTM references from {project_file}...")
    success = clean_google_references(project_file)
    
    if success:
        print("✅ Google/GTM cleanup completed successfully!")
    else:
        print("ℹ️  No changes were needed.")
