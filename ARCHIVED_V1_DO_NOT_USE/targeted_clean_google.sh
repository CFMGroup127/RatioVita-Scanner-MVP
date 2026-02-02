#!/bin/bash

# Targeted script to remove problematic GoogleAPIClientForREST references
# Based on previous successful experience - only removes specific problematic references

PROJECT_FILE="RatioVita.xcodeproj/project.pbxproj"
BACKUP_FILE="RatioVita.xcodeproj/project.pbxproj.targeted_backup"

echo "Targeted cleaning of problematic GoogleAPIClientForREST references..."

# Create backup
cp "$PROJECT_FILE" "$BACKUP_FILE"
echo "Created backup: $BACKUP_FILE"

# Count references before cleaning
echo "References before cleaning:"
grep -c "GoogleAPIClientForREST" "$PROJECT_FILE"

# Targeted approach: Only remove specific problematic references
echo "Removing only problematic references..."

# 1. Remove build file references (PBXBuildFile) - these cause "file not found" errors
echo "Removing build file references..."
sed -i '' '/GoogleAPIClientForREST.*= {isa = PBXBuildFile/d' "$PROJECT_FILE"

# 2. Remove framework in Frameworks references - these cause linking errors
echo "Removing framework in Frameworks references..."
sed -i '' '/GoogleAPIClientForREST\.framework in Frameworks/d' "$PROJECT_FILE"

# 3. Remove file reference entries (PBXFileReference) - these point to missing files
echo "Removing file reference entries..."
sed -i '' '/GoogleAPIClientForREST.*= {isa = PBXFileReference/d' "$PROJECT_FILE"

# 4. Remove path references - these point to missing directories
echo "Removing path references..."
sed -i '' '/path = GoogleAPIClientForREST/d' "$PROJECT_FILE"

# Count references after cleaning
echo "References after cleaning:"
grep -c "GoogleAPIClientForREST" "$PROJECT_FILE"

echo "Targeted cleaning completed. Backup saved to: $BACKUP_FILE"
