# QuakeRoute — Tech Stack

## 0. Document Purpose and Status

This document defines the **technical stack** for QuakeRoute's implementation. It does not define architecture, API specifications, database schema, or UI/UX — those are separate, subsequent deliverables.

- **Source of truth for requirements:** `PRD.md`, `SRS.md`, and `Domain-Risk-Model.md`. This document does not change, add to, or remove any requirement from those documents.
- **Source of truth for technology decisions:** the stack below is treated as already decided. This document explains the role, rationale, integration, and constraints of each technology in relation to the requirements — it does not re-select or re-justify alternatives.
- **Scope:** this stack targets a **10-day hackathon MVP**, consistent with PRD §18/§19 and SRS §9/§11. It is deliberately not a production-scale architecture (PRD §6 Non-Goals; SRS §8, §11).
- Items not yet decided are marked `TBD` rather than assumed, per PRD/SRS convention.

---

## 1. Stack Summary

| Layer | Technology |
|---|---|
| Mobile | Flutter, flutter_map, geolocator, image_picker, dio, Riverpod |
| Backend | Laravel 13, REST API, AI Service Abstraction |
| Database | PostgreSQL, PostGIS |
| Mapping | OpenStreetMap, flutter_map, OSM-compatible Tile Provider |
| AI | Provider-agnostic AI integration, LLM for hazard understanding, Vision (conditional on MVP scope) |
| Routing | TBD |
| Development | Docker |

---

## 2. Mobile

### 2.1 Flutter
**Role:** Client application framework for the Evacuee / Community Reporter experience — dynamic safety map, destination selection, multimodal hazard reporting (photo, text, quick tap), and route display/recalculation.
**Why:** The PRD's core user journey (§8) and MUST HAVE features (§18) — map, reporting flows, route display — all live on a single mobile client. A single cross-platform framework covers this without maintaining separate native codebases, which fits a 10-day timeline.

### 2.2 flutter_map
**Role:** Renders the Dynamic Safety Map (PRD §9.1, SRS §4.1) — user location, destinations, road network, and hazard overlays with severity/confidence indicators (NFR-004).
**Why:** Directly satisfies FR-001–FR-004 and NFR-004 (visible confidence/status indicators) as a Flutter-native map rendering layer. Also listed under Mapping (Section 5) since it is the bridge between the Mapping layer and the Mobile client.

### 2.3 geolocator
**Role:** Provides the user's current location for FR-001 (display user location) and for anchoring hazard reports and route origin points.
**Why:** Required input for both the safety map and for destination-to-user routing; a standard, minimal dependency for this single responsibility.

### 2.4 image_picker
**Role:** Captures or selects photos for Photo-Based Hazard Reporting (PRD §9.4; FR-010).
**Why:** Directly required by FR-010 ("capture or upload a photo as a hazard report"). No additional image-handling library is introduced beyond this.

### 2.5 dio
**Role:** HTTP client for all mobile-to-backend REST API communication — submitting reports, fetching the safety map/hazard state, requesting routes, and receiving recalculated routes.
**Why:** Single, consistent networking layer for every mobile↔backend integration point described below (Section 6).

### 2.6 Riverpod
**Role:** State management for the mobile client — active route state, hazard/map state, reporting flow state, and recalculation updates (FR-035–FR-037).
**Why:** The client must reflect frequently changing state (new hazards, updated routes, confidence/status changes) consistently across the map, reporting, and navigation views; Riverpod is the designated mechanism for that.

---

## 3. Backend

### 3.1 Laravel 13
**Role:** Backend application layer implementing the REST API, orchestrating the AI Hazard Understanding pipeline (PRD §11; SRS §6), the Risk Model (Domain-Risk-Model §13–§17), and coordination with the Routing layer (Section 6, TBD).
**Why:** Central server-side responsibility for QuakeRoute — receiving Observations, invoking AI processing, updating Hazard/Risk state, triggering recalculation (FR-035–FR-037), and running the Emergency Simulation (FR-041–FR-044) — is consolidated in one backend framework for a 10-day build.

### 3.2 REST API
**Role:** The single interface contract between the Mobile client and the Backend for all functional flows: reporting, map/hazard state retrieval, destination selection, route generation, recalculation, and simulation triggers.
**Why:** Matches SRS §1.2's provider-agnostic, implementation-detail framing and keeps the mobile/backend boundary simple and testable within the hackathon timeframe. (Detailed endpoint definitions belong in a separate API Specification document, per this document's Rules.)

### 3.3 AI Service Abstraction
**Role:** An internal backend layer that sits between the REST API / domain logic and any external AI inference provider, implementing the "Multimodal Hazard Understanding Layer" boundary defined in PRD §11 and SRS §6.
**Why:** SRS §7 explicitly requires the AI inference service to be treated as an external, replaceable dependency, with no functional requirement tied to a specific provider. This abstraction is what makes that requirement concrete in code: the rest of the backend (risk model, routing trigger logic) depends only on this abstraction's output contract (hazard type, severity, road impact, confidence — FR-024), never on a specific AI vendor/SDK.

---

## 4. Database

### 4.1 PostgreSQL
**Role:** Primary datastore for all persistent domain entities defined in Domain-Risk-Model §2: Observations, Hazards, Road Segments, Routes, and simulation scenario state.
**Why:** A relational database fits the structured, relationship-heavy domain model (Observation → candidate Hazard → confirmed Hazard → Road Segment → Risk → Routing Cost → Route), including hazard lifecycle/status transitions (FR-026–FR-029) and conflicting-report tracking (FR-038–FR-040).

### 4.2 PostGIS
**Role:** Spatial extension to PostgreSQL used to store and query the controlled road network (Road Segments as geometry), hazard locations, destination locations, and user location, and to support spatial operations needed by routing and map rendering.
**Why:** PRD §12 and Domain-Risk-Model §2.1 define Location and Road Segment as spatial concepts; PostGIS provides this without introducing a separate spatial datastore.

---

## 5. Mapping

### 5.1 OpenStreetMap
**Role:** Source of the base map data and, within the controlled scope of the MVP, the road network substrate referenced by PRD §18 ("controlled road network").
**Why:** Provides an open, no-license-cost source of map/road data suitable for constructing the controlled network used across all six simulation scenarios (PRD §15).

### 5.2 flutter_map
**Role:** (See Section 2.2.) Also serves as the mapping layer's rendering client, consuming tiles from the OSM-compatible Tile Provider below.

### 5.3 OSM-compatible Tile Provider
**Role:** Serves map tiles to flutter_map for the Dynamic Safety Map.
**Why:** Required as the tile source for FR-001–FR-004; kept OSM-compatible (rather than tied to a specific commercial tile vendor) to remain consistent with the OpenStreetMap decision above.
**TBD:** Specific tile provider (self-hosted vs. third-party OSM-compatible service) — not decided.

---

## 6. AI

### 6.1 Provider-agnostic AI integration
**Role:** Governing principle for how the Backend's AI Service Abstraction (Section 3.3) connects to whatever external AI inference capability is used.
**Why:** Directly required by SRS §1.2 ("This SRS is provider-agnostic at the requirement level") and SRS §7 ("The specific provider or model is TBD and is not fixed by this SRS"). No specific AI vendor or model is named as a requirement in this document, consistent with the Rules governing this document.

### 6.2 LLM for hazard understanding
**Role:** Performs AI text extraction (PRD §9.7, FR-016, FR-022) — converting free-text hazard descriptions (and, if voice reporting is implemented, transcribed voice input, FR-023) into structured hazard candidates (type, severity, road impact, confidence — FR-024).
**Why:** PRD §11 and SRS §6 define AI's role strictly as understanding/structuring input, never deciding routes; an LLM fulfills the text/voice-transcript side of this role.

### 6.3 Vision capability (conditional)
**Role:** If Photo-Based Hazard Reporting / AI Vision (PRD §9.4, FR-010–FR-014) is included in the final MVP build, this capability analyzes photo input and proposes a candidate hazard (type, severity, road impact, confidence) for user confirmation.
**Why:** PRD §18 lists Photo-Based Reporting / AI Vision as MUST HAVE (limited hazard set). Per the instruction accompanying this stack, Vision is included in this document **only insofar as photo reporting ends up in the MVP build** — its inclusion here does not itself decide MVP scope, which remains governed by PRD §18 / SRS §9.
**Constraint:** Limited to the MVP hazard set defined in PRD §12: Debris/Rubble, Road Blockage, Fire, Flood, Electrical Hazard, Visible Building Damage. Full AI Vision coverage of all damage types is explicitly OUT OF SCOPE (PRD §18, §19; SRS §11).

---

## 7. Routing

**Status:** `TBD`.

Per PRD §13 ("The specific routing algorithm... is an implementation detail and is not prescribed by this PRD") and SRS FR-034 ("The specific routing algorithm is an implementation detail and is not fixed by this SRS or the PRD"), no routing engine or algorithm is selected in this document.

What is fixed by the requirements (Domain-Risk-Model §13–§17), regardless of which routing approach is eventually chosen:
- The routing layer must accept a per-segment **Routing Cost = Base Travel Cost + Hazard Penalty + Uncertainty Penalty** (FR-030, FR-031).
- It must treat fully blocked segments as unusable / effectively infinite cost (FR-032).
- It must be able to select a non-shortest path when it has lower risk-adjusted cost (FR-033).
- It must support recomputation on demand for Dynamic Route Recalculation (FR-035–FR-037).
- It must operate over the PostGIS-stored road network (Section 4.2).

The specific routing engine, library, or algorithm (e.g., a graph library invoked from Laravel, an external routing service, or a custom implementation) remains an open decision to be made during implementation and documented separately (e.g., in an Architecture Document), per PRD FR-034 / SRS §7.

---

## 8. Development

### 8.1 Docker
**Role:** Local development and environment consistency for the Backend (Laravel), Database (PostgreSQL/PostGIS), and any supporting services, across the hackathon team.
**Why:** Keeps environment setup fast and reproducible across team members within a 10-day window, and supports the reproducibility requirement for the Emergency Simulation (NFR-002, FR-042) by keeping the backing services consistent across runs.

---

## 9. Key Integrations

| Integration | Direction | Purpose |
|---|---|---|
| Mobile (Flutter/dio) ↔ Backend (Laravel REST API) | Bidirectional | All functional flows: reporting, map/hazard retrieval, destination selection, route generation, recalculation, simulation triggers. |
| Backend (AI Service Abstraction) → External AI provider (LLM / Vision, TBD vendor) | Outbound | Converts photo/text/voice-transcript Observations into candidate Hazards (type, severity, road impact, confidence). |
| Backend → PostgreSQL/PostGIS | Bidirectional | Persists and queries Observations, Hazards, Road Segments, Risk/Routing Cost inputs, Routes, and simulation state. |
| Backend → Routing layer (TBD) | Outbound | Supplies per-segment Routing Cost (from the Risk Model) for route computation; receives computed Route back. |
| Mobile (flutter_map) → OSM-compatible Tile Provider | Outbound | Retrieves map tiles for the Dynamic Safety Map. |
| flutter_map ↔ PostGIS-backed road network (via Backend REST API) | Bidirectional | Road network geometry and hazard overlays displayed on the map originate from PostGIS, served through the Backend. |

---

## 10. Dependencies and Constraints

- **AI must remain provider-agnostic.** The AI Service Abstraction (Section 3.3) is the only layer permitted to know which concrete AI provider/model is in use; no other layer (mobile, routing, risk model) may depend on a specific AI vendor, per SRS §7.
- **Routing algorithm/engine is undecided by design.** Nothing in this stack presumes a specific routing engine; only the cost-function contract (Section 7) is fixed. Selecting a routing approach is a separate implementation decision.
- **Hazard scope is fixed to six MVP types.** PostGIS schema, AI extraction/vision prompts or models, and risk model logic must all stay within the six hazard types defined in PRD §12; expanding this list is explicitly OUT OF SCOPE for the MVP (PRD §18, §19).
- **Voice reporting is conditional.** If implemented, it reuses the same LLM text-extraction path (Section 6.2) via speech-to-text — no separate AI understanding pipeline. Speech-to-text provider is TBD (SRS §7) and is not part of this stack unless voice reporting is built.
- **No production-scale infrastructure.** Per PRD §6 and §18 and SRS §8/§11, this stack does not include production-grade availability, scaling, or infrastructure components (e.g., load balancing, managed AI/routing SLAs) — Docker-based local/demo deployment is sufficient for the MVP.
- **Controlled road network only.** PostGIS stores a controlled, simulation-scoped road network (PRD §18), not a comprehensive real-world dataset; OpenStreetMap is a data source for constructing that controlled network, not a live production map integration.
- **Single disaster type.** All layers (AI, risk model, routing cost contract) are scoped to the earthquake-only MVP; multi-disaster support is OUT OF SCOPE (PRD §18, §19).

---

## 11. Open Items (`TBD`)

The following are explicitly left undecided by this document, consistent with PRD/SRS/Domain-Risk-Model conventions:

- **Routing engine/algorithm** (Section 7) — approach for computing min-cost routes over the risk-adjusted cost graph.
- **OSM-compatible tile provider** (Section 5.3) — self-hosted vs. third-party.
- **AI provider/model selection** (Sections 3.3, 6.1) — which LLM/vision provider is used behind the AI Service Abstraction.
- **Vision capability's final MVP inclusion** (Section 6.3) — governed by PRD §18/§19 and SRS §9, not decided here.
- **Speech-to-text provider** (conditional on voice reporting, SRS §7) — not selected; voice reporting itself is SHOULD HAVE, not MUST HAVE.
- **Numeric routing/risk parameters** (severity weights, confidence factors, uncertainty weighting, staleness decay) — these are Domain-Risk-Model concerns (its §14–§15, §18.1), not tech-stack concerns, and remain TBD there regardless of the stack chosen here.
- **Response time targets** (NFR-001) — no numeric target specified; relevant to how the above technologies are configured/tuned during implementation, not to stack selection itself.
- **Privacy handling** (NFR-006) — data retention/handling for location, reports, and photos stored in PostgreSQL/PostGIS is not specified.

---

## 12. MVP / Hackathon Scope Note

This tech stack is scoped strictly to a **10-day hackathon MVP prototype**, consistent with PRD §18, SRS §9, and Domain-Risk-Model §0/§18.2:

- It targets the six controlled Emergency Simulation scenarios (PRD §15; FR-041–FR-044), not real-world deployment.
- It excludes production-scale infrastructure, direct responder integration, comprehensive real-world disaster data, multi-disaster support, and full AI Vision damage-type coverage (PRD §18; SRS §9, §11).
- Technology choices favor speed of implementation and reproducibility (Docker, a single backend framework, a single mobile framework, one relational+spatial database) over horizontal scalability, high availability, or multi-tenant concerns.
- Any extension beyond this scope (additional disaster types, additional hazard types, production hardening, coordinator dashboards) is future work per PRD §19 and is out of scope for this document.

---

**Document status:** Tech Stack document for the QuakeRoute 10-day hackathon MVP, derived from `PRD.md`, `SRS.md`, and `Domain-Risk-Model.md`. Technology selections in Sections 2–6 and 8 are treated as already-decided inputs to this document, not choices made by it. Items marked `TBD` mirror unresolved items in the source documents or reflect technical decisions intentionally deferred to later implementation/design work.
