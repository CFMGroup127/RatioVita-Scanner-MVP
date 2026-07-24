# Unified Document Suite — Pages · Numbers · Keynote Integration Backlog

**Status:** 🔴 Future / not scheduled  
**Logged:** 2026-07-23  
**Owner note:** *"Not now, but later down the road"* — capture so we don't lose this on the long enhancement list.

**Related docs:** `PRODUCT_AND_ROADMAP.md` · `VISION_AND_INSPIRATION.md` · `MASTER_FEATURE_LEDGER_AND_COVERAGE.md` (New Horizons spec)

---

## North-star vision

Integrate the **core capabilities of Apple's Pages, Numbers, and Keynote** into RatioVita — not as three bolted-on apps, but as **native views of the same sovereign production data** that already powers receipts, scripts, call sheets, budgets, and continuity.

On film and TV productions, crews constantly app-hop: script revisions, continuity photos, call sheets, line-item budgets, vendor invoices — often across a dozen disconnected tools. RatioVita's multi-agent architecture is the right foundation to collapse that friction **when** a dynamic document + data-grid + canvas engine is layered in.

---

## Why this is the ideal evolutionary path

Traditional office suites fail on set because of **data isolation**: a cell in a spreadsheet doesn't know it's tied to a scene in a script breakdown, which doesn't know it's tied to an asset in a wardrobe truck.

RatioVita can solve that differently:

### Unified context layer

A script breakdown, continuity log, and budget spreadsheet would not be three separate files in three separate apps. They would be **different views of the same underlying production data** — the same entities RatioVita already tracks (productions, scenes, assets, receipts, call sheets, ledger lines).

### Agent-driven automation

Multi-agent workflows could:

- Automatically update budget lines when scene elements change in a breakdown
- Flag continuity inconsistencies between script pages and continuity notes
- Generate daily call sheets directly from live schedule grids
- Cross-reference vendor invoices against PO lines and department budgets without manual copy-paste

### Contextual intelligence

AI agents inside RatioVita would have simultaneous visibility across:

- **Narrative text** (script pages, sides, revision colors)
- **Tabular data** (budgets, timecards, expense matrices)
- **Visual layouts** (look boards, continuity photo grids, deck-style production briefings)

That eliminates the manual data entry and context-switching that consumes hours in prep and on set.

---

## Target capability map (iWork parity → production-native)

| iWork surface | Production-native RatioVita expression | Ties to existing stack |
|---------------|----------------------------------------|-------------------------|
| **Pages** | Script sides, call sheet narratives, production memos, deal memo exports, continuity notes | SetOS, script manager, call sheets, Sovereign export |
| **Numbers** | Department budgets, expense matrices, timecard grids, PO/invoice reconciliation tables | Finance agents, operational bookkeeper, reconciliation |
| **Keynote** | Production briefings, look boards, department dailies, investor/EP decks | Continuity vault, look board assets, corporate registry |

**Design principle:** One canvas/grid/document engine; multiple **view modes** over shared SwiftData + Firestore production graph — not three siloed file types.

---

## Architectural direction (when we pick this up)

1. **Shared document model** — blocks, tables, media embeds, and layout regions bound to production entities (scene ID, asset ID, receipt ID, production day state)
2. **View mode switcher** — same document opens as paginated narrative (Pages-like), live grid (Numbers-like), or slide/canvas (Keynote-like)
3. **Agent hooks** — `@Published` production mutations trigger agent passes that propose grid updates, flag conflicts, or draft deck slides
4. **Export interoperability** — keep Apple iWork export paths (`AppleiWorkService`, daily ledger Numbers scripts) as **export targets**, not the source of truth
5. **Offline-first** — SwiftData authoritative locally; Firestore sync for crew collaboration where clearance rules allow

---

## Phased incorporation (suggested — not committed)

| Phase | Scope | Depends on |
|-------|--------|------------|
| **A — Read-only views** | Render existing production data as grid + paginated report templates (no new editor) | Stable production schema, layout loop fixes |
| **B — Editable grids** | In-app Numbers-like editing for budgets, timecards, expense lines with agent validation | Firestore rules + clearance seeding |
| **C — Narrative canvas** | Pages-like blocks for scripts, sides, memos linked to scene/element IDs | Script manager maturity |
| **D — Presentation mode** | Keynote-like decks from look boards + daily summaries | Continuity vault, media core |
| **E — Full agent loop** | Agents auto-update linked views when any bound entity changes | Hybrid agent broker, production clearance |

---

## Success criteria (definition of done — future)

- [ ] A costume supervisor can update a breakdown grid and see budget impact without leaving RatioVita
- [ ] A script revision triggers agent review of continuity notes and flagged scene references
- [ ] A line producer generates a call sheet and daily sides from the same schedule grid
- [ ] Export to real `.pages` / `.numbers` / `.key` remains available but is no longer the primary workflow
- [ ] No app-hopping for the core prep/on-set document triangle: **script · spreadsheet · deck**

---

## Explicit non-goals (for now)

- Cloning iWork feature-for-feature (animations, full template marketplace, etc.)
- Replacing Final Draft / Movie Magic as specialist tools on day one
- Shipping before Firestore security rules and production clearance are production-ready

---

## One-line summary

> **Bring a unified Document + Data Grid + Canvas engine into RatioVita — tailored for high-velocity production — so teams stop drowning in app fatigue.**

---

*Add cross-links when implementation starts. Update status row in `PRODUCT_AND_ROADMAP.md` §5 when scheduled.*
