# New Horizons — VitaLogic & RatioVita system architecture

Functional specification for engineering. One app binary, three operational faces.

```
                  +---------------------------------------+
                  |     VITALOGIC & RATIOVITA KERNEL      |
                  +---------------------------------------+
                                      |
       +------------------------------+------------------------------+
       v                              v                              v
[ 1. VITALOGIC — Consumer ]   [ 2. RATIOVITA — Crew ]      [ 3. B2B STUDIO — Fleet ]
```

## 1. VitaLogic (consumer / guest)

**Goal:** Frictionless revenue, voting, packages — no receipt OCR on manuscripts.

| Epic ID | Feature | Data / integration |
|---------|---------|-------------------|
| `VitaLogic.Consumer` | PATH pre-order, grab-and-go, $6 breakfast hook | Orders tied to `Receipt` / POS export later |
| `VitaLogic.PensionDiscount` | OTPP 15% retired / 10% active | Credential upload → QR wallet badge |
| `VitaLogic.SpeakersCorner` | 30s exit booth clips → weekly vote | Media upload → YouTube cut pipeline (external) |
| `VitaLogic.ExperiencePackages` | Theater + hotel loft + dinner bundles | Partner codes; Mirvish / Massey / hotel blocks |

**RatioVita today:** payroll, receipts, vault, manuscripts, zones — **host** consumer UI when epics ship.

## 2. RatioVita (crew bio-insulation)

**Goal:** Cut turnover, fraud, injury — sell as B2B retainer to New Horizons OpCo.

| Epic ID | Feature | Sensors / rules |
|---------|---------|-----------------|
| `RatioVita.GeofenceClock` | No off-site punch-in/out | Building Wi‑Fi mesh + GPS fence at 176 Yonge |
| `RatioVita.BLEZoneTelemetry` | Zone-aware shift state | Beacons: PATH, GF theatre, L11 pit, Rebel hub |
| `RatioVita.BioInsulation` | Circadian panels, hydration prompts, rotation nudges | Tie to ticket timing + heat exposure on roof |

**Existing leverage:** `CrewTimecardDay`, `LaborAgreement`, EP Canada PDF, `HistoricalKnowledgeNode` for SOPs.

## 3. B2B studio module (mobile fleet)

**Goal:** Hold/Fire, standby fees, union-compliant per-head + fleet rider billing.

| Epic ID | Feature | Workflow |
|---------|---------|----------|
| `B2B.AssistantDirectorPortal` | Live wrap forecast, T-6h standby | Web or iPad role; pushes to kitchen |
| `B2B.HoldFireProtocol` | FIRE → dispatch; STAND-DOWN → $1,500 standby | Menu locked 12h before call |
| `B2B.FleetStandbyDispatch` | GTA vs Hamilton/Cobourg surcharge | Mileage + 20% OOZ labor on invoice |

**Defaults (manifest):** craft $15, meal $25–30, 28' $2k/day, 54' $5k/day — see `NewHorizonsProgramManifest.swift`.

## Cross-cutting

- **Auth:** Face ID / device biometric for crew; union card upload for discounts.
- **Billing:** Emergency Rescue Surcharge — 2× first rescue, +100% compounding per failed vendor swap (legal template in deal memo).
- **Media:** Docu-series arcs (origin → arrival → tech run → finale); not in v1 app — export metadata to production bible vault.

## Schema / vault

| Asset | Path |
|-------|------|
| Manuscripts | `New-Horizons/176-Yonge/Project-Manuscripts-Historical-Vault` |
| Deal memos | `New-Horizons/176-Yonge/Legal-Deal-Memos` |
| Fleet contracts | `New-Horizons/176-Yonge/Mobile-Fleet-B2B` |

Receipt tags: `expenseClassification` (Crew / CapEx / Culinary / Media), `physicalZoneTag` from `NewHorizonsZoneCatalog`.

## Dependency order (build)

1. Geofence + biometric clock (stops leakage).
2. AD portal + Hold/Fire state machine.
3. Pension / union discount verification.
4. Speakers' Corner upload (can be manual export first).
5. Package concierge (CRM-style, not full OTA).
