# QuakeRoute — UI/UX Specification

## 0. Document Status and Source of Truth

- **Source of truth:** `PRD.md`, `SRS.md`, `Tech-Stack.md`, `Architecture-Document.md`. This document does not introduce any feature, screen, requirement, or data field that is not traceable to those documents. Where a source document marks something `TBD` (e.g. exact severity scale, numeric risk parameters, response-time targets, exact hazard status set), this document leaves it `TBD` and instead defines the **UI contract** the implementation must honor once the value is decided.
- **What this document does:** translates the confirmed feature set (PRD §9, §18; SRS §4) and the confirmed technical architecture (Flutter mobile client, Feature-Oriented structure, REST-only communication with the Laravel backend — Architecture §5) into a concrete, implementable Flutter UI/UX specification: design tokens, a component system, screen-by-screen specification, user flows, emergency states, and accessibility rules.
- **What this document does not do:** it does not change the domain model, the risk formula, the routing contract, or MVP scope. It does not add coordinator/dashboard tooling, offline mode, authentication flows, multi-disaster support, additional hazard types, or search/filter as new backend capabilities — none of these exist in the source documents (PRD §6, §18; SRS §11; Architecture §11).
- **Audience:** an AI coding agent (or human engineer) implementing the Flutter client described in `Tech-Stack.md` §2 and `Architecture-Document.md` §5, using Riverpod, `flutter_map`, `dio`, `geolocator`, and `image_picker`.
- **Priority order for every decision in this document:** clarity → usability → safety → consistency → aesthetics. Where the techwear/HUD visual direction would conflict with clarity or safety (e.g. a hazard being illegible, a critical status blending into decoration), clarity and safety win and the visual direction yields.

---

## 1. Design Principles

1. **Never imply certainty the system doesn't have.** Every hazard, route, and AI suggestion carries confidence/status. The UI must never present a hazard or route as verified fact when its status says otherwise (PRD §17, NFR-005). This is the single non-negotiable principle of the whole spec.
2. **Map-first, glanceable, one-handed.** The user may be walking, stressed, or holding a phone one-handed while evacuating. The map is the home surface; every other flow returns to it. Primary actions sit within thumb reach at the bottom of the screen.
3. **Lowest possible friction to report.** Quick-tap must be completable in a few taps with zero typing (SRS NFR-003). Photo and text flows must never block on non-essential fields.
4. **Status is always visible, never buried.** Confidence, severity, and road-impact are shown at a glance on the map, on report cards, and in every confirmation step — not only on a detail screen (NFR-004).
5. **Functional motion only.** Motion communicates state change (a hazard appearing, a route recalculating, an escalation) — it is never purely decorative. Every animation respects `prefers-reduced-motion`.
6. **Progressive disclosure.** The map shows a compact, legible summary by default; detail (evidence, exact confidence value, timestamp, source) is one tap away in a bottom sheet, never forced onto the base view.
7. **Consistent semantic language.** The same six-color, six-icon semantic system (§10.1) is used everywhere a hazard, segment, or route touches the UI — map, cards, list, confirmation, toasts. No screen invents its own color meaning.

---

## 2. Visual Identity Direction

- **Visual tone:** Light UI, minimalist, techwear/HUD accents. The base UI is clean, high-contrast, and mostly white/near-white surfaces — HUD elements (corner brackets, scan-line dividers, crosshair markers, thin glowing accent rings) are used sparingly, only where they reinforce situational awareness (map, live status, scanning/loading states), never as generic decoration on forms or lists.
- **Design system:** custom **QuakeRoute Design System (QRDS)** — token-driven, Atomic Design structure (§4), Flutter-native components. Material Design and Apple HIG are used as **UX reference only** (touch target sizes, platform interaction conventions, motion timing feel) — QuakeRoute does not adopt Material or Cupertino visuals wholesale; it uses its own component skin (custom `QR*` widgets built on Flutter's base widgets).
- **Color:** light theme, high contrast, cyan/teal/blue as the primary/brand accent family; a separate, strictly reserved six-value **semantic** palette (Safe/Info/Uncertain/Warning/Danger/Critical) communicates hazard and route risk. Subtle duotone cyan→teal gradients are used only as accents (primary CTA, active-state rings, HUD scan motifs) — never as a background behind body text.
- **Typography:** Neo-grotesk sans-serif for all UI text; monospace for data/status values (confidence %, timestamps, coordinates, distance/time) so scannable numeric data reads as "system output," reinforcing trust calibration (this is a deliberate legibility/trust device, not just style).
- **Icons:** monoline/outline by default; filled variant only for active or critical states (selected destination, active hazard pin at Danger/Critical severity, recording/capturing state). HUD-style technical accents (crosshair, scan corners, radar sweep) are reserved for map chrome and loading states.

---

## 3. Design Tokens

Tokens are the single source of truth for styling. Implement as a Dart `QRTokens` class (or `ThemeExtension`) in `lib/core/theme/`, consumed by every custom component — no screen may hardcode a raw color, font size, spacing value, radius, or duration.

### 3.1 Color Tokens — Light Theme (base UI)

| Token | Hex | Usage |
|---|---|---|
| `color.bg.base` | `#F6FAFB` | App background (cool-tinted near-white) |
| `color.bg.surface` | `#FFFFFF` | Cards, sheets, panels |
| `color.bg.surfaceAlt` | `#EEF3F5` | Secondary surface, input fields, skeletons |
| `color.bg.overlay` | `#0B1A1FCC` (80% alpha) | Modal/scrim behind bottom sheets |
| `color.border.default` | `#D8E2E5` | Dividers, card borders |
| `color.border.strong` | `#B7C6CA` | Input borders, focus outlines (non-accent) |
| `color.text.primary` | `#0B1A1F` | Headlines, body text |
| `color.text.secondary` | `#4B5D63` | Supporting text, captions |
| `color.text.disabled` | `#9AAAAE` | Disabled labels |
| `color.text.onAccent` | `#FFFFFF` | Text/icons on filled accent surfaces |
| `color.accent.cyan` | `#06B6D4` | Primary brand accent, primary buttons, links |
| `color.accent.teal` | `#0D9488` | Secondary accent, gradient partner |
| `color.accent.blue` | `#2563EB` | Tertiary accent, informational elements |
| `color.gradient.brand` | `linear-gradient(135deg, #06B6D4 0%, #0D9488 100%)` | Primary CTA fill, active-state ring, HUD scan accent |

### 3.2 Semantic Status Colors (hazard/route risk — reserved, never reused for branding)

| Token | Hex | Meaning | Paired icon shape |
|---|---|---|---|
| `color.semantic.safe` | `#16A34A` | Passable segment, no active hazard, matches-baseline route | Outline check |
| `color.semantic.info` | `#2563EB` | Neutral system information, current route (unaffected), destination markers | Outline info/pin |
| `color.semantic.uncertain` | `#B45309` (amber-brown, deliberately distinct from Warning orange) | Reported-but-unconfirmed hazard, Uncertain/Conflicting status | Outline question mark, dashed ring |
| `color.semantic.warning` | `#F59E0B` | Medium-severity hazard, partially blocked segment | Outline triangle-exclamation |
| `color.semantic.danger` | `#DC2626` | High-severity, high-confidence hazard | Filled triangle-exclamation |
| `color.semantic.critical` | `#9F1239` | Blocked segment (routing-unusable), active-route-affected alert | Filled octagon-X, diagonal hazard-stripe pattern |

Every semantic status is encoded with **color + icon shape + text label** simultaneously (never color alone), per accessibility rule §12.2.

### 3.3 Typography Tokens

Font families: `fontFamily.ui` = neo-grotesk sans (e.g. Inter or General Sans via `google_fonts`); `fontFamily.mono` = monospace (e.g. JetBrains Mono via `google_fonts`), used only for data/status values.

| Token | Size / Weight / Line-height | Usage |
|---|---|---|
| `type.display` | 28 / 700 / 34 | Screen hero heading (rare — e.g. onboarding disclaimer) |
| `type.h1` | 22 / 700 / 28 | Screen title (app bar / sheet header) |
| `type.h2` | 18 / 600 / 24 | Section header, card title |
| `type.h3` | 16 / 600 / 22 | Sub-section, list item title |
| `type.body` | 15 / 400 / 22 | Default body text |
| `type.bodyStrong` | 15 / 600 / 22 | Emphasized body text |
| `type.caption` | 13 / 400 / 18 | Supporting/secondary text, timestamps |
| `type.label` | 12 / 600 / 16, uppercase, +0.4 tracking | Field labels, chip labels, section eyebrows |
| `type.dataMono` | 14 / 500 / 20, `fontFamily.mono` | Confidence %, distance/time, coordinates, status codes |
| `type.dataMonoLarge` | 20 / 600 / 26, `fontFamily.mono` | Route ETA / distance emphasis, simulation comparison numbers |

### 3.4 Spacing Grid

4pt base grid: `space.xs=4, space.sm=8, space.md=12, space.lg=16, space.xl=20, space.2xl=24, space.3xl=32, space.4xl=40, space.5xl=48, space.6xl=64`.
Screen edge padding: `space.lg` (16) on mobile; `space.2xl` (24) on large screens (§5.2).

### 3.5 Radius

`radius.sm=8` (chips, small buttons), `radius.md=12` (cards, inputs), `radius.lg=16` (bottom sheets top corners, primary panels), `radius.xl=24` (large hero cards), `radius.full=999` (pills, FABs, map pin badges).

### 3.6 Elevation

Techwear-light theme avoids heavy drop shadows; elevation is mostly a **thin accent border or glow**, not a dark shadow:
- `elevation.0`: flat, `border: color.border.default`.
- `elevation.1`: card resting state — `shadow: 0 1px 2px rgba(11,26,31,0.06)` + `border: color.border.default`.
- `elevation.2`: bottom sheet / floating panel — `shadow: 0 8px 24px rgba(11,26,31,0.10)`.
- `elevation.active`: selected / active item — replace shadow with a 1.5px `color.gradient.brand` ring instead of a darker shadow (HUD "active" feel).

### 3.7 Iconography

- Stroke width 1.75px for outline (default), filled variant for active/critical only (§2).
- Sizes: `icon.sm=16, icon.md=20, icon.lg=24, icon.xl=32` (map pin glyph).
- HUD accents (corner brackets, crosshair, scan-line) are a small, separate icon subset used only in: map loading/init, AI-analysis loading, current-location marker, and the Simulation screen's "live scenario" indicator.

### 3.8 Motion Tokens

| Token | Duration | Easing | Usage |
|---|---|---|---|
| `motion.micro` | 120ms | standard (easeOutCubic) | Button press, chip toggle, checkbox |
| `motion.standard` | 200ms | standard | Sheet content swap, toast in |
| `motion.transition` | 320ms | emphasized (easeOutCubic w/ slight overshoot ≤4%) | Bottom sheet open/close, screen push |
| `motion.recalc` | 480ms | standard, staggered (route fade-out 160ms → new route draw-in 320ms) | Route recalculation redraw (§10.4) |
| `motion.escalate` | 600ms, pulse ×2 then settle | standard | Segment escalating to Danger/Critical on the map (§10.3) |

**Reduced motion:** when the OS `reduce motion` preference is on, every entry above collapses to a simple 100ms cross-fade with no movement, no scale, no pulse. Route recalculation and escalation still communicate the change via a static color/icon swap plus a toast — the information is never lost, only the animation is.

---

## 4. Design System & Atomic Design Structure

Component work lives under `lib/core/theme/` (tokens) and a shared `lib/core/widgets/` component library (`QR*` prefix), consumed by every feature folder per `Architecture-Document.md` §5.

### 4.1 Atoms
`QRButtonPrimary`, `QRButtonSecondary`, `QRButtonGhost`, `QRIconButton`, `QRTextField`, `QRTextArea`, `QRStatusDot`, `QRBadge` (semantic chip: color+icon+label), `QRAvatarPin` (map marker base), `QRDivider`, `QRSkeletonBlock`, `QRSpinner`, `QRCheckboxTile`, `QRRadioTile`.

### 4.2 Molecules
`QRConfidenceMeter` (horizontal bar + mono % label + status word), `QRSeverityBadge` (semantic badge specialized for severity), `QRHazardTypeChip` (one of the six MVP hazard types, with icon), `QRDestinationCard` (name, type, distance, ETA), `QRHazardCard` (type, severity/confidence badges, timestamp, mini-map thumbnail), `QRRouteSummaryStrip` (distance, ETA, risk-adjusted vs baseline delta), `QRToast`, `QREmptyState`, `QRErrorState`, `QRLoadingRow`.

### 4.3 Organisms
`QRMapCanvas` (wraps `flutter_map` + hazard/destination overlay layer + user location layer + HUD chrome), `QRBottomSheet` (draggable, snap points: peek/half/full), `QRReportModeSelector` (photo/text/quick-tap/[voice] entry organism), `QRAIReviewPanel` (AI-suggested hazard confirm/edit/reject organism), `QRQuickCategoryGrid`, `QRRoutePanel` (active route card + recalculation banner), `QREmergencyBanner` (persistent critical-state banner), `QRScenarioComparisonPanel` (baseline vs risk-aware, simulation screen).

### 4.4 Templates
`MapScreenTemplate` (full-bleed map + floating top HUD + bottom sheet slot), `FlowScreenTemplate` (app bar + scrollable content + sticky bottom action bar — used by reporting flows), `ListScreenTemplate` (app bar + optional search/filter row + list), `ComparisonScreenTemplate` (two-column on large screens, stacked tabs on mobile — used by Simulation).

### 4.5 Custom Flutter Component Inventory

| Component | Maps to feature folder | Core props (indicative) |
|---|---|---|
| `QRMapCanvas` | `features/map` | `hazards`, `destinations`, `userLocation`, `activeRoute`, `onHazardTap`, `onDestinationTap` |
| `QRHazardPin` | `features/map` | `severity`, `status`, `hazardType`, `selected` |
| `QRRouteLine` | `features/routing`, `features/map` | `points`, `variant: initial \| recalculated \| baseline` |
| `QRConfidenceMeter` | `features/reporting`, `features/map` | `confidencePercent`, `status` |
| `QRSeverityBadge` / `QRStatusBadge` | shared | `semantic: safe \| info \| uncertain \| warning \| danger \| critical`, `label` |
| `QRAIReviewPanel` | `features/reporting/photo`, `features/reporting/text` | `candidateHazard`, `onConfirm`, `onEdit`, `onReject` |
| `QRQuickCategoryGrid` | `features/reporting/quick_tap` | `categories` (6 MVP types), `onSelect` |
| `QREmergencyBanner` | `features/routing`, `features/map` | `semantic`, `message`, `actionLabel` |
| `QRRecalculationOverlay` | `features/routing` | `previousRoute`, `newRoute`, `reason` |
| `QRScenarioComparisonPanel` | `features/simulation` | `baselineRoute`, `riskAwareRoute`, `metrics` |
| `QRToast` | shared | `semantic`, `message`, `durationMs` |

---

## 5. Layout System

### 5.1 Screen Anatomy (mobile default)

- **Full-screen map is the base layer** on the Home screen; there is no persistent tab bar competing with the map for vertical space (PRD §9.1 primacy).
- **Floating top HUD bar** (transparent-to-surface gradient scrim): current status chip (e.g. "3 active hazards nearby"), report entry-point button.
- **Bottom sheet** is the primary secondary-content surface: destination selection, route summary, hazard detail, report list all render as a `QRBottomSheet` over the map with three snap points — *peek* (compact summary, map mostly visible), *half* (balanced), *full* (map fully covered, scrollable content) — so the user never fully loses map context unless they choose to.
- **Floating action button (bottom-right, thumb reach):** primary "Report Hazard" entry point, always available while the map is visible.
- **Overlay/floating panels** (non-sheet): `QREmergencyBanner` (top, below HUD bar, appears only on critical state), `QRToast` (bottom, above FAB, transient feedback).
- Report flows, hazard detail (full evidence), and Simulation use full-screen pushed routes (`FlowScreenTemplate` / `ComparisonScreenTemplate`) rather than sheets, since they need full attention and a sticky action bar.

### 5.2 Responsive Behavior

- **Mobile (default, <600dp width):** everything above, single column, bottom sheets, stacked flows.
- **Large screen (≥900dp width — tablet/desktop-class, optional per design direction):** two-column layout becomes available *only* where it aids clarity without adding new functionality: map (left, ~60%) + persistent side panel (right, ~40%) replacing the bottom sheet for destination list, route summary, hazard detail, report list, and the Simulation comparison view. Report *entry* flows (photo/text/quick-tap) remain centered single-column forms even on large screens — they are transactional, not browsing surfaces, and don't benefit from two columns.
- 600–900dp is treated as mobile layout with wider spacing (`space.2xl` edge padding instead of `space.lg`).

---

## 6. Navigation & Information Architecture

```
App Launch
  └─ Safety Disclaimer (first-run only) ─────────────────► Home (Dynamic Safety Map)
                                                                  │
        ┌─────────────────────────────┬─────────────────────────┼───────────────────────────┐
        ▼                             ▼                          ▼                           ▼
  Destination Selection      Report Hazard (FAB)          Hazard Detail (tap pin)     Simulation (evaluator entry)
        │                             │                          │                           │
        ▼                     ┌───────┼────────┬────────┐        ▼                           ▼
  Route Overview /            Photo   Text  Quick-Tap [Voice]  (sheet: type, severity,   Scenario List
  Active Navigation            │       │        │               confidence, status,           │
        │                      ▼       ▼        ▼               timestamp, evidence)     Scenario Run
        │                 AI Review Panel  Category Grid                                       │
        │                 (confirm/edit/reject)  → Location confirm                     Baseline vs
        │                      │              │                                          Risk-Aware
        └──────────────────────┴──────────────┴────────────────────► back to Home         Comparison
                                                                     (map/route updates)
```

Navigation is a **shallow hub-and-spoke** rooted at Home — every flow above returns to Home on completion or cancellation. There is no deep multi-level drill-down; this matches the small, MVP-scoped feature set (PRD §18) and keeps the app usable under stress (Design Principle 2).

The **Simulation** entry point (evaluator/operator tool, PRD §9.12, SRS §4.12) is reachable from a low-emphasis affordance (e.g. an icon in the HUD bar or app settings) — it is functionally available to any user per SRS §3.3 (no separate role/account type exists) but is visually de-prioritized relative to the Evacuee-facing flows, since the Evacuee/Community Reporter journey is the primary product surface (PRD §4).

---

## 7. UX Patterns

### 7.1 Search & Filtering (applied only to existing MVP data — not a new capability)
- **Destination list:** a lightweight text filter field at the top of the destination sheet/panel narrows the fixed, controlled destination set (PRD §9.2) by name/type as the user types. This is a client-side filter over data already returned by the backend — it does not add a new destination-discovery feature.
- **Hazard/report list:** filter chips for the six MVP hazard types (§10.1) and for status (Reported / Uncertain / Confirmed / Verified) let the user narrow an already-fetched hazard list. No new query capability is implied beyond what the map/hazard endpoints already return (Tech-Stack §9).
- Filters never hide hazards from the map itself — only from the list view — so situational awareness (PRD §9.1) is never silently reduced.

### 7.2 Forms
- Minimum fields, sensible defaults, no field is required unless the source FR requires it (e.g. quick-tap requires only category + location confirmation — FR-019).
- Location fields default to device GPS (`geolocator`) with an explicit "adjust location" affordance (map pin drag or tap) rather than manual coordinate entry.
- Text report field: single multi-line `QRTextArea`, placeholder demonstrates the kind of detail useful for extraction (e.g. "What did you see, and where?") without being a rigid template — free text per FR-015.
- Primary submit action is sticky at the bottom of the screen; secondary/cancel is a plain text button, top-left back or top-right "Cancel."

### 7.3 Confirmation
- Any AI-suggested hazard (photo or text) **must** pass through `QRAIReviewPanel` before becoming an active hazard (FR-012–FR-013, FR-017). The panel always shows: hazard type, severity, road impact, confidence meter, and the evidence (photo thumbnail / submitted text) side by side with three explicit actions: **Confirm**, **Edit**, **Reject** — never an auto-accept path.
- Destructive/consequential actions (changing destination mid-route, rejecting an AI suggestion) show a lightweight inline confirmation (not a blocking modal) unless data would be lost, in which case a modal confirms explicitly.

### 7.4 Loading / Error / Empty States
Every async surface (map data, AI analysis, route generation, recalculation, simulation run) implements all three states via `QRLoadingRow`/`QRSkeletonBlock`, `QRErrorState`, `QREmptyState` — see the consolidated table in §11.

### 7.5 Toast / Feedback
`QRToast` is used for non-blocking confirmations (report submitted, hazard added to map) and for informational recalculation notices that don't require the `QREmergencyBanner`'s persistence. Toasts auto-dismiss (default 4s, configurable), never block interaction, and always pair an icon with text (never color alone, §12.2).

### 7.6 Progressive Disclosure
- Map default view: compact hazard pins + color only.
- Tap pin → sheet peek: type, severity badge, status badge, one-line summary.
- Expand sheet → full: confidence meter, timestamp, source (AI Vision/Text/Quick-tap/[Voice]), evidence (photo/text), affected road segment(s).
- Route: default view shows distance/ETA/risk delta strip; "Why this route?" expands to show which segments were penalized/avoided and why (severity/confidence/blocked), directly supporting NFR-005 (non-absolute risk communication) without cluttering the default view.

### 7.7 Clear Status Indicators
Every hazard, segment, and route surface uses the six-value semantic system (§10.1) consistently: map segment color, hazard pin color+icon, badge on cards, and route line style. See §10 for the full encoding table.

### 7.8 Route Recalculation Feedback
See §10.4 — dedicated pattern combining `QREmergencyBanner`/toast, `QRRecalculationOverlay` map animation, and an explicit "why did my route change" disclosure, directly implementing FR-037.

### 7.9 Emergency State Transition
See §10 — segment/route escalation from Safe→Uncertain/Warning→Danger→Critical always animates via `motion.escalate` (or its reduced-motion fallback) and is paired with a toast/banner, never a silent color change the user could miss.

---

## 8. Screen Specifications

Each screen lists: **Purpose**, **Content**, **Primary Actions**, **States**, **Interaction Behavior**.

### 8.1 Safety Disclaimer (first-run only)
- **Purpose:** set correct expectations immediately, per NFR-005/PRD §17 — QuakeRoute is decision support, not a safety guarantee, and official responder guidance takes precedence.
- **Content:** short statement (2–3 sentences) covering: routes are not guaranteed safe; hazard data comes from the community and AI and is uncertain; follow official instructions when available. Single "Continue" action.
- **Primary actions:** Continue → Home.
- **States:** shown once (first run) or on-demand from Settings/About (§8.13); no loading/error state (static content).
- **Interaction:** simple full-screen `FlowScreenTemplate`, no skip option — this is a safety-critical acknowledgment, not marketing.

### 8.2 Home — Dynamic Safety Map
- **Purpose:** primary situational-awareness surface (PRD §9.1); shows user location, road network, hazards, and destinations at all times.
- **Content:** `QRMapCanvas` full-bleed; user location marker (HUD crosshair style); road segments colored by worst active hazard status on that segment (§10.1); destination pins (shelters/medical, distinguished by icon); floating top HUD bar with active-hazard-count chip; `QREmergencyBanner` slot (shown only if user has an active route currently on a Danger/Critical segment); FAB "Report Hazard."
- **Primary actions:** tap a destination pin or open Destination Selection sheet → generate route (FR-006); tap a hazard pin → Hazard Detail sheet; tap FAB → Report Hazard mode selector.
- **States:**
  - *Loading:* skeleton map tile shimmer + HUD scan-line loading motif (respecting reduced motion) while initial road network/hazard data loads.
  - *Error:* `QRErrorState` overlay ("Couldn't load current conditions") with Retry — map falls back to last-known cached view where available, per NFR-007's acknowledgment that this is a demo-scale system (no offline mode is implied or required, Architecture §11).
  - *Empty (no hazards):* map renders normally with no hazard pins — this is a valid, expected state (Simulation Scenario 1), not an error.
  - *Active route present:* route line overlay (semantic `info`), recalculated route uses `variant: recalculated` styling (§10.4).
- **Interaction behavior:** map updates hazard/segment state reactively as new data arrives (Riverpod state per Architecture §5); no manual refresh required. Panning/zooming never triggers new fetches beyond what the architecture's map/hazard endpoints already scope to the controlled network (Tech-Stack §5).

### 8.3 Destination Selection
- **Purpose:** let the user pick a shelter/medical facility destination (FR-005).
- **Content:** `QRBottomSheet` (or side panel on large screens) listing the controlled destination set as `QRDestinationCard`s: name, type (shelter/medical), distance, estimated time; optional text filter (§7.1) if the list is long enough to warrant it.
- **Primary actions:** select a destination → triggers initial route generation (FR-006) and transitions to Route Overview.
- **States:** *Loading* (skeleton cards while destination data loads), *Error* (`QRErrorState`, retry), *Empty* is not a valid state — the controlled network always has a defined destination set (PRD §18).
- **Interaction behavior:** selecting a new destination while a route is already active (FR-007) replaces the active route after a brief inline confirmation ("Replace current route to [old destination]?").

### 8.4 Route Overview / Active Navigation
- **Purpose:** show the generated risk-aware route and keep the user informed as they travel (FR-006, FR-035–037).
- **Content:** `QRRoutePanel` (as bottom sheet, peek by default so the map stays visible): destination name, distance, ETA, `QRRouteSummaryStrip` (risk-adjusted vs conventional distance delta, shown plainly, not hidden — reinforces trust per Design Principle 1); "Why this route?" progressive-disclosure link (§7.6); route line drawn on the map beneath.
- **Primary actions:** "Change destination" (→ 8.3), expand "Why this route?", dismiss to peek/collapse sheet.
- **States:** *Generating* (spinner + "Calculating the safest route…" — mono ETA placeholder skeleton), *Active* (normal), *Recalculating* (see §10.4 — distinct visual state, not the same spinner as initial generation, since the user is already mid-journey and needs to know *why*), *Route unavailable* (`QRErrorState`: "No feasible route found" — occurs only if all paths are Blocked; offers Retry and "View hazards causing this").
- **Interaction behavior:** the route line and summary strip update live as recalculation completes; the previous route briefly fades (per `motion.recalc`) rather than snapping, so the change is perceivable, not jarring or missed.

### 8.5 Report Hazard — Mode Selector
- **Purpose:** entry point for all reporting modes, minimizing time-to-first-action (FR-008).
- **Content:** `QRReportModeSelector` — large, thumb-friendly tiles: **Photo**, **Text**, **Quick Report** (and **Voice**, only if implemented per its SHOULD-HAVE status — SRS §4.6/§9), each with a one-line description of effort level (e.g. Quick Report: "Fastest — no typing").
- **Primary actions:** tap a mode → push corresponding flow (8.6/8.7/8.8).
- **States:** static content, no async state.
- **Interaction behavior:** location is pre-filled from `geolocator` current position for every mode, adjustable within the chosen flow (§7.2) — this is set once here so downstream flows don't re-ask.

### 8.6 Photo Report Flow
- **Purpose:** lowest-typing-effort report via `image_picker` + AI Vision (FR-010–FR-014).
- **Content — step 1 (Capture):** camera/gallery picker, single photo, preview thumbnail with retake/remove.
- **Content — step 2 (AI Analysis):** loading state — "Analyzing photo…" with HUD scan-line motif (bounded, non-decorative use of the scan accent — §2) over the thumbnail.
- **Content — step 3 (Review):** `QRAIReviewPanel` — photo thumbnail, proposed hazard type (`QRHazardTypeChip`, editable via a picker limited to the six MVP types — PRD §12), severity, road impact, `QRConfidenceMeter`, location (adjustable pin).
- **Primary actions:** step 1: Retake / Use Photo. Step 3: **Confirm** (submit as active hazard, FR-014), **Edit** (inline-edit type/severity/road-impact before confirming), **Reject** (discard, return to mode selector or Home).
- **States:** *Uploading*, *AI analysis in progress*, *AI analysis failed* (`QRErrorState`: "Couldn't analyze this photo — you can still report it as a Quick Report" with a direct link to 8.8, since AI failure must never block the user's ability to report per the system's low-friction principle), *Review* (normal), *Submitted* (toast + return Home).
- **Interaction behavior:** the AI's proposed values are pre-filled but never disabled — every field is editable before Confirm, per FR-013. Confidence meter uses `color.semantic.*` matched to the AI's returned value.

### 8.7 Text Report Flow
- **Purpose:** free-text hazard description for users able to provide detail (FR-015–FR-017); may extract more than one hazard from a single report.
- **Content — step 1 (Compose):** `QRTextArea` with lightweight helper caption; location field (pre-filled/adjustable).
- **Content — step 2 (AI Extraction, loading):** "Reading your report…".
- **Content — step 3 (Review):** one `QRAIReviewPanel` **per extracted hazard** (stacked, scrollable) — each independently editable, confirmable, or rejectable, since a single text report can yield multiple structured hazards (FR-016).
- **Primary actions:** Submit (step 1) → Review (step 3): Confirm All / review individually, Edit per-hazard, Reject per-hazard.
- **States:** *Submitting*, *Extraction in progress*, *No hazards detected* (`QREmptyState`: "We couldn't identify a specific hazard from this text — try Quick Report instead" with link to 8.8), *Extraction failed* (`QRErrorState`, same fallback as 8.6), *Review*, *Submitted*.
- **Interaction behavior:** identical confirm/edit/reject contract as the photo flow (§7.3) — text-derived hazards get exactly the same scrutiny as photo-derived ones, consistent with FR-017.

### 8.8 Quick Report Flow
- **Purpose:** lowest-effort report path — no typing, no AI wait (FR-018–FR-020).
- **Content — step 1 (Category):** `QRQuickCategoryGrid` — the six MVP hazard categories (Debris/Rubble, Road Blockage, Fire, Flood, Electrical Hazard, Visible Building Damage — PRD §12) as large tappable tiles with icon + label.
- **Content — step 2 (Location confirm):** map pin at current GPS location, draggable to adjust.
- **Primary actions:** select category → confirm/adjust location → Submit.
- **States:** *Submitting* (brief — no AI step in this path), *Submitted* (toast), *Error* (`QRErrorState`, retry — network/backend failure only, since there is no AI dependency in this path).
- **Interaction behavior:** no AI review panel appears here by design (FR-020: quick reports get a default confidence value without AI processing) — after Submit, the hazard is immediately part of the structured dataset; the UI communicates this plainly (e.g. "Reported — status: Reported" badge) so the user understands it's not yet AI-analyzed or confirmed by others, distinct from a photo/text-confirmed hazard.

### 8.9 Voice Report Flow (SHOULD HAVE / conditional — only build if implemented per SRS §4.6, §9)
- **Purpose:** speech-to-text into the same text-extraction path as 8.7 (FR-023).
- **Content:** record button (press-and-hold or tap-to-start/stop), live transcript preview, then reuses 8.7's steps 2–3 (Extraction → Review) unchanged.
- **Primary actions:** Record → Stop → (auto) Submit transcript.
- **States:** *Recording*, *Transcribing*, then identical to 8.7's extraction/review/error states.
- **Interaction behavior:** if this flow is not built for the MVP, the mode tile in 8.5 is simply omitted — no placeholder/disabled tile should ship, to avoid implying a feature that doesn't exist.

### 8.10 Hazard Detail
- **Purpose:** full detail on a single hazard, reached by tapping a map pin or a `QRHazardCard` in the list (NFR-004 full-detail tier).
- **Content:** hazard type, `QRSeverityBadge`, `QRStatusBadge`, `QRConfidenceMeter` with exact mono percentage, timestamp (mono, relative + absolute), source (AI Vision / Text / Quick Report / Voice), evidence (photo if present, or submitted text excerpt), affected road segment name/reference, and — if status is Uncertain/Conflicting — an explicit explanatory note (§10.2).
- **Primary actions:** none destructive from this view in MVP (no user-facing verification/upvote mechanism exists per PRD §9.8's "additional confirmation signals" being an internal/TBD mechanism, not a user action) — "Close" returns to map/list.
- **States:** *Loading* (skeleton), *Error* (`QRErrorState`), *Loaded* (normal). No empty state (only reachable when a hazard exists).
- **Interaction behavior:** static detail view; if the hazard's status/severity changes while the sheet is open (live update), the badges update in place with a brief highlight flash, not a jarring reload.

### 8.11 Hazard / Report List
- **Purpose:** browsable list view of hazards/reports, complementing the map for scanning many items at once (design direction: "List untuk reports, hazards, destinations").
- **Content:** `ListScreenTemplate` — filter chips (hazard type, status — §7.1), list of `QRHazardCard`s sorted by recency by default.
- **Primary actions:** tap a card → Hazard Detail (8.10); tap FAB → Report Hazard (8.5), consistent with Home.
- **States:** *Loading* (skeleton rows), *Error* (`QRErrorState`), *Empty* (`QREmptyState`: "No hazards reported yet" — valid pre-Scenario-1 state), *Filtered-empty* (`QREmptyState` variant: "No hazards match these filters" with a Clear Filters action).
- **Interaction behavior:** list and map share the same underlying hazard state (Riverpod) — filtering the list never mutates what's shown on the map (§7.1).

### 8.12 Emergency Simulation (Evaluator/Operator)
- **Purpose:** trigger and observe the six predefined scenarios; compare baseline vs. risk-aware routing (FR-041–044).
- **Content:** scenario list (the six named scenarios — No Hazard, Blocked Road, High-Risk Hazard, New Hazard During Navigation, Conflicting Reports, AI Vision Hazard Report — PRD §15); on run, `QRScenarioComparisonPanel` shows baseline route and risk-aware route side-by-side (large screens: two columns; mobile: tabbed toggle) with `QRRouteSummaryStrip`-style metrics for each (distance, cost, segments avoided).
- **Primary actions:** select scenario → Run; after run, toggle Baseline / Risk-Aware / Both (overlay) on the map; Reset scenario.
- **States:** *Idle* (scenario list), *Running* (step-by-step progress — "Injecting hazard reports…", "Recalculating risk…", "Computing baseline route…", "Computing risk-aware route…" — mirroring the actual orchestrated flow per Architecture §8, so the evaluator sees the real pipeline, not a black box), *Complete* (comparison panel), *Error* (`QRErrorState`, retry — scenario run failed).
- **Interaction behavior:** this screen visually reuses the exact same map/route/hazard components as the Evacuee flows (Architecture §8 principle: simulation replays production paths) — it must never look like a separate mocked-up demo UI; that consistency is itself part of what the evaluator is assessing.

### 8.13 Settings / About / Safety Disclaimer (re-access)
- **Purpose:** low-emphasis screen holding the safety disclaimer (re-accessible after first run), app version/info, and the entry point to Simulation (8.12).
- **Content:** disclaimer text (same as 8.1), link to Simulation, static app info.
- **Primary actions:** navigate to Simulation; no other interactive elements required by MVP scope.
- **States:** static; no loading/error/empty states apply.

---

## 9. User Flows

### 9.1 Happy Path — Evacuation (PRD §8)
Home (map loads, hazards visible) → open Destination Selection (8.3) → select destination → Route Overview (8.4) generates risk-aware route → user follows route on Home map → (optionally) another user's report triggers a recalculation → Route Overview updates with `QRRecalculationOverlay` → user reaches destination (no explicit "arrived" screen is required by MVP scope; the app simply continues showing the map).

### 9.2 Photo Hazard Report
Home → FAB → Mode Selector (8.5) → Photo (8.6): Capture → AI Analysis (loading) → Review (`QRAIReviewPanel`) → Confirm → toast "Hazard reported" → return to Home, new pin visible on map.
*Alternate:* AI Analysis fails → inline fallback offer to switch to Quick Report (8.8) without losing the captured photo's location context.

### 9.3 Text Hazard Report
Home → FAB → Mode Selector → Text (8.7): Compose → AI Extraction (loading) → Review (one or more panels) → Confirm each/all → toast → Home.

### 9.4 Quick Hazard Report
Home → FAB → Mode Selector → Quick Report (8.8): Category → Location confirm → Submit → toast → Home (near-instant, no AI wait, consistent with NFR-003).

### 9.5 Dynamic Route Recalculation (FR-035–037)
Trigger: any user's confirmed report affects a segment on this user's active route → backend recalculates (Architecture §7) → mobile receives updated route → Home/Route Overview shows `QREmergencyBanner` or toast ("Your route has changed — a new hazard was reported ahead") → map redraws with `QRRecalculationOverlay` (old route fades, new route draws in, per `motion.recalc`) → Route Overview's summary strip and "Why this route?" reflect the new path. If the hazard does **not** affect this user's route, nothing changes for them (§10.4) — the map's hazard layer still updates silently since that's core situational awareness (FR-004), but no recalculation banner appears.

### 9.6 Conflicting Reports (visual behavior only — FR-038–040)
Two reports disagree on the same segment → segment/hazard status becomes Uncertain/Conflicting → map segment recolors to `color.semantic.uncertain` with the dashed-ring pin treatment → Hazard Detail (8.10) shows the explanatory note (§10.2) → routing cost reflects the uncertainty penalty, visible in the route's "Why this route?" disclosure if it affects route choice. The UI never resolves the conflict on the user's behalf or hides either report.

### 9.7 Emergency Simulation Run
Settings/About (or HUD entry) → Simulation (8.12) → select scenario → Run (step progress) → Comparison panel (baseline vs risk-aware) → toggle map overlay to inspect either route → Reset to try another scenario.

---

## 10. Emergency States and Safety Communication

### 10.1 Semantic Status Encoding (single source of truth for all screens)

| Semantic | Hazard/segment meaning | Color token | Icon (outline / filled) | Map segment style | Route implication shown to user |
|---|---|---|---|---|---|
| Safe | No active hazard / passable, matches baseline | `color.semantic.safe` | check | solid green line, default weight | "No known hazards on this segment" |
| Info | Neutral/system (e.g. unaffected active route line, destination pins) | `color.semantic.info` | pin / info | solid blue line | — |
| Uncertain | Reported-but-unconfirmed, or Conflicting-reports status | `color.semantic.uncertain` | question-mark, dashed ring | dashed amber-brown line | "Conflicting or unconfirmed reports — treated with caution, not excluded" |
| Warning | Medium-severity hazard, partially blocked | `color.semantic.warning` | triangle-exclamation (outline) | solid orange line, +weight | "Higher cost — avoided when a safer option exists" |
| Danger | High-severity, high-confidence hazard, still technically passable | `color.semantic.danger` | triangle-exclamation (filled) | solid red line, +weight, subtle pulse on first appearance | "Strongly penalized — route will avoid this unless no alternative exists" |
| Critical | Blocked segment (routing-unusable) or user's active route is currently affected | `color.semantic.critical` | octagon-X (filled), diagonal hazard-stripe | red/black diagonal-stripe line pattern | "Impassable — excluded from all routes" / persistent `QREmergencyBanner` if on the user's active route |

This table is the canonical mapping — every component in §4 that renders a hazard, segment, or route status must reference it rather than defining ad hoc colors.

### 10.2 Uncertainty Communication Pattern (NFR-004, NFR-005)
Wherever an Uncertain/Conflicting status appears, the UI shows a short, plain-language explanatory microcopy pattern rather than just a badge — e.g. "Reports disagree about this road. It's not blocked, but treated as riskier until more information comes in." This directly operationalizes PRD §14/§17: uncertainty is preserved and explained, never silently resolved or hidden.

### 10.3 Escalation Transition
When a segment's status worsens (Safe→Warning, Warning→Danger, any→Critical) while visible on screen: the segment plays `motion.escalate` (brief double-pulse in the new color, then settles) and a toast announces it ("A hazard was just reported on [segment/area]"). De-escalation (status improves) uses a calmer single cross-fade, no pulse, and does not force a toast unless it affects the user's active route (to avoid over-notifying).

### 10.4 Route Recalculation Feedback (FR-037)
Recalculated routes are distinguished from the original in three simultaneous ways (never just one, to satisfy "distinguishable" robustly):
1. **Visual:** the map redraw itself (`motion.recalc`, or its reduced-motion cross-fade) — old line fades, new line draws.
2. **Explicit banner/toast:** states *why* ("new hazard reported ahead"), not just *that* something changed.
3. **Persistent label:** the active `QRRoutePanel` shows a small "Updated" tag with a mono timestamp until the user has viewed the change, then it clears.

### 10.5 Non-Guarantee Reinforcement (NFR-005, PRD §17)
- The Safety Disclaimer (8.1/8.13) states this once, persistently accessible.
- The Route Overview's summary strip never uses language like "safe route" — copy standard is **"lower-risk route"** / **"risk-aware route"**, consistently, everywhere in the app (map labels, toasts, route panel, simulation panel). "Safe" is reserved strictly for the semantic-safe status token (§10.1: absence of known hazard), never as a claim about a route or destination as a whole.

---

## 11. Loading / Error / Empty States — Consolidated Reference

| Surface | Loading | Error | Empty |
|---|---|---|---|
| Map / hazard layer (8.2) | Tile shimmer + bounded HUD scan motif | `QRErrorState`, Retry, fall back to last-known view | Valid state: map with no hazard pins (no special empty screen — this is normal) |
| Destination list (8.3) | Skeleton `QRDestinationCard`s | `QRErrorState`, Retry | Not applicable — controlled set always exists |
| Route generation (8.4) | Spinner + mono ETA skeleton, "Calculating the safest route…" | `QRErrorState`, "No feasible route found," Retry + link to hazards causing it | Not applicable |
| Route recalculation (8.4) | Distinct from initial generation — see §10.4 (never the same generic spinner) | Same `QRErrorState` treatment, but banner clarifies the *previous* route remains active until resolved | Not applicable |
| Photo AI analysis (8.6) | "Analyzing photo…" + scan motif over thumbnail | `QRErrorState` + fallback link to Quick Report | Not applicable (a photo always yields either a proposal or a failure) |
| Text AI extraction (8.7) | "Reading your report…" | `QRErrorState` + fallback link to Quick Report | `QREmptyState`: "No hazard identified in this text" + fallback link to Quick Report |
| Quick report submit (8.8) | Brief inline spinner on Submit button | `QRErrorState`, Retry (network/backend only) | Not applicable |
| Hazard detail (8.10) | Skeleton detail rows | `QRErrorState`, Retry | Not applicable |
| Hazard/report list (8.11) | Skeleton rows | `QRErrorState`, Retry | `QREmptyState` ("No hazards reported yet") and filtered-empty variant (Clear Filters) |
| Simulation run (8.12) | Step-by-step progress list (mirrors real pipeline) | `QRErrorState`, Retry/Reset | Not applicable |

Every `QRErrorState` includes: a plain-language message (never a raw error code/stack trace), an icon (outline, neutral — not semantic-critical unless the error itself represents a Critical hazard condition), and a Retry action where retrying is meaningful.

---

## 12. Accessibility

1. **Never color-only.** Every semantic status (§10.1) pairs color with a distinct icon shape and a text label. This also serves colorblind users and keeps the map legible on low-quality screens in bright daylight — a realistic evacuation condition.
2. **Contrast:** all text meets WCAG AA (4.5:1 body text, 3:1 large text/icons) against its background token; semantic colors on `color.bg.surface` are verified against this minimum — where a semantic hue alone doesn't clear contrast against white (e.g. amber/orange), it is used on filled chips with dark text or with a sufficiently dark shade, never as light text on white.
3. **Touch targets:** minimum 44×44dp (iOS HIG reference) / 48×48dp (Material reference) for every tappable element, including map pins' hit area (the visual pin may be smaller; the tap target is padded invisibly to this minimum).
4. **Text scaling:** all typography tokens (§3.3) respond to system font-scaling; layouts (especially `QRAIReviewPanel`, `QRRoutePanel`) must reflow (wrap, stack) rather than truncate critical safety information (hazard type, status, confidence) at larger scales.
5. **Screen reader labels:** every icon-only control (`QRIconButton`, map pins, FAB) has a semantic label describing both the object and its status, e.g. "Hazard pin, Road Blockage, Danger, high confidence" — not just "Hazard pin."
6. **Reduced motion:** honored globally per §3.8 — no required information is ever conveyed by animation alone; every animated state change has a static equivalent (color/icon/text) that appears regardless of the motion setting.
7. **Focus order & keyboard/switch access** (large-screen/desktop-class use): logical top-to-bottom, left-to-right focus order in sheets and forms; the bottom sheet drag handle also exposes an equivalent tap target for snap-point changes, since dragging is not accessible to all input methods.
8. **Language/tone:** microcopy (§10.2, error states, disclaimers) is written in plain, non-technical language appropriate for a stressed user, avoiding jargon like "confidence interval" in favor of "how sure we are."

---

## 13. Implementation Notes for the Coding Agent

- Build tokens (§3) first as a single `QRTokens`/`ThemeExtension` source before any screen — every subsequent widget references tokens, never raw values.
- Build atoms → molecules → organisms (§4) before screens; screens in §8 should compose almost entirely from existing components by the time they're implemented.
- Each screen in §8 corresponds to a `features/*` folder per `Architecture-Document.md` §5 (`map`, `destination`, `reporting/{photo,text,quick_tap,voice}`, `routing`, `simulation`); this document does not require any folder or state-management structure beyond what that architecture already defines.
- The mobile app **never computes** severity, confidence, or routing cost itself (Architecture §5) — every value shown by `QRConfidenceMeter`, `QRSeverityBadge`, and `QRRouteSummaryStrip` is a direct read of backend response data, not a client-side calculation.
- Where a source document leaves a value `TBD` (exact status set, severity scale granularity, default quick-tap confidence, response-time targets), implement the component to accept that value as a parameter/enum rather than hardcoding an assumption, so the UI adapts once the backend value is finalized without a redesign.

---

## 14. Explicitly Out of Scope for This UI/UX Specification

Consistent with PRD §6/§18 and Architecture §11, this specification does **not** define:
- Authentication/account UI (no auth mechanism exists in MVP scope).
- Offline-mode UI/indicators (no offline mode is part of the architecture).
- A dedicated Volunteer/Coordinator dashboard (that role uses the same Evacuee/Community Reporter screens — SRS §3.3).
- Push-notification UI/permission flows (delivery mechanism for updates is an implementation detail per Architecture §7, not specified here).
- Multi-disaster-type UI variants, additional hazard-type UI beyond the six MVP types, or any verification/upvoting UI beyond what's described in §8.10.
- Any e-commerce, social, or gamification UI — none exist in the source requirements.

---

**Document status:** UI/UX Specification for the QuakeRoute 10-day hackathon MVP, derived strictly from `PRD.md`, `SRS.md`, `Tech-Stack.md`, and `Architecture-Document.md`. No feature, screen, or data field beyond those documents' MVP scope has been introduced. Items left `TBD` by the source documents remain `TBD` here; this document defines the UI contract around them rather than resolving them.
