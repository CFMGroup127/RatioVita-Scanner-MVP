#!/usr/bin/env bash
#
# Sovereign Archive Commit — Seal the recovery (Monday Ignition / Re-Hydration).
# Run after models are fixed and simulation is successful.
#

set -e
cd "$(dirname "$0")/.."

MESSAGE="[Sovereign Archive] - Service Verified at 144.0"

if [ -n "$(git status --porcelain)" ]; then
  git add -A
  git commit -m "$MESSAGE"
  echo "Sealed: $MESSAGE"
else
  echo "Nothing to commit; working tree clean."
fi
