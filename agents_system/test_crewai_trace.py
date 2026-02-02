"""
Simple test to generate a CrewAI trace that will appear in the dashboard.
This will verify that traces are being sent to your account (collin.m@ratiovita.com).
"""
import os
from crewai import Agent, Task, Crew
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Ensure telemetry is enabled
os.environ['CREWAI_TELEMETRY_OPT_OUT'] = 'false'

# Set CrewAI API token if available
crewai_token = os.getenv('CREWAI_API_TOKEN') or os.getenv('CREWAI_API_KEY')
if crewai_token:
    os.environ['CREWAI_API_KEY'] = crewai_token
    os.environ['CREWAI_API_TOKEN'] = crewai_token
    print(f"✅ CrewAI API token configured")
else:
    print("⚠️  No CrewAI API token found in environment")

print("="*80)
print("🧪 CREWAI TRACE GENERATION TEST")
print("="*80)
print()
print("This test will generate a trace that should appear in your dashboard")
print("Account: collin.m@ratiovita.com")
print("Dashboard: https://app.crewai.com/")
print()
if crewai_token:
    print(f"✅ Using API token: {crewai_token[:20]}...")
print()
print("="*80)
print()

# Create a simple test agent
test_agent = Agent(
    role='Trace Test Agent',
    goal='Generate a test trace to verify CrewAI dashboard integration',
    backstory='This is a test agent to verify that traces are being sent to the CrewAI dashboard correctly.',
    verbose=True
)

# Create a simple task
test_task = Task(
    description='Generate a test trace by completing a simple task: Say "Hello, this is a test trace from RatioVita V2 agent system" and confirm that this trace will appear in the CrewAI dashboard.',
    agent=test_agent,
    expected_output='A confirmation message that the trace has been generated'
)

# Create and run crew
print("🚀 Creating test crew...")
crew = Crew(
    agents=[test_agent],
    tasks=[test_task],
    verbose=True
)

print("✅ Crew created")
print()
print("="*80)
print("Starting test execution...")
print("="*80)
print()

try:
    result = crew.kickoff()
    
    print()
    print("="*80)
    print("✅ TEST EXECUTION COMPLETE")
    print("="*80)
    print()
    print("📊 Result:")
    print(result)
    print()
    print("="*80)
    print("🔍 NEXT STEPS:")
    print("="*80)
    print()
    print("1. Wait 1-2 minutes for trace to sync to dashboard")
    print("2. Go to: https://app.crewai.com/")
    print("3. Navigate to 'Traces' section")
    print("4. Look for a trace batch with:")
    print("   - Agent: 'Trace Test Agent'")
    print("   - Task: 'Generate a test trace...'")
    print("   - Recent timestamp (just now)")
    print()
    print("✅ If you see this trace, your setup is working correctly!")
    print("❌ If you don't see it after 2 minutes, check:")
    print("   - Are you logged in to the correct account?")
    print("   - Is CREWAI_TELEMETRY_OPT_OUT=false in .env?")
    print("   - Is CREWAI_API_TOKEN set correctly?")
    print("   - Check browser console for any errors")
    print()
    
except Exception as e:
    print()
    print("="*80)
    print("❌ TEST FAILED")
    print("="*80)
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()
