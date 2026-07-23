#!/usr/bin/env bash
# Deploy Firestore security rules to the ratiovita-c1a79 Firebase project.
#
# Usage:
#   ./Scripts/deploy-firestore-rules.sh bootstrap    # signed-in users only (dev / emergency)
#   ./Scripts/deploy-firestore-rules.sh production   # clearance-gated production rules (default)
#
# Prerequisites:
#   npm install -g firebase-tools
#   firebase login
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROFILE="${1:-production}"

case "$PROFILE" in
  bootstrap)
    CONFIG="$ROOT/firebase.bootstrap.json"
    echo "Deploying BOOTSTRAP rules (authenticated users — not clearance-gated)."
    ;;
  production)
    CONFIG="$ROOT/firebase.json"
    echo "Deploying PRODUCTION rules (clearance-gated — requires security_clearance docs)."
    ;;
  *)
    echo "Unknown profile: $PROFILE" >&2
    echo "Usage: $0 [bootstrap|production]" >&2
    exit 1
    ;;
esac

if ! command -v firebase >/dev/null 2>&1; then
  echo "firebase-tools not found. Install with: npm install -g firebase-tools" >&2
  exit 1
fi

cd "$ROOT"
firebase deploy --only firestore:rules --config "$CONFIG" --project ratiovita-c1a79

echo "Done. Verify in Firebase Console → Firestore → Rules."
