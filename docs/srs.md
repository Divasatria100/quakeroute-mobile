# QuakeRoute — Software Requirements Specification

## 1. Introduction

### 1.1 Purpose
This Software Requirements Specification (SRS) defines the functional and non-functional requirements for QuakeRoute, a post-earthquake, risk-aware navigation prototype. This document translates the QuakeRoute Product Requirements Document (PRD) into requirements that are specific, implementable, and testable, to guide design and development during the 10-day hackathon build.

### 1.2 Scope
QuakeRoute converts low-friction, multimodal hazard reports (photo, text, quick tap, and optionally voice) from users and the community into structured hazard data, and uses that data to compute routes based on risk rather than distance or travel time alone. The system operates within a controlled, simulated post-earthquake scenario on a controlled road network, and includes an emergency simulation capability for demonstration and validation.

This SRS covers the requirements needed to build the prototype described in the PRD. It does not cover production deployment, real-world emergency use, disaster types other than earthquake, or integration with external emergency response systems — these remain out of scope (see Section 11).

This SRS is provider-agnostic at the requirement level. Where an external AI inference or mapping/routing capability is required, it is described as a dependency rather than tied to a specific vendor or model (see Section 7).

### 1.3 Intended Audience
- Hackathon development team (engineers, designers) implementing QuakeRoute.
- Hackathon evaluators/judges assessing the prototype against its stated goals.
- Anyone producing follow-on technical documentation (e.g., architecture, API, or database design) based on this SRS.

### 1.4 Definitions / Terminology

| Term | Definition |
|---|---|
| Hazard | A structured record of a reported or detected road-condition risk, with type, location, severity, confidence, source, status, road impact, timestamp, and evidence. |
| Severity | Estimated impact level of a hazard on a road segment. |
| Confidence | A value representing how certain the system is that a hazard report reflects actual conditions. |
| Status | The lifecycle state of a hazard (e.g., Reported, Uncertain, Confirmed, Verified — exact set TBD). |
| Road Impact | The effect of a hazard on a road segment's usability (e.g., passable, partially blocked, blocked). |
| Risk-Aware Routing | Route computation that factors hazard severity and confidence/uncertainty into segment cost, in addition to base travel cost. |
| Base Travel Cost | The conventional distance/time-based cost of traversing a road segment, independent of hazards. |
| Uncertainty Penalty | An added routing cost applied to a segment whose hazard status is unconfirmed or conflicting. |
| Community Reporter | A user (evacuee or other community member) who submits a hazard report. |
| Emergency Simulation | A controlled environment for triggering predefined hazard scenarios to demonstrate and validate system behavior. |
| AI Hazard Understanding | The layer that converts photo, text, or voice input into structured hazard data. |
| TBD | To Be Determined — not specified in the PRD; requires a decision during implementation. |

---

## 2. System Overview

QuakeRoute is structured around a single core information flow, driven by community observations and processed into routing decisions:

```
User Observation
       │
       ▼
Multimodal Reporting
(Photo / Text / Quick Tap / [Voice - limited])
       │
       ▼
AI Hazard Understanding
       │
       ▼
Structured Hazard
(Type + Location + Road Impact)
       │
       ▼
Risk Assessment
(Severity + Confidence → Routing Cost)
       │
       ▼
Risk-Aware Routing
       │
       ▼
Dynamic Recalculation
(triggered when new information changes known conditions)
```

The system deliberately separates responsibilities across this flow:

- **AI Hazard Understanding** interprets raw field input (photo/text/voice) and structures it into a hazard record with type, severity, confidence, and road impact. AI does not decide routes.
- **Risk Assessment** translates structured hazards into a routing cost, incorporating both severity and confidence/uncertainty.
- **Risk-Aware Routing** uses that cost to compute a route that may differ from the shortest/fastest path.
- **Dynamic Recalculation** re-evaluates the user's active route whenever new hazard information affects it.

The system is bounded to a controlled road network and a single post-earthquake scenario for the MVP, with an Emergency Simulation capability used to trigger and observe this flow end-to-end (Section 4.12).

---

## 3. User Roles

### 3.1 Evacuee
The primary user. Views the dynamic safety map, selects a shelter or medical facility as a destination, receives a risk-aware route, and follows route updates as conditions change. An Evacuee may also act as a Community Reporter by submitting hazard reports.

### 3.2 Community Reporter
Any user in the affected area — including Evacuees — who submits a hazard report via photo, text, quick tap, or (if implemented) voice. This is not a separate account type in the MVP; it describes the reporting behavior available to any user.

### 3.3 Volunteer / Coordinator
Referenced in the PRD as a secondary user category (volunteers, community rescue coordinators) whose need is visibility into how reports affect the shared safety map and other users' routes. The PRD explicitly states that broader coordinator/dashboard-style tooling is not a primary focus for the MVP. This SRS therefore does not define dedicated coordinator-only functional requirements; Volunteers/Coordinators use the same Evacuee/Community Reporter capabilities described above. Dedicated coordinator tooling is TBD and out of MVP scope unless revisited.

---

## 4. Functional Requirements

Priority key: **MUST** (MUST HAVE), **SHOULD** (SHOULD HAVE), **COULD** (COULD HAVE).

### 4.1 Dynamic Safety Map

#### FR-001 — Display User Location
**Priority:** MUST
**Description:** The system must display the user's current location on the road network.
**Actor:** Evacuee, Community Reporter.
**Preconditions:** The user has an active session within the controlled road network/simulation.
**Expected Behavior:** The map renders the user's current position on the road network.
**Acceptance Criteria:** Given the map is open, when the user's location is available, then the location is displayed on the road network view.

#### FR-002 — Display Destinations
**Priority:** MUST
**Description:** The system must display available shelter and medical facility destinations on the map.
**Actor:** Evacuee.
**Preconditions:** A set of destinations exists within the controlled road network.
**Expected Behavior:** All available shelters/medical facilities are shown on the map.
**Acceptance Criteria:** Given the map is open, when destinations exist in the network, then they are visible on the map.

#### FR-003 — Render Hazards with Severity and Confidence/Status
**Priority:** MUST
**Description:** The map must render known hazards with an indication of severity and confidence/status.
**Actor:** Evacuee, Community Reporter, Volunteer/Coordinator.
**Preconditions:** At least one hazard exists in the hazard dataset.
**Expected Behavior:** Each hazard is displayed with a visual indication of severity and confidence/status, distinguishing it from unaffected segments.
**Acceptance Criteria:** Given a hazard exists on a road segment, when the map is viewed, then that segment displays a visual indicator distinguishing it from unaffected segments.

#### FR-004 — Reflect Road Segment Condition Changes
**Priority:** MUST
**Description:** The map must visually reflect road segment condition changes when hazard data is updated.
**Actor:** Evacuee, Community Reporter, Volunteer/Coordinator.
**Preconditions:** A hazard's severity or status changes after initial reporting.
**Expected Behavior:** The map updates the affected segment's visual indicator to reflect the new condition.
**Acceptance Criteria:** Given a hazard's status or severity changes, when the map refreshes, then the visual indicator updates accordingly.

### 4.2 Destination Selection

#### FR-005 — Select Destination
**Priority:** MUST
**Description:** The user must be able to select a destination from the available shelters/medical facilities.
**Actor:** Evacuee.
**Preconditions:** Destinations are visible on the map (FR-002).
**Expected Behavior:** The user selects one destination from the available set.
**Acceptance Criteria:** Given available destinations, when the user selects one, then the selection is registered by the system.

#### FR-006 — Generate Initial Route
**Priority:** MUST
**Description:** Upon destination selection, the system must generate an initial route.
**Actor:** Evacuee.
**Preconditions:** A destination has been selected (FR-005).
**Expected Behavior:** The system computes and displays an initial risk-aware route to the selected destination.
**Acceptance Criteria:** Given a user selects a destination, when selection is confirmed, then an initial route is displayed within the prototype's expected response time (TBD).

#### FR-007 — Change Destination
**Priority:** MUST
**Description:** The user must be able to change destination and receive a newly generated route.
**Actor:** Evacuee.
**Preconditions:** An initial route already exists (FR-006).
**Expected Behavior:** Selecting a new destination triggers generation of a new route, replacing the previous one.
**Acceptance Criteria:** Given an active route exists, when the user selects a different destination, then a new route to that destination is generated and displayed.

### 4.3 Hazard Reporting (General)

#### FR-008 — Multiple Reporting Modes Available
**Priority:** MUST
**Description:** The system must provide at least photo, text, and quick-tap reporting options accessible from the main app flow.
**Actor:** Community Reporter.
**Preconditions:** The user has access to the main app flow.
**Expected Behavior:** The user can choose among photo, text, and quick-tap reporting from the main flow.
**Acceptance Criteria:** Given a user opens the reporting flow, when they choose any supported mode, then a hazard report can be produced and submitted.

#### FR-009 — Unified Structured Hazard Pipeline
**Priority:** MUST
**Description:** All reporting modes must feed into the same structured hazard pipeline.
**Actor:** System (internal).
**Preconditions:** A report has been submitted via any supported mode.
**Expected Behavior:** Regardless of input mode, the report is processed into the same structured hazard format (Section 4.7, 4.11 in this document; PRD Section 12).
**Acceptance Criteria:** Given a report submitted via any mode, when processed, then the resulting hazard record conforms to the common structured hazard format.

### 4.4 Photo / AI Vision Reporting

#### FR-010 — Capture or Upload Photo
**Priority:** MUST
**Description:** The system must allow the user to capture or upload a photo as a hazard report.
**Actor:** Community Reporter.
**Preconditions:** The user is in the reporting flow and has selected the photo mode.
**Expected Behavior:** The user can take or upload a photo and submit it as the basis of a hazard report.
**Acceptance Criteria:** Given the photo reporting mode is selected, when a photo is captured or uploaded, then it is accepted for processing.

#### FR-011 — AI Vision Proposes a Hazard
**Priority:** MUST (limited hazard set — see PRD Section 12)
**Description:** The system must run AI Vision analysis on the photo and propose a hazard type, severity, road impact, and confidence.
**Actor:** System (internal, via AI Hazard Understanding).
**Preconditions:** A photo has been submitted (FR-010).
**Expected Behavior:** AI Vision analyzes the photo and returns a proposed hazard with type, severity, road impact, and confidence.
**Acceptance Criteria:** Given a photo depicting one of the MVP's supported visual hazard types, when analyzed by AI Vision, then the system proposes a hazard with type, severity, road impact, and a confidence value.

#### FR-012 — Present Suggestion for Confirmation
**Priority:** MUST
**Description:** The system must present the AI-suggested hazard to the user for confirmation before it is treated as an active hazard.
**Actor:** Community Reporter.
**Preconditions:** AI Vision has produced a proposed hazard (FR-011).
**Expected Behavior:** The proposed hazard is shown to the user with its type, severity, road impact, and confidence, pending user action.
**Acceptance Criteria:** Given a proposed hazard exists, when the user views the reporting flow, then the proposal is displayed prior to being added to the active hazard dataset.

#### FR-013 — Confirm, Reject, or Edit Suggestion
**Priority:** MUST
**Description:** The user must be able to confirm, reject, or edit the AI-suggested hazard.
**Actor:** Community Reporter.
**Preconditions:** A proposed hazard has been presented (FR-012).
**Expected Behavior:** The user's confirmation, rejection, or edit determines whether/how the hazard is finalized.
**Acceptance Criteria:** Given a proposed hazard is presented, when the user confirms, rejects, or edits it, then the system applies the corresponding action (add, discard, or modify-then-add).

#### FR-014 — Confirmed Hazard Becomes Structured Data
**Priority:** MUST
**Description:** Confirmed hazards must be attached to a location and become part of the structured hazard dataset.
**Actor:** System (internal).
**Preconditions:** The user has confirmed a proposed hazard (FR-013).
**Expected Behavior:** The confirmed hazard is stored with its location and becomes usable by the safety map and risk model.
**Acceptance Criteria:** Given the user confirms the suggested hazard, when confirmation is submitted, then the hazard is added to the safety map and risk model.

### 4.5 Text Reporting

#### FR-015 — Accept Free-Text Reports
**Priority:** MUST
**Description:** The system must accept free-text hazard descriptions from the user.
**Actor:** Community Reporter.
**Preconditions:** The user has selected text reporting mode.
**Expected Behavior:** The user can enter a free-text description and submit it.
**Acceptance Criteria:** Given the text reporting mode is selected, when text is entered and submitted, then it is accepted for processing.

#### FR-016 — Extract One or More Hazards from Text
**Priority:** MUST
**Description:** The AI extraction step must be able to identify one or more hazards from a single text report.
**Actor:** System (internal, via AI Hazard Understanding).
**Preconditions:** A free-text report has been submitted (FR-015).
**Expected Behavior:** The AI extraction step parses the text and identifies one or more distinct hazards, if present.
**Acceptance Criteria:** Given a text report describing at least one hazard, when processed by AI, then at least one structured hazard is produced with type, severity, road impact, and confidence.

#### FR-017 — Extracted Hazards Are Fully Structured
**Priority:** MUST
**Description:** Extracted hazards must include type, severity (estimated), road impact, and confidence before being added to the hazard dataset.
**Actor:** System (internal).
**Preconditions:** Hazard(s) have been extracted from text (FR-016).
**Expected Behavior:** Each extracted hazard is completed with all required structured fields before being added to the hazard dataset.
**Acceptance Criteria:** Given an extracted hazard, when it is added to the hazard dataset, then it includes type, severity, road impact, and confidence.

### 4.6 Quick Hazard Reporting

#### FR-018 — Predefined Hazard Category List
**Priority:** MUST
**Description:** The system must present a predefined, limited list of hazard categories for quick reporting.
**Actor:** Community Reporter.
**Preconditions:** The user has selected quick reporting mode.
**Expected Behavior:** A limited list of hazard categories (e.g., blocked road, debris, fire, electrical hazard, flood, building damage) is presented.
**Acceptance Criteria:** Given quick reporting mode is selected, when the list is displayed, then it shows the predefined hazard categories.

#### FR-019 — Submit Quick Report
**Priority:** MUST
**Description:** The user must be able to submit a quick report by selecting a category and confirming/adjusting location.
**Actor:** Community Reporter.
**Preconditions:** The category list is displayed (FR-018).
**Expected Behavior:** The user selects a category, confirms or adjusts location, and submits the report.
**Acceptance Criteria:** Given a user selects a hazard category and confirms location, when submitted, then a structured hazard is created and added to the hazard dataset.

#### FR-020 — Quick Reports Use Common Structured Format
**Priority:** MUST
**Description:** Quick reports must be converted into the same structured hazard format used by other reporting modes, with a default confidence appropriate to a self-reported (non-AI-processed) category selection (exact default value TBD).
**Actor:** System (internal).
**Preconditions:** A quick report has been submitted (FR-019).
**Expected Behavior:** The system assigns a default confidence value to the quick report and stores it in the common structured hazard format.
**Acceptance Criteria:** Given a submitted quick report, when stored, then it conforms to the structured hazard format and carries a defined default confidence value (value TBD).

### 4.7 AI Hazard Understanding

#### FR-021 — Process Photo via AI Vision
**Priority:** MUST
**Description:** The system must process photo input through AI Vision to propose a hazard.
**Actor:** System (internal).
**Preconditions:** A photo has been submitted.
**Expected Behavior:** AI Vision runs on the photo and produces a proposed hazard.
**Acceptance Criteria:** Given a submitted photo, when processed, then a proposed hazard is produced (see FR-011).

#### FR-022 — Process Text via AI Extraction
**Priority:** MUST
**Description:** The system must process text input through AI extraction to propose one or more hazards.
**Actor:** System (internal).
**Preconditions:** Free text has been submitted.
**Expected Behavior:** AI extraction runs on the text and produces one or more proposed hazards.
**Acceptance Criteria:** Given submitted text, when processed, then one or more proposed hazards are produced (see FR-016).

#### FR-023 — Process Voice via Text-Extraction Path (if implemented)
**Priority:** SHOULD (contingent on voice reporting being implemented; see Section 9 constraint on voice as SHOULD HAVE / limited)
**Description:** If voice reporting is implemented, transcribed voice input must be processed through the same text-extraction path used for text reports.
**Actor:** System (internal).
**Preconditions:** Voice reporting has been implemented; a voice report has been transcribed.
**Expected Behavior:** The transcript is passed into the same AI extraction path as free-text input.
**Acceptance Criteria:** Given voice reporting is implemented and a voice report is transcribed, when processed, then the transcript is handled by the same extraction path as text reports.

#### FR-024 — Minimum Required AI Output Fields
**Priority:** MUST
**Description:** AI output must include, at minimum, hazard type, severity estimate, road impact, and confidence.
**Actor:** System (internal).
**Preconditions:** AI has processed a photo, text, or voice-transcript input.
**Expected Behavior:** The AI output object contains type, severity, road impact, and confidence at minimum.
**Acceptance Criteria:** Given any AI-processed input, when output is produced, then it includes type, severity, road impact, and confidence.

#### FR-025 — AI Output Treated as Prediction, Not Fact
**Priority:** MUST
**Description:** AI output must be treated as an observation/prediction with associated uncertainty, not as verified fact, prior to any confirmation/verification step.
**Actor:** System (internal).
**Preconditions:** AI has produced hazard output.
**Expected Behavior:** The hazard is not marked as confirmed/verified status until an applicable confirmation step (e.g., user confirmation for photo reports) occurs.
**Acceptance Criteria:** Given AI-produced hazard output, when added to the dataset, then its status reflects an unconfirmed/predicted state until confirmation occurs.

### 4.8 Hazard Status & Confidence

#### FR-026 — Confidence Value on Every Hazard
**Priority:** MUST
**Description:** Every hazard must have an associated confidence value.
**Actor:** System (internal).
**Preconditions:** A hazard has been created via any reporting mode.
**Expected Behavior:** Every hazard record includes a confidence value.
**Acceptance Criteria:** Given any hazard in the dataset, when inspected, then it has a confidence value.

#### FR-027 — Status Field on Every Hazard
**Priority:** MUST
**Description:** Every hazard must have an associated status field.
**Actor:** System (internal).
**Preconditions:** A hazard has been created via any reporting mode.
**Expected Behavior:** Every hazard record includes a status field (e.g., Reported, Uncertain, Confirmed, Verified — exact status set TBD, but must at minimum distinguish "reported/unconfirmed" from "confirmed").
**Acceptance Criteria:** Given any hazard in the dataset, when inspected, then it has a status field distinguishing at least "reported/unconfirmed" from "confirmed."

#### FR-028 — Status Transitions on New Information
**Priority:** MUST
**Description:** The system must support status transitions as new information arrives (e.g., additional matching reports increasing confidence).
**Actor:** System (internal).
**Preconditions:** A hazard already exists; new related information (e.g., another report) arrives.
**Expected Behavior:** The hazard's status and/or confidence updates in response to new matching or conflicting information.
**Acceptance Criteria:** Given an existing hazard, when new related information is received, then the hazard's status/confidence may change accordingly.

#### FR-029 — Confidence/Status Visible to User
**Priority:** MUST
**Description:** Confidence and status must be visible to the user on the safety map, at least at a summary level.
**Actor:** Evacuee, Community Reporter, Volunteer/Coordinator.
**Preconditions:** At least one hazard exists on the map.
**Expected Behavior:** The map exposes confidence/status via a visible indicator (icon, label, or color).
**Acceptance Criteria:** Given a hazard is created, when viewed on the map, then its confidence/status is visible in some form (e.g., icon, label, or color).

### 4.9 Risk-Aware Routing

#### FR-030 — Incorporate Severity into Segment Cost
**Priority:** MUST
**Description:** The routing engine must incorporate hazard severity into segment cost.
**Actor:** System (internal, routing engine).
**Preconditions:** At least one hazard with a severity value exists on a segment.
**Expected Behavior:** Segment cost calculation includes a penalty component derived from hazard severity.
**Acceptance Criteria:** Given a segment with a hazard of known severity, when routing cost is computed, then the severity contributes to that segment's cost.

#### FR-031 — Incorporate Confidence/Uncertainty into Segment Cost
**Priority:** MUST
**Description:** The routing engine must incorporate hazard confidence/uncertainty into segment cost.
**Actor:** System (internal, routing engine).
**Preconditions:** At least one hazard with a confidence value exists on a segment.
**Expected Behavior:** Segment cost calculation includes an uncertainty penalty component derived from hazard confidence.
**Acceptance Criteria:** Given a segment with a hazard of known confidence, when routing cost is computed, then confidence/uncertainty contributes to that segment's cost.

#### FR-032 — Blocked Segments Treated as Unusable
**Priority:** MUST
**Description:** The routing engine must treat fully blocked segments as unusable (or effectively infinite cost).
**Actor:** System (internal, routing engine).
**Preconditions:** A segment has road impact status "blocked."
**Expected Behavior:** Blocked segments are excluded from route candidates.
**Acceptance Criteria:** Given a segment on the shortest path has a hazard fully blocking it, when a lower-risk alternative exists, then the system proposes the alternative instead of the shortest path (see PRD Validation Scenario 2).

#### FR-033 — Non-Shortest Route Selection When Lower Risk
**Priority:** MUST
**Description:** The routing engine must be able to select a route that is not the shortest path when it has a lower risk-adjusted cost.
**Actor:** System (internal, routing engine).
**Preconditions:** A risk-adjusted alternative route with lower total cost than the shortest path exists.
**Expected Behavior:** The routing engine selects the lower risk-adjusted-cost route, even if longer in distance/time.
**Acceptance Criteria:** Given no hazards exist on the network, when a route is requested, then the risk-aware route matches (or closely matches) the conventional shortest route (PRD Validation Scenario 1). Given hazards exist on the shortest path, when a lower risk-adjusted alternative exists, then that alternative is selected.

#### FR-034 — Routing Algorithm Is an Implementation Detail
**Priority:** MUST
**Description:** The specific routing algorithm is an implementation detail and is not fixed by this SRS or the PRD.
**Actor:** N/A (documentation/design constraint).
**Preconditions:** N/A.
**Expected Behavior:** Implementation may choose any routing algorithm capable of satisfying FR-030 through FR-033.
**Acceptance Criteria:** The chosen algorithm is documented separately in technical design documentation (TBD) and is not constrained by this SRS beyond FR-030–FR-033.

### 4.10 Dynamic Route Recalculation

#### FR-035 — Detect Hazard Impact on Active Route
**Priority:** MUST
**Description:** The system must detect when a newly reported hazard affects a road segment on a user's active route.
**Actor:** System (internal).
**Preconditions:** A user has an active route; a new hazard is reported and processed.
**Expected Behavior:** The system checks whether the new hazard's segment(s) intersect the user's active route.
**Acceptance Criteria:** Given a user is navigating a route, when a new hazard is reported on a segment of that route, then the system detects the impact.

#### FR-036 — Recalculate When Active Route Is Affected
**Priority:** MUST
**Description:** The system must recalculate the route when an active route is affected by a new hazard.
**Actor:** System (internal).
**Preconditions:** Impact on the active route has been detected (FR-035).
**Expected Behavior:** The routing engine recomputes a route from the user's current position to their destination, incorporating the updated hazard data.
**Acceptance Criteria:** Given a user is navigating a route, when a new hazard is reported on a segment of that route, then the system recalculates and offers an alternative route (PRD Validation Scenario 4).

#### FR-037 — Present Updated Route Distinguishably
**Priority:** MUST
**Description:** The system must present the updated route to the user in a way that is distinguishable from the initial route.
**Actor:** Evacuee.
**Preconditions:** A recalculated route has been produced (FR-036).
**Expected Behavior:** The updated route is visually or otherwise distinguished from the prior route when shown to the user.
**Acceptance Criteria:** Given a recalculated route, when displayed, then the user can distinguish it from the previously active route.

### 4.11 Uncertain / Conflicting Reports

#### FR-038 — Detect Material Disagreement Between Reports
**Priority:** MUST
**Description:** The system must detect when two or more reports about the same segment materially disagree.
**Actor:** System (internal).
**Preconditions:** Two or more reports exist for the same road segment.
**Expected Behavior:** The system compares reports for the same segment and flags material disagreement (e.g., one report indicates "blocked," another indicates "passable").
**Acceptance Criteria:** Given two conflicting reports for the same segment, when both are processed, then the system identifies them as materially disagreeing.

#### FR-039 — Mark Segment as Uncertain/Conflicting
**Priority:** MUST
**Description:** A segment with conflicting reports must be marked with an uncertain/conflicting status rather than automatically fully blocked or fully cleared.
**Actor:** System (internal).
**Preconditions:** Material disagreement has been detected (FR-038).
**Expected Behavior:** The segment's status is set to an uncertain/conflicting state.
**Acceptance Criteria:** Given two conflicting reports for the same segment, when both are processed, then the segment status becomes "uncertain/conflicting" (PRD Validation Scenario 5).

#### FR-040 — Apply Uncertainty Penalty
**Priority:** MUST
**Description:** An uncertainty penalty must be applied to the segment's routing cost while its status remains uncertain/conflicting.
**Actor:** System (internal, routing engine).
**Preconditions:** A segment has an uncertain/conflicting status (FR-039).
**Expected Behavior:** The segment's routing cost includes an uncertainty penalty while the conflicting status persists.
**Acceptance Criteria:** Given a segment marked "uncertain/conflicting," when routing cost is computed, then it includes an uncertainty penalty (PRD Validation Scenario 5).

### 4.12 Emergency Simulation

#### FR-041 — Trigger Predefined Hazard Events
**Priority:** MUST
**Description:** The system must support triggering predefined hazard events within a simulated post-earthquake scenario.
**Actor:** Volunteer/Coordinator (or hackathon operator/evaluator).
**Preconditions:** The simulation environment is available.
**Expected Behavior:** An operator can trigger a predefined scenario/event within the controlled road network.
**Acceptance Criteria:** Given a predefined scenario, when triggered, then the corresponding hazard event(s) occur within the simulation.

#### FR-042 — Reproducible Simulation
**Priority:** MUST
**Description:** The simulation must be reproducible — running the same scenario should produce comparable outcomes.
**Actor:** System (internal).
**Preconditions:** A scenario has been defined.
**Expected Behavior:** Repeated runs of the same scenario yield comparable hazard, risk, and routing outcomes.
**Acceptance Criteria:** Given the same scenario is run multiple times, when outcomes are compared, then they are comparable (not contradictory).

#### FR-043 — Support the Six Defined Scenarios
**Priority:** MUST
**Description:** The simulation must support at least the six scenarios defined in the PRD (No Hazard; Blocked Road; High-Risk Hazard; New Hazard During Navigation; Conflicting Reports; AI Vision Hazard Report).
**Actor:** Volunteer/Coordinator (or hackathon operator/evaluator).
**Preconditions:** The simulation environment and controlled road network exist.
**Expected Behavior:** Each of the six scenarios can be triggered and observed end-to-end.
**Acceptance Criteria:** Given a predefined scenario is triggered, when it runs, then the expected sequence of state changes (hazard creation, risk update, recalculation) occurs and is observable.

#### FR-044 — Compare Baseline vs. Risk-Aware Output
**Priority:** MUST
**Description:** The simulation must allow comparison between conventional shortest-route output and QuakeRoute's risk-aware output for the same scenario.
**Actor:** Volunteer/Coordinator (or hackathon operator/evaluator).
**Preconditions:** A scenario has been run (FR-043).
**Expected Behavior:** Both the baseline (shortest/fastest) route and the risk-aware route are available for the same scenario for comparison.
**Acceptance Criteria:** Given a completed scenario run, when results are reviewed, then both the baseline route and the risk-aware route are available for comparison.

---

## 5. Non-Functional Requirements

#### NFR-001 — Response Time (Performance)
**Category:** Performance
**Description:** The system should generate an initial route and process hazard reports within a response time acceptable for a live demonstration. The PRD does not specify a numeric target.
**Target:** TBD.

#### NFR-002 — Simulation Reproducibility (Reliability)
**Category:** Reliability
**Description:** The Emergency Simulation must behave reproducibly across runs of the same scenario, as required by FR-042, so that results are trustworthy for demonstration and validation.
**Target:** Comparable outcomes across repeated runs of the same scenario (qualitative; no numeric target specified in the PRD).

#### NFR-003 — Low-Effort Reporting (Usability)
**Category:** Usability
**Description:** Hazard reporting flows (photo, quick tap, text) must be usable with minimal effort, consistent with the PRD's guiding principle to "minimize the effort required to contribute safety information." Quick tap is the lowest-effort mode and must not require typing.
**Target:** Qualitative; no numeric usability target specified in the PRD.

#### NFR-004 — Uncertainty Communication (Explainability)
**Category:** Explainability
**Description:** The system must communicate hazard confidence and status to users in a way that distinguishes certainty levels, rather than presenting all hazards or routes with equal certainty (PRD Section 17).
**Target:** At minimum, a visible confidence/status indicator per hazard (see FR-029).

#### NFR-005 — Non-Absolute Risk Communication (Safety)
**Category:** Safety
**Description:** The system must not present AI output as absolute truth or any route as a safety guarantee. Users should be able to understand that QuakeRoute is a decision-support tool, not an emergency response system (PRD Section 17).
**Target:** Qualitative; enforced via UI/UX and status/confidence indicators rather than a numeric target.

#### NFR-006 — Privacy
**Category:** Privacy
**Description:** The PRD does not specify privacy requirements (e.g., handling of user location data, report attribution, or photo storage/retention).
**Target:** TBD.

#### NFR-007 — Availability
**Category:** Availability
**Description:** The PRD does not specify an availability target. QuakeRoute is a hackathon prototype/demonstration system, not a production emergency system (PRD Section 6, Non-Goals).
**Target:** TBD; production-grade availability is explicitly out of scope (see Section 11).

#### NFR-008 — Maintainability / Extensibility
**Category:** Maintainability
**Description:** The system should preserve the core Hazard → Risk Model → Routing abstraction so that future extensions (e.g., additional hazard types or disaster types, per PRD Section 19) do not require rebuilding the routing engine — only extending the hazard input and risk modeling layers.
**Target:** Architectural separation between AI/hazard-input, risk modeling, and routing (see Section 2), maintained through implementation.

---

## 6. AI Requirements

AI in QuakeRoute is scoped strictly as a **multimodal hazard understanding layer**. This section is provider-agnostic; no specific AI model or vendor is prescribed by this SRS (see Section 7).

**AI is responsible for:**
- Understanding photo input (AI Vision) to identify possible hazards (FR-011, FR-021).
- Understanding text input to extract one or more hazards (FR-016, FR-022).
- Processing voice transcripts through the same text-extraction path, if voice reporting is implemented (FR-023).
- Estimating hazard severity.
- Determining road impact.
- Producing a confidence value for each identified hazard.
- Structuring the report into the system's common hazard data format (FR-024).

**AI is explicitly not responsible for:**
- Determining routes directly — routing decisions are made by the routing engine based on structured hazard cost inputs, not by AI (Section 2).
- Guaranteeing that any road is safe.
- Replacing emergency responders or official authorities.
- Automatically converting its own prediction into verified fact — AI output remains an observation/prediction with associated confidence until a confirmation/verification step occurs (FR-025).

---

## 7. External Dependencies

QuakeRoute's requirements are defined independently of any specific external provider. The following categories of external dependency are anticipated, at an implementation-detail level:

- **AI inference service:** Required to perform AI Vision (photo) and AI extraction (text/voice-transcript) processing described in Section 6. The specific provider or model is TBD and is not fixed by this SRS.
- **Mapping / routing service or engine:** Required to represent the controlled road network and compute base travel cost and risk-adjusted routes (Section 4.9). The specific provider, library, or algorithm is TBD and is not fixed by this SRS (see FR-034).
- **Speech-to-text service (conditional):** Required only if voice reporting is implemented (SHOULD HAVE / limited scope). Provider TBD.

These dependencies are treated strictly as external, replaceable implementation details. No functional requirement in Section 4 assumes a specific provider.

---

## 8. System Constraints & Safety Requirements

- AI output is not absolute truth; it is treated as an observation/prediction with an associated confidence value (FR-025).
- No route produced by QuakeRoute is guaranteed to be safe; QuakeRoute is a decision-support tool, not a safety guarantee or emergency response system.
- Hazard information can become stale as conditions continue to change; every hazard carries a timestamp for this reason (see hazard attributes, Section 4).
- Users should follow official authority and emergency responder instructions when available, in preference to app guidance.
- Community reports can be inaccurate, incomplete, or conflicting; the system must not treat any single unverified report as absolute truth (Section 4.11).
- The MVP is scoped to a single controlled post-earthquake scenario; other disaster types are out of scope for the MVP (see Section 11).
- The system must not automatically treat AI-detected or user-reported hazards as verified fact without an applicable confirmation/verification step.

---

## 9. MVP Scope

| Requirement / Feature | Priority | MVP Status | Notes |
|---|---|---|---|
| Post-earthquake controlled scenario | MUST | In MVP | Core context for all other features; keeps scope to one disaster domain. |
| Controlled road network | MUST | In MVP | Required substrate for routing and simulation. |
| Dynamic Safety Map (FR-001–FR-004) | MUST | In MVP | Primary interface for user situational awareness. |
| Destination Selection (FR-005–FR-007) | MUST | In MVP | Required to generate any route. |
| Hazard Reporting, general (FR-008–FR-009) | MUST | In MVP | Core input mechanism for hazard data. |
| Photo-Based Reporting / AI Vision (FR-010–FR-014) | MUST | In MVP (limited hazard set) | Central low-friction reporting mode and AI showcase. |
| Text Reporting (FR-015–FR-017) | MUST | In MVP | Needed for users who can provide more detail. |
| Quick Hazard Reporting (FR-018–FR-020) | MUST | In MVP | Lowest-effort reporting mode. |
| AI Hazard Understanding (FR-021–FR-025) | MUST | In MVP | Converts raw input into structured hazard data. |
| Hazard Status & Confidence (FR-026–FR-029) | MUST | In MVP | Required for risk-aware cost calculation and uncertainty communication. |
| Risk-Aware Routing (FR-030–FR-034) | MUST | In MVP | Core differentiator of the product. |
| Dynamic Route Recalculation (FR-035–FR-037) | MUST | In MVP | Demonstrates adaptive behavior, key to the discovery question. |
| Uncertain / Conflicting Reports (FR-038–FR-040) | MUST | In MVP | Core to the uncertainty-aware positioning of the product. |
| Emergency Simulation, 6 scenarios (FR-041–FR-044) | MUST | In MVP | Required for demonstration and validation. |
| Baseline comparison (shortest vs. risk-aware) (FR-044) | MUST | In MVP | Required for success criteria. |
| Voice Reporting (FR-023) | SHOULD | Limited / Optional | Only if core system is stable; not required for MVP completeness. |
| Additional hazard categories | COULD | Limited / Optional | Nice-to-have if time allows after core hazards are covered. |
| Advanced verification logic | COULD | Limited / Optional | Basic confidence/status handling suffices for MVP. |
| Real emergency deployment | OUT OF SCOPE | Not in MVP | Requires production-grade reliability, legal, and operational readiness. |
| Direct responder integration | OUT OF SCOPE | Not in MVP | Requires external systems/partnerships beyond hackathon scope. |
| Comprehensive real-world disaster data | OUT OF SCOPE | Not in MVP | Prototype uses controlled/simulated data only. |
| Full AI Vision coverage of all damage types | OUT OF SCOPE | Not in MVP | Limited hazard set is sufficient to validate the concept. |
| Multi-disaster support | OUT OF SCOPE | Not in MVP | Earthquake-only scope keeps depth achievable in 10 days. |
| Production-scale infrastructure | OUT OF SCOPE | Not in MVP | Not required to validate the product hypothesis. |

---

## 10. Requirement Traceability

| Product Goal (PRD Section 5) | Requirement IDs |
|---|---|
| Help users find a route with lower risk than the conventional shortest/fastest route | FR-030, FR-031, FR-032, FR-033, FR-044 |
| Allow users to report hazards with minimal effort (photo, quick tap, text, optionally voice) | FR-008, FR-009, FR-010, FR-018, FR-019, FR-023 |
| Convert unstructured hazard observations into structured hazard information | FR-011, FR-016, FR-017, FR-020, FR-021, FR-022, FR-024 |
| Enable route recalculation when road conditions change during navigation | FR-035, FR-036, FR-037 |
| Provide a controlled emergency simulation environment for testing, validation, and demonstration | FR-041, FR-042, FR-043, FR-044 |
| Give users visibility into current hazard conditions (situational awareness) | FR-001, FR-002, FR-003, FR-004, FR-029 |
| Represent hazard confidence explicitly, including conflicting reports | FR-026, FR-027, FR-028, FR-038, FR-039, FR-040 |

---

## 11. Out of Scope

The following are explicitly out of scope for the QuakeRoute MVP, per the PRD:

- Replacing emergency responders, medical personnel, or official authorities.
- Guaranteeing that any recommended route is safe.
- Serving as a comprehensive disaster management platform.
- Providing production-scale emergency infrastructure.
- Deployment for real-world emergency use.
- Disaster types other than earthquake.
- Automatically treating AI-detected or user-reported hazards as verified fact.
- Real emergency deployment.
- Direct integration with responder systems.
- Comprehensive real-world disaster data (the prototype uses controlled/simulated data only).
- Full AI Vision coverage of all possible damage types (the MVP uses a limited, predefined hazard set: Debris/Rubble, Road Blockage, Fire, Flood, Electrical Hazard, Visible Building Damage).
- Multi-disaster support.
- Dedicated Volunteer/Coordinator dashboard tooling beyond shared Evacuee/Community Reporter capabilities (not a primary focus per PRD Section 4).

---

**Document status:** Draft SRS derived from the QuakeRoute PRD for a 10-day hackathon prototype. Items marked TBD require decisions during implementation and do not block SRS approval.
