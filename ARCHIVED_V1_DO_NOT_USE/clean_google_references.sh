#!/bin/bash

# Script to clean GoogleAPIClientForREST references from project file
# This will remove cached references that are causing build issues

PROJECT_FILE="RatioVita.xcodeproj/project.pbxproj"
BACKUP_FILE="RatioVita.xcodeproj/project.pbxproj.clean_backup"

echo "Cleaning GoogleAPIClientForREST references from project file..."

# Create backup
cp "$PROJECT_FILE" "$BACKUP_FILE"
echo "Created backup: $BACKUP_FILE"

# Remove GoogleAPIClientForREST references
# This removes lines containing GoogleAPIClientForREST but preserves the file structure

# Remove build file references
sed -i '' '/GoogleAPIClientForREST.*in Sources/d' "$PROJECT_FILE"
sed -i '' '/GoogleAPIClientForREST.*in Resources/d' "$PROJECT_FILE"
sed -i '' '/GoogleAPIClientForREST.*in Frameworks/d' "$PROJECT_FILE"

# Remove file references
sed -i '' '/GoogleAPIClientForREST.*\.h/d' "$PROJECT_FILE"
sed -i '' '/GoogleAPIClientForREST.*\.m/d' "$PROJECT_FILE"
sed -i '' '/GoogleAPIClientForREST.*\.mm/d' "$PROJECT_FILE"

# Remove build phase references
sed -i '' '/GoogleAPIClientForREST/d' "$PROJECT_FILE"

echo "Cleaned GoogleAPIClientForREST references from project file"
echo "Backup saved to: $BACKUP_FILE"
