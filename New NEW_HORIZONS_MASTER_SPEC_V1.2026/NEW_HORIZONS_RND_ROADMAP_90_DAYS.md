# New Horizons — 90-day RatioVita / VitaLogic R&D roadmap

Aligns app R&D with Production Bible execution. Assumes existing RatioVita v2 shell (SwiftData, vault, EP Canada, manuscripts).

## Month 1 — Trust layer (crew)

**Theme:** Prove geofence clock + biometric auth on one pilot production.

| Week | Deliverable | Acceptance |
|------|-------------|------------|
| 1 | `GeofenceClockService` — fence polygon 176 Yonge + Rebel hub stub | Punch blocked outside fence |
| 2 | Biometric gate on shift start/end | No buddy punch on shared iPad |
| 3 | BLE beacon POC (2 zones: kitchen vs PATH) | App logs zone transitions |
| 4 | Pilot with 5–10 testers; export audit CSV | Legal review of location data policy |

**RatioVita surfaces:** Settings → New Horizons crew pilot toggle; audit in `FilingCoordinator`.

## Month 2 — Fleet Hold/Fire

**Theme:** AD portal alpha for 2nd meal standby.

| Week | Deliverable | Acceptance |
|------|-------------|------------|
| 5 | Data model: `ProductionMealWindow`, states `standby` / `fire` / `standDown` | Persisted per shoot day |
| 6 | iPad AD dashboard (role-gated) | T-6h standby alert |
| 7 | Push to “kitchen lead” notification stub | FIRE triggers dispatch checklist UI |
| 8 | Invoice line generator: standby $1500, OOZ flags | PDF/CSV export for deal memo billing |

**Vault:** store contracts under `Mobile-Fleet-B2B`.

## Month 3 — Consumer discounts & knowledge

**Theme:** Pension / union pass + manuscript ops at scale

| Week | Deliverable | Acceptance |
|------|-------------|------------|
| 9 | Credential upload → pending → approved badge | OTPP / union doc types |
| 10 | QR discount token in VitaLogic wallet (static MVP) | 10–15% at checkout manual verify |
| 11 | Bulk import all `Docs/NewHorizons/*.md` into knowledge graph | Nodes searchable in Media Core |
| 12 | CapEx + zone filters on receipt list for NH project | Filter by `physicalZoneTag` |

## Post-90 (backlog)

- Speakers' Corner video upload + vote Tally
- Experience package SKUs (theater bundles)
- POS integration / gross royalty reporting dashboard
- DMC displacement CRM — studio outreach tracker entity

## Team split (suggested)

| Track | Owner focus |
|-------|-------------|
| iOS crew | Geofence, BLE, RatioVita home module tile |
| iPad AD | SwiftUI portal, notifications |
| Backend later | Optional sync for AD portal; local-first OK for v1 |
| Legal/product | Deal memo vault imports, pitch playbook |

## Success metrics

- **Crew:** <2% off-site clock attempts; zero buddy punches in pilot
- **Fleet:** 1 real or simulated 2nd-meal week with Hold/Fire log + invoice lines
- **Knowledge:** Full New Horizons doc set in `HistoricalKnowledgeNode`
- **Business:** NDA signed + Charles meeting held (non-code milestone)

## Link to code constants

`NewHorizonsProgramManifest.ModuleEpic` — use for feature flags and analytics event names.
