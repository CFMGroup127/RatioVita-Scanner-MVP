
#!/bin/bash

# Surgical script to clean GoogleAPIClientForREST references from project file
# This targets only specific reference types to avoid damaging project structure

PROJECT_FILE="RatioVita.xcodeproj/project.pbxproj"
BACKUP_FILE="RatioVita.xcodeproj/project.pbxproj.surgical_backup"

echo "Surgical cleaning of GoogleAPIClientForREST references from project file..."

# Create backup
cp "$PROJECT_FILE" "$BACKUP_FILE"
echo "Created backup: $BACKUP_FILE"

# Count references before cleaning
echo "References before cleaning:"
grep -c "GoogleAPIClientForREST" "$PROJECT_FILE"

# Surgical approach: Only remove specific types of references
# 1. Remove build file references (PBXBuildFile)
echo "Removing build file references..."
sed -i '' '/GoogleAPIClientForREST.*= {isa = PBXBuildFile/d' "$PROJECT_FILE"

# 2. Remove file reference entries (PBXFileReference)
echo "Removing file reference entries..."
sed -i '' '/GoogleAPIClientForREST.*= {isa = PBXFileReference/d' "$PROJECT_FILE"

# 3. Remove group entries (PBXGroup)
echo "Removing group entries..."
sed -i '' '/GoogleAPIClientForREST.*= {isa = PBXGroup/d' "$PROJECT_FILE"

# 4. Remove framework entries (PBXFrameworkReference)
echo "Removing framework entries..."
sed -i '' '/GoogleAPIClientForREST.*= {isa = PBXFrameworkReference/d' "$PROJECT_FILE"

# 5. Remove bundle entries (PBXBundleReference)
echo "Removing bundle entries..."
sed -i '' '/GoogleAPIClientForREST.*= {isa = PBXBundleReference/d' "$PROJECT_FILE"

# Count references after cleaning
echo "References after cleaning:"
grep -c "GoogleAPIClientForREST" "$PROJECT_FILE"

echo "Surgical cleaning completed. Backup saved to: $BACKUP_FILE"
