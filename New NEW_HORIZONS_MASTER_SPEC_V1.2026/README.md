# New Horizons — RatioVita integration hub

Program: **New Horizons** at **176 Yonge Street** (historic Hudson's Bay / Simpson's flagship).  
Master spec folder (manuscript vault): `New NEW_HORIZONS_MASTER_SPEC_V1.2026/`

## Documents in this folder

| File | Purpose |
|------|---------|
| [NEW_HORIZONS_EXECUTIVE_SYNTHESIS.md](./NEW_HORIZONS_EXECUTIVE_SYNTHESIS.md) | One-place narrative: venue, Charles pitch, CF JV, math |
| [NEW_HORIZONS_APP_ARCHITECTURE.md](./NEW_HORIZONS_APP_ARCHITECTURE.md) | VitaLogic + RatioVita module epics (FSD-style) |
| [NEW_HORIZONS_DEAL_MEMO_TEMPLATE.md](./NEW_HORIZONS_DEAL_MEMO_TEMPLATE.md) | Charles / INK / CF terms, royalties, fleet rider |
| [NEW_HORIZONS_RND_ROADMAP_90_DAYS.md](./NEW_HORIZONS_RND_ROADMAP_90_DAYS.md) | Engineering sprint plan |
| [NEW_HORIZONS_PITCH_PLAYBOOK.md](./NEW_HORIZONS_PITCH_PLAYBOOK.md) | Opening script, NDA, teaser vs full Bible |

## Import into RatioVita (no receipt OCR)

1. Copy or save any `.md` / `.txt` from the master spec folder.
2. In the app: **Scanner / import** → pick the manuscript file (Camera capture import path detects `.md`).
3. Vault path: `New-Horizons/176-Yonge/Project-Manuscripts-Historical-Vault`
4. Tags: `NewHorizons`, `176Yonge`, `ManuscriptVault`

Code: `ManuscriptVaultImportService`, `NewHorizonsZoneCatalog`.

## Code anchors

- Zones: `RatioVita/Utilities/NewHorizonsZoneCatalog.swift`
- Program manifest (modules, rates): `RatioVita/Utilities/NewHorizonsProgramManifest.swift`
- Receipt fields: `expenseClassificationRaw`, `physicalZoneTag` on `Receipt`

## Next engineering (after docs)

See [NEW_HORIZONS_RND_ROADMAP_90_DAYS.md](./NEW_HORIZONS_RND_ROADMAP_90_DAYS.md) — geofence clock-in, BLE zones, AD Hold/Fire portal, union discount badges.
