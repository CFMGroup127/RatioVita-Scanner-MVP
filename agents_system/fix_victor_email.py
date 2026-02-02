"""
Fix Victor Alvarez Email Issue
This script provides options to handle victor.alvarez@ratiovita.com email bounces.
"""
import os
from config import Config
from main import load_agents_from_yaml, get_agent_metadata

def fix_victor_email():
    """
    Fix Victor Alvarez email issue - provide options and recommendations.
    """
    print("\n" + "="*80)
    print("🔧 FIXING VICTOR ALVAREZ EMAIL ISSUE")
    print("="*80)
    print("Email: victor.alvarez@ratiovita.com")
    print("Issue: Address not found / unable to receive mail")
    print("="*80)
    
    # Validate configuration
    try:
        Config.validate()
        print("✅ Configuration validated")
    except ValueError as e:
        print(f"❌ Configuration Error: {e}")
        return None
    
    # Load agents
    print("\n📋 Loading agents...")
    try:
        agents = load_agents_from_yaml('agents.yaml')
        print(f"✅ Loaded {len(agents)} agents")
    except Exception as e:
        print(f"❌ Error loading agents: {e}")
        return None
    
    # Get Victor's metadata
    victor_meta = get_agent_metadata("Go-to-Market Strategy")
    victor_email = victor_meta.get('email_address', 'victor.alvarez@ratiovita.com')
    victor_role = "Go-to-Market Strategy"
    
    print(f"\n👤 Victor Alvarez Configuration:")
    print(f"   Role: {victor_role}")
    print(f"   Email: {victor_email}")
    print(f"   Memory Doc ID: {victor_meta.get('memory_doc_id', 'N/A')}")
    
    print("\n" + "="*80)
    print("📋 RECOMMENDED SOLUTIONS")
    print("="*80)
    
    print("\n✅ OPTION 1: Email Address Verification (RECOMMENDED)")
    print("   - Verify if victor.alvarez@ratiovita.com should exist")
    print("   - Check if it's a typo (e.g., victor.alvarez@ratiovita.com vs victor.alvarez@ratiovita.com)")
    print("   - Create the email address in your email system if it should exist")
    print("   - Once verified, no code changes needed")
    
    print("\n✅ OPTION 2: Temporary Email Replacement")
    print("   - Replace with a valid email address (e.g., collin.m@ratiovita.com as proxy)")
    print("   - Update agents.yaml with the new email")
    print("   - All scripts will automatically use the new address")
    
    print("\n✅ OPTION 3: Smart Email Filtering (IMPLEMENTED)")
    print("   - Create a function that filters out invalid emails before sending")
    print("   - Logs which emails failed for monitoring")
    print("   - Victor remains in the system but won't cause bounces")
    
    print("\n" + "="*80)
    print("🔧 IMPLEMENTING OPTION 3: Smart Email Filtering")
    print("="*80)
    
    # Create a list of known invalid emails
    INVALID_EMAILS = ['victor.alvarez@ratiovita.com']
    
    # Get all agent emails
    all_agent_emails = []
    valid_agent_emails = []
    invalid_agent_emails = []
    
    for agent in agents:
        agent_meta = get_agent_metadata(agent.role)
        email = agent_meta.get('email_address', '')
        if email:
            all_agent_emails.append(email)
            if email.lower() in [e.lower() for e in INVALID_EMAILS]:
                invalid_agent_emails.append(email)
                print(f"⚠️  Invalid email (will be filtered): {email} ({agent.role})")
            else:
                valid_agent_emails.append(email)
    
    print(f"\n📊 Email Status:")
    print(f"   Total agents: {len(all_agent_emails)}")
    print(f"   Valid emails: {len(valid_agent_emails)}")
    print(f"   Invalid emails: {len(invalid_agent_emails)}")
    
    if invalid_agent_emails:
        print(f"\n⚠️  Invalid emails that will be filtered:")
        for email in invalid_agent_emails:
            print(f"   - {email}")
    
    print(f"\n✅ Valid email list for distribution ({len(valid_agent_emails)} addresses):")
    for email in valid_agent_emails:
        print(f"   - {email}")
    
    # Create a helper function file
    helper_code = f'''"""
Email Filtering Helper
Filters out invalid email addresses before sending.
"""
INVALID_EMAILS = {INVALID_EMAILS}

def filter_valid_emails(email_list):
    """
    Filter out invalid email addresses from a list.
    
    Args:
        email_list: List of email addresses or comma-separated string
        
    Returns:
        List of valid email addresses
    """
    if isinstance(email_list, str):
        emails = [e.strip() for e in email_list.split(',')]
    else:
        emails = email_list
    
    valid_emails = []
    invalid_emails = []
    
    for email in emails:
        email_clean = email.strip()
        if email_clean and email_clean.lower() not in [e.lower() for e in INVALID_EMAILS]:
            valid_emails.append(email_clean)
        elif email_clean:
            invalid_emails.append(email_clean)
    
    if invalid_emails:
        print(f"⚠️  Filtered out invalid emails: {{', '.join(invalid_emails)}}")
    
    return valid_emails

def get_all_valid_agent_emails():
    """
    Get all valid agent email addresses (excluding invalid ones).
    
    Returns:
        List of valid agent email addresses
    """
    from main import load_agents_from_yaml, get_agent_metadata
    
    agents = load_agents_from_yaml('agents.yaml')
    valid_emails = []
    
    for agent in agents:
        agent_meta = get_agent_metadata(agent.role)
        email = agent_meta.get('email_address', '')
        if email and email.lower() not in [e.lower() for e in INVALID_EMAILS]:
            valid_emails.append(email)
    
    return valid_emails
'''
    
    helper_file = os.path.join(os.path.dirname(__file__), 'email_filter_helper.py')
    with open(helper_file, 'w') as f:
        f.write(helper_code)
    
    print(f"\n✅ Created email filtering helper: {helper_file}")
    print("   This can be imported in scripts to filter invalid emails")
    
    print("\n" + "="*80)
    print("📝 NEXT STEPS")
    print("="*80)
    print("\n1. Update meeting invitation scripts to use email filtering:")
    print("   from email_filter_helper import filter_valid_emails, get_all_valid_agent_emails")
    print("   valid_emails = get_all_valid_agent_emails()")
    print("   # Use valid_emails instead of all agent emails")
    print("\n2. For Victor to receive invites:")
    print("   - OPTION A: Verify/create victor.alvarez@ratiovita.com email address")
    print("   - OPTION B: Update agents.yaml with a valid email for Victor")
    print("   - OPTION C: Use email filtering (Victor won't receive emails but won't cause bounces)")
    print("\n3. Once Victor's email is fixed, remove it from INVALID_EMAILS list")
    
    return {
        'valid_emails': valid_agent_emails,
        'invalid_emails': invalid_agent_emails,
        'helper_file': helper_file
    }

if __name__ == "__main__":
    fix_victor_email()

