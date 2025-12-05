"""
Run BLOCK A and BLOCK P concurrently for maximum efficiency.
This script launches both blocks simultaneously using multiprocessing.
"""
import subprocess
import sys
import os
from datetime import datetime

def run_blocks_concurrent():
    """
    Launch BLOCK A (Archival) and BLOCK P (Pre-Flight Strategy) concurrently.
    """
    print("\n" + "="*80)
    print("🚀 LAUNCHING BLOCK A & BLOCK P CONCURRENTLY")
    print("="*80)
    print(f"Start Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("="*80)
    
    # Change to agents_system directory
    agents_dir = "/Users/colliemorris/Projects 2/RatioVita_v2/agents_system"
    os.chdir(agents_dir)
    
    # Activate venv if it exists
    venv_activate = ""
    if os.path.exists("venv"):
        venv_activate = "source venv/bin/activate && "
    
    # Launch BLOCK A in background
    block_a_cmd = f"{venv_activate}python3 block_a_initial_delegation.py"
    block_a_log = f"block_a_concurrent_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
    
    # Launch BLOCK P in background
    block_p_cmd = f"{venv_activate}python3 block_p_preflight_strategy.py"
    block_p_log = f"block_p_concurrent_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
    
    print("\n📋 Launching:")
    print(f"   BLOCK A: Archival (Alice Kim) → {block_a_log}")
    print(f"   BLOCK P: Pre-Flight Strategy (Samuel, Arthur, Megan) → {block_p_log}")
    print("\n⏱️  Both blocks running concurrently...\n")
    
    # Launch both processes
    try:
        # BLOCK A
        block_a_process = subprocess.Popen(
            block_a_cmd,
            shell=True,
            stdout=open(block_a_log, 'w'),
            stderr=subprocess.STDOUT,
            cwd=agents_dir
        )
        
        # BLOCK P
        block_p_process = subprocess.Popen(
            block_p_cmd,
            shell=True,
            stdout=open(block_p_log, 'w'),
            stderr=subprocess.STDOUT,
            cwd=agents_dir
        )
        
        print(f"✅ BLOCK A Process ID: {block_a_process.pid}")
        print(f"✅ BLOCK P Process ID: {block_p_process.pid}")
        print("\n📊 Monitoring both processes...")
        print("   (Press Ctrl+C to stop monitoring, processes will continue in background)\n")
        
        # Wait for both to complete
        block_a_code = block_a_process.wait()
        block_p_code = block_p_process.wait()
        
        print("\n" + "="*80)
        print("✅ BOTH BLOCKS COMPLETE")
        print("="*80)
        print(f"BLOCK A Exit Code: {block_a_code}")
        print(f"BLOCK P Exit Code: {block_p_code}")
        print(f"\n📋 Logs:")
        print(f"   BLOCK A: {block_a_log}")
        print(f"   BLOCK P: {block_p_log}")
        print("="*80)
        
        # Check for errors
        if block_a_code != 0:
            print(f"\n⚠️  BLOCK A exited with code {block_a_code}")
        if block_p_code != 0:
            print(f"\n⚠️  BLOCK P exited with code {block_p_code}")
        
        return block_a_code == 0 and block_p_code == 0
        
    except KeyboardInterrupt:
        print("\n\n⚠️  Monitoring interrupted. Processes continue in background.")
        print(f"   BLOCK A PID: {block_a_process.pid}")
        print(f"   BLOCK P PID: {block_p_process.pid}")
        return False
    except Exception as e:
        print(f"\n❌ Error launching concurrent blocks: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = run_blocks_concurrent()
    sys.exit(0 if success else 1)



