# ⚠️ IMPORTANT: tools.py Restoration Required

## Issue
The `tools.py` file was accidentally overwritten during the FileMoveTool addition process.

## What Happened
The file was truncated to only 40 lines (just the FileMoveTool definition) when it should be ~1214 lines with all Google API tools, Gmail tool, Calendar tool, etc.

## Required Action
**You need to restore `tools.py` from your backup or version control.**

## FileMoveTool Addition
Once `tools.py` is restored, add the FileMoveTool after the FileWriterTool definition (around line 155):

```python
# File Move Tool (for archiving/quarantining)
@tool("File Move Tool")
def file_move_tool(source_path: str, destination_path: str) -> str:
    """
    Move a file or directory from source_path to destination_path.
    This is useful for archiving, quarantining, or reorganizing files.
    
    Args:
        source_path: The full absolute path of the file or directory to move
        destination_path: The full absolute path of the destination (directory or new file path)
    
    Returns:
        Success message with confirmation of the move operation
    """
    import shutil
    
    try:
        if not os.path.exists(source_path):
            return f"Error: Source path '{source_path}' does not exist."
        
        # If destination is a directory, move source into it
        if os.path.isdir(destination_path):
            dest = os.path.join(destination_path, os.path.basename(source_path))
        else:
            dest = destination_path
        
        # Create parent directory if it doesn't exist
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        
        # Move the file or directory
        shutil.move(source_path, dest)
        
        return f"SUCCESS: Moved '{source_path}' to '{dest}'"
    except Exception as e:
        return f"Error moving file: {str(e)}"

def get_file_move_tool():
    """Get the FileMoveTool instance."""
    return file_move_tool
```

And add the export to the imports section in `main.py` (already done).

## Status
- ✅ `main.py` updated with FileMoveTool import and assignment
- ✅ `ash_roy_engineering_protocol.py` created and ready
- ❌ `tools.py` needs to be restored



