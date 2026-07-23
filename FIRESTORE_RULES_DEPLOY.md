# Firestore Security Rules — RatioVita + VitaLogic

Firebase project: **`ratiovita-c1a79`**

This repo is the **canonical source** for Firestore rules shared by RatioVita and VitaLogic.

## Why you received the expiry alert

Firestore **test mode** allows open read/write for 30 days, then blocks all client access. Your alert (`expiring in 0 day(s)`) means client requests will start failing until rules are published.

Nothing in this folder auto-deploys. Rules are version-controlled here; you choose when to publish.

## Two rule profiles

| File | Profile | When to use |
|------|---------|-------------|
| `firestore.rules.bootstrap` | **Bootstrap** | Emergency / development — any **signed-in** user (anonymous auth counts) can access `productions/` and `artifacts/` |
| `firestore.rules` | **Production** | After `security_clearance` documents exist per production — role/tier gated access |

RatioVita uses anonymous Firebase auth today. Bootstrap rules work immediately after publish. Production rules require seeding clearance docs at:

```text
productions/{productionId}/security_clearance/{firebaseUID}
  role: "ProductionManager"   (or other role string)
  tier: 1
```

## Option A — Firebase Console (no CLI)

1. Open [Firebase Console](https://console.firebase.google.com/) → **ratiovita-c1a79** → **Firestore** → **Rules**
2. Copy contents of `firestore.rules.bootstrap` (if not ready for clearance gating) **or** `firestore.rules` (production)
3. Click **Publish**

## Option B — Firebase CLI (recommended)

```bash
npm install -g firebase-tools
firebase login

# Not ready for clearance gating yet — stops the lockout:
./Scripts/deploy-firestore-rules.sh bootstrap

# Ready for production clearance model:
./Scripts/deploy-firestore-rules.sh production
```

## RatioVita paths covered

Production rules include RatioVita `FirestoreCollectionRefs` paths:

- `productions/{id}/call_sheets/.../transit_exceptions`
- `productions/{id}/production_day_state/{docId}`
- `productions/{id}/ingestion_logs/{logId}`
- `productions/{id}/look_board_assets/{assetId}`
- `productions/{id}/medic_*`
- `productions/{id}/lsp_location_tasks/{taskId}`
- `productions/{id}/security_access_logs/{logId}`

## VitaLogic sync

VitaLogic maintains a copy at `VitaLogic/firestore.rules`. When updating rules here, copy or merge changes into the VitaLogic repo before deploying from either project checkout.

## Security notes

- Do **not** commit `GoogleService-Info.plist` (contains API keys).
- Bootstrap rules are **not** production-hardened — migrate to `firestore.rules` before App Store release.
- Anonymous UIDs differ per device until iCloud Keychain linking converges identity.
