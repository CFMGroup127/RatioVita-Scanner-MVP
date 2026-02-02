#!/bin/bash

echo "Cleaning up Google ecosystem pod references from project.pbxproj..."

# Remove Google ecosystem pod references
sed -i '' '/GoogleAPIClientForREST/d' RatioVita.xcodeproj/project.pbxproj
sed -i '' '/GTMSessionFetcher/d' RatioVita.xcodeproj/project.pbxproj
sed -i '' '/GTMAppAuth/d' RatioVita.xcodeproj/project.pbxproj
sed -i '' '/GoogleSignIn/d' RatioVita.xcodeproj/project.pbxproj

echo "Google ecosystem pod references removed from project.pbxproj!"
