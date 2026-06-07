# New Horizons — 176 Yonge Street  
## Master blueprint & Gemini conversation archive

**Source share:** [Gemini — Global Culinary Residency Concept](https://gemini.google.com/share/8cba871cd1ca)  
**Captured:** 2026-05-20 (manual transcript required — see `README_Gemini_Capture.md`)  
**RatioVita vault path:** `New-Horizons/176-Yonge/Project-Manuscripts-Historical-Vault`

---

## Transcript status

Full Gemini dialogue was captured **2026-05-21** (Cursor session paste). For navigation see **`NewHorizons_Gemini_Transcript_Index.md`**. Optional raw archive: **`NewHorizons_Gemini_Transcript_FULL.md`** (paste entire export there for vault import).

**RatioVita prep docs** (import into app):

- `RatioVita/RatioVita/Docs/NewHorizons/NEW_HORIZONS_EXECUTIVE_SYNTHESIS.md`
- `RatioVita/RatioVita/Docs/NewHorizons/NEW_HORIZONS_APP_ARCHITECTURE.md`
- `RatioVita/RatioVita/Docs/NewHorizons/NEW_HORIZONS_DEAL_MEMO_TEMPLATE.md`
- `RatioVita/RatioVita/Docs/NewHorizons/NEW_HORIZONS_RND_ROADMAP_90_DAYS.md`
- `RatioVita/RatioVita/Docs/NewHorizons/NEW_HORIZONS_PITCH_PLAYBOOK.md`

---

## Executive synthesis (from strategic planning session)

### Program thesis

New Horizons is a **high-volume culinary theatre and media production hub** at **176 Yonge Street** — a multi-floor heritage venue combining:

- 1,000-seat culinary theatre programming  
- Rooftop canopy / roasting infrastructure  
- Broadcast booth (“Speakers’ Corner”)  
- Heavy CapEx (kitchen, AV, structural)  
- Downtown Toronto logistics and fleet handoffs  

RatioVita must support **crew-scale payroll** (existing) plus **corporate CapEx**, **zone-sliced inventory**, and **manuscript / blueprint archives** (this document).

### Physical zones (RatioVita catalog)

See `NewHorizonsZoneCatalog.swift` — PATH concourse, ground soundstage, F2 Marché/lanai, F3 banquets, lofts, greenhouse shelf, talent lofts, L10 broadcast, L11 pit, Rebel fleet hub.

### Financial tiers

- **Crew field** — existing receipt / timesheet flows  
- **CapEx** — multi-line vendor POs, equipment, build-out  
- **Culinary logistics** — ingredients, commissary, Scoville-tier menu ops  
- **Media infrastructure** — cameras, LED, audio, post paths  

### RatioVita ingestion strategy

1. **Manuscripts** (this file, Songs of Solomon, Negative Confessions) → Media Core `HistoricalKnowledgeNode` + Manuscript vault receipt — **no receipt OCR**.  
2. **Field receipts & POs** → standard Review queue with `expenseClassification` + `physicalZoneTag`.  
3. **Cross-device** → `.rvvault` snapshots (Sprint VV) via Settings → Vault transport.  

### Competitive design stance (Obsidian × Notion × Zoho)

- **Storage:** Obsidian-style local-first (SwiftData + `.rvvault`), not Notion cloud lock-in.  
- **UI:** Notion-style modular surfaces when feature flags are on.  
- **Operations:** Zoho-style atomized modules (payroll, inventory, FSM, procurement) behind **radio-switch sovereignty panel** (planned Sprint XX).  

See `CompetitiveAnalysis_Obsidian_Notion_Zoho.md` for the full product matrix.

### Urgent build vectors (Sprint WW+)

1. CapEx schema + commercial invoice parsers  
2. Floor/venue zone filters on receipts, inventory, timecards  
3. Manuscript vault import (shipped)  
4. Identity graph for multi-name / multi-entity payroll resolution (Sprint ZZ)  
5. Passive creativity monitor → Manuscript module prompt (Sprint XX)  

---

## Appendix — link metadata

- **Share title observed:** Global Culinary Residency Concept  
- **Share ID:** `8cba871cd1ca`  
- **Automated fetch status:** Sign-in wall only; full transcript not available to build tools  

---

### Charles / deal / fleet (summary)

- **Pitch:** NDA → Rebel mental model → co–Executive Producer → live Bible (teaser only beforehand).
- **Phase 1:** $1.5–2.2M CAD development (fleet + RatioVita hardware).
- **Phase 2:** $350–500k showrunner salary; **3–5% gross** flagship royalty (escalator); **5–7%** fleet/catering; RatioVita **$25–40k/mo** retainer; Rebel **15%** fleet credit.
- **Fleet:** $15 craft / $25–30 meal; 28' $2k/day · 54' $5k/day; Hold/Fire + $1.5k standby; Emergency Rescue 2× compounding.
- **Competitive history:** highest-paid craft chef in Canada; synthesis of Blazing/DMC/Star Grazing flaws.

---

*Blueprint v1.2026 — engineering detail in `RatioVita/Docs/NewHorizons/`.*
