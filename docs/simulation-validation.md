# QuakeRoute — Simulation and Validation

## 0. Document Status and Source of Truth

- **Source of truth:** `PRD.md`, `SRS.md`, and `Domain-Risk-Model.md`. This document does not introduce new product concepts, requirements, features, or numeric thresholds beyond what those three documents already define or explicitly leave `TBD`.
- **What this document is:** a definition of how QuakeRoute's risk model and routing behavior will be simulated, exercised, and validated within the 10-day hackathon.
- **What this document is not:** source code, a database schema, or an API specification. It also does not report experiment results — it defines how those results will later be produced and recorded (Section 13).
- **Numbers:** Any metric, threshold, or parameter not already fixed by the PRD/SRS/Domain-Risk-Model is marked `TBD` here as well, consistent with how those documents treat the same items.

---

## 1. Purpose

This document defines how QuakeRoute will be simulated, tested, and validated. It connects three earlier deliverables into one execution plan:

- **PRD.md** — defines the product's Emergency Simulation feature (§9.12, §15), its validation/success criteria (§16), and the six emergency scenarios that both the feature and the validation mechanism are built around.
- **SRS.md** — translates those into testable functional requirements (FR-041–FR-044, the six scenarios in §4.12) and non-functional requirements (NFR-002 Simulation Reproducibility).
- **Domain-Risk-Model.md** — defines the risk model formulas (Base Travel Cost + Hazard Penalty + Uncertainty Penalty), the causal chain to validate (§19.1: *Hazard change → Risk change → Road cost change → Route decision change*), and the specific model choices that validation needs to resolve (§19.2).

This document operationalizes that causal chain into concrete, runnable scenarios, a baseline comparison method, and pass/fail criteria — without inventing new behavior, and without pretending any experiment has already been run.

### 1.1 Two distinct purposes, kept separate

A recurring point in the source documents (PRD §9.12, §15; Domain-Risk-Model §19) is that "simulation" serves two different purposes. This document treats them as related but distinct throughout:

1. **Emergency Simulation as a product feature** (PRD §9.12, FR-041–FR-044) — helps a user or evaluator understand how QuakeRoute behaves, provides a controlled disaster scenario to explore, and serves as a demonstration/preparedness environment. Covered in Section 11 of this document.
2. **Controlled Simulation as a validation mechanism** — tests whether the risk model and routing behavior work as intended, compares QuakeRoute against the baseline, and produces evidence to support or reject the product hypothesis (Section 3). Covered in Sections 4–10 and 12–15 of this document.

Both purposes reuse the same six underlying scenarios (PRD §15) and the same simulation environment (Section 5), but they are evaluated differently: the feature is judged by whether a user can observe and understand the flow; the validation mechanism is judged by whether the observed behavior matches the expected behavior defined per scenario.

---

## 2. Validation Goals

This validation activity aims to establish, through controlled and reproducible scenarios, whether the following hold true for the QuakeRoute prototype:

- Hazard reports can influence a road segment's routing risk (Domain-Risk-Model §13–§16).
- Risk-aware routing can avoid a road segment that becomes blocked (PRD §15 Scenario 2; FR-032).
- High-severity, high-confidence hazards can influence route selection away from an otherwise-shortest path, without excluding the segment outright (PRD §15 Scenario 3; FR-033).
- A low-confidence or unconfirmed report is not immediately treated as ground truth (PRD §11; FR-025).
- Conflicting reports about the same segment are preserved as an explicit uncertainty state rather than resolved arbitrarily (PRD §14; FR-038–FR-040).
- A newly reported hazard on a user's active route can trigger route recalculation (PRD §9.10; FR-035–FR-037).
- In the absence of any hazard, risk-aware routing does not diverge from conventional shortest-path routing without cause (PRD §15 Scenario 1; FR-033).

These goals map directly to the six PRD scenarios (Section 6) and to the causal chain defined in Domain-Risk-Model §19.1. No goal beyond what is listed above, or implied by the three source documents, is in scope for this validation activity.

---

## 3. Hypothesis

### 3.1 Main hypothesis

> **H0 (main hypothesis):** Risk-aware routing can produce lower-risk feasible route decisions than conventional shortest-path routing when post-earthquake road conditions are dynamic, incomplete, and uncertain.

This is the hypothesis stated in the PRD's Product Goal (§1) and Validation and Success Criteria (§16), restated here as the object of this validation plan.

### 3.2 Sub-hypotheses

The main hypothesis is broad; the following sub-hypotheses break it into independently testable claims, each tied to one or more of the six scenarios (Section 6) and to specific functional requirements:

| ID | Sub-hypothesis | Primary scenario(s) | Related requirement(s) |
|---|---|---|---|
| H1 | When no hazards are present, risk-aware routing does not produce a materially different route from the shortest-path baseline. | Scenario 1 | FR-033 |
| H2 | When a segment on the shortest route becomes fully blocked, risk-aware routing produces a feasible alternative that avoids the blocked segment. | Scenario 2 | FR-032, FR-033 |
| H3 | When a passable segment carries a high-severity, high-confidence hazard, risk-aware routing can select a longer but lower-risk alternative. | Scenario 3 | FR-030, FR-031, FR-033 |
| H4 | When a new hazard is reported on a user's active route, the system detects the impact and recalculates the route. | Scenario 4 | FR-035, FR-036, FR-037 |
| H5 | A hazard reported with low confidence is not treated as a confirmed or blocking condition. | Scenario 5 | FR-025, FR-027 |
| H6 | When two reports about the same segment materially disagree, the segment is marked uncertain/conflicting (not blocked, not cleared) and its routing cost reflects an uncertainty penalty. | Scenario 6 | FR-038, FR-039, FR-040 |

H1–H6 are not new claims; they restate, in testable form, the expected behaviors already defined in PRD §15 and Domain-Risk-Model §17. This document does not add sub-hypotheses beyond what those six scenarios already cover.

---

## 4. Baseline

### Baseline
The conventional shortest/fastest route between origin and destination, computed using only Base Travel Cost (distance/time), with no hazard-aware risk model applied (Domain-Risk-Model §13.2).

### QuakeRoute
The risk-aware route between the same origin and destination, computed using the full routing cost defined in Domain-Risk-Model §13–§16:

```
Segment Routing Cost = Base Travel Cost + Hazard Penalty + Uncertainty Penalty
Route Cost = Σ Segment Routing Cost, over all segments in the route
```

subject to Blocked segments being excluded (Domain-Risk-Model §16.1).

### Why a baseline is required

The PRD's Product Goal and Validation and Success Criteria (§16) explicitly define success in terms of a comparison — not in terms of QuakeRoute's absolute behavior alone. A baseline is required because:

- It is the only way to demonstrate that risk-aware routing produces a *different and better* outcome than what a conventional system would produce under the same conditions (PRD §16).
- Scenario 1 (Section 6) specifically requires that QuakeRoute matches the baseline when no hazards are present — this can only be checked if a baseline is actually computed for comparison, not assumed.
- Metrics such as distance trade-off and route cost delta (Section 8; PRD §16) are inherently relative and require both routes to be computed for the same scenario.

Both routes must be computed **for the same origin, destination, and road network state**, per scenario, so that any difference in outcome can be attributed to the risk model rather than to a difference in scenario setup.

---

## 5. Simulation Environment

The simulation environment is the controlled substrate that all six scenarios (Section 6) run against. Per PRD §9.12/§18 and SRS §4.12/§9, it is a single controlled post-earthquake scenario on a controlled road network — not real-world data.

### 5.1 Controlled road network
A fixed, predefined graph of Road Segments (Domain-Risk-Model §9.1), each with a defined Base Travel Cost. The exact size, topology, and coordinate/visual representation of this network are **TBD** at implementation time; this document only requires that the network be:
- Fixed for the duration of validation (not regenerated between runs), so results are reproducible (SRS NFR-002).
- Large enough to contain at least one meaningful alternate path between the origin and destination used in Scenario 2/3 (PRD §15 explicitly describes an alternative such as A→B→E→F→D), so that a blocked or high-risk segment has somewhere to reroute to.

### 5.2 Road segments
Each Road Segment carries, at minimum, the attributes defined in Domain-Risk-Model §9.1: an identifier, a Base Travel Cost, and zero or more active Hazards. For validation purposes, segment identifiers should be stable and human-readable (e.g., `A→B`) so that scenario specifications (Section 7) can reference them unambiguously.

### 5.3 Origin
The user's simulated starting location on the road network, fixed per scenario run so that baseline and QuakeRoute routes are computed from the same starting point (Section 4).

### 5.4 Destination
A shelter or medical facility destination, selected from the controlled set defined by the Destination Selection feature (PRD §9.2; SRS §4.2). Fixed per scenario run, for the same reason as the origin.

### 5.5 Shelter / medical destination
Per PRD §4, §9.2, destinations represent shelters or medical facilities within the controlled network. For simulation purposes, at least one such destination must exist that is reachable from the origin via more than one distinct path, to support Scenarios 2 and 3.

### 5.6 Predefined hazards
Hazards used in each scenario are predefined as part of that scenario's setup (Section 7), not generated dynamically or randomly, so that runs are reproducible (FR-042, NFR-002). Each predefined hazard uses the attribute set defined in Domain-Risk-Model §3 (type, location, severity, confidence, source, status, road impact, timestamp, evidence).

### 5.7 Hazard reports
Where a scenario requires simulating a Community Reporter submitting an Observation (e.g., Scenario 6 in Section 6), the report content is predefined as part of the scenario setup, not left to live user input during a validation run, so that the same scenario produces comparable outcomes across runs (FR-042).

### 5.8 Hazard states
Each predefined hazard has an explicit starting Status (Domain-Risk-Model §7.1: Reported, Confirmed, Uncertain/Conflicting, etc.) and, where the scenario requires a state change (e.g., Scenario 4's "new hazard during navigation"), an explicit triggering event that changes that state.

### 5.9 Scenario state changes
Where a scenario involves an event occurring after an initial state (e.g., a new hazard appearing mid-navigation, or a second conflicting report arriving), that event is applied as a discrete, scripted step — not on a timer or polling interval, consistent with Domain-Risk-Model §12's requirement that recalculation is "triggered by information, not by time."

### 5.10 Reproducibility requirement
Per FR-042 (SRS §4.12) and NFR-002 (SRS §5), the same scenario, run multiple times against the same road network and predefined hazard/report inputs, must produce comparable outcomes (same route selection, same segment classifications). This document does not define a numeric tolerance for "comparable" beyond exact route/segment-classification match, since the simulation environment as scoped here is deterministic (no randomized inputs); if any part of the implementation introduces non-determinism (e.g., AI Vision output varying run-to-run for the same photo), that must be reconciled before this reproducibility requirement can be considered satisfied — this reconciliation approach is **TBD**.

---

## 6. Simulation Scenarios

The six scenarios below are the same six scenarios defined in PRD §15 and SRS §4.12 (FR-043). This document does not add, remove, or rename any of them; it operationalizes them for the validation activity described in Sections 8–10.

### Scenario 1 — No Hazard
No hazard exists on the road network.

**Purpose:** Confirm that risk-aware routing does not produce unusual or unwarranted behavior under normal conditions — i.e., it does not diverge from the shortest-path baseline without cause (PRD §15 Scenario 1; FR-033).

### Scenario 2 — Blocked Road
A road segment on the shortest route becomes blocked.

**Expected behavior:** QuakeRoute finds a feasible alternative route that excludes the blocked segment (PRD §15 Scenario 2; FR-032).

### Scenario 3 — High-Risk Hazard
A road segment remains passable but carries a high-severity, high-confidence hazard.

**Expected behavior:** QuakeRoute may select a route with lower risk-adjusted cost, even if it is somewhat longer, without excluding the segment outright (PRD §15 Scenario 3; FR-030, FR-031, FR-033).

### Scenario 4 — Dynamic Hazard During Navigation
The user already has an active route. A new hazard is reported on a segment of that route.

**Expected behavior:** The risk model updates for the affected segment, the impact on the active route is detected, and the route is recalculated (PRD §15 Scenario 4; FR-035, FR-036, FR-037).

### Scenario 5 — Uncertain Report
A hazard is reported with low confidence.

**Expected behavior:** The hazard is not immediately treated as confirmed or as a blocking condition (PRD §11, §15 Scenario 5 language; FR-025, FR-027).

### Scenario 6 — Conflicting Reports
Two reports provide differing information about the same road segment.

**Expected behavior:** The system preserves the disagreement as an explicit uncertain/conflicting status rather than resolving it in either direction, and routing accounts for the resulting risk proportionally (PRD §14, §15 Scenario 5 language, and SRS §4.11; FR-038, FR-039, FR-040).

> **Note on scenario numbering:** PRD §15 lists a sixth scenario ("AI Vision Hazard Report") separately from the "Conflicting Reports" scenario described in PRD §14/SRS §4.11. Per this document's brief, the required scenario set is: No Hazard, Blocked Road, High-Risk Hazard, Dynamic Hazard During Navigation, Uncertain Report, and Conflicting Reports — six scenarios in total, matching FR-043's requirement that the simulation "support at least the six scenarios defined in the PRD." The AI Vision Hazard Report flow (PRD §15 Scenario 6, FR-010–FR-014) is a reporting-pipeline concern (how a hazard *enters* the system) rather than a distinct risk/routing behavior to validate, and its structured-hazard output is exercised indirectly by Scenarios 3, 5, and 6 above, whichever reporting mode is used to create the hazard in each scenario's setup.

---

## 7. Scenario Specification

Each scenario is specified using the format below. Numerical thresholds are only included where the PRD/SRS/Domain-Risk-Model already fix them; all threshold-dependent judgments otherwise remain `TBD` and are called out explicitly as such (see also Section 14, Limitations).

### Scenario 1 — No Hazard

**Initial State**
Controlled road network with no active hazards. Origin and destination fixed (Section 5.3, 5.4).

**Input / Event**
None. A route is requested from origin to destination.

**System Behavior**
Both the Baseline and QuakeRoute compute a route using only Base Travel Cost, since Hazard Penalty and Uncertainty Penalty are ~0 everywhere (Domain-Risk-Model §17).

**Expected Result**
QuakeRoute's route matches, or closely matches, the Baseline's route.

**What This Tests**
H1 — that risk-aware routing does not introduce unwarranted deviation from shortest-path behavior when there is nothing to route around.

**Pass Criteria**
QuakeRoute's route uses the same sequence of segments as the Baseline's route. What counts as "closely matches" if the routes are not identical (e.g., due to tie-breaking between equal-cost paths) is **TBD** and should be defined during implementation.

---

### Scenario 2 — Blocked Road

**Initial State**
An initial shortest route exists across segments A→B→C→D (per PRD §15's own example numbering). No hazards yet active.

**Input / Event**
A hazard is introduced on segment C→D with Road Impact = Blocked.

**System Behavior**
Segment C→D's Segment Routing Cost becomes infinite / the segment is excluded from the routable graph (Domain-Risk-Model §16.1). The routing engine recomputes the minimum-cost path over the remaining graph.

**Expected Result**
QuakeRoute proposes a feasible alternative route (e.g., A→B→E→F→D, per the PRD's own example) that does not traverse C→D. The Baseline, since it does not treat C→D as blocked, either still proposes the now-infeasible original route or is evaluated only for comparison of what "shortest ignoring hazards" would have been — see Section 9 for how baseline/QuakeRoute comparison is handled when the baseline route is infeasible.

**What This Tests**
H2 — that a fully blocked segment is excluded from route candidates and a feasible alternative is found.

**Pass Criteria**
- QuakeRoute's proposed route does not include segment C→D.
- QuakeRoute's proposed route is feasible (traversable given current hazard states).

---

### Scenario 3 — High-Risk Hazard

**Initial State**
A segment on the shortest route (e.g., B→C) is passable but has no active hazard yet.

**Input / Event**
A hazard is reported and reaches Confirmed status on segment B→C, with high severity and high confidence.

**System Behavior**
Segment B→C's Hazard Penalty rises substantially per Domain-Risk-Model §14.1 (`SeverityWeight × ConfidenceFactor`, both high), while Road Impact remains Passable or Partially Blocked (not Blocked), so the segment is not excluded.

**Expected Result**
QuakeRoute selects an alternative route with a lower risk-adjusted total cost, even if that route is longer in distance, provided such an alternative exists in the network.

**What This Tests**
H3 — that severity and confidence jointly produce a penalty large enough to influence route selection without excluding the segment outright.

**Pass Criteria**
- Segment B→C remains a valid (non-excluded) candidate segment.
- QuakeRoute's route differs from the Baseline's route in a way that avoids or reduces use of segment B→C, provided a lower-total-cost alternative exists.
- The specific severity/confidence values and the exact penalty magnitude that trigger this behavior are **TBD** (Domain-Risk-Model §14.3) and must be set and tuned as part of running this scenario, not assumed in advance.

---

### Scenario 4 — Dynamic Hazard During Navigation

**Initial State**
The user has an active route (the QuakeRoute route computed for a prior scenario or a fresh request).

**Input / Event**
A new hazard is reported and processed on a segment that lies on the user's active route.

**System Behavior**
The affected segment's Risk and Routing Cost are recomputed (Domain-Risk-Model §12). The system checks whether the affected segment is on the user's active route (FR-035). Since it is, the route is recalculated (FR-036) and the new route is flagged as distinguishable from the original (FR-037).

**Expected Result**
The user receives an updated alternative route, visibly distinguished from the original route.

**What This Tests**
H4 — that a new hazard on an active route triggers detection and recalculation, and that the result is presented as updated rather than silently replacing the original.

**Pass Criteria**
- The system detects that the new hazard's segment intersects the active route.
- A new route is computed.
- The new route is observably distinguishable from the original route (per FR-037; exact UI mechanism is out of scope for this document).

---

### Scenario 5 — Uncertain Report

**Initial State**
A segment has no confirmed hazard.

**Input / Event**
A single hazard report is submitted for that segment with low confidence (e.g., via a reporting mode that yields a low default or AI-estimated confidence).

**System Behavior**
The hazard is created with Status = Reported (not Confirmed) per Domain-Risk-Model §7.1, and its low confidence produces a small `ConfidenceFactor`, discounting the Hazard Penalty per Domain-Risk-Model §14.1–14.2.

**Expected Result**
The hazard does not cause the segment to be treated as Blocked or as a high-confidence Confirmed hazard would be. It contributes a proportionally small Hazard Penalty.

**What This Tests**
H5 — that low confidence meaningfully discounts a hazard's effect on routing, rather than the hazard being treated as fact.

**Pass Criteria**
- The segment's Road Impact does not become Blocked solely from this single low-confidence report (unless the report's own Road Impact field for a confirmed high-severity case would independently justify it — this scenario should use a report whose severity/impact does not itself imply Blocked, to isolate the confidence effect).
- The segment's Hazard Penalty is measurably smaller than it would be for an otherwise-identical high-confidence report on the same segment (a same-severity, high-confidence comparison case may be needed to make this observable — see Section 8, Metrics).
- Exact numeric thresholds for "low confidence" and the resulting discount are **TBD** (Domain-Risk-Model §14.3).

---

### Scenario 6 — Conflicting Reports

**Initial State**
A segment has no confirmed hazard.

**Input / Event**
Two reports are submitted for the same segment with materially disagreeing claims (e.g., one reports Blocked, the other reports Passable).

**System Behavior**
The system detects material disagreement (FR-038) and sets the segment's status to Uncertain/Conflicting (FR-039) rather than Blocked or Passable. An Uncertainty Penalty is applied, intended to be proportional to the degree of disagreement (FR-040; Domain-Risk-Model §15.1).

**Expected Result**
The segment is neither treated as fully blocked nor fully safe. Its routing cost reflects the added uncertainty, and it remains selectable if no better alternative exists.

**What This Tests**
H6 — that conflicting reports are preserved as an explicit uncertainty state, and that routing incorporates that uncertainty as cost rather than resolving it arbitrarily.

**Pass Criteria**
- The segment's status becomes Uncertain/Conflicting.
- The segment is not excluded from the routable graph (it is not treated as Blocked).
- The segment's Segment Routing Cost includes a non-zero Uncertainty Penalty.
- The exact "degree of disagreement" function and the resulting uncertainty weight are **TBD** (Domain-Risk-Model §15.3) and must be defined before this scenario's numeric pass criteria (beyond "non-zero penalty, not excluded") can be made precise.

---

## 8. Metrics

The following metrics are drawn from PRD §16's "Prototype-appropriate metrics" and Domain-Risk-Model §19.2, and are the metrics used to compare Baseline and QuakeRoute across the scenarios in Section 7. No metric introduces a numeric target that is not already stated in the PRD/SRS; where a target would be needed to judge "pass," it is marked `TBD`.

| Metric | Meaning | Status |
|---|---|---|
| Route distance | Total distance (or equivalent unit) of the proposed route. Used to measure the "distance trade-off" when QuakeRoute selects a longer route for lower risk. | In scope |
| Estimated travel cost/time | If available from Base Travel Cost data, the time-equivalent of the route. | Optional / TBD (depends on whether Base Travel Cost is modeled as time, distance, or both) |
| Accumulated risk (Hazard Penalty + Uncertainty Penalty, summed over the route) | The total risk-related cost carried by a route, separate from its Base Travel Cost. Used to show that QuakeRoute's selected route has lower accumulated risk than the Baseline's, where applicable. | In scope |
| Number of hazardous segments | Count of segments in a route that carry an active (non-zero-penalty) hazard. Used for the "hazardous segments avoided" comparison (PRD §16). | In scope |
| Blocked segments traversed | Count of Blocked segments included in a proposed route. For QuakeRoute this must always be zero (FR-032); tracked for the Baseline for comparison, since the Baseline does not exclude blocked segments. | In scope |
| Route changes (recalculation events) | Whether and how many times a route was recalculated during a scenario run (relevant to Scenario 4). | In scope |
| Recalculation success | Whether a valid alternative route was produced when the active route became affected (Scenario 4). | In scope |
| Uncertainty handling | Whether a segment with conflicting or low-confidence reports ended up in the expected state (Uncertain/Conflicting, not Blocked or Confirmed) — a categorical, not numeric, metric (Scenarios 5, 6). | In scope |
| Feasibility | Whether the proposed route is actually traversable given current hazard states (no route through a fully Blocked segment). | In scope |
| Route cost (risk-adjusted) | Total Route Cost as defined in Domain-Risk-Model §16.2, for direct Baseline vs. QuakeRoute comparison. | In scope |
| Risk reduction vs. additional travel cost | The relationship between how much accumulated risk QuakeRoute's route avoids and how much additional distance/cost it incurs to do so, where a detour is chosen (Scenario 3 in particular). | In scope, but no target ratio is defined — the PRD does not specify an acceptable trade-off threshold; this is observed and reported, not pass/failed against a number. `TBD` if a threshold is later desired. |

No metric in this table introduces a numeric pass/fail target beyond what is already implied by the scenario's Pass Criteria (Section 7) — e.g., "zero Blocked segments traversed by QuakeRoute" is a hard requirement (FR-032), while "risk reduction vs. additional travel cost" is observational only, consistent with PRD §16's statement that "metrics requiring real-world field data or long-term usage are out of scope."

---

## 9. Validation Method

Each scenario is run and evaluated using the same repeatable procedure:

```text
Scenario (Section 6/7)
   ↓
Set up Initial State (Section 5): road network, origin, destination, predefined hazards
   ↓
Apply Input / Event (per scenario spec)
   ↓
Compute Baseline route (Section 4)
   ↓
Compute QuakeRoute route (Section 4)
   ↓
Collect Metrics (Section 8) for both routes
   ↓
Compare Baseline vs. QuakeRoute
   ↓
Check against Pass Criteria (Section 7) and Expected Behavioral Validation (Section 10)
   ↓
Evaluate relevant sub-hypothesis (Section 3.2)
```

### 9.1 How this produces evidence

- Each scenario run produces a concrete, recorded outcome (Section 13) for both the Baseline and QuakeRoute, under identical initial conditions (Section 5.10, reproducibility).
- A scenario's Pass/Fail result (Section 10) is evidence **for or against** the specific sub-hypothesis it targets (Section 3.2) — not for the main hypothesis (H0) directly. H0 is supported to the extent that H1–H6 collectively hold across all six scenarios; it is not proven or disproven by any single scenario in isolation.
- Where a scenario's numeric pass criteria are marked `TBD` (Section 7), that scenario's evidentiary value is limited to the categorical behaviors it can check (e.g., "segment excluded," "status became Uncertain/Conflicting") until the relevant parameter is fixed and validated. This is a deliberate, honest scope limitation — see Section 14.
- Baseline vs. QuakeRoute comparison, run under the same scenario, is what isolates the effect of the risk model from any other difference (e.g., network topology), per Section 4's rationale for having a baseline at all.

---

## 10. Expected Behavioral Validation

| Behavior | Expected Result | Validation |
|---|---|---|
| Blocked road | Route avoids blocked segment | Pass/Fail |
| High-risk hazard | Higher-risk route is penalized (segment cost rises; alternative may be selected) | Pass/Fail |
| New hazard on active route | Route recalculates | Pass/Fail |
| Low-confidence hazard | Does not automatically become blocked or confirmed | Pass/Fail |
| Conflicting reports | Uncertainty maintained (status Uncertain/Conflicting; not blocked, not cleared) | Pass/Fail |
| No hazard present | Risk-aware route matches baseline | Pass/Fail |

These six rows correspond directly to Scenarios 1–6 (Section 6/7) and to sub-hypotheses H1–H6 (Section 3.2). Each row's Pass/Fail outcome is recorded per Section 13 and is left blank in this document, since no scenario has yet been executed.

---

## 11. Emergency Simulation Feature

This section describes how the same underlying scenarios (Section 6) are exposed to a user or evaluator as a product feature (PRD §9.12; FR-041–FR-044), distinct from the internal validation runs described in Sections 8–10.

```text
Earthquake Scenario
        ↓
Emergency Mode
        ↓
Hazards Appear
        ↓
Select Destination
        ↓
Initial Route
        ↓
New Hazard
        ↓
Risk Update
        ↓
Route Recalculation
        ↓
Alternative Route
```

### 11.1 Distinction from internal experiments

| | Emergency Simulation (feature) | Controlled Simulation (validation) |
|---|---|---|
| **Audience** | End user or hackathon evaluator, interacting with the app | Whoever is running/reviewing validation (developer, evaluator reviewing evidence) |
| **Purpose** | Demonstrate and let a user explore QuakeRoute's behavior (PRD §9.12) | Test whether risk model and routing behavior match the expected behavior (Sections 2–3) |
| **Trigger** | User/operator triggers a scenario from within the app (FR-041) | Scenario is run as part of a validation pass, potentially without a full UI |
| **Output** | Observable map, route, and hazard updates in the UI | Recorded metrics and Pass/Fail results (Section 13) |
| **Comparison to baseline** | Optional/illustrative, if the UI chooses to surface it (FR-044 makes this data available) | Required for every scenario (Section 4, Section 9) |

Both share the same underlying scenario definitions (Section 6/7) and the same simulation environment (Section 5) — the feature is a user-facing presentation of the same mechanism the validation activity exercises internally. This satisfies FR-041–FR-044 without requiring two separate implementations of the scenario logic.

---

## 12. Validation Acceptance Criteria

The QuakeRoute prototype is considered validated for the purposes of this hackathon if the following observable, testable conditions hold, based on running the six scenarios in Section 6/7:

- Scenario 1: QuakeRoute's route matches (or closely matches, per the `TBD` tie-breaking definition in Section 7) the Baseline route when no hazards are present.
- Scenario 2: QuakeRoute's route never traverses a Blocked segment, and a feasible alternative route is produced.
- Scenario 3: QuakeRoute is capable of selecting a longer, lower-total-cost alternative route when a passable segment carries a high-severity, high-confidence hazard, for at least the parameter values used during validation.
- Scenario 4: A new hazard on the user's active route triggers detection and recalculation, producing a distinguishable updated route.
- Scenario 5: A low-confidence hazard report does not cause the affected segment to be treated as Blocked or Confirmed.
- Scenario 6: Conflicting reports on the same segment result in an Uncertain/Conflicting status (not Blocked, not cleared) and a non-zero Uncertainty Penalty.

### 12.1 What this validation does and does not claim

- This validation only demonstrates that the prototype **behaves according to the model** (Domain-Risk-Model §13–§17) within these six controlled scenarios.
- This validation does **not** claim, and this document makes no claim, that QuakeRoute is proven to save lives, prevent harm, or produce a safe route in any real-world sense (PRD §6, §17; SRS §8; Domain-Risk-Model §18.2). Any recommended route remains, per those documents, not a safety guarantee.
- Meeting all six criteria above supports sub-hypotheses H1–H6 (Section 3.2) within the scope of the controlled simulation; it does not, by itself, generalize to the main hypothesis H0 beyond that scope (Section 9.1).

---

## 13. Result Recording

Results are recorded using the table below once scenarios are actually executed. This document defines the format only — it does not populate it with results, since no experiment has been run as of this document's authoring.

| Scenario | Baseline Result | QuakeRoute Result | Metrics | Pass/Fail | Notes |
|---|---|---|---|---|---|
| 1 — No Hazard | *(to be recorded)* | *(to be recorded)* | *(to be recorded)* | *(to be recorded)* | |
| 2 — Blocked Road | *(to be recorded)* | *(to be recorded)* | *(to be recorded)* | *(to be recorded)* | |
| 3 — High-Risk Hazard | *(to be recorded)* | *(to be recorded)* | *(to be recorded)* | *(to be recorded)* | |
| 4 — Dynamic Hazard During Navigation | *(to be recorded)* | *(to be recorded)* | *(to be recorded)* | *(to be recorded)* | |
| 5 — Uncertain Report | *(to be recorded)* | *(to be recorded)* | *(to be recorded)* | *(to be recorded)* | |
| 6 — Conflicting Reports | *(to be recorded)* | *(to be recorded)* | *(to be recorded)* | *(to be recorded)* | |

---

## 14. Limitations

The following limitations apply to this validation approach and to any evidence it produces, consistent with PRD §6, §17 and Domain-Risk-Model §18.2:

- Controlled simulation does not represent the full range of real-world post-earthquake conditions; it is limited to the single controlled scenario and road network defined in Section 5.
- Hazard data used in validation is synthetic/predefined (Section 5.6, 5.7), not sourced from real disaster events.
- AI Hazard Understanding output (where used to create scenario hazards) can be inaccurate; AI output is always treated as an observation/prediction, never as verified fact (PRD §11; Domain-Risk-Model §3).
- Community reports, real or simulated, can be incorrect or stale; QuakeRoute's uncertainty handling (Scenarios 5–6) is designed around this, but validation does not prove the handling is correct for every possible real-world report pattern — only for the scenario cases tested.
- The controlled road network (Section 5.1) may differ structurally from any real road network; results are not claimed to generalize beyond the tested network topology.
- The risk model itself (Domain-Risk-Model §13–§16) is an approximation with multiple parameters explicitly marked `TBD` (severity weights, confidence-factor mapping, uncertainty weighting, disagreement scaling, staleness decay). Validation as scoped here can confirm the model's *directional* behavior (e.g., higher severity+confidence → larger penalty) but cannot, by itself, confirm that any specific numeric parameter is "correct" without a defined target to validate against.
- Results from this simulation do not prove real-world safety, and must not be represented as doing so in any summary or communication derived from this document (PRD §17; Domain-Risk-Model §18.2).

---

## 15. Validation-to-Implementation Traceability

```text
SRS Requirement
        ↓
Domain/Risk Rule
        ↓
Simulation Scenario
        ↓
Metric / Expected Behavior
        ↓
Validation Evidence
```

| SRS Requirement | Domain/Risk Rule | Simulation Scenario | Metric / Expected Behavior | Validation Evidence |
|---|---|---|---|---|
| FR-032 (blocked segments unusable) | Blocked Road handling (Domain-Risk-Model §16.1) | Scenario 2 | Blocked segments traversed = 0; Feasibility | Section 13, Scenario 2 row |
| FR-030, FR-031, FR-033 (severity/confidence into cost; non-shortest selection) | Hazard Penalty formula (§14) | Scenario 3 | Accumulated risk; Route cost; Risk reduction vs. additional travel cost | Section 13, Scenario 3 row |
| FR-035, FR-036, FR-037 (detect impact, recalculate, present distinguishably) | Dynamic Risk Update and Route Recalculation (§12) | Scenario 4 | Route changes; Recalculation success | Section 13, Scenario 4 row |
| FR-025, FR-027 (AI output as prediction; status field) | Confidence (§5); Hazard Status Lifecycle (§7) | Scenario 5 | Uncertainty handling (categorical) | Section 13, Scenario 5 row |
| FR-038, FR-039, FR-040 (detect disagreement; mark uncertain; apply penalty) | Conflicting Reports (§11.2); Uncertainty Penalty (§15) | Scenario 6 | Uncertainty handling (categorical); Accumulated risk | Section 13, Scenario 6 row |
| FR-033 (risk-aware matches shortest when no hazards) | Risk-Aware Routing summary (§17) | Scenario 1 | Route distance; Route cost (should match Baseline) | Section 13, Scenario 1 row |
| FR-042 (reproducibility) | Deterministic scenario setup (this document, §5.6–5.10) | All six scenarios | Comparable outcomes across repeated runs | Not scenario-specific; a cross-cutting check applied to every row in Section 13 |
| FR-044 (baseline vs. risk-aware comparison available) | Baseline definition (this document, §4) | All six scenarios | All metrics in Section 8, computed for both Baseline and QuakeRoute | Section 13 (Baseline Result and QuakeRoute Result columns) |

---

## 16. Final Validation Summary

**What was tested:** Whether QuakeRoute's risk-aware routing behaves according to the risk model defined in `Domain-Risk-Model.md` — specifically, whether hazards, blocked segments, high-risk-but-passable segments, dynamically appearing hazards, low-confidence reports, and conflicting reports each produce the routing and status behavior required by the PRD and SRS.

**Baseline used:** Conventional shortest/fastest routing using only Base Travel Cost, with no hazard-aware risk model (Section 4).

**Main scenarios:** The six PRD-defined scenarios — No Hazard, Blocked Road, High-Risk Hazard, Dynamic Hazard During Navigation, Uncertain Report, and Conflicting Reports (Section 6/7) — each run against a fixed, controlled road network and origin/destination.

**Metrics:** Route distance, accumulated risk, number of hazardous segments, blocked segments traversed, route changes, recalculation success, uncertainty handling, feasibility, risk-adjusted route cost, and risk-reduction-vs-travel-cost trade-off (Section 8) — all drawn directly from PRD §16 and Domain-Risk-Model §19.2, with no invented numeric targets.

**Behavioral acceptance criteria:** The six conditions listed in Section 12 — each tied to one scenario and one or more sub-hypotheses (H1–H6) — define what "validated" means for this prototype. All six must hold, based on actual scenario runs recorded per Section 13, for the prototype to be considered validated within the scope of this document.

**Limitations on the evidence:** This validation is confined to a single controlled post-earthquake scenario on a synthetic road network with predefined hazards (Section 14). It demonstrates model-consistent behavior within that scope; it does not demonstrate, and does not claim to demonstrate, real-world safety or generalization beyond the tested scenarios (PRD §17; Domain-Risk-Model §18.2).

No result is reported as final in this document — Section 13 remains to be populated once the six scenarios are actually executed against the implemented prototype.
