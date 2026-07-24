# RatioVita + VitaLogic — Forensic Audit & Parity Matrix

**As of:** 2026-07-23  
**Repos audited:**

| Repo | Path | Typical branch (Jul 2026) |
|------|------|---------------------------|
| **RatioVita** | `RatioVita_v2` | `feature/sovereign-decoupled-ledger` |
| **VitaLogic** | `~/VitaLogic` | `fix/firebase-downcast-cleanup` |

**Purpose:** Cross-reference the **founding V2 blueprint**, **chat/architecture session lists** (multi-agent VitaLogic, SovereignPhysics, Firebase lifecycle, enterprise tiers), and **on-disk documentation** against what is actually implemented in Swift, Python agents, and Firebase wiring.

---

## How this audit was produced (and chat context limits)

| Source | What the assistant can use |
|--------|----------------------------|
| **This workspace** | Full read/search of RatioVita_v2 (and VitaLogic when on disk). |
| **Cursor agent transcripts** | Only when explicitly searched (e.g. `agent-transcripts/*.jsonl`); not an automatic index of every historical thread. |
| **Durable truth** | Committed `.md` files, code, `agents_system/`, and changelogs — treat these as the canonical record between sessions. |

If a feature appears only in a past chat and never landed in repo docs or code, it will show as **Not found / session-only** below.

---

## Executive summary

1. **RatioVita_v2** has grown far beyond the **May 2026** `BLUEPRINT_TRACEABILITY.md` snapshot: inventory/library SwiftData, production payroll & logistics, sovereign encrypted backup/restore, SetOS scaffolding, Firestore rules (prepared, not necessarily published), and hybrid agent broker stubs — while many **founding prompt** rows (full asset lifecycle, AI categorization, StoreKit monetization) remain open.
2. **VitaLogic** owns the **VitaLogic orchestration UI stack** from your session lists: **OpenRouter-compatible Kimi client**, **multi-persona agents**, **Board Room** collaboration UI, **`SovereignPhysics` + `GlassBottle3DView`** (SceneKit PBR). These symbols are **not present in RatioVita_v2** (grep-clean).
3. **`agents_system/`** (repo root) documents **Google Workspace / ratiovita.com** agent ops — largely **Python protocol automation**, not wired into the iOS/macOS targets.
4. **Firebase presence / high-frequency listeners:** **Partial** — RatioVita has real Firestore listeners with stored `ListenerRegistration` in logistics services; VitaLogic has auth state listener + **mock** meeting presence in Board Room; neither matches a full production presence heartbeat spec end-to-end.

---

## Section A — Your four-domain checklist (cross-repo)

### 1. Multi-Agent & AI Orchestration (VitaLogic Engine)

| Item | Status | Evidence |
|------|--------|----------|
| OpenRouter / dynamic model routing | **Partial (VitaLogic)** | `KimiIntegrationService.swift` — OpenAI-compatible base URL + model ID; Preferences preset for OpenRouter. Env: `KIMI_API_KEY`. No dedicated `OpenRouterClient` type name. |
| Multi-persona agent architecture | **Partial (VitaLogic)** | `AgentPersonaManager`, `AgentMantlePersonaMatrix.swift`, Gemini/Kimi persona injection. |
| Google Workspace agent infrastructure | **Partial (repo root)** | `agents_system/` scripts, YAML personas, `*@ratiovita.com` in verify/force-report docs — **not** in-app. |
| Context & state pipeline | **Partial** | VitaLogic task/agent listeners; RatioVita `HybridAgentBrokerService` + file queue under `RatioVita/HybridAgentBroker` — **local/cloud relay stub**, not full multi-agent debate loop. |
| RatioVita finance agents | **Partial** | `ReceiptFinanceAgentsService`, `GeminiBankStatementExtractionService`, `HybridAgentBrokerService.submit` from comptroller hooks. |

### 2. SwiftUI Frontend (RatioVita workspace vs VitaLogic glass stack)

| Item | Status | Evidence |
|------|--------|----------|
| Custom layout engine (finance/production) | **Shipped (RatioVita)** | Home modules, sovereign sidebar, SetOS views, logistics banners — not the glass parade stack. |
| Collaborative multi-agent workspace | **Partial (VitaLogic)** | `BoardRoomMeetingView`, Kanban/task views, streaming depends on backend mode (live Kimi vs sovereign sim). |
| Presence & status indicators | **Partial** | Board Room participant states; RatioVita SetOS/voice subscription refresh — **not** unified Firebase presence UI in RatioVita. |
| SovereignPhysics glass stack | **Shipped (VitaLogic sandbox)** | `GlassStackSandboxView.swift` — pitch **64.5°**, yaw **26.5°**, thickness **18pt**, parade **130×50**, step-out **25pt**. |
| GlassBottle3DView PBR | **Shipped (VitaLogic)** | `GlassBottle3DView.swift` — glass **IOR 1.52**, water **IOR 1.333**, studio HDRI / strip lighting comments. |

### 3. Backend Infrastructure & Firebase Lifecycle

| Item | Status | Evidence |
|------|--------|----------|
| Firebase bootstrap & UID keychain | **Shipped (RatioVita)** | `RatioVitaFirebaseBootstrap.swift`, `SovereignSharedAuthKeychain.swift` (shared group `com.cfmgroup.sovereign`). |
| Firestore security rules (prepared) | **Shipped (files)** | Repo root `firestore.rules`, `FIRESTORE_RULES_DEPLOY.md`, `Scripts/deploy-firestore-rules.sh` — **publish when operator ready**. |
| Listener lifecycle / teardown | **Partial** | e.g. `TransitGuardianStreamService` holds `ListenerRegistration?` — verify `deinit`/stop on scene tear-down in QA pass. |
| Presence heartbeats / onDisconnect | **Not started / mock** | Board Room: "Firebase presence lifecycle **simulation**" (`docs/FILE_STATE_REVIEW.md`). |
| Environment & key management | **Partial** | Kimi keys in UserDefaults + env; `GoogleService-Info.plist` local (untracked); no checked-in `.xcconfig` secrets. |

### 4. Platform Administration & Enterprise Rules

| Item | Status | Evidence |
|------|--------|----------|
| Administrative access tiers | **Not started (app)** | No `StoreKit`, `AdminRole`, or pricing tier types in RatioVita Swift grep. |
| Monetization / subscriptions | **Not started (app)** | Product copy mentions subscriptions in glossary/context only. |
| Audit log (sovereign) | **Partial** | `SovereignAuditLogEntry`, `SovereignAuditLogListView` — not full RBAC. |

---

## Section B — Xcode / Cursor audit checklist (from architecture sessions)

| Component / Layer | Target state | Checked | Finding |
| --- | --- | :---: | --- |
| **OpenRouter client** | Model endpoints + key fallback | ☑ | VitaLogic: `KimiIntegrationService` + Preferences; RatioVita: Gemini-first, no OpenRouter wrapper. |
| **Firebase listeners** | Teardown on scene change | ☐ | Code stores registrations; manual QA recommended on logistics + VitaLogic Firestore paths. |
| **`SovereignPhysics`** | 64.5° pitch, 26.5° yaw, 18pt lift | ☑ | Matches `GlassStackSandboxView.swift` constants. |
| **`GlassBottle3DView`** | Glass 1.52 / Water 1.333 | ☑ | Confirmed in SceneKit material setup. |
| **Lighting rig** | Backlit + L/R strip | ☑ | Documented in file header / HDRI path; verify visually in sandbox. |
| **Multi-agent UI states** | loading / reasoning / streaming | ☐ | Partial in task/Kimi flows; not unified across RatioVita receipt UI. |
| **Continuity / on-set tools** | Digital continuity engine | **Partial (RatioVita SetOS)** | Look boards, E104 continuity codes, first looks — **scaffold/sim**, not full breakdown graph. |
| **Haptics / proximity sign-in** | Production alerts | **Partial** | SetOS `HardwareIngestionManager`, wedding haptics — not crew sign-in product. |
| **Pages/Numbers/Keynote horizon** | Unified doc suite | **Backlog** | `UNIFIED_DOCUMENT_SUITE_BACKLOG.md` |

---

## Section C — Founding V2 blueprint (7 pillars) vs today (RatioVita)

Derived from `INITIAL_V2_BLUEPRINT.md` and code inspection (Jul 2026). See **`BLUEPRINT_TRACEABILITY.md`** for row-level receipt/finance detail; this table is the **strategic** layer.

| Pillar | May 2026 matrix said | Jul 2026 reality |
|--------|---------------------|------------------|
| Document filing cabinet | Partial placeholders | Still partial; sovereign sidebar + modules expanded; no full versioning tree. |
| Receipts / OCR / Gemini | Shipped / partial | **Shipped** core; bank recon **partial**; multi-page **partial**. |
| Asset lifecycle | Not started | Still largely **not started** (library/inventory models may exist — see `FEATURE_REGISTRY.md`). |
| Inventory / kits | Not started | **Partial** — extensive SwiftData library schema vs UI completeness varies by module. |
| Production / costume | Not started | **Partial / advanced** — production projects, payroll, SetOS, look boards, logistics Firestore. |
| Security / RBAC | Not started | **Partial** — sovereign backup encryption, audit log list; not enterprise RBAC. |
| Sync / backup | Not started | **Partial → Shipped paths** — `SovereignMasterBackupService`, `RatioVitaBackupManager`, restore service; Firestore sync for logistics; not full conflict-free sync. |

---

## Section D — Documentation corpus index (RatioVita_v2)

### In-app canonical docs (`RatioVita/RatioVita/Docs/`)

| File | Role |
|------|------|
| `INITIAL_V2_BLUEPRINT.md` | Founding prompt / scope |
| `BLUEPRINT_TRACEABILITY.md` | Prompt → code matrix (**updated 2026-07-23**) |
| `FORENSIC_AUDIT_2026-07-23.md` | **This file** |
| `PRODUCT_AND_ROADMAP.md` | Living product narrative |
| `PHASED_WORK_SCHEDULE.md` | Phase planning |
| `FEATURE_REGISTRY.md` | Feature inventory (May 2026) |
| `FEATURE_ACCESS_AUDIT.md` | Access / surface audit |
| `UNIFIED_DOCUMENT_SUITE_BACKLOG.md` | iWork integration horizon |
| `RatioVita_Audit_Report.md` | Prior structured audit |
| `VISION_AND_INSPIRATION.md`, `LEGACY_V1_GAP_NOTES.md` | Backlog & v1 gaps |
| `NewHorizons/` | Sprint notes subdirectory |
| `BUILD_AND_TOOLS.md`, `Config.md`, `ScannerPipelinePlan.md` | Engineering ops |

> Note: Root `docs/` may be gitignored; **`RatioVita/RatioVita/Docs/`** is the tracked app-doc tree (use `git add -f` if ignore rules block).

### Repo root & satellites (95+ `.md` files)

| Area | Paths | Notes |
|------|-------|------|
| **Agents / Google** | `agents_system/*.md` | Protocol audits Nov–Dec 2025, Kimi orchestrator role, setup guides — operational runbooks, not Swift. |
| **New Horizons** | `New NEW_HORIZONS_MASTER_SPEC_V1.2026/` | Pitch, architecture, Gemini transcript index, master feature ledger. |
| **Archive** | `ARCHIVED_V1_DO_NOT_USE/` | v1 phase progress — do not treat as current app. |
| **Firebase deploy** | `FIRESTORE_RULES_DEPLOY.md` | Bootstrap vs production rules. |
| **Changelog / ops** | `CHANGELOG.md`, `CHANGELOG_NEXT.md`, `cursor_tasks.md`, `MONDAY_IGNITION_VERIFICATION.md` | Release and verification notes. |

### VitaLogic docs (`~/VitaLogic/docs/`)

75 markdown files — many titled `*_COMPLETE.md` (Dec 2025 integration reports). **High-signal for parity:**

- `FILE_STATE_REVIEW.md` — Board Room + listener TODO closure snapshot  
- `KIMI_K2_LOGIC_BLUEPRINT.md`, `KIMI_BEHAVIORAL_LOGIC_BLUEPRINT.md`  
- `GOOGLE_WORKSPACE_ARCHITECTURE_COMPLETE.md`, `VITALOGIC_COMPREHENSIVE_FEATURE_DESCRIPTION.md`  
- `OUTSTANDING_FEATURES_COMPREHENSIVE.md`, `MISSING_FEATURES_AND_CONNECTIONS.md`  
- `FIREBASE_SETUP.md`, `SOVEREIGN_IDENTITY_IMPLEMENTATION.md`  

Treat `*_COMPLETE.md` as **milestone claims** — always verify against Swift.

### Backup / log artifacts (not a single “backup log” file)

| Kind | Location |
|------|----------|
| Sovereign encrypted backup | `SovereignMasterBackupService.swift`, `SovereignBackupEncryption.swift`, UI in `CloudVaultTransportSettingsSection.swift` |
| Local archive hooks | `RatioVitaBackupManager.swift` (post-write archive) |
| Agent Python logging | `agents_system/*logging*.py`, meeting retroactive logging scripts |
| Audit models | `SovereignAuditLogEntry.swift`, `SovereignAuditLogListView.swift` |

---

## Section E — Outstanding / session-only / high-risk gaps

1. **Split brain:** Glass stack + OpenRouter-first orchestration live in **VitaLogic**; RatioVita is **receipt + production + sovereign backup** heavy — plan explicit **shared package or sync** if you want one “RatioVita” binary story.  
2. **Firebase rules:** Wired locally; **test mode expiry** — use bootstrap rules first when publishing (`FIRESTORE_RULES_DEPLOY.md`).  
3. **Cross-device Firebase UID:** Keychain stores linked UID; **anonymous auth remains device-local** — custom tokens may be needed for true multi-device auth.  
4. **Enterprise tiers / monetization:** Documented in sessions; **no StoreKit/RBAC** in RatioVita target.  
5. **Real presence:** Replace Board Room mock with RTDB/Firestore presence + listener teardown tests.  
6. **Doc drift:** `FEATURE_REGISTRY.md` / `RatioVita_Audit_Report.md` (May 2026) predate sovereign ledger + Firestore work — refresh when closing phases.  
7. **Secrets:** Do not commit `GoogleService-Info.plist` or API keys; use schemes + Keychain/UserDefaults patterns already in VitaLogic Kimi settings.

---

## Section F — Recommended next audit passes (ordered)

1. **View layer:** RatioVita persona states on long-running Gemini jobs; VitaLogic Kimi live vs offline sim indicator binding.  
2. **Listener layer:** `TransitGuardianStreamService`, `ProductionLogisticsLiveCoordinator`, VitaLogic `FirebaseService` — document stop/start matrix in a one-page `FIREBASE_LISTENER_LIFECYCLE.md` (future).  
3. **Network layer:** Standardize OpenRouter/Gemini env naming across targets.  
4. **Environment sync:** Diff VitaLogic vs RatioVita Firebase project IDs and collection paths against `firestore.rules`.  

---

## Related links

- `BLUEPRINT_TRACEABILITY.md` — receipt/finance row matrix (updated Jul 2026)  
- `PRODUCT_AND_ROADMAP.md`  
- `UNIFIED_DOCUMENT_SUITE_BACKLOG.md`  
- `FIRESTORE_RULES_DEPLOY.md`  

*Regenerate or append when a major phase closes or when VitaLogic/RatioVita merge targets are chosen.*
