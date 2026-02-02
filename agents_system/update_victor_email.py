"""
Update Victor Alvarez Email Address
This script allows you to update Victor's email address in agents.yaml
"""
import os
import yaml
from pathlib import Path

def update_victor_email(new_email=None):
    """
    Update Victor Alvarez's email address in agents.yaml.
    
    Args:
        new_email: New email address for Victor. If None, will prompt for options.
    """
    print("\n" + "="*80)
    print("📧 UPDATING VICTOR ALVAREZ EMAIL ADDRESS")
    print("="*80)
    
    agents_yaml = Path(__file__).parent / "agents.yaml"
    
    if not agents_yaml.exists():
        print(f"❌ Error: {agents_yaml} not found")
        return False
    
    # Read current agents.yaml
    with open(agents_yaml, 'r') as f:
        data = yaml.safe_load(f)
    
    # Find Victor's agent entry
    victor_found = False
    for agent in data.get('agents', []):
        if agent.get('role') == 'Go-to-Market Strategy' or agent.get('email_address') == 'victor.alvarez@ratiovita.com':
            victor_found = True
            old_email = agent.get('email_address', '')
            print(f"\n👤 Found Victor Alvarez:")
            print(f"   Role: {agent.get('role', 'N/A')}")
            print(f"   Current Email: {old_email}")
            
            if not new_email:
                print("\n📋 OPTIONS:")
                print("1. Keep current email (victor.alvarez@ratiovita.com)")
                print("2. Use collin.m@ratiovita.com as proxy")
                print("3. Enter a custom email address")
                print("\n⚠️  Note: If the email bounces, you should:")
                print("   - Verify the email exists in your email system")
                print("   - Or use a valid proxy email")
                print("   - Or update agents.yaml manually")
                
                choice = input("\nEnter choice (1/2/3) or email address: ").strip()
                
                if choice == '1':
                    print("\n✅ Keeping current email address")
                    print("⚠️  If this email bounces, you'll need to fix it in your email system")
                    return False
                elif choice == '2':
                    new_email = 'collin.m@ratiovita.com'
                elif choice == '3':
                    new_email = input("Enter new email address: ").strip()
                elif '@' in choice:
                    new_email = choice
                else:
                    print("❌ Invalid choice")
                    return False
            
            if new_email and new_email != old_email:
                agent['email_address'] = new_email
                print(f"\n✅ Updating email:")
                print(f"   Old: {old_email}")
                print(f"   New: {new_email}")
                
                # Write back to file
                with open(agents_yaml, 'w') as f:
                    yaml.dump(data, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
                
                print(f"\n✅ Successfully updated agents.yaml")
                print(f"   Victor's email is now: {new_email}")
                print(f"\n📝 Next steps:")
                print(f"   1. All future scripts will use the new email")
                print(f"   2. Remove victor.alvarez@ratiovita.com from INVALID_EMAILS in email_filter_helper.py")
                print(f"   3. Re-run meeting invitation scripts")
                return True
            else:
                print(f"\n✅ Email already set to: {old_email}")
                return False
    
    if not victor_found:
        print("❌ Error: Victor Alvarez not found in agents.yaml")
        return False

if __name__ == "__main__":
    import sys
    new_email = sys.argv[1] if len(sys.argv) > 1 else None
    update_victor_email(new_email)


