"""
Email Filtering Helper
Filters out invalid email addresses before sending.
"""
INVALID_EMAILS = []  # victor.alvarez@ratiovita.com removed - email tested and working

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
        print(f"⚠️  Filtered out invalid emails: {', '.join(invalid_emails)}")
    
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
