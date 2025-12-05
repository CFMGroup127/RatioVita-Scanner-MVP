#!/bin/bash
# Helper script to move credentials.json to the right location

echo "="
echo "Moving credentials.json to agents_system directory"
echo "="
echo ""

# Check Downloads folder
if [ -f ~/Downloads/credentials.json ]; then
    echo "✅ Found credentials.json in Downloads"
    cp ~/Downloads/credentials.json "/Users/colliemorris/Projects 2/RatioVita_v2/agents_system/credentials.json"
    echo "✅ Copied to agents_system directory"
elif [ -f ~/Downloads/client_secret_*.json ]; then
    echo "✅ Found client_secret file in Downloads"
    cp ~/Downloads/client_secret_*.json "/Users/colliemorris/Projects 2/RatioVita_v2/agents_system/credentials.json"
    echo "✅ Copied and renamed to credentials.json"
else
    echo "❌ No credentials.json found in Downloads folder"
    echo ""
    echo "Please:"
    echo "1. Download the JSON file from Google Cloud Console"
    echo "2. Save it to your Downloads folder"
    echo "3. Run this script again, OR"
    echo "4. Manually move it to:"
    echo "   /Users/colliemorris/Projects 2/RatioVita_v2/agents_system/credentials.json"
fi

echo ""
echo "Checking if file is now in place..."
if [ -f "/Users/colliemorris/Projects 2/RatioVita_v2/agents_system/credentials.json" ]; then
    echo "✅ SUCCESS: credentials.json is in the right place!"
    ls -lh "/Users/colliemorris/Projects 2/RatioVita_v2/agents_system/credentials.json"
else
    echo "❌ File not found. Please check the path above."
fi

