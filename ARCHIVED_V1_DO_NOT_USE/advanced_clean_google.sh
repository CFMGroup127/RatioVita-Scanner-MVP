#!/bin/bash

PROJECT_FILE="RatioVita.xcodeproj/project.pbxproj"
BACKUP_FILE="RatioVita.xcodeproj/project.pbxproj.advanced_backup"

echo "Advanced cleaning of GoogleAPIClientForREST references from project file..."
cp "$PROJECT_FILE" "$BACKUP_FILE"
echo "Created backup: $BACKUP_FILE"

echo "References before cleaning:"
grep -c "GoogleAPIClientForREST" "$PROJECT_FILE"

echo "Removing remaining problematic references..."

# Remove specific GTLR file references that are causing compilation issues
sed -i '' '/GTLR.*\.m in Sources/d' "$PROJECT_FILE"
sed -i '' '/GTLR.*\.h in Headers/d' "$PROJECT_FILE"

# Remove any remaining build file references
sed -i '' '/GoogleAPIClientForREST.*= {isa = PBXBuildFile/d' "$PROJECT_FILE"

# Remove any remaining file references
sed -i '' '/GoogleAPIClientForREST.*= {isa = PBXFileReference/d' "$PROJECT_FILE"

# Remove any remaining group references
sed -i '' '/GoogleAPIClientForREST.*= {isa = PBXGroup/d' "$PROJECT_FILE"

# Remove any remaining framework references
sed -i '' '/GoogleAPIClientForREST.*= {isa = PBXFrameworkReference/d' "$PROJECT_FILE"

# Remove any remaining bundle references
sed -i '' '/GoogleAPIClientForREST.*= {isa = PBXBundleReference/d' "$PROJECT_FILE"

# Remove any remaining remote info references
sed -i '' '/remoteInfo = "GoogleAPIClientForREST/d' "$PROJECT_FILE"

# Remove any remaining path references
sed -i '' '/path = GoogleAPIClientForREST/d' "$PROJECT_FILE"

# Remove any remaining framework in Frameworks references
sed -i '' '/GoogleAPIClientForREST\.framework in Frameworks/d' "$PROJECT_FILE"

echo "References after cleaning:"
grep -c "GoogleAPIClientForREST" "$PROJECT_FILE"

echo "Advanced cleaning completed. Backup saved to: $BACKUP_FILE"
