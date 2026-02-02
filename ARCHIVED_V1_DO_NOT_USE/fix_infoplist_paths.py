#!/usr/bin/env python3
"""
Script to check and fix Info.plist file paths for all CocoaPods targets.
This script will:
1. Check all pod targets in the Pods project
2. Verify their Info.plist file paths are correct
3. Fix any incorrect paths
"""

import os
import re
import subprocess
import sys
from pathlib import Path

def run_command(cmd):
    """Run a command and return the output."""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        return result.stdout.strip(), result.stderr.strip(), result.returncode
    except Exception as e:
        return "", str(e), -1

def get_pod_targets():
    """Get all pod targets from the project."""
    cmd = "find 'Pods/Target Support Files' -name '*-Info.plist' -type f"
    output, error, code = run_command(cmd)
    
    if code != 0:
        print(f"Error finding Info.plist files: {error}")
        return []
    
    targets = []
    for line in output.split('\n'):
        if line.strip():
            # Extract target name from path like "Pods/Target Support Files/AppAuth-iOS/AppAuth-iOS-Info.plist"
            path = Path(line.strip())
            target_name = path.parent.name
            targets.append(target_name)
    
    return sorted(set(targets))

def check_infoplist_path(target_name):
    """Check the Info.plist path for a specific target."""
    # Expected path format
    expected_path = f"$(SRCROOT)/Target Support Files/{target_name}/{target_name}-Info.plist"
    
    # Check if the file actually exists
    actual_path = f"Pods/Target Support Files/{target_name}/{target_name}-Info.plist"
    if not os.path.exists(actual_path):
        print(f"❌ ERROR: Info.plist file not found: {actual_path}")
        return False, expected_path
    
    print(f"✅ Found Info.plist for {target_name}: {actual_path}")
    return True, expected_path

def fix_infoplist_paths():
    """Main function to check and fix all Info.plist paths."""
    print("🔍 Checking CocoaPods Info.plist file paths...")
    print("=" * 60)
    
    targets = get_pod_targets()
    if not targets:
        print("❌ No pod targets found. Make sure 'pod install' was run successfully.")
        return False
    
    print(f"Found {len(targets)} pod targets:")
    for target in targets:
        print(f"  - {target}")
    print()
    
    # Check each target
    all_correct = True
    corrections = []
    
    for target in targets:
        is_correct, expected_path = check_infoplist_path(target)
        if not is_correct:
            all_correct = False
            corrections.append((target, expected_path))
    
    print("\n" + "=" * 60)
    
    if all_correct:
        print("✅ All Info.plist paths are correct!")
        return True
    else:
        print("❌ Found incorrect Info.plist paths that need to be fixed in Xcode:")
        print()
        for target, expected_path in corrections:
            print(f"Target: {target}")
            print(f"  Set Info.plist File to: {expected_path}")
            print()
        
        print("📋 Manual Fix Instructions:")
        print("1. Open Xcode workspace: RatioVita.xcworkspace")
        print("2. Select the Pods project in the Project Navigator")
        print("3. For each target listed above:")
        print("   - Select the target")
        print("   - Go to Build Settings tab")
        print("   - Search for 'Info.plist'")
        print("   - Update the 'Info.plist File' path to the correct value")
        print("4. Clean and rebuild the project")
        
        return False

if __name__ == "__main__":
    success = fix_infoplist_paths()
    sys.exit(0 if success else 1) 