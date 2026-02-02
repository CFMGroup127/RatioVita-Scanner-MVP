#!/bin/bash

# Comprehensive script to clean ALL GoogleAPIClientForREST references from project file
# This targets all reference types to completely remove cached references

PROJECT_FILE="RatioVita.xcodeproj/project.pbxproj"
BACKUP_FILE="RatioVita.xcodeproj/project.pbxproj.comprehensive_backup"

echo "Comprehensive cleaning of GoogleAPIClientForREST references from project file..."

# Create backup
cp "$PROJECT_FILE" "$BACKUP_FILE"
echo "Created backup: $BACKUP_FILE"

# Count references before cleaning
echo "References before cleaning:"
grep -c "GoogleAPIClientForREST" "$PROJECT_FILE"

# Comprehensive approach: Remove ALL types of references
echo "Removing ALL GoogleAPIClientForREST references..."

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

# 6. Remove remote info references
echo "Removing remote info references..."
sed -i '' '/remoteInfo = "GoogleAPIClientForREST/d' "$PROJECT_FILE"

# 7. Remove path references
echo "Removing path references..."
sed -i '' '/path = GoogleAPIClientForREST/d' "$PROJECT_FILE"

# 8. Remove framework in Frameworks references
echo "Removing framework in Frameworks references..."
sed -i '' '/GoogleAPIClientForREST\.framework in Frameworks/d' "$PROJECT_FILE"

# 9. Remove any remaining lines containing GoogleAPIClientForREST
echo "Removing any remaining GoogleAPIClientForREST references..."
sed -i '' '/GoogleAPIClientForREST/d' "$PROJECT_FILE"

# Count references after cleaning
echo "References after cleaning:"
grep -c "GoogleAPIClientForREST" "$PROJECT_FILE"

echo "Comprehensive cleaning completed. Backup saved to: $BACKUP_FILE"
