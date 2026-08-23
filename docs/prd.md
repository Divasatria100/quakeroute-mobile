# QuakeRoute — Product Requirements Document

## 1. Product Overview

- **Product Name:** QuakeRoute
- **Product Description:** QuakeRoute is a post-earthquake, risk-aware navigation prototype. It converts low-friction, multimodal hazard reports (photo, text, quick tap, and optionally voice) from users and the community into structured hazard data, then uses that data to compute routes based on risk rather than distance or travel time alone.
- **One-sentence Value Proposition:** QuakeRoute helps people evacuating after an earthquake reach shelters or medical facilities via a lower-risk feasible route, by turning uncertain, unstructured field observations into structured, risk-aware routing decisions.
- **Product Vision:** To explore how low-friction multimodal reporting and AI can transform uncertain post-earthquake observations into risk-aware navigation decisions that adapt as the environment changes.
- **Product Goal:** Within a 10-day hackathon, build and validate a working prototype demonstrating that risk-aware, uncertainty-aware routing — driven by AI-processed community hazard reports — can produce safer route decisions than conventional shortest-path routing, for a single controlled post-earthquake scenario.

---

## 2. Problem Statement

After an earthquake, road conditions can change quickly. A road that was previously safe may become dangerous or impassable due to debris, collapsed buildings, fire, flooding, fallen electrical cables, or blockages.

Conventional navigation systems are built to answer "how do I get there fastest?" — they optimize for shortest distance or travel time, not for the safety of the route under changing post-disaster conditions.

Hazard information after a disaster typically comes from the community — from people who are themselves in the affected area. In an emergency, these people may not have the time, ability, or composure to type a detailed report. For example, someone may observe:

> "The road ahead is blocked by debris and there's a fallen power line."

Under normal conditions this is easy to write. During evacuation or panic, however, taking a photo or making a quick tap-based report can be far easier than typing a detailed description.

In addition, community-provided information is not always accurate or consistent. Two different users may report conflicting conditions for the same road segment — one saying it is blocked, another saying it is still passable.

**Core problem statement:** How can a navigation system help users choose safer routes when road conditions change dynamically, hazard information is incomplete and uncertain, and users need to be able to report field conditions with minimal effort during an emergency?

---

## 3. Problem Context

The problem above arises from a combination of the following conditions:

- **Dynamic environment** — road conditions continue to change after the earthquake as new hazards emerge or existing ones evolve.
- **Incomplete information** — not every hazard on the road network is known or reported at any given time.
- **Uncertain information** — reports vary in reliability; not every report can be treated as confirmed fact.
- **Community-generated reports** — hazard information mainly originates from ordinary people in the field, not verified authorities, which affects how much the system can trust any single report.
- **Emergency user constraints** — users reporting hazards may be under stress, time pressure, or physically limited, reducing their ability to provide detailed input.
- **Shortest route ≠ safest feasible route** — the fastest path to a destination may pass through hazardous or uncertain road segments, while a slightly longer path may be meaningfully safer.

---

## 4. Target Users

### Primary Users
- Evacuees.
- People traveling to shelters.
- People traveling to medical facilities.

**Primary need:** quickly obtain a lower-risk feasible route to a destination (shelter or medical facility) without having to manually assess road/hazard conditions themselves.

### Secondary Users
- Volunteers.
- Community rescue coordinators.
- Community members reporting hazards they observe.

**Secondary need:** an easy, low-effort way to report observed hazards, and visibility into how those reports affect the shared safety map and other users' routes.

For the hackathon prototype, the system is focused primarily on **individual evacuation navigation** and **community hazard reporting**; broader coordinator/dashboard-style tooling is not a primary focus (see Section 6 and Section 18).

---

## 5. Product Goals

- Help users find a route with lower risk than the conventional shortest/fastest route, given currently known hazards.
- Allow users to report hazards with minimal effort (photo, quick tap, text, and optionally voice).
- Convert unstructured hazard observations (photo, text, voice) into structured hazard information (type, severity, confidence, road impact).
- Enable route recalculation when road conditions change during navigation.
- Provide a controlled emergency simulation environment for testing, validation, and demonstration of the above behaviors.

---

## 6. Non-Goals

QuakeRoute, as an MVP, explicitly does **not** attempt to:

- Replace emergency responders, medical personnel, or official authorities.
- Guarantee that any recommended route is safe.
- Serve as a comprehensive disaster management platform.
- Provide production-scale emergency infrastructure.
- Be deployed for real-world emergency use.
- Cover disaster types other than earthquake in the MVP.
- Automatically treat AI-detected or user-reported hazards as verified fact.

---

## 7. Core Product Concept

QuakeRoute's core information flow:

```
User Observation
       │
       ▼
Low-Friction Reporting
(Photo / Quick Tap / Text / [Voice - limited])
       │
       ▼
AI Hazard Understanding
       │
       ▼
Structured Hazard
(Type + Location + Road Impact)
       │
       ▼
Severity + Confidence
       │
       ▼
Risk Assessment
       │
       ▼
Risk-Aware Routing
       │
       ▼
Dynamic Recalculation
(when new information changes known conditions)
```

QuakeRoute deliberately separates responsibilities:

- **AI** understands and structures field observations.
- **Risk model** translates structured hazards (severity + confidence) into a routing cost.
- **Routing engine** uses that cost to compute a route.

AI does not decide routes directly; it produces the structured, uncertainty-aware input that the routing engine consumes.

---

## 8. Core User Journey

**Happy path:**

1. User opens QuakeRoute.
2. User views the dynamic safety map (current location, road network, known hazards, shelters/medical facilities).
3. User selects a shelter or medical facility as destination.
4. System generates an initial risk-aware route.
5. User or another community member reports a hazard (photo / text / quick report / optionally voice).
6. The report is processed by AI into a structured hazard (type, severity, confidence, road impact).
7. The hazard is added to the dynamic safety map.
8. The risk model is updated for the affected road segment(s).
9. If the current route is affected, the system recalculates and proposes an alternative route.
10. User receives and follows the updated route toward their destination.

**Important alternative paths:**

- **No new hazards during navigation:** the user follows the original route without recalculation (Validation Scenario 1).
- **Conflicting reports for the same segment:** the system does not immediately treat either report as absolute truth; the segment is marked with an uncertain status and an uncertainty penalty is applied instead of an outright block (see Section 14).
- **Hazard reported on a segment not on the user's current route:** the safety map and risk model update, but no recalculation is triggered for that user unless their route is affected.
- **User reports via photo but the AI's suggested hazard is inaccurate:** the user reviews the AI-suggested hazard before confirming; confirmation step exists precisely to catch this case.

---

## 9. Feature Requirements

Priority key: **MUST HAVE**, **SHOULD HAVE**, **COULD HAVE**, **OUT OF SCOPE**.

### 9.1 Dynamic Safety Map

**Priority:** MUST HAVE

**Purpose**
Give the user a single view of their location, destinations, the road network, and currently known hazard conditions.

**User Story**
As an evacuee, I want to see a map that shows current hazard conditions along with shelters and medical facilities, so that I can understand the situation before choosing where to go.

**Description**
The map displays user location, shelter/medical facility locations, the (controlled) road network, known hazards with severity, and hazard confidence/status. Road segment appearance reflects current condition (e.g., normal, hazardous, blocked) and updates as new reports come in.

**Functional Requirements**
- FR-01: The map must display the user's current location on the road network.
- FR-02: The map must display available shelter and medical facility destinations.
- FR-03: The map must render known hazards with an indication of severity and confidence/status.
- FR-04: The map must visually reflect road segment condition changes when hazard data is updated.

**Acceptance Criteria**
- Given a hazard exists on a road segment, when the map is viewed, then that segment displays a visual indicator distinguishing it from unaffected segments.
- Given a hazard's status or severity changes, when the map refreshes, then the visual indicator updates accordingly.

---

### 9.2 Destination Selection

**Priority:** MUST HAVE

**Purpose**
Let the user choose where they need to go.

**User Story**
As an evacuee, I want to select a shelter or medical facility as my destination, so that the system can generate a route for me.

**Description**
User selects from a defined, controlled set of shelter/medical destinations within the simulated road network.

**Functional Requirements**
- FR-05: The user must be able to select a destination from the available shelters/medical facilities.
- FR-06: Upon destination selection, the system must generate an initial route.
- FR-07: The user must be able to change destination and receive a newly generated route.

**Acceptance Criteria**
- Given a user selects a destination, when selection is confirmed, then an initial route is displayed within the prototype's expected response time (TBD).

---

### 9.3 Multimodal Hazard Reporting

**Priority:** MUST HAVE (photo, text, quick report) / Voice is SHOULD HAVE / LIMITED (see Section 10)

**Purpose**
Allow users and community members to report observed hazards using whichever input method requires the least effort in their situation.

**User Story**
As a person in the affected area, I want to report a hazard using a photo, quick tap, or short text, so that I don't have to spend time typing a detailed description during an emergency.

**Description**
QuakeRoute supports multiple reporting modes feeding into the same AI Hazard Understanding pipeline: photo, text, quick category tap, and — as a limited/optional feature — voice.

**Functional Requirements**
- FR-08: The system must provide at least photo, text, and quick-tap reporting options accessible from the main app flow.
- FR-09: All reporting modes must feed into the same structured hazard pipeline (Section 11).

**Acceptance Criteria**
- Given a user opens the reporting flow, when they choose any supported mode, then a hazard report can be produced and submitted.

---

### 9.4 Photo-Based Hazard Reporting / AI Vision

**Priority:** MUST HAVE (limited hazard set)

**Purpose**
Let users report a hazard by simply taking a photo, minimizing typing effort.

**User Story**
As an evacuee, I want to take a photo of a hazard I see, so that the system can understand it without me needing to describe it in words.

**Description**
User captures a photo → AI Vision analyzes it → system proposes a possible hazard (type, severity, road impact, confidence) → user reviews and confirms → hazard becomes structured data usable by routing.

For the MVP, AI Vision is limited to a small set of visually identifiable hazards (see Section 12): debris/rubble, road obstruction, fire, flooding, visible building damage, and visible electrical hazards where clearly identifiable. QuakeRoute does not claim AI Vision can detect all forms of damage or guarantee a road is safe.

**Functional Requirements**
- FR-10: The system must allow the user to capture or upload a photo as a hazard report.
- FR-11: The system must run AI Vision analysis on the photo and propose a hazard type, severity, road impact, and confidence.
- FR-12: The system must present the AI-suggested hazard to the user for confirmation before it is treated as an active hazard.
- FR-13: The user must be able to confirm, reject, or edit the AI-suggested hazard.
- FR-14: Confirmed hazards must be attached to a location and become part of the structured hazard dataset.

**Acceptance Criteria**
- Given a photo depicting one of the MVP's supported visual hazard types, when analyzed by AI Vision, then the system proposes a hazard with type, severity, road impact, and a confidence value.
- Given the user confirms the suggested hazard, when confirmation is submitted, then the hazard is added to the safety map and risk model.

---

### 9.5 Text Hazard Reporting

**Priority:** MUST HAVE

**Purpose**
Allow users able to provide more detail to describe a hazard (or multiple hazards) in natural language.

**User Story**
As a community member, I want to describe what I observed in a short text message, so that the system can extract structured hazard information from it.

**Description**
User enters a free-text description (e.g., "The road in front of the school is blocked by debris and there's a fallen power line"). AI extracts one or more hazards from the text.

**Functional Requirements**
- FR-15: The system must accept free-text hazard descriptions from the user.
- FR-16: The AI extraction step must be able to identify one or more hazards from a single text report.
- FR-17: Extracted hazards must include type, severity (estimated), road impact, and confidence before being added to the hazard dataset.

**Acceptance Criteria**
- Given a text report describing at least one hazard, when processed by AI, then at least one structured hazard is produced with type, severity, road impact, and confidence.

---

### 9.6 Quick Hazard Reporting

**Priority:** MUST HAVE

**Purpose**
Give users the lowest-effort reporting option, for situations where taking a photo or writing text is not feasible.

**User Story**
As an evacuee under time pressure, I want to report a hazard by simply tapping a predefined category, so that I can report a hazard in a few seconds.

**Description**
User selects a hazard category from a predefined, limited list (e.g., blocked road, debris, fire, electrical hazard, flood, building damage) and confirms location.

**Functional Requirements**
- FR-18: The system must present a predefined, limited list of hazard categories for quick reporting.
- FR-19: The user must be able to submit a quick report by selecting a category and confirming/adjusting location.
- FR-20: Quick reports must be converted into the same structured hazard format used by other reporting modes, with a default confidence appropriate to a self-reported (non-AI-processed) category selection (TBD exact default value).

**Acceptance Criteria**
- Given a user selects a hazard category and confirms location, when submitted, then a structured hazard is created and added to the hazard dataset.

---

### 9.7 AI Hazard Understanding

**Priority:** MUST HAVE

**Purpose**
Serve as the single layer that converts any reporting mode's raw input into structured, routable hazard data.

**User Story**
As the system, I need to convert photo, text, and (optionally) voice input into structured hazard data, so that the risk model and routing engine can use consistent, comparable information regardless of how a hazard was reported.

**Description**
AI functions strictly as a **multimodal hazard understanding layer** — see Section 11 for the full scope and boundaries of AI's role.

**Functional Requirements**
- FR-21: The system must process photo input through AI Vision to propose a hazard.
- FR-22: The system must process text input through AI extraction to propose one or more hazards.
- FR-23: If voice reporting is implemented, transcribed voice input must be processed through the same text-extraction path.
- FR-24: AI output must include, at minimum, hazard type, severity estimate, road impact, and confidence.
- FR-25: AI output must be treated as an observation/prediction, not as verified fact, prior to any confirmation/verification step (see Section 6).

**Acceptance Criteria**
- Given any supported input mode, when processed by AI, then a structured hazard object with type, severity, road impact, and confidence is produced.

---

### 9.8 Hazard Confidence and Status

**Priority:** MUST HAVE

**Purpose**
Track how certain the system is about a hazard, and how that certainty evolves.

**User Story**
As the system, I need to represent how confident a hazard report is and its current status, so that routing can distinguish a possible hazard from a confirmed one.

**Description**
Every hazard carries a confidence value and a status (e.g., Reported, Uncertain, Confirmed, Verified — exact status set TBD but must at minimum distinguish "reported/unconfirmed" from "confirmed").

**Functional Requirements**
- FR-26: Every hazard must have an associated confidence value.
- FR-27: Every hazard must have an associated status field.
- FR-28: The system must support status transitions as new information arrives (e.g., additional matching reports increasing confidence).
- FR-29: Confidence and status must be visible to the user on the safety map (at least at a summary level).

**Acceptance Criteria**
- Given a hazard is created, when viewed on the map, then its confidence/status is visible in some form (e.g., icon, label, or color).

---

### 9.9 Risk-Aware Routing

**Priority:** MUST HAVE

**Purpose**
Compute routes based on risk rather than distance/time alone — the core mechanism of QuakeRoute.

**User Story**
As an evacuee, I want the system to find a route that accounts for known hazards, so that I don't get directed through segments with high or uncertain risk when a safer alternative exists.

**Description**
Route cost is computed as:

```
Route Cost = Base Travel Cost + Hazard Penalty + Uncertainty Penalty
```

A fully blocked segment can be treated as effectively unusable. A segment with a high-severity, high-confidence hazard receives a large penalty, making it less likely to be chosen. A segment with an uncertain hazard receives an uncertainty penalty rather than being immediately excluded. As a result, the shortest route is not always the one selected — a slightly longer route may be chosen if its risk-adjusted cost is lower.

**Functional Requirements**
- FR-30: The routing engine must incorporate hazard severity into segment cost.
- FR-31: The routing engine must incorporate hazard confidence/uncertainty into segment cost.
- FR-32: The routing engine must treat fully blocked segments as unusable (or effectively infinite cost).
- FR-33: The routing engine must be able to select a route that is not the shortest path when it has lower risk-adjusted cost.
- FR-34: The specific routing algorithm is an implementation detail and not fixed by this PRD (TBD at implementation stage).

**Acceptance Criteria**
- Given a segment on the shortest path has a high-severity, high-confidence hazard, when a lower-risk alternative exists, then the system proposes the alternative instead of the shortest path.
- Given no hazards exist on the network, when a route is requested, then the risk-aware route matches (or closely matches) the conventional shortest route (Validation Scenario 1).

---

### 9.10 Dynamic Route Recalculation

**Priority:** MUST HAVE

**Purpose**
Keep the user's route up to date as conditions change after navigation has started.

**User Story**
As an evacuee already navigating, I want my route to update automatically when a new hazard affects it, so that I don't continue toward a road that has since become dangerous.

**Description**
When a new hazard is reported and confirmed/processed, the risk model updates. If the user's active route is affected, the system recalculates and proposes an alternative route.

**Functional Requirements**
- FR-35: The system must detect when a newly reported hazard affects a road segment on a user's active route.
- FR-36: The system must recalculate the route when an active route is affected by a new hazard.
- FR-37: The system must present the updated route to the user in a way that is distinguishable from the initial route.

**Acceptance Criteria**
- Given a user is navigating a route, when a new hazard is reported on a segment of that route, then the system recalculates and offers an alternative route (Validation Scenario 4).

---

### 9.11 Uncertain / Conflicting Reports

**Priority:** MUST HAVE

**Purpose**
Prevent the system from treating a single unverified report as absolute truth, and handle contradicting reports about the same segment.

**User Story**
As the system, I need to handle two conflicting reports about the same road segment without discarding either, so that routing decisions remain reasonable even when field information disagrees.

**Description**
Example: Report A says "road blocked"; Report B says "road still passable." The system does not treat either as absolute truth. It maintains the segment in an uncertain state (e.g., "Conflicting Reports" status), applies an uncertainty penalty, and may use additional confirmation/verification signals as they arrive.

**Functional Requirements**
- FR-38: The system must detect when two or more reports about the same segment materially disagree.
- FR-39: A segment with conflicting reports must be marked with an uncertain/conflicting status rather than automatically fully blocked or fully cleared.
- FR-40: An uncertainty penalty must be applied to the segment's routing cost while its status remains uncertain/conflicting.

**Acceptance Criteria**
- Given two conflicting reports for the same segment, when both are processed, then the segment status becomes "uncertain/conflicting" and its routing cost includes an uncertainty penalty (Validation Scenario 5).

---

### 9.12 Emergency Simulation

**Priority:** MUST HAVE

**Purpose**
Provide a controlled environment to demonstrate, test, and validate QuakeRoute's behavior without needing a real disaster.

**User Story**
As a hackathon evaluator, I want to run predefined disaster scenarios, so that I can observe how QuakeRoute responds to hazards, uncertainty, and changing conditions in a reproducible way.

**Description**
The simulation lets an operator trigger predefined scenarios (see Section 15) against the controlled road network and observe the resulting map, risk, and routing behavior.

**Functional Requirements**
- FR-41: The system must support triggering predefined hazard events within a simulated post-earthquake scenario.
- FR-42: The simulation must be reproducible — running the same scenario should produce comparable outcomes.
- FR-43: The simulation must support at least the six scenarios defined in Section 15.
- FR-44: The simulation must allow comparison between conventional shortest-route output and QuakeRoute's risk-aware output for the same scenario.

**Acceptance Criteria**
- Given a predefined scenario is triggered, when it runs, then the expected sequence of state changes (hazard creation, risk update, recalculation) occurs and is observable.

---

## 10. Multimodal Reporting Requirements

QuakeRoute's guiding principle for reporting:

> **Minimize the effort required to contribute safety information.**

### Photo
```
User takes photo → AI Vision → possible hazard → user confirmation → structured hazard
```
Lowest-typing-effort mode; primary MVP reporting path alongside quick report.

### Text
```
User enters description → AI extraction → structured hazard(s)
```
For users able to provide more detail; can yield multiple hazards from one report.

### Quick Report
```
User selects hazard category → report created
```
Lowest-effort mode overall; no AI processing required for extraction, since the category is already structured.

### Voice
Voice reporting is a **limited/optional feature for the MVP** (SHOULD HAVE, not MUST HAVE). If implemented, it follows: speech-to-text → AI extraction (same path as text). It is not required for MVP completeness and should only be built if the core system (map, photo, text, quick report, routing, recalculation, simulation) is stable.

---

## 11. AI Requirements

AI in QuakeRoute is scoped strictly as a:

> **Multimodal Hazard Understanding Layer**

**AI can:**
- Understand photo input (AI Vision).
- Understand text input.
- Process voice transcripts, if voice reporting is implemented.
- Identify possible hazards from the above input.
- Estimate or suggest hazard severity.
- Determine road impact.
- Produce a confidence value.
- Structure the report into the system's hazard data format.

**AI cannot / does not:**
- Determine routes directly.
- Guarantee that any road is safe.
- Replace emergency responders.
- Automatically convert its own prediction into verified fact.

AI output is always an **observation or prediction with associated uncertainty**, not an absolute statement of ground truth. This is why every hazard carries a confidence value and status field (Section 9.8), and why user confirmation is part of the photo-reporting flow (Section 9.4).

---

## 12. Hazard Domain Requirements

At the product level, a hazard is defined by the following attributes:

| Attribute | Description |
|---|---|
| Hazard Type | The category of hazard (see supported types below) |
| Location | Where the hazard is on the road network |
| Severity | Estimated impact level of the hazard |
| Confidence | How certain the system is about this hazard |
| Source | How the hazard was reported (AI Vision, text, quick report, voice) |
| Status | Current lifecycle state (e.g., Reported, Uncertain, Confirmed, Verified) |
| Road Impact | Effect on the road segment (e.g., passable, partially blocked, blocked) |
| Timestamp | When the hazard was reported/last updated |
| Evidence | Supporting input for the hazard (e.g., photo, report text) |

**Supported hazard types for MVP** (intentionally limited in scope):
- Debris / Rubble
- Road Blockage
- Fire
- Flood
- Electrical Hazard
- Visible Building Damage

This list is deliberately narrow to keep AI Vision and extraction scope realistic for a 10-day hackathon. Expanding hazard coverage is addressed in Section 19 (Future Potential).

---

## 13. Risk-Aware Routing Requirements

Product-level routing behavior:

```
Base Travel Cost
+
Hazard Penalty
+
Uncertainty Penalty
=
Risk-Aware Route Cost
```

- **Blocked roads:** a segment marked as fully blocked is treated as unusable (or effectively infinite cost) and must be excluded from route candidates.
- **High-risk hazards:** segments with high-severity, high-confidence hazards receive a large penalty, making them unlikely to be selected when a viable alternative exists.
- **Uncertain hazards:** segments with unconfirmed or conflicting hazard information receive an uncertainty penalty, rather than being excluded outright — the system does not overreact to a single unverified report.
- **Route selection:** the shortest route is not always selected; a longer route can be chosen if its risk-adjusted cost is lower.

The specific routing algorithm (e.g., which shortest-path variant is used under the hood) is an implementation detail and is not prescribed by this PRD beyond what is stated in the project notes.

---

## 14. Uncertainty and Conflicting Reports

Example situation:

> **Report A:** "Road blocked."
> **Report B:** "Road still passable."

QuakeRoute handles this by:

- Not immediately treating either report as absolute truth.
- Preserving the uncertainty explicitly, rather than resolving it arbitrarily.
- Representing the situation via confidence and status fields on the hazard (e.g., "Uncertain," "Conflicting Reports").
- Applying an uncertainty penalty to the affected segment's routing cost, proportional to the degree of disagreement/uncertainty (exact weighting TBD).
- Allowing for future verification/confirmation signals (e.g., additional matching reports) to shift status and confidence over time.

This ensures the system reflects real-world ambiguity rather than prematurely closing off routes that may still be usable, or trusting routes that may not be.

---

## 15. Emergency Simulation Requirements

Emergency Simulation serves as:

- A demonstration environment.
- A reproducible testing environment.
- A disaster preparedness tool.
- A validation mechanism for comparing QuakeRoute against conventional routing.

### Scenario 1 — No Hazard
- **Initial state:** controlled road network, no active hazards.
- **Event:** none.
- **Expected behavior:** risk-aware routing behaves equivalently to conventional shortest-path routing.
- **Expected outcome:** route from QuakeRoute matches (or closely matches) the shortest/fastest baseline route, demonstrating no unwarranted penalties.

### Scenario 2 — Blocked Road
- **Initial state:** an initial route exists across segments A→B→C→D.
- **Event:** a hazard fully blocks segment C→D.
- **Expected behavior:** the routing engine excludes the blocked segment.
- **Expected outcome:** system proposes an alternative route (e.g., A→B→E→F→D).

### Scenario 3 — High-Risk Hazard
- **Initial state:** a segment on the shortest route is passable but carries a high-severity hazard.
- **Event:** hazard is reported and confirmed with high confidence.
- **Expected behavior:** the segment's cost increases substantially without being marked as fully blocked.
- **Expected outcome:** system selects a slightly longer alternative route with lower risk-adjusted cost.

### Scenario 4 — New Hazard During Navigation
- **Initial state:** user is actively navigating a route.
- **Event:** another user submits a photo report; AI Vision detects a new hazard on the current route.
- **Expected behavior:** risk model updates; affected route is detected; recalculation is triggered.
- **Expected outcome:** user receives an updated alternative route.

### Scenario 5 — Conflicting Reports
- **Initial state:** a segment has no confirmed hazard.
- **Event:** two reports disagree about the segment's condition.
- **Expected behavior:** segment status becomes uncertain/conflicting; uncertainty penalty applied.
- **Expected outcome:** segment is neither treated as fully blocked nor fully safe; routing cost reflects the added uncertainty.

### Scenario 6 — AI Vision Hazard Report
- **Initial state:** a hazard exists in the field but is not yet reported in the system.
- **Event:** a user submits a photo of the hazard.
- **Expected behavior:** AI Vision proposes a structured hazard; user confirms; hazard is added to the map and risk model.
- **Expected outcome:** the confirmed hazard affects routing cost/route selection as appropriate to its severity and confidence.

---

## 16. Validation and Success Criteria

QuakeRoute has a research/discovery component in addition to being a working prototype. Success is evaluated by comparing:

> **Baseline:** conventional shortest/fastest route

against:

> **QuakeRoute:** risk-aware route (base cost + hazard penalty + uncertainty penalty)

**Prototype-appropriate metrics:**
- Number of hazardous segments avoided by QuakeRoute's route vs. the baseline route, per scenario.
- Successful rerouting: whether the system produces a valid alternative route when the active route becomes affected (Scenario 4).
- Route feasibility: whether the proposed route is actually traversable given current hazard states (no route through a fully blocked segment).
- Route cost: comparison of risk-adjusted cost between baseline and QuakeRoute routes.
- Distance trade-off: how much longer (if at all) QuakeRoute's route is compared to the baseline, in scenarios where a detour is chosen.
- Handling of uncertain reports: whether conflicting reports result in an uncertain status + penalty rather than an outright block or an ignored report (Scenario 5).

These metrics are chosen because they can be measured directly from the six simulation scenarios within a 10-day hackathon timeframe. Metrics requiring real-world field data or long-term usage are out of scope for this validation.

---

## 17. Safety Requirements

- AI output is not absolute truth; it is an observation/prediction with associated confidence.
- No route produced by QuakeRoute is guaranteed to be safe.
- Hazard information can become stale as conditions continue to change; hazards carry a timestamp for this reason.
- Users should follow official authority and emergency responder instructions when available, in preference to app guidance.
- QuakeRoute is a decision-support tool, not an emergency response system or a safety guarantee.
- The system must communicate uncertainty to the user appropriately (e.g., via confidence/status indicators), rather than presenting all hazards or routes with equal certainty.

---

## 18. MVP Scope — 10-Day Hackathon

| Feature | Priority | MVP Status | Reason |
|---|---|---|---|
| Post-earthquake controlled scenario | MUST HAVE | In MVP | Core context for all other features; keeps scope to one disaster domain |
| Controlled road network | MUST HAVE | In MVP | Required substrate for routing and simulation |
| Dynamic safety map | MUST HAVE | In MVP | Primary interface for user situational awareness |
| Shelter/medical destination selection | MUST HAVE | In MVP | Required to generate any route |
| Community hazard reporting (general) | MUST HAVE | In MVP | Core input mechanism for hazard data |
| Photo-based hazard reporting / AI Vision | MUST HAVE | In MVP (limited hazard set) | Central low-friction reporting mode and AI showcase |
| Text hazard reporting | MUST HAVE | In MVP | Needed for users who can provide more detail |
| Quick hazard reporting | MUST HAVE | In MVP | Lowest-effort reporting mode |
| AI hazard extraction (text/photo) | MUST HAVE | In MVP | Converts raw input into structured hazard data |
| Severity and confidence modeling | MUST HAVE | In MVP | Required for risk-aware cost calculation |
| Risk-aware routing | MUST HAVE | In MVP | Core differentiator of the product |
| Dynamic route recalculation | MUST HAVE | In MVP | Demonstrates adaptive behavior, key to the discovery question |
| Uncertain/conflicting report handling | MUST HAVE | In MVP | Core to the uncertainty-aware positioning of the product |
| Emergency simulation (6 scenarios) | MUST HAVE | In MVP | Required for demonstration and validation |
| Baseline comparison (shortest vs. risk-aware) | MUST HAVE | In MVP | Required for success criteria in Section 16 |
| Voice reporting | SHOULD HAVE | Limited/Optional | Only if core system is stable; not required for MVP completeness |
| Additional hazard categories | COULD HAVE | Limited/Optional | Nice-to-have if time allows after core hazards are covered |
| Advanced verification logic | COULD HAVE | Limited/Optional | Basic confidence/status handling suffices for MVP |
| Real emergency deployment | OUT OF SCOPE | Not in MVP | Requires production-grade reliability, legal, and operational readiness |
| Direct responder integration | OUT OF SCOPE | Not in MVP | Requires external systems/partnerships beyond hackathon scope |
| Comprehensive real-world disaster data | OUT OF SCOPE | Not in MVP | Prototype uses controlled/simulated data only |
| Full AI Vision coverage of all damage types | OUT OF SCOPE | Not in MVP | Limited hazard set is sufficient to validate the concept |
| Multi-disaster support | OUT OF SCOPE | Not in MVP | Earthquake-only scope keeps depth achievable in 10 days |
| Production-scale infrastructure | OUT OF SCOPE | Not in MVP | Not required to validate the product hypothesis |

---

## 19. Future Potential

### Disaster Generalization
The hazard/risk/routing abstraction used in QuakeRoute is not inherently earthquake-specific and could, in future work, extend to:
- Flood
- Fire
- Landslide
- Storm
- Other environmental emergencies

### Data Integration
Future development could integrate:
- Official disaster information sources.
- Emergency response systems.
- Responder-facing dashboards.
- Real-time geospatial data.
- Offline maps.
- Satellite imagery.
- Additional sensor data.

### Core Abstraction (unchanged across future work)

```
Hazard
+ Severity
+ Confidence
+ Location
+ Road Impact
        ↓
   Risk Model
        ↓
    Routing
```

This means future disaster-type or data-source expansion does not require rebuilding the routing engine — only extending the hazard input and risk modeling layers that feed into it.

---

## 20. Requirement Traceability

| Problem | Goal | Feature | Requirement | Validation |
|---|---|---|---|---|
| Road conditions change dynamically after an earthquake | Adaptive navigation as conditions change | Dynamic Route Recalculation | FR-35, FR-36, FR-37 | Scenario 4 |
| Users struggle to report hazards under stress | Enable low-effort hazard reporting | Photo-Based Hazard Reporting / AI Vision | FR-10, FR-11, FR-12 | Scenario 6 |
| Users struggle to report hazards under stress | Enable low-effort hazard reporting | Quick Hazard Reporting | FR-18, FR-19, FR-20 | Scenario 6 |
| Hazard information is unstructured | Convert observations into structured hazard data | AI Hazard Understanding | FR-21 to FR-25 | Scenario 6 |
| Reports about the same segment conflict | Handle uncertainty without discarding information | Uncertain / Conflicting Reports | FR-38, FR-39, FR-40 | Scenario 5 |
| Shortest route may not be the safest route | Route users toward lower-risk feasible paths | Risk-Aware Routing | FR-30 to FR-34 | Scenario 2, Scenario 3 |
| No baseline exists to demonstrate risk-aware routing's value | Provide controlled testing/demonstration environment | Emergency Simulation | FR-41 to FR-44 | Scenario 1–6 |
| Users need situational awareness of hazards | Give users visibility into current conditions | Dynamic Safety Map | FR-01 to FR-04 | Scenario 1–6 (observable throughout) |
| Users need to reach a destination | Enable destination-based route generation | Destination Selection | FR-05, FR-06, FR-07 | Scenario 1 |
| Hazard reports vary in certainty | Represent confidence explicitly | Hazard Confidence and Status | FR-26 to FR-29 | Scenario 3, Scenario 5 |
| Detailed text reporting is not always feasible in an emergency | Support multiple report formats with varying effort levels | Text Hazard Reporting | FR-15, FR-16, FR-17 | Scenario 6 |

---

**Document status:** Draft PRD for 10-day hackathon prototype. Items marked TBD require decisions during implementation and do not block PRD approval.
