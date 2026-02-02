#!/bin/bash

# Comprehensive script to remove all Google-related pod references
# This targets GTMSessionFetcher, GTMAppAuth, GoogleAPIClientForREST, and related pods

PROJECT_FILE="RatioVita.xcodeproj/project.pbxproj"
BACKUP_FILE="RatioVita.xcodeproj/project.pbxproj.comprehensive_backup"

echo "Comprehensive cleaning of all Google-related pod references..."

# Create backup
cp "$PROJECT_FILE" "$BACKUP_FILE"
echo "Created backup: $BACKUP_FILE"

# Count references before cleaning
echo "References before cleaning:"
echo "GTMSessionFetcher: $(grep -c "GTMSessionFetcher" "$PROJECT_FILE")"
echo "GTMAppAuth: $(grep -c "GTMAppAuth" "$PROJECT_FILE")"
echo "GoogleAPIClientForREST: $(grep -c "GoogleAPIClientForREST" "$PROJECT_FILE")"
echo "GoogleSignIn: $(grep -c "GoogleSignIn" "$PROJECT_FILE")"

# Remove all Google-related references
echo "Removing all Google-related references..."

# Remove entire sections containing Google pods
sed -i '' '/GTMSessionFetcher.*= {/,/};/d' "$PROJECT_FILE"
sed -i '' '/GTMAppAuth.*= {/,/};/d' "$PROJECT_FILE"
sed -i '' '/GoogleAPIClientForREST.*= {/,/};/d' "$PROJECT_FILE"
sed -i '' '/GoogleSignIn.*= {/,/};/d' "$PROJECT_FILE"

# Remove individual file references
sed -i '' '/GTMSessionFetcher/d' "$PROJECT_FILE"
sed -i '' '/GTMAppAuth/d' "$PROJECT_FILE"
sed -i '' '/GoogleAPIClientForREST/d' "$PROJECT_FILE"
sed -i '' '/GoogleSignIn/d' "$PROJECT_FILE"

# Remove framework references
sed -i '' '/GTMSessionFetcher\.framework/d' "$PROJECT_FILE"
sed -i '' '/GTMAppAuth\.framework/d' "$PROJECT_FILE"
sed -i '' '/GoogleAPIClientForREST\.framework/d' "$PROJECT_FILE"
sed -i '' '/GoogleSignIn\.framework/d' "$PROJECT_FILE"

# Count references after cleaning
echo "References after cleaning:"
echo "GTMSessionFetcher: $(grep -c "GTMSessionFetcher" "$PROJECT_FILE" 2>/dev/null || echo "0")"
echo "GTMAppAuth: $(grep -c "GTMAppAuth" "$PROJECT_FILE" 2>/dev/null || echo "0")"
echo "GoogleAPIClientForREST: $(grep -c "GoogleAPIClientForREST" "$PROJECT_FILE" 2>/dev/null || echo "0")"
echo "GoogleSignIn: $(grep -c "GoogleSignIn" "$PROJECT_FILE" 2>/dev/null || echo "0")"

echo "Comprehensive cleaning completed. Backup saved to: $BACKUP_FILE"
