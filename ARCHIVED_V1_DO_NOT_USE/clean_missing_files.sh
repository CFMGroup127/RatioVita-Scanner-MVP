#!/bin/bash

# Script to remove references to missing files from the project file
# This targets files that are referenced but don't exist

PROJECT_FILE="RatioVita.xcodeproj/project.pbxproj"
BACKUP_FILE="RatioVita.xcodeproj/project.pbxproj.missing_files_backup"

echo "Cleaning up references to missing files..."

# Create backup
cp "$PROJECT_FILE" "$BACKUP_FILE"
echo "Created backup: $BACKUP_FILE"

# List of missing files that need to be removed from project references
MISSING_FILES=(
    "SecurityCoreManager.swift"
    "MileageManager.swift"
    "Managers.swift"
    "LocationManager.swift"
    "FinancialManager.swift"
    "EmailProcessingManager.swift"
    "DocumentProcessor.swift"
    "CloudManager.swift"
)

# Remove references to missing files
for file in "${MISSING_FILES[@]}"; do
    echo "Removing references to $file..."
    
    # Remove PBXFileReference entries
    sed -i '' "/$file.*= {isa = PBXFileReference/d" "$PROJECT_FILE"
    
    # Remove PBXBuildFile entries
    sed -i '' "/$file.*in Sources/d" "$PROJECT_FILE"
    
    # Remove from file list in groups
    sed -i '' "/$file/d" "$PROJECT_FILE"
done

# Also remove Core Data model references from RatioVitaModels package
echo "Removing Core Data model references from RatioVitaModels package..."
sed -i '' "/RatioVitaModels.*CoreData.*RatioVita\.xcdatamodeld/d" "$PROJECT_FILE"

echo "Cleanup completed. Backup saved to: $BACKUP_FILE"
