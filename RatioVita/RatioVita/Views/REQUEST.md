# RatioVita – Single‑Paste Diagnostic Request
Goal: Fix immediate launch crash (error 163) and ensure RatioVita’s theme is applied globally and consistently.

Instructions (single action):
- In Cursor, respond to this REQUEST.md by pasting the full content requested under each heading below. If a file doesn’t exist, write “MISSING”. Do not summarize; paste full file contents.

Note: This is a single copy‑and‑paste request. Provide everything here in one reply so we can produce exact, safe fixes.

---

## 0) Quick Context
- iOS version + simulator/device model you’re using:
- Xcode version:
- Did the crash start after a recent change? If yes, what changed? (e.g., SwiftData, theme, camera)
- Current issue summary: App crashes immediately on launch (error 163), design system not applied (default iOS styling).

---

## 1) App Entry Points (full files)

### 1.1 RatioVitaApp.swift
- Confirm `.modelContainer(...)` is applied at `WindowGroup` (or equivalent).
- Confirm theme modifier application at the root (either here or in ContentView).

