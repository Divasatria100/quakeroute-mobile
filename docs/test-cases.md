# QuakeRoute — Test Cases

## 0. Document Status and Source of Truth

- **Source of truth:** `PRD.md`, `SRS.md`, `Domain-Risk-Model.md`, `Simulation-Validation.md`, `AI-Requirements.md`. This document does not modify, add to, or remove any requirement, domain rule, or validation scenario defined in those five documents.
- **Purpose:** provide a practical set of test cases that a developer or an AI coding agent can use to verify that a QuakeRoute implementation matches the requirements, domain/risk model, AI requirements, and validation scenarios already defined.
- **Numbers:** where the source documents mark a value as `TBD` (severity bands, confidence thresholds, penalty weights, disagreement scaling, response-time targets, etc.), this document keeps it as `TBD` in the relevant test case rather than inventing a number. A test case marked `TBD` for its expected numeric result should still be run — its pass/fail check is limited to the qualitative/categorical behavior stated, until the parameter is fixed during implementation.
- **Framework-agnostic:** test cases describe observable input/action and expected result. They intentionally avoid prescribing a specific UI framework, database, routing library, or AI provider, consistent with the provider-agnostic stance of the SRS and Domain-Risk-Model.

---

## 1. Testing Scope

### 1.1 In Scope (MVP, per PRD §18 / SRS §9)

- Dynamic Safety Map (user location, destinations, hazard rendering, condition updates).
- Destination selection and initial route generation.
- Multimodal hazard reporting: **text**, **photo (AI Vision)**, and **quick tap**.
- AI Hazard Understanding (text extraction and photo/AI Vision) — single hazard, multiple hazards, ambiguous/incomplete input, and failure handling.
- Hazard confidence and status (creation, visibility, transitions).
- Risk-aware routing (Base Travel Cost + Hazard Penalty + Uncertainty Penalty; blocked-segment exclusion; non-shortest route selection).
- Dynamic route recalculation when an active route is affected by a new hazard.
- Uncertain / conflicting report handling.
- Emergency Simulation: the six scenarios defined in PRD §15 / SRS §4.12 (No Hazard, Blocked Road, High-Risk Hazard, Dynamic Hazard During Navigation, Uncertain Report, Conflicting Reports), and baseline (shortest-path) vs. QuakeRoute (risk-aware) comparison.

### 1.2 Out of Scope

- **Voice reporting** — SHOULD HAVE / limited-optional per PRD §10, §18 and SRS §9. Not covered by dedicated test cases here. If implemented, it should be verified using the same acceptance pattern as text reporting (AI-FR-010), since voice transcripts are required to follow the identical text-extraction path.
- Additional hazard categories beyond the MVP's six supported types (Debris/Rubble, Road Blockage, Fire, Flood, Electrical Hazard, Visible Building Damage).
- Advanced verification/trust logic beyond basic confidence/status handling.
- Coordinator/dashboard-specific tooling (Volunteers/Coordinators use the same Evacuee/Community Reporter capabilities — SRS §3.3).
- Real emergency deployment, direct responder integration, production-scale infrastructure, comprehensive real-world disaster data, full AI Vision coverage of all damage types, and multi-disaster support (all explicitly OUT OF SCOPE per PRD §18 / SRS §9).
- Cross-report conflict resolution *by AI* — this is a system/domain-model responsibility, not an AI capability (AI-Requirements §10.1).
- AI-driven route suggestion or routing decisions — AI never selects or influences route candidates directly (AI-Requirements §2).
- Numeric performance claims for AI (accuracy rates, exact confidence thresholds) — these are explicitly not established by any source document (AI-Requirements §18).

---

## 2. Test Case Format

| ID | Category | Scenario | Preconditions | Input/Action | Expected Result | Priority |
|---|---|---|---|---|---|---|

**Category values used below:** `Functional`, `AI Behavior`, `Risk Model`, `Routing`, `Dynamic Behavior`, `Simulation/Validation`, `Negative`.

**Priority values used below:** `Critical` (must pass for MVP demo), `High` (core behavior, should pass), `Medium` (important but not demo-blocking).

---

## 3. Core Test Cases

### 3.1 Functional

| ID | Category | Scenario | Preconditions | Input/Action | Expected Result | Priority |
|---|---|---|---|---|---|---|
| TC-001 | Functional | User location and destinations shown on map | Controlled road network and destination set exist (FR-001, FR-002) | Open the map view | User's current location and all available shelter/medical destinations are visible on the road network | High |
| TC-002 | Functional | Hazard rendered with severity/confidence indicator | At least one hazard exists in the dataset (FR-003, FR-029) | View the map | The hazard's road segment shows a visual indicator distinguishing it from unaffected segments, and its confidence/status is visible in some form (icon, label, or color) | Critical |
| TC-003 | Functional | Map reflects a hazard condition change | A hazard's severity or status changes after initial reporting (FR-004) | Refresh/view the map after the change | The affected segment's visual indicator updates to reflect the new condition | High |
| TC-004 | Functional | Selecting a destination generates an initial route | Destinations are visible on the map (FR-005) | User selects a destination | An initial risk-aware route to that destination is generated and displayed | Critical |
| TC-005 | Functional | Changing destination replaces the route | An active route already exists (FR-006) | User selects a different destination (FR-007) | A new route to the new destination is generated and displayed, replacing the previous one | Medium |
| TC-006 | Functional | All required reporting modes are available and usable | User is in the main app flow (FR-008, FR-009) | Open the reporting flow and attempt each of: photo, text, quick-tap | Each mode accepts input and produces a submittable hazard report; all three feed the same structured hazard pipeline | Critical |

### 3.2 AI Behavior (Hazard & AI)

| ID | Category | Scenario | Preconditions | Input/Action | Expected Result | Priority |
|---|---|---|---|---|---|---|
| TC-007 | AI Behavior | Text report → single structured hazard | Text reporting mode selected (AI-FR-001, FR-016, FR-017) | Submit a clear text report describing exactly one hazard (e.g., "the road is blocked by debris") | Exactly one candidate hazard is produced with Type, Severity, Confidence, and Road Impact populated | Critical |
| TC-008 | AI Behavior | Multiple hazards from a single text report | Text reporting mode selected (AI-FR-008, FR-016) | Submit a text report describing two distinct hazards in one message (e.g., debris and a fallen power line) | Two independently structured candidate hazards are produced, each with its own Type, Severity, Confidence, and Road Impact — neither hazard is merged nor dropped | Critical |
| TC-009 | AI Behavior | Photo of a supported hazard type → proposed hazard | Photo reporting mode selected; photo depicts one of the six MVP hazard types (AI-FR-002, FR-011) | Capture/upload the photo and submit it | AI Vision proposes a candidate hazard with Type, Severity, Road Impact, and Confidence | Critical |
| TC-010 | AI Behavior | AI-suggested hazard requires user confirmation | A candidate hazard has been proposed by AI Vision (FR-012, FR-013, FR-014) | View the proposal, then confirm it | The hazard is added to the safety map and risk model only after confirmation, attached to a location | Critical |
| TC-011 | AI Behavior | User rejects an AI-suggested hazard | A candidate hazard has been proposed by AI Vision (FR-013) | View the proposal, then reject it | The hazard is discarded and does not become part of the active hazard dataset | High |
| TC-012 | AI Behavior | Quick report produces a structured hazard with default confidence | Quick reporting mode selected; predefined category list displayed (FR-018–FR-020) | Select a hazard category and confirm location | A structured hazard is created and added to the dataset, using the same structured format as other modes and carrying a defined default confidence (exact value `TBD`) | High |
| TC-013 | AI Behavior | Severity and Confidence are estimated independently | A hazard is processed from text or photo input (AI-Requirements §8) | Submit an input that is clearly severe but vaguely worded (e.g., "possible collapsed building, not sure") | Severity reflects the described impact level; Confidence reflects the wording's uncertainty — the two values are not collapsed into one (e.g., low confidence does not automatically also lower severity) | High |
| TC-014 | AI Behavior | Ambiguous/vague report yields lower confidence, not a forced classification | Text or photo input is ambiguous or vague (AI-FR-009, §7.3) | Submit an ambiguous report (e.g., "something might be wrong on the road ahead") | A candidate hazard (if any is plausibly identifiable) is produced with a Confidence value lower than an equivalent clear report of the same hazard type — no field is force-filled with unwarranted certainty | High |
| TC-015 | AI Behavior | Incomplete report with no plausible hazard | Text input lacks enough detail to support any hazard classification (§7.4, §12) | Submit a report with no usable hazard detail (e.g., "something is wrong") | No fabricated hazard is produced; the condition is treated as a failure case and surfaced to the reporting flow rather than silently discarded or guessed | Critical |
| TC-016 | AI Behavior | Photo with no supported hazard evidence | Photo does not depict any of the six MVP hazard types (§14.5) | Submit the photo | No candidate hazard is produced; AI does not claim to detect a hazard type outside the MVP's supported set | High |
| TC-017 | AI Behavior | Malformed AI output is not passed downstream | AI processing produces output that does not conform to the required structure (Type, Severity, Confidence, Road Impact) (§12) | Trigger/simulate a malformed AI output | The malformed output is not treated as a valid candidate hazard and is not added to the hazard dataset or risk model | Medium |

### 3.3 Risk Model

| ID | Category | Scenario | Preconditions | Input/Action | Expected Result | Priority |
|---|---|---|---|---|---|---|
| TC-018 | Risk Model | Normal road, no hazard | A road segment has no active hazards (Domain-Risk-Model §13.2) | Compute segment routing cost | Segment Routing Cost equals Base Travel Cost only (Hazard Penalty ≈ 0, Uncertainty Penalty ≈ 0) | Critical |
| TC-019 | Risk Model | Hazard penalty for a high-severity, high-confidence hazard | A segment carries a Confirmed hazard with high severity and high confidence (FR-030, FR-031; Domain-Risk-Model §14.1) | Compute segment routing cost | The segment's Hazard Penalty is substantially larger than for a segment with no hazard; exact magnitude is `TBD` but must be large enough to make the segment less attractive than a viable alternative | Critical |
| TC-020 | Risk Model | Hazard penalty scales down with lower confidence | Two otherwise-identical hazards exist on comparable segments, one high-confidence and one low-confidence (same severity) (Domain-Risk-Model §14.1–14.2) | Compute segment routing cost for both | The low-confidence segment's Hazard Penalty is measurably smaller than the high-confidence segment's Hazard Penalty | High |
| TC-021 | Risk Model | Blocked segment treated as unusable | A segment's Road Impact is Blocked (FR-032; Domain-Risk-Model §16.1) | Compute segment routing cost / attempt to route through it | The segment's cost is effectively infinite (or it is excluded from the routable graph); it is never selected as part of a route | Critical |
| TC-022 | Risk Model | Multiple hazards on one segment aggregate correctly | A single segment has two or more active hazards with different Road Impact and severity values (Domain-Risk-Model §9.2, §10) | Compute segment Road Impact and Hazard Penalty | Segment Road Impact equals the worst Road Impact among active hazards; Hazard Penalty equals the maximum individual hazard penalty among active hazards (Max-aggregation) | Medium |
| TC-023 | Risk Model | Conflicting reports produce Uncertain status and a non-zero penalty | A segment has no confirmed hazard; two reports about it materially disagree (e.g., one "blocked," one "passable") (FR-038–FR-040) | Process both reports | Segment status becomes Uncertain/Conflicting (not Blocked, not cleared); Segment Routing Cost includes a non-zero Uncertainty Penalty | Critical |

### 3.4 Routing

| ID | Category | Scenario | Preconditions | Input/Action | Expected Result | Priority |
|---|---|---|---|---|---|---|
| TC-024 | Routing | Normal route with no hazards | No hazards exist anywhere on the network (FR-033; PRD §15 Scenario 1) | Request a route from origin to destination | The risk-aware route matches, or closely matches, the conventional shortest/fastest baseline route (exact tie-breaking rule for "closely matches" is `TBD`) | Critical |
| TC-025 | Routing | Blocked route triggers an alternative route | An initial route traverses segments A→B→C→D; C→D becomes Blocked (FR-032, FR-033; PRD §15 Scenario 2) | Request/recompute the route | The system proposes a feasible alternative route (e.g., A→B→E→F→D) that does not include the blocked segment | Critical |
| TC-026 | Routing | Lower-risk route selected over a shorter route | A segment on the shortest route (e.g., B→C) is passable but carries a Confirmed, high-severity, high-confidence hazard; a viable alternative exists (FR-030, FR-031, FR-033; PRD §15 Scenario 3) | Request a route from origin to destination | The system selects a longer route whose total risk-adjusted cost is lower, rather than the shortest path through the high-risk segment | Critical |
| TC-027 | Routing | Route cost equals the sum of segment routing costs | A candidate route with multiple segments exists (Domain-Risk-Model §16.2) | Compute the route's total cost | Route Cost equals the sum of each segment's (Base Travel Cost + Hazard Penalty + Uncertainty Penalty) across all segments in the route | Medium |

### 3.5 Dynamic Behavior

| ID | Category | Scenario | Preconditions | Input/Action | Expected Result | Priority |
|---|---|---|---|---|---|---|
| TC-028 | Dynamic Behavior | New hazard on the active route triggers recalculation | User has an active route (FR-035, FR-036; PRD §15 Scenario 4) | A new hazard is reported and processed on a segment of that route | The system detects the impact on the active route and recalculates a new route | Critical |
| TC-029 | Dynamic Behavior | Recalculated route is distinguishable from the original | A recalculated route has been produced (FR-037) | Display the updated route to the user | The user can distinguish the updated route from the previously active route (mechanism is an implementation detail; distinguishability itself is required) | High |
| TC-030 | Dynamic Behavior | New hazard not on the active route does not trigger recalculation for that user | User has an active route; a new hazard is reported on a segment not part of that route (PRD §8) | Process the new hazard report | The safety map and risk model update for that segment, but no route recalculation is triggered for the user whose route is unaffected | High |
| TC-031 | Dynamic Behavior | No new hazards during navigation | User is actively navigating a route; no new hazards are reported (PRD §8, Validation Scenario 1) | Continue navigation with no new reports | The user continues to follow the original route; no recalculation occurs | Medium |

### 3.6 Emergency Simulation

| ID | Category | Scenario | Preconditions | Input/Action | Expected Result | Priority |
|---|---|---|---|---|---|---|
| TC-032 | Simulation/Validation | Scenario 1 — No Hazard | Controlled road network, no active hazards, fixed origin/destination (FR-041, FR-043) | Trigger Scenario 1 | QuakeRoute's route matches, or closely matches, the Baseline route (Simulation-Validation §7, Scenario 1) | Critical |
| TC-033 | Simulation/Validation | Scenario 2 — Blocked Road | Initial route across A→B→C→D exists; no hazard yet active | Trigger Scenario 2 (segment C→D becomes Blocked) | QuakeRoute's proposed route excludes C→D and is feasible; the sequence of state changes (hazard creation, risk update, recalculation) is observable | Critical |
| TC-034 | Simulation/Validation | Scenario 3 — High-Risk Hazard | A segment on the shortest route is passable, no hazard yet active | Trigger Scenario 3 (hazard reported and confirmed with high severity/high confidence on that segment) | Segment remains a valid candidate (not excluded); QuakeRoute's route differs from Baseline in a way that avoids/reduces use of the high-risk segment, provided a lower-total-cost alternative exists | Critical |
| TC-035 | Simulation/Validation | Scenario 4 — Dynamic Hazard During Navigation | User has an active route from a prior request | Trigger Scenario 4 (new hazard reported on a segment of the active route) | Impact is detected; a new route is computed and presented distinguishably from the original | Critical |
| TC-036 | Simulation/Validation | Scenario 5 — Uncertain Report | A segment has no confirmed hazard | Trigger Scenario 5 (single low-confidence report submitted for that segment) | The segment's Road Impact does not become Blocked solely from this report; its status remains something other than Confirmed; its Hazard Penalty is measurably smaller than an equivalent high-confidence case | Critical |
| TC-037 | Simulation/Validation | Scenario 6 — Conflicting Reports | A segment has no confirmed hazard | Trigger Scenario 6 (two materially disagreeing reports submitted for the same segment) | Segment status becomes Uncertain/Conflicting; segment is not excluded from the routable graph; Segment Routing Cost includes a non-zero Uncertainty Penalty | Critical |
| TC-038 | Simulation/Validation | Simulation reproducibility | A scenario has been defined and previously run (FR-042, NFR-002) | Run the same scenario a second time against the same road network and predefined inputs | The route selection and segment classifications are comparable (not contradictory) between the two runs | High |
| TC-039 | Simulation/Validation | Baseline vs. QuakeRoute comparison available | A scenario run has completed (FR-044) | Review the results of the run | Both the Baseline (shortest/fastest) route and the QuakeRoute (risk-aware) route are available for the same scenario, for direct comparison | High |

---

## 4. Negative / Failure Cases

| ID | Category | Scenario | Preconditions | Input/Action | Expected Result | Priority |
|---|---|---|---|---|---|---|
| TC-040 | Negative | Invalid/unusable report input | User is in the reporting flow | Submit an unusable input (e.g., empty text, an unreadable/corrupted photo file) | The submission is rejected gracefully; no malformed or empty hazard is created; the user is not left without feedback | High |
| TC-041 | Negative | Incomplete information yields no fabricated hazard | Text input contains no usable hazard detail (§7.4, §12) | Submit an incomplete report | No hazard is fabricated to fill missing fields; the case is treated as a failure and surfaced to the reporting flow | Critical |
| TC-042 | Negative | Low-confidence hazard is preserved, not silently discarded | A plausible (if weak) hazard is identifiable from a low-evidence input (Domain-Risk-Model §8; AI-Requirements §9) | Submit the low-evidence report | A candidate hazard is still produced, carrying a low Confidence value — it is not dropped, and it is not force-upgraded to a confident classification | High |
| TC-043 | Negative | Conflicting reports are both preserved, neither discarded | Two reports disagree about the same segment (FR-038–FR-040) | Process both reports | Neither report is discarded; neither is treated as sole ground truth; the segment is marked Uncertain/Conflicting rather than resolved arbitrarily in either direction | Critical |
| TC-044 | Negative | AI processing failure | AI inference fails to complete (e.g., service unavailable) (AI-Requirements §12) | Submit a report while AI processing fails | No candidate hazard is produced; the failure is surfaced to the reporting flow rather than silently ignored; the system remains stable (no crash, no corrupted hazard record) | Critical |
| TC-045 | Negative | No feasible route exists | Every path between origin and destination includes at least one Blocked segment (Domain-Risk-Model §11.1) | Request a route | The system indicates that no feasible route is available, rather than returning a route through a Blocked segment or failing silently (exact UX/message is `TBD`) | High |
| TC-046 | Negative | Invalid hazard data is rejected by the risk model | A hazard record is missing a required field (e.g., no Type or no Road Impact) (AI-Requirements §12; FR-024) | Attempt to feed this record into the risk model | The malformed record is not treated as a valid active hazard and does not contribute to any segment's Hazard Penalty or Road Impact | Medium |

---

## 5. Traceability

```text
Requirement
    ↓
Test Case
    ↓
Expected Behavior
```

| Requirement (PRD / SRS / AI-FR) | Test Case(s) | Expected Behavior |
|---|---|---|
| FR-001, FR-002 | TC-001 | User location and destinations visible on map |
| FR-003, FR-029 | TC-002 | Hazard shown with severity/confidence indicator |
| FR-004 | TC-003 | Map updates on hazard condition change |
| FR-005, FR-006 | TC-004 | Destination selection generates initial route |
| FR-007 | TC-005 | Changing destination generates new route |
| FR-008, FR-009 | TC-006 | All reporting modes usable and unified |
| FR-016, FR-017, AI-FR-001 | TC-007 | Single-hazard text extraction |
| FR-016, AI-FR-008 | TC-008 | Multiple-hazard text extraction |
| FR-011, AI-FR-002 | TC-009 | Photo hazard detection |
| FR-012, FR-013, FR-014 | TC-010, TC-011 | Confirmation step before hazard is active |
| FR-018, FR-019, FR-020 | TC-012 | Quick report structured with default confidence |
| AI-Requirements §8 | TC-013 | Severity/Confidence independence |
| AI-FR-009, AI-Requirements §7.3, §9 | TC-014 | Ambiguous input → lower confidence, not forced |
| AI-Requirements §7.4, §12 | TC-015, TC-041 | Incomplete input → no fabricated hazard |
| AI-Requirements §14.5 | TC-016 | No supported hazard in photo → no hazard |
| AI-Requirements §12 | TC-017, TC-046 | Malformed AI output rejected |
| FR-030 | TC-019 | Severity contributes to segment cost |
| FR-031 | TC-020 | Confidence/uncertainty contributes to segment cost |
| FR-032 | TC-021, TC-025, TC-033 | Blocked segments excluded / unusable |
| FR-033 | TC-024, TC-026, TC-032, TC-034 | Non-shortest route selection when lower risk |
| Domain-Risk-Model §9.2, §10 | TC-022 | Multiple-hazard aggregation on one segment |
| FR-038, FR-039, FR-040 | TC-023, TC-037, TC-043 | Conflicting reports → Uncertain status + penalty |
| Domain-Risk-Model §16.2 | TC-027 | Route cost = sum of segment costs |
| FR-035, FR-036 | TC-028, TC-035 | New hazard on active route → recalculation |
| FR-037 | TC-029 | Recalculated route distinguishable |
| PRD §8 | TC-030 | Hazard off-route → no recalculation for that user |
| PRD §8, Validation Scenario 1 | TC-031 | No new hazard → route unchanged |
| FR-041, FR-043; PRD §15 Scenario 1 | TC-032 | Scenario 1 run |
| FR-043; PRD §15 Scenario 2 | TC-033 | Scenario 2 run |
| FR-043; PRD §15 Scenario 3 | TC-034 | Scenario 3 run |
| FR-043; PRD §15 Scenario 4 | TC-035 | Scenario 4 run |
| FR-043; PRD §15 Scenario 5 | TC-036 | Scenario 5 run |
| FR-043; PRD §14, §15 Scenario 5 language | TC-037 | Scenario 6 run |
| FR-042, NFR-002 | TC-038 | Reproducibility |
| FR-044 | TC-039 | Baseline vs. QuakeRoute comparison available |
| PRD §6, §17; SRS §8 | TC-040, TC-044 | Invalid input / AI failure handled without corrupting the dataset |
| Domain-Risk-Model §8, AI-Requirements §9 | TC-042 | Low confidence never silently discarded |
| Domain-Risk-Model §11.1 | TC-045 | No feasible route represented explicitly |

---

## 6. Critical Test Set

The following test cases are the minimum set that must pass before the hackathon demo. They cover the behaviors that most directly demonstrate QuakeRoute's core hypothesis — that risk-aware, uncertainty-aware routing driven by AI-processed hazard reports produces different, safer route decisions than conventional shortest-path routing.

- **TC-002** — Hazard visible on the map with severity/confidence indication.
- **TC-004** — Destination selection generates an initial route.
- **TC-006** — Photo, text, and quick-tap reporting all work and feed the same pipeline.
- **TC-007 / TC-008** — Text reports (single and multiple hazards) are correctly structured.
- **TC-009 / TC-010** — Photo → AI Vision proposal → user confirmation flow works end-to-end.
- **TC-015** — Incomplete input never produces a fabricated hazard.
- **TC-021** — Blocked segments are never routed through.
- **TC-023 / TC-037 / TC-043** — Conflicting reports produce an Uncertain/Conflicting status with a real cost, never an outright block or an ignored report.
- **TC-024 / TC-032** — No hazards → QuakeRoute matches the baseline (no unwarranted penalty).
- **TC-025 / TC-033** — Blocked road → feasible alternative route.
- **TC-026 / TC-034** — High-risk-but-passable segment → lower-risk alternative chosen over the shortest path.
- **TC-028 / TC-035** — New hazard on an active route triggers detection and recalculation.
- **TC-044** — AI failure does not crash the system or silently create a hazard.

If time is constrained, this list — not the full test suite — is the set to protect first.

---

**Document status:** Test Cases derived from `PRD.md`, `SRS.md`, `Domain-Risk-Model.md`, `Simulation-Validation.md`, and `AI-Requirements.md` for the QuakeRoute 10-day hackathon prototype. Items marked `TBD` mirror TBD items already present in the source documents; no threshold, metric, or expected numeric result has been invented. This document does not modify, add to, or remove any requirement, domain rule, or validation scenario defined in the source documents.
