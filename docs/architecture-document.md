# QuakeRoute — Architecture Document

## 0. Document Status and Source of Truth

- **Source of truth:** `PRD.md`, `SRS.md`, `Domain-Risk-Model.md`, `AI-Requirements.md`, and `tech-stack.md`. This document **does not** change, add, or remove any requirement, domain entity, risk-model formula, or technology decision already defined in those documents.
- **What this document does:** translates requirements (SRS), the domain/risk model (Domain-Risk-Model), AI scope (AI-Requirements), and the decided tech stack (tech-stack) into an architecture that is **implementable** within a 10-day hackathon — components, responsibilities, interaction flows, module structure, and inter-layer boundaries.
- **What this document does not do:** API specification, database schema, and detailed UI/UX specification — these are separate documents derived *from* this architecture, not part of this architecture.
- **Routing engine:** remains `TBD` per `tech-stack.md` §7 and SRS FR-034. This document defines the **contract** that the routing layer must satisfy (see §4.4 and §6), not a specific engine/algorithm.
- **Numbers/parameters:** all numeric parameters that remain `TBD` in the Domain-Risk-Model (severity weight, confidence factor, uncertainty weight, staleness decay) remain `TBD` here. This architecture only provides the *place* (module/interface) where those parameters will be configured at implementation time.

---

## 1. Architecture Overview

QuakeRoute MVP is built as:

- **Backend:** Modular Monolith based on **Laravel 13**, a single deployable unit, split **logically** (not by network/service) into Hazard, AI, Risk, Routing, and Simulation modules.
- **Mobile:** **Flutter**, Feature-Oriented Architecture — a single app, split by feature (map, reporting, routing, simulation) with a shared `core/` layer.
- **Database:** **PostgreSQL + PostGIS** — a single relational+spatial datastore, used only by the backend (the mobile app never accesses the database directly).
- **AI:** accessed by the backend via an **AI Service Abstraction** — provider-agnostic, per `tech-stack.md` §3.3 and `AI-Requirements.md`.
- **Routing:** accessed via a single **Routing Interface** inside the backend; the concrete implementation (in-process graph library or external service) is **not selected** here — remains `TBD` per the brief.

```
┌─────────────────────────────────────────────────────────────┐
│                      Flutter Mobile App                       │
│   (Feature-Oriented: map, reporting, routing, simulation)     │
└───────────────────────────┬────────────────────────────────┘
                             │ REST API (dio)
┌───────────────────────────▼────────────────────────────────┐
│                    Laravel Modular Monolith                  │
│                                                                │
│   ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌──────────┐ │
│   │  Hazard   │  │    AI     │  │   Risk    │  │ Routing  │ │
│   │  Module   │◀─│  Module   │  │  Module   │─▶│  Module  │ │
│   └───────────┘  └─────┬─────┘  └───────────┘  └────┬─────┘ │
│                         │                              │      │
│   ┌───────────┐         │                              │      │
│   │Simulation │◀────────┴──────────────────────────────┘      │
│   │  Module   │  (orchestrates scenarios via other modules)   │
│   └───────────┘                                                │
└──────────────┬──────────────────────────┬────────────────────┘
               │                           │
    ┌──────────▼──────────┐     ┌──────────▼──────────────┐
    │ PostgreSQL + PostGIS │     │  External AI Provider    │
    │ (Hazard, RoadSegment,│     │  (LLM + Vision, TBD)      │
    │  Route, Simulation)  │     │  via AI Service Abstraction│
    └───────────────────────┘     └───────────────────────────┘
```

**Primary design principles** (directly from the brief & source docs):

1. **Modular monolith, not microservices** — a single process/deployable, with purely logical separation of concerns (namespace/folder + interface), to stay simple for 10 days (`tech-stack.md` §10: "no production-scale infrastructure").
2. **Each module communicates via an explicit interface/contract**, not by directly calling Eloquent models owned by another module — this is what makes Risk, Routing, Hazard, AI, and Simulation "logically separate" as instructed, while also satisfying NFR-008 (maintainability/extensibility — SRS §5).
3. **AI and Routing are the strictest boundaries**, because both are `TBD` providers/engines. Each may only be accessed through a single interface.
4. **The domain flow from the source documents (Observation → Hazard → Risk → Routing Cost → Route) becomes the inter-module call sequence**, not a standalone diagram.

---

## 2. System Components and Responsibilities

| Component | Responsibility | Not Responsible For |
|---|---|---|
| **Mobile App (Flutter)** | Display the Dynamic Safety Map, accept reporting input (photo/text/quick-tap/[voice]), display routes & recalculation, trigger simulation runs (for demo). | AI logic, risk scoring, routing algorithm, persistent data storage. |
| **Backend — Hazard Module** | Receive Observations from all reporting modes, store Hazards (PRD §12 / Domain-Risk-Model §3 structure), manage Hazard status lifecycle (§7), detect conflicting reports (§11.2). | Determining Severity/Confidence from raw input (that is the AI Module's job for photo/text), calculating routing cost, selecting routes. |
| **Backend — AI Module (AI Service Abstraction)** | Transform Observations (photo/text/voice-transcript) into candidate Hazards (Type, Severity, Confidence, Road Impact, Context, Evidence) per `AI-Requirements.md` §5–§6. Hide the concrete AI provider behind a single interface. | Storing the final Hazard, determining Status lifecycle, calculating Risk/Routing Cost, selecting routes (`AI-Requirements.md` §2, §11). |
| **Backend — Risk Module** | Calculate Hazard Penalty and Uncertainty Penalty per Road Segment from active Hazards (Domain-Risk-Model §13–§16), producing Segment Routing Cost. | Storing/managing Hazards themselves, choosing the pathfinding algorithm, calling the AI provider. |
| **Backend — Routing Module** | Provide a Routing Interface that accepts a cost graph (from the Risk Module) and returns a Route (minimum-cost path, never traversing a Blocked segment). The engine behind it is **TBD**. | Calculating Hazard/Uncertainty Penalties (that is the Risk Module's job), deciding when recalculation is triggered (that is the Hazard Module + orchestrator's job, see §7). |
| **Backend — Simulation Module** | Store & run the 6 controlled scenarios (FR-041–044), trigger Observations/Hazards programmatically through the same path as normal reporting, provide baseline vs. risk-aware route comparison. | Does not own risk/AI/routing logic — purely an orchestrator that calls other modules. |
| **PostgreSQL + PostGIS** | Store all persistent domain entities: Observation, Hazard, Road Segment (geometry), Route, Simulation scenario/state. | Any business logic (no complex stored procedures; logic stays in Laravel). |
| **External AI Provider** | Perform LLM (text) and Vision (photo) inference, called only by the AI Module. | Anything outside hazard understanding (see `AI-Requirements.md` §2). |
| **OSM-compatible Tile Provider** | Supply base map tiles for `flutter_map`. | Controlled road network data (that lives in PostGIS, seeded from OSM at setup, not consumed live). |

---

## 3. Interaction / Primary Inter-Component Flow

The diagram below maps the core flow from `Domain-Risk-Model.md` §1 to inter-component calls in the architecture:

```
Mobile App
   │  (1) submit Observation (photo/text/quick-tap/[voice])
   ▼
Backend REST Layer
   │  (2) route to Hazard Module
   ▼
Hazard Module
   │  (3) if photo/text/voice → delegate to AI Module
   │      if quick-tap → create Hazard directly (default confidence, no AI)
   ▼
AI Module ──(4) call AI Service Abstraction──▶ External AI Provider
   │
   ▼ (5) candidate Hazard (Type, Severity, Confidence, Road Impact, Context, Evidence)
Hazard Module
   │  (6) store Hazard (Status: Reported/pending confirmation per FR-025),
   │      run conflicting-report check (§11.2) if applicable
   ▼
Risk Module
   │  (7) recalculate Segment Routing Cost for affected segments
   ▼
Routing Module
   │  (8) if affected segment lies on any user's active route →
   │      request a new Route via the Routing Interface
   ▼
Backend REST Layer ──(9)── notification/response ──▶ Mobile App
   │
   ▼ (10) display Hazard on map (NFR-004) and/or new Route (FR-037)
```

Important notes that constrain this sequence (directly from source docs, must not be relaxed at implementation time):

- The Hazard Module **never** calls the AI Module for quick-tap (`AI-Requirements.md` §4: quick-tap "Unsupported (not an AI input)").
- The AI Module **never** calls the Risk or Routing Module directly — its output only goes to the Hazard Module (`AI-Requirements.md` §2: "AI does not determine routes").
- The Risk Module **never** selects a route — it only produces per-segment cost; route selection is solely the Routing Module's responsibility (Domain-Risk-Model §13.1).
- For photo reports, a new Hazard reaches its final/confirmed status only after the user confirms/rejects/edits it (FR-012–FR-014) — this step occurs in the Mobile App + Hazard Module, before the Risk Module recalculates cost for that Hazard.

---

## 4. Backend Module Structure (Laravel Modular Monolith)

The folder structure below is an **implementation guide**, not an API/DB spec. Each module is a separate namespace within a single Laravel application; modules communicate via a **Contract (interface)**, not via direct calls to internal classes of another module.

```
app/
├── Modules/
│   ├── Hazard/
│   │   ├── Domain/            # Entity: Observation, Hazard, Evidence (POPO/DTO, not direct Eloquent)
│   │   ├── Models/            # Eloquent models (Hazard, Observation)
│   │   ├── Services/          # HazardService: create, confirm, reject, detect conflict
│   │   ├── Contracts/         # HazardRepositoryInterface, ConflictDetectorInterface
│   │   └── Http/              # Controllers for reporting endpoints (details in separate API Spec)
│   │
│   ├── AI/
│   │   ├── Contracts/         # AIProviderInterface (single gateway to external provider)
│   │   ├── Services/          # AIHazardUnderstandingService (implements AI-Requirements §5–§6 pipeline)
│   │   ├── Providers/         # Concrete implementations of AIProviderInterface (LLM, Vision) — provider TBD
│   │   └── DTO/                # CandidateHazardDTO (Type, Severity, Confidence, Road Impact, Context, Evidence)
│   │
│   ├── Risk/
│   │   ├── Services/          # RiskCalculationService: HazardPenalty(), UncertaintyPenalty(), SegmentRoutingCost()
│   │   ├── Contracts/         # RiskCalculatorInterface
│   │   └── Config/            # configuration for TBD parameters (severity weight, confidence factor, etc.)
│   │
│   ├── Routing/
│   │   ├── Contracts/         # RoutingEngineInterface (compute route from cost graph) — engine TBD
│   │   ├── Services/          # RoutingOrchestrator: build cost graph from Risk Module, call engine,
│   │   │                      #   detect impact on active routes (FR-035), trigger recalculation
│   │   └── Models/            # RoadSegment, Route (Eloquent, PostGIS geometry)
│   │
│   ├── Simulation/
│   │   ├── Scenarios/         # Definitions for the 6 scenarios (No Hazard, Blocked Road, High-Risk, New Hazard,
│   │   │                      #   Conflicting Reports, AI Vision) — structured data, not hard-coded logic
│   │   ├── Services/          # SimulationRunnerService: replay scenarios via the normal path
│   │   │                      #   (Hazard/AI/Risk/Routing Modules), not a separate shortcut/mock path
│   │   └── Http/              # Controller for trigger & baseline-vs-risk-aware comparison (FR-044)
│   │
│   └── Shared/
│       ├── Location/          # value object Location + resolution to Road Segment (PostGIS query)
│       └── ValueObjects/      # Severity, Confidence, RoadImpact, Status (enum/ordinal, per §4.2 Domain-Risk-Model)
│
├── Http/                      # Thin REST entry point, delegates to Module Services
└── Providers/                 # Service Container bindings: bind each *Interface* to its concrete implementation
                                #   (where AIProviderInterface & RoutingEngineInterface are wired up)
```

**Boundary rules (must be maintained during implementation):**

- Other modules may **only** depend on the `Contracts/` of another module, never directly on that module's internal `Models/` or `Services/`.
- `AIProviderInterface` and `RoutingEngineInterface` are the only points where external vendors/engines "leak" into the codebase — per `tech-stack.md` §10 ("AI must remain provider-agnostic") and SRS FR-034 (routing algorithm = implementation detail).
- Numeric parameters that remain `TBD` (severity weight, confidence factor, uncertainty weight, staleness decay, default quick-tap confidence) live in `Modules/Risk/Config` and `Modules/Hazard` as values that can be changed without altering code structure — not hard-coded in many places.

---

## 5. Flutter Project Structure (Feature-Oriented)

```
lib/
├── core/
│   ├── network/            # dio client, interceptors, base API client
│   ├── state/              # global Riverpod providers (e.g., active route, connectivity)
│   ├── models/             # shared DTOs: Hazard, RoadSegment, Route (mirror backend structure, read-only on client)
│   ├── theme/               # shared styling
│   └── utils/
│
├── features/
│   ├── map/                 # Dynamic Safety Map (FR-001–004)
│   │   ├── presentation/    # map widget (flutter_map), hazard overlay, severity/confidence indicator (NFR-004)
│   │   ├── application/     # Riverpod providers/state for map & hazard layer
│   │   └── data/            # REST calls to fetch hazard/road network state
│   │
│   ├── destination/         # Destination Selection (FR-005–007)
│   │
│   ├── reporting/           # Hazard Reporting — all modes (FR-008–020)
│   │   ├── photo/           # image_picker + confirm/reject/edit flow (FR-012–014)
│   │   ├── text/            # free-text input
│   │   ├── quick_tap/       # predefined category list
│   │   └── voice/           # [optional/SHOULD HAVE — only if implemented]
│   │
│   ├── routing/             # Route display, dynamic recalculation (FR-006, FR-035–037)
│   │   ├── presentation/    # active vs. new route display (distinguishable, FR-037)
│   │   ├── application/     # Riverpod state for active route + change listener
│   │   └── data/
│   │
│   └── simulation/          # Trigger scenarios & view baseline vs. risk-aware (FR-041–044)
│                             #   — for demo/evaluator, may be a separate screen within the same app
│
└── main.dart                # bootstrap Riverpod ProviderScope, routing between features
```

**Feature-Oriented principles here:**

- Each folder under `features/` is self-contained (presentation + application/state + data), so it can be worked on in parallel by different team members during the hackathon without file-level contention.
- `core/` only contains what is truly shared across features (network client, shared models, global state such as the active route) — it does not become a catch-all for mixed logic.
- The mobile app **does not** compute Severity/Confidence/Routing Cost itself — all those values are displayed directly from backend responses, consistent with the separation of concerns in §2.

---

## 6. Data Flow: Hazard Reporting → AI → Risk Assessment → Routing

This flow is the concrete implementation of `Domain-Risk-Model.md` §1 and §12, mapped to backend modules:

```
[Mobile] Observation submitted (photo / text / quick-tap / [voice])
   │
   ▼
[Hazard Module] receive Observation, determine path by mode:
   │
   ├─ quick-tap ──────────────────────────────────────────────┐
   │                                                            │
   ├─ photo / text / voice-transcript                          │
   │      │                                                     │
   │      ▼                                                     │
   │  [AI Module] → AIProviderInterface → External AI Provider  │
   │      │                                                     │
   │      ▼                                                     │
   │  candidate Hazard (Type, Severity, Confidence,              │
   │  Road Impact, Context, Evidence) — AI-Requirements §5       │
   │      │                                                     │
   │      ▼ (photo report: requires user confirm/reject/edit     │
   │         before proceeding — FR-012–014)                     │
   │      │                                                     │
   └──────┴─────────────────────────────────────────────────────┘
              │
              ▼
[Hazard Module] store Hazard with initial Status (Reported/Confirmed per FR-025,
   default confidence for quick-tap — Domain-Risk-Model §5.1), attach to Location
              │
              ▼
[Hazard Module] check whether another active Hazard exists on the same Road Segment →
   if material disagreement exists → set Status = Uncertain/Conflicting (§11.2)
              │
              ▼
[Risk Module] for each affected Road Segment:
   SegmentRoadImpact = worst(RoadImpact(h) for all active Hazards)      (Domain-Risk-Model §9.2)
   HazardPenalty     = max(SeverityWeight(h) × ConfidenceFactor(h))       (§14.1)
   UncertaintyPenalty = UncertaintyWeight(SegmentStatus)                  (§15.1)
   SegmentRoutingCost = ∞ if Blocked, else BaseTravelCost + HazardPenalty + UncertaintyPenalty  (§16.1)
              │
              ▼
[Routing Module] cost graph (all Segment Routing Costs) available for route requests
              │
              ▼
Route computed on demand when:
   (a) user selects a destination (FR-006) → initial route, or
   (b) affected segment lies on the user's active route (see §7 below)
```

**Points that must be preserved at implementation time** (directly from source docs):

- Severity and Confidence are **never combined** into a single number in any module — they remain two separate fields from the AI Module through to the Risk Module (AI-Requirements §8; Domain-Risk-Model §5.2).
- Uncertainty is **never allowed to "silently disappear"** — every Hazard with low confidence or a conflicting status must still produce a visible penalty (Domain-Risk-Model §8), not be ignored by the Risk Module.
- The Risk Module recalculates cost **only for affected segments**, not the entire graph, to keep recalculation cheap (see §7).

---

## 7. Dynamic Route Recalculation Flow

Implements FR-035–037 and Domain-Risk-Model §11.4/§12, with two required properties: **triggered by information (not polling)** and **scoped only to affected users**.

```
New/changed Hazard stored (from flow in §6)
              │
              ▼
[Risk Module] recalculate Segment Routing Cost ONLY for affected segments
              │
              ▼
[Routing Module] — Impact Detector:
   for each active Route currently in progress (stored in PostgreSQL):
       is one of this Route's segments among the newly changed segments?  (FR-035)
              │
        ┌─────┴─────┐
        │           │
       No           Yes
        │             │
        ▼             ▼
  no action       [Routing Module] request a new Route from the user's
  for this        current position to the same destination, via the
  user —          Routing Interface, using the latest cost graph (FR-036)
  map/hazard             │
  layer still             ▼
  updated        new Route stored, marked as distinct from the old Route
  (global map    (e.g., flag `superseded_by` / route version) — FR-037
  still                  │
  refreshed)             ▼
                  [Backend REST] send notification/response for the new Route to
                  the affected Mobile App user only
                          │
                          ▼
                  [Mobile — routing feature] display the new Route
                  visually distinct from the previous Route (FR-037)
```

**Architectural notes:**

- The "Impact Detector" is not a separate module — it is part of the **Routing Module** (`RoutingOrchestrator`), because the only entity that knows "who is active on which route" is the Routing Module (owner of Route data).
- The mechanism for delivering notifications to the Mobile App (periodic REST polling vs. push/websocket) is an implementation detail **not locked** here — the SRS does not specify a mechanism; what is required is the *effect* (the user whose route is affected receives the new Route, other users do not receive an unnecessary recalculation).
- Recalculation is never triggered on a fixed schedule/interval — only by the event "new/changed Hazard stored", consistent with Domain-Risk-Model §12.

---

## 8. Simulation Architecture

Emergency Simulation (FR-041–044) is **not** a separate engine with its own logic — it is a **thin orchestrator over the same production path** (§6–§7), so that simulation results truly reflect actual system behavior (and so two separate logic paths do not need to be built within 10 days).

```
[Simulation Module] — Scenario Definition (data, not code logic)
   Each scenario (No Hazard, Blocked Road, High-Risk Hazard, New Hazard During
   Navigation, Conflicting Reports, AI Vision Hazard Report) is defined as
   structured data: the list of Observations to be "injected", onto which
   Road Segment, and (for AI Vision) the fixed sample photo/text used repeatedly
   for reproducibility (FR-042/NFR-002).
              │
              ▼
[Simulation Module] — Scenario Runner:
   1. Reset/prepare the same controlled road network state for each run
   2. For each Observation in the scenario: send to [Hazard Module] exactly
      as an Observation from a real Mobile App (calling the same Service,
      NOT a separate endpoint/mock)
   3. Flow in §6 executes as-is: AI Module (if photo/text mode) → Hazard
      Module → Risk Module → Routing Module
   4. After all scenario Observations are processed, request 2 Routes from
      [Routing Module]:
         a. Baseline Route  = Route computed with Routing Cost = Base Travel
            Cost only (Hazard/Uncertainty Penalties ignored)  — FR-044
         b. Risk-Aware Route = Route computed with full Routing Cost
            (Base + Hazard Penalty + Uncertainty Penalty)     — normal flow
   5. Store both Routes + the resulting hazard/risk state for side-by-side
      display to the evaluator (FR-044)
```

**Key design decisions:**

- **Baseline route is not a separate engine** — it is the same call to the Routing Interface, only with a cost graph stripped of Hazard/Uncertainty Penalties (`BaseTravelCost` only). This avoids duplicating routing logic and keeps the baseline "fair" compared to the risk-aware route.
- **Reproducibility (FR-042/NFR-002)** is achieved by: (a) scenarios defined as fixed data (seeds), not random; (b) the same road network reset/re-seeded on each run (supported by Docker per `tech-stack.md` §8.1); (c) the AI Module called with the same fixed input on each run — non-determinism from the AI provider (if any) is a known risk and is not mitigated architecturally here, because the AI provider is an external dependency (`TBD`, outside this architecture's control).
- The Simulation Module **does not store a copy of Risk/Routing logic** — if the risk-model formula changes during tuning (`TBD` parameters in §4 and §6), the simulation automatically reflects the change without manual synchronization.

---

## 9. External Dependencies / Integrations

Per `tech-stack.md` §9, mapped to the module that is its sole consumer:

| Dependency | Accessed By | Direction | Notes |
|---|---|---|---|
| **External AI Provider** (LLM for text/voice, Vision for photo — provider `TBD`) | `AI Module` (via `AIProviderInterface`) only | Outbound | No other module may call this provider directly. |
| **Routing Engine/Library** (`TBD`) | `Routing Module` (via `RoutingEngineInterface`) only | In-process call (if a library) or outbound (if a service) — the form itself is still `TBD` | Contract that must be satisfied: accept a cost graph, return a minimum-cost Route, respect Blocked segments (§16.1 Domain-Risk-Model). |
| **OSM-compatible Tile Provider** | `Mobile — features/map` (via `flutter_map`) | Outbound from Mobile directly, not via Backend | Only for the base map's visual tiles, not the source for the controlled road network at runtime. |
| **OpenStreetMap data (for road network setup)** | Initial seed/setup process (not runtime) | Data source during PostGIS initialization | The road network actually used at runtime is the data already seeded into PostGIS, not a live query to OSM. |
| **PostgreSQL + PostGIS** | All backend Modules | Bidirectional | The only datastore; no separate database per module (still a single monolithic data layer). |
| **Docker** | Entire environment (Backend, DB) | Development-time | Ensures a consistent environment across team members and supports simulation reproducibility (NFR-002). |

No new external dependencies beyond those already defined in `tech-stack.md` are introduced.

---

## 10. Architectural Decisions and Rationale

| Decision | Brief Rationale |
|---|---|
| **Modular Monolith (not microservices)** | 10 days is not enough to handle microservices deployment overhead, network calls, and observability; the requirements (SRS §9, §11) also explicitly state "no production-scale infrastructure". Separation of concerns is still achieved via modules + interfaces, not network boundaries. |
| **Inter-module communication via Contract/Interface, not direct calls** | The only way to make AI and Routing truly *provider-agnostic* and *algorithm-agnostic* (tech-stack §10, SRS FR-034) inside a single monolithic process — without interfaces, "provider-agnostic" remains a claim in the document, not a reality in code. |
| **Routing Interface defined now, engine behind it not selected** | Satisfies the explicit instruction ("do not lock in a routing engine") while still giving the team clear implementation direction — the contract (cost graph in, Route out, Blocked = excluded) is sufficient to start coding the Risk/Hazard side without waiting for an engine decision. |
| **Simulation Module replays the same production Services, not building its own logic path** | Reduces the risk of "lying simulation" (simulation results not reflecting the real system) and saves implementation time — consistent with FR-043 (scenarios run end-to-end through the actual system). |
| **AI Module never touches Hazard status lifecycle** | Directly follows `AI-Requirements.md` §5 ("AI output does not include a hazard lifecycle Status") and §11 (AI output is not ground truth) — Status remains the Hazard Module's responsibility. |
| **Baseline route computed from the same cost graph as risk-aware, only minus penalties** | Ensures FR-044 (baseline vs. risk-aware comparison) is a fair comparison (identical base travel cost), not two separate data sources that could drift. |
| **Flutter Feature-Oriented with minimal `core/`** | Enables parallel work by different hackathon team members per feature (map, reporting, routing, simulation) without locking the same files, while still having a single shared state/network layer for consistency (NFR-008 analog on the mobile side). |
| **PostgreSQL + PostGIS as the sole datastore** | Already decided in `tech-stack.md` §4 — this document only confirms that no additional datastore per module is introduced, so the monolith remains truly a single deployable unit. |

---

## 11. MVP Boundaries — What Is Intentionally Not Built for the Hackathon

Consistent with `PRD`/`SRS` §9/§11 and `tech-stack.md` §12, this architecture **intentionally does not include**:

- **No microservices, message broker, or service mesh** — all modules live in a single Laravel process.
- **No API Gateway or load balancer** — a single backend instance is sufficient for the demo/hackathon.
- **No separate database per module** — a single PostgreSQL+PostGIS for all data.
- **No selection of a routing engine/algorithm** — only the interface contract is defined; choosing an engine is a separate implementation decision (per FR-034).
- **No selection of a concrete AI provider (LLM/Vision)** — only `AIProviderInterface` is defined.
- **No dedicated Volunteer/Coordinator dashboard/tooling** — this role uses the same Evacuee/Community Reporter capabilities (SRS §3.3); no separate backend module or Flutter feature for it.
- **No complex authentication/authorization mechanism** — outside the scope of the given requirements; if minimal identification is needed to distinguish users/active routes, it is a lightweight implementation detail, not part of this module architecture.
- **No offline mode, push notification infrastructure, or dedicated caching layer** — not requested by the SRS/tech-stack; the route-update delivery mechanism (§7) is intentionally left as an implementation detail.
- **No automatic staleness/decay handling for confidence** — remains `TBD` per Domain-Risk-Model §11.3; the architecture only provides a Timestamp field, not a job/cron that degrades confidence.
- **No multi-disaster support or hazard types beyond the 6 MVP types** — the AI Module, Risk Module, and data schema are strictly limited to 6 types (`PRD` §12).
- **No production-grade reliability/scaling** (sophisticated retry policies, circuit breakers, autoscaling) — simple failure handling is sufficient (e.g., AI fails → no candidate Hazard, per `AI-Requirements.md` §12), because this is a demo prototype, not a production system (SRS §8, §11, NFR-007).
- **No API specification, database schema, or detailed UI/UX specification in this document** — all three are separate downstream documents, per the given constraints.

---

**Document status:** Architecture Document for the QuakeRoute 10-day hackathon MVP, derived from `SRS.md`, `Domain-Risk-Model.md`, `AI-Requirements.md`, and `tech-stack.md`. No requirement, domain entity, risk-model formula, or technology decision has been changed, added, or removed by this document. The routing engine remains intentionally `TBD`. Items marked `TBD` in the source documents remain `TBD` here.
