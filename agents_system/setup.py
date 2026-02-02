"""
Interactive setup script for configuring the multi-agent system.
"""
import os
from pathlib import Path

def setup_api_key():
    """Help user set up their OpenAI API key."""
    env_file = Path(".env")
    
    if not env_file.exists():
        print("❌ .env file not found. Creating it...")
        env_file.write_text("OPENAI_API_KEY=\nOPENAI_MODEL=gpt-4-turbo-preview\n")
    
    # Read current .env
    current_content = env_file.read_text()
    
    # Check if key is already set
    if "OPENAI_API_KEY=sk-" in current_content or "OPENAI_API_KEY=your_" in current_content:
        print("\n📝 Current .env file:")
        print("-" * 60)
        for line in current_content.split('\n'):
            if 'OPENAI_API_KEY' in line:
                # Mask the key for display
                if 'sk-' in line:
                    masked = line.split('=')[0] + '=sk-***' + line.split('sk-')[1][-4:] if 'sk-' in line else line
                    print(masked)
                else:
                    print(line)
            else:
                print(line)
        print("-" * 60)
        
        response = input("\nAPI key already set. Do you want to update it? (y/n): ")
        if response.lower() != 'y':
            return
    
    print("\n" + "="*60)
    print("OpenAI API Key Setup")
    print("="*60)
    print("\nPlease enter your OpenAI API key.")
    print("(It should start with 'sk-')")
    print("\nYou can find it at: https://platform.openai.com/api-keys")
    print("\n" + "-"*60)
    
    api_key = input("\nEnter your OpenAI API key: ").strip()
    
    if not api_key.startswith('sk-'):
        print("⚠️  Warning: API key should start with 'sk-'. Continuing anyway...")
    
    # Update .env file
    lines = current_content.split('\n')
    updated_lines = []
    for line in lines:
        if line.startswith('OPENAI_API_KEY='):
            updated_lines.append(f'OPENAI_API_KEY={api_key}')
        else:
            updated_lines.append(line)
    
    env_file.write_text('\n'.join(updated_lines))
    print("\n✅ API key saved to .env file!")
    print("   (The .env file is in .gitignore and won't be committed)")

def main():
    """Main setup function."""
    print("\n" + "="*60)
    print("Multi-Agent System Setup")
    print("="*60)
    
    # Setup API key
    setup_api_key()
    
    print("\n" + "="*60)
    print("Next Steps:")
    print("="*60)
    print("\n1. ✅ API key configured")
    print("2. 📝 Add your 15 agent personas:")
    print("   - Edit 'add_agents.py' to add your agents")
    print("   - Or use the template in 'personas_template.py'")
    print("\n3. 🚀 Run: python3 add_agents.py")
    print("4. 🎯 Start using your agents!")

if __name__ == "__main__":
    main()

