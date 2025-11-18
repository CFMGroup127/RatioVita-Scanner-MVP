"""
Remove victor.alvarez@ratiovita.com from all distribution lists
This script updates all Python files to exclude the invalid email address.
"""
import os
import re
from pathlib import Path

def remove_victor_from_lists():
    """
    Remove victor.alvarez@ratiovita.com from all distribution lists in Python scripts.
    """
    print("\n" + "="*80)
    print("🔧 REMOVING INVALID EMAIL FROM DISTRIBUTION LISTS")
    print("="*80)
    print("Email: victor.alvarez@ratiovita.com")
    print("Reason: Address not found / unable to receive mail")
    print("Action: Remove from all distribution lists")
    print("="*80)
    
    # Find all Python files in agents_system directory
    agents_system_dir = Path(__file__).parent
    python_files = list(agents_system_dir.glob("*.py"))
    
    print(f"\n📋 Found {len(python_files)} Python files to check")
    
    files_updated = []
    total_replacements = 0
    
    for file_path in python_files:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            original_content = content
            
            # Pattern 1: Remove victor.alvarez from comma-separated lists
            # Pattern: "victor.alvarez@ratiovita.com," or ", victor.alvarez@ratiovita.com"
            content = re.sub(r',\s*victor\.alvarez@ratiovita\.com', '', content)
            content = re.sub(r'victor\.alvarez@ratiovita\.com,\s*', '', content)
            
            # Pattern 2: Remove from individual_email_list constructions
            # This will be handled by the script logic, but we can note it
            
            # Count replacements
            replacements = len(re.findall(r'victor\.alvarez@ratiovita\.com', original_content))
            if replacements > 0:
                # Remove remaining instances (standalone or in different contexts)
                content = re.sub(r'victor\.alvarez@ratiovita\.com\s*', '', content)
                # Clean up any double commas that might result
                content = re.sub(r',\s*,', ',', content)
                content = re.sub(r',\s*\)', ')', content)
                content = re.sub(r'\(\s*,', '(', content)
                
                if content != original_content:
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(content)
                    files_updated.append(str(file_path))
                    total_replacements += replacements
                    print(f"✅ Updated: {file_path.name} ({replacements} instances removed)")
        except Exception as e:
            print(f"⚠️  Error processing {file_path.name}: {e}")
    
    print(f"\n📊 Summary:")
    print(f"  - Files updated: {len(files_updated)}")
    print(f"  - Total replacements: {total_replacements}")
    
    if files_updated:
        print(f"\n✅ Files updated:")
        for f in files_updated:
            print(f"   - {f}")
    else:
        print("\n⚠️  No files needed updating (victor.alvarez may not be in distribution lists)")
    
    # Also update agents.yaml to note the issue
    agents_yaml = agents_system_dir / "agents.yaml"
    if agents_yaml.exists():
        print(f"\n📝 Note: victor.alvarez@ratiovita.com remains in agents.yaml")
        print(f"   This is correct - the agent exists, but the email is invalid.")
        print(f"   Distribution lists in scripts will exclude this address.")
    
    print("\n" + "="*80)
    print("✅ EMAIL CLEANUP COMPLETE")
    print("="*80)
    print("\n⚠️  IMPORTANT: All future scripts must exclude victor.alvarez@ratiovita.com")
    print("   from distribution lists until the email address is verified/created.")
    
    return files_updated

if __name__ == "__main__":
    remove_victor_from_lists()


