# QuakeRoute — API Specification (MVP)

## 0. Document Status and Source of Truth

- **Source of truth:** `SRS.md`, `Domain-Risk-Model.md`, `Architecture-Document.md`. This document **does not** change, add, or remove any requirement, domain entity, risk-model formula, or architectural decision defined in those documents.
- **What this document does:** translates requirements (SRS §4), the domain/risk model (Domain-Risk-Model §2–§16), and inter-module flows (Architecture Document §3, §6–§8) into a REST API contract that can be implemented by the Backend (Laravel Modular Monolith) and consumed by the Mobile App (Flutter).
- **What this document does not do:** change the module architecture, change the risk-model formula, or select a specific routing engine/algorithm. The routing endpoints below only define the request/response contract that the Routing Module must satisfy — not how the Routing Module computes routes internally (remains `TBD` per SRS FR-034 and Architecture Document §9, §11).
- **Numbers/parameters:** all numeric parameters that remain `TBD` in the Domain-Risk-Model (severity weight, confidence factor, uncertainty weight, staleness decay, default quick-tap confidence) remain `TBD` here. The API only exposes *fields* for those values, not the values themselves.
- **Scope:** only endpoints required for the MVP per SRS §9 (MVP Scope). No endpoints for features outside the MVP (e.g., Volunteer/Coordinator dashboard, complex authentication, multi-disaster).

---

## 1. General Conventions

| Aspect | Convention |
|---|---|
| **Base path** | `/api/v1` (API version — common convention; not defined by source documents, added as standard REST practice) |
| **Data format** | JSON for request and response bodies. Photo upload uses `multipart/form-data` (see §3.1). |
| **Authentication / user identity** | **TBD.** The SRS/Architecture Document explicitly do not define a complex authentication/authorization mechanism for the MVP (Architecture Document §11: "No complex authentication/authorization mechanism"). Endpoints that require user identity (e.g., a user's active route) assume a lightweight identifier (e.g., `session_id` or `device_id`) sent via the `X-Session-Id` header — the exact mechanism is **TBD**, this is only a contract placeholder. |
| **Time** | All timestamps are in ISO 8601 UTC format (e.g., `2026-08-21T09:15:00Z`), as required by the Hazard Timestamp field (Domain-Risk-Model §3, §11.3). |
| **Location** | Coordinate points are sent as `{ "lat": number, "lng": number }`. Resolving Location → Road Segment is an internal process (PostGIS, Architecture Document §4 — `Shared/Location`), not exposed as a separate API step. |
| **Pagination** | List endpoints that may return large results (e.g., `GET /hazards`) support `?limit=` and `?cursor=` or `?page=` — the exact mechanism is **TBD**, not specified by the source documents. |
| **Common error format** | See §2. |
| **Domain enum values** | `severity`: `Low` \| `Medium` \| `High` (final bands and band count **TBD**, Domain-Risk-Model §4.2). `road_impact`: `Passable` \| `PartiallyBlocked` \| `Blocked` (Domain-Risk-Model §9.2). `status`: must at minimum distinguish `Reported` \| `Confirmed` from other states; final set **TBD** (SRS FR-027) — conceptual values used in this document: `Reported`, `Confirmed`, `UncertainConflicting` (Domain-Risk-Model §7.1). `type` (hazard): one of the 6 MVP types (§3.1 Domain-Risk-Model): `DebrisRubble`, `RoadBlockage`, `Fire`, `Flood`, `ElectricalHazard`, `VisibleBuildingDamage`. `source`: `AIVisionPhoto` \| `AITextExtraction` \| `QuickTap` \| `AIVoiceExtraction` (voice, conditional — SHOULD, only if implemented, FR-023). |

---

## 2. Standard Error Format

All errors use the following structure with the appropriate HTTP status code:

```json
{
  "error": {
    "code": "string (machine-readable, e.g., VALIDATION_ERROR)",
    "message": "string (for display/logging)",
    "details": { }
  }
}
```

| HTTP Status | When Used |
|---|---|
| `400 Bad Request` | Request body/parameters are structurally invalid (e.g., malformed JSON). |
| `422 Unprocessable Entity` | Validation failed (e.g., required field empty, `type` is not one of the 6 MVP types). |
| `404 Not Found` | Resource (hazard, route, destination, suggestion, scenario, run) not found. |
| `409 Conflict` | Action is invalid for the current resource state (e.g., re-confirming a suggestion that has already been rejected). |
| `502 Bad Gateway` / `503 Service Unavailable` | External AI provider or routing engine failed to respond (both are external dependencies, `TBD`, Architecture Document §9). Per `AI-Requirements.md` §12 (referenced in Architecture Document §10): an AI failure means "no candidate Hazard produced" — not an error that halts the entire reporting flow; the response must indicate that AI failed, not that the hazard is invalid. |
| `500 Internal Server Error` | Other unexpected failures. |

---

## 3. Hazard Reporting

Covers FR-008–FR-024 (SRS §4.3–§4.7) and the Observation → AI Hazard Understanding → Hazard flow (Domain-Risk-Model §1–§9; Architecture Document §3, §6). All reporting modes converge to the same Hazard structure (FR-009).

### 3.1 `POST /api/v1/hazard-reports/photo`

**Purpose:** Submit a photo as the basis for a hazard report (FR-010), trigger AI Vision (FR-011, FR-021), and return a **suggestion** pending user confirmation (FR-012) — not yet an active Hazard (FR-025).

**Request:**
- Content-Type: `multipart/form-data`
- Fields:
  - `photo` (file, required) — hazard image.
  - `location` (object, required) — `{ "lat": number, "lng": number }`.
  - `note` (string, optional) — additional note from the reporter.

**Response — `201 Created`:**
```json
{
  "suggestion_id": "string",
  "status": "PendingConfirmation",
  "proposed_hazard": {
    "type": "RoadBlockage",
    "severity": "High",
    "confidence": 0.72,
    "road_impact": "Blocked",
    "location": { "lat": -6.20, "lng": 106.81 },
    "evidence": { "photo_url": "string" },
    "source": "AIVisionPhoto"
  }
}
```
The `proposed_hazard` field corresponds to the minimum AI output (FR-024): type, severity, road_impact, confidence. No `hazard_id` yet because it has not entered the hazard dataset (FR-025).

**Status/Error:**
- `422` — photo missing / location invalid.
- `502/503` — AI Vision provider failed (see §2); response contains `error.code = "AI_PROVIDER_UNAVAILABLE"`, no `proposed_hazard` is produced.

---

### 3.2 `POST /api/v1/hazard-suggestions/{suggestion_id}/confirm`

**Purpose:** User confirms (optionally with edits) the AI Vision suggestion (FR-013), making the hazard part of the structured dataset (FR-014).

**Request:**
```json
{
  "edits": {
    "type": "RoadBlockage",
    "severity": "High",
    "road_impact": "Blocked"
  }
}
```
`edits` is optional — if provided, the included fields replace the AI-generated values before the hazard is stored (FR-013 "edit"). Confidence cannot be manually edited by the user (its value still comes from AI or the system default — no source requirement allows manual override of confidence).

**Response — `200 OK`:**
```json
{
  "hazard_id": "string",
  "status": "Reported",
  "type": "RoadBlockage",
  "severity": "High",
  "confidence": 0.72,
  "road_impact": "Blocked",
  "location": { "lat": -6.20, "lng": 106.81 },
  "source": "AIVisionPhoto",
  "timestamp": "2026-08-21T09:15:00Z",
  "evidence": { "photo_url": "string" }
}
```
The new hazard enters with an initial status per FR-025 (not automatically "Verified" just because the user confirmed it — the final status still follows Domain-Risk-Model §7.1, exact status set TBD).

**Status/Error:**
- `404` — `suggestion_id` not found.
- `409` — suggestion has already been confirmed/rejected.
- `422` — `edits` contains values outside the allowed enums.

---

### 3.3 `POST /api/v1/hazard-suggestions/{suggestion_id}/reject`

**Purpose:** User rejects the AI Vision suggestion (FR-013) — the suggestion is discarded and never enters the hazard dataset.

**Request:** No required body.

**Response — `200 OK`:**
```json
{ "suggestion_id": "string", "status": "Rejected" }
```

**Status/Error:**
- `404` — `suggestion_id` not found.
- `409` — suggestion has already been confirmed/rejected.

---

### 3.4 `POST /api/v1/hazard-reports/text`

**Purpose:** Submit a free-text report (FR-015), triggering AI text extraction (FR-016, FR-022) that may produce one or more structured hazards (FR-017), added directly to the hazard dataset (no explicit confirm/reject step in the SRS for text mode — unlike photo mode §3.1–§3.3, per Architecture Document §3).

**Request:**
```json
{
  "text": "Jalan di depan pasar tertutup reruntuhan, sepertinya cukup parah",
  "location": { "lat": -6.20, "lng": 106.81 }
}
```

**Response — `201 Created`:**
```json
{
  "hazards": [
    {
      "hazard_id": "string",
      "status": "Reported",
      "type": "DebrisRubble",
      "severity": "High",
      "confidence": 0.65,
      "road_impact": "PartiallyBlocked",
      "location": { "lat": -6.20, "lng": 106.81 },
      "source": "AITextExtraction",
      "timestamp": "2026-08-21T09:20:00Z",
      "evidence": { "text": "Jalan di depan pasar tertutup reruntuhan, sepertinya cukup parah" }
    }
  ]
}
```
The `hazards` array accommodates the case where a single text report produces more than one hazard (FR-016, Domain-Risk-Model §2.3).

**Status/Error:**
- `422` — `text` is empty / `location` is invalid.
- `502/503` — AI extraction provider failed; no hazards created (`hazards: []`), `error.code = "AI_PROVIDER_UNAVAILABLE"`.

---

### 3.5 `POST /api/v1/hazard-reports/quick`

**Purpose:** Submit a quick-tap report (FR-018, FR-019) — no AI, directly becomes a structured hazard with a default confidence (FR-020).

**Request:**
```json
{
  "type": "Fire",
  "location": { "lat": -6.20, "lng": 106.81 }
}
```
`type` must be one of the 6 MVP categories shown in the quick-tap list (FR-018).

**Response — `201 Created`:**
```json
{
  "hazard_id": "string",
  "status": "Reported",
  "type": "Fire",
  "severity": "TBD",
  "confidence": "TBD (default quick-tap, exact value not yet determined)",
  "road_impact": "TBD",
  "location": { "lat": -6.20, "lng": 106.81 },
  "source": "QuickTap",
  "timestamp": "2026-08-21T09:25:00Z",
  "evidence": null
}
```
Default values for `severity`, `confidence`, and `road_impact` for quick-tap reports have not been defined in the source documents (Domain-Risk-Model §4.1, §5.1: "exact default TBD") — the API still requires these fields in the response once default values are set during implementation.

**Status/Error:**
- `422` — `type` is not one of the 6 MVP categories, or `location` is invalid.

---

### 3.6 `POST /api/v1/hazard-reports/voice` *(conditional — SHOULD, only if voice reporting is implemented)*

**Purpose:** Submit a voice recording as a hazard report (FR-023) — the transcript is processed through the same text-extraction path as §3.4.

**Request:**
- Content-Type: `multipart/form-data`
- Fields: `audio` (file, required), `location` (object, required).

**Response — `201 Created`:** Same structure as §3.4 (`hazards[]`), with `source: "AIVoiceExtraction"`.

**Status/Error:** Same as §3.4. Additional:
- `501 Not Implemented` — if voice reporting is not implemented in a given build (this feature is **SHOULD**, not **MUST** — SRS §9).

---

## 4. Hazard Retrieval (Dynamic Safety Map)

Covers FR-001–FR-004, FR-026–FR-029 (SRS §4.1, §4.8).

### 4.1 `GET /api/v1/hazards`

**Purpose:** Retrieve the list of active hazards to display on the Dynamic Safety Map, including severity and confidence/status (FR-003, FR-029).

**Request (query params):**
| Param | Required | Description |
|---|---|---|
| `bbox` | No | `minLng,minLat,maxLng,maxLat` — filter for the currently visible map area. |
| `status` | No | Filter by status, e.g., `UncertainConflicting` (supports uncertain/conflicting report needs, §7 of this document). |
| `updated_since` | No | ISO 8601 timestamp — for incremental client refresh (update delivery mechanism, polling vs. push, **TBD** per Architecture Document §7). |

**Response — `200 OK`:**
```json
{
  "hazards": [
    {
      "hazard_id": "string",
      "type": "RoadBlockage",
      "severity": "High",
      "confidence": 0.72,
      "road_impact": "Blocked",
      "status": "Confirmed",
      "location": { "lat": -6.20, "lng": 106.81 },
      "road_segment_id": "string",
      "source": "AIVisionPhoto",
      "timestamp": "2026-08-21T09:15:00Z"
    }
  ]
}
```

**Status/Error:**
- `400` — `bbox` malformed.

---

### 4.2 `GET /api/v1/hazards/{hazard_id}`

**Purpose:** Retrieve details for a single hazard, including evidence (FR-014, Domain-Risk-Model §6) — used when the user wants to see the basis for a hazard on the map.

**Request:** No body.

**Response — `200 OK`:**
```json
{
  "hazard_id": "string",
  "type": "RoadBlockage",
  "severity": "High",
  "confidence": 0.72,
  "road_impact": "Blocked",
  "status": "Confirmed",
  "location": { "lat": -6.20, "lng": 106.81 },
  "road_segment_id": "string",
  "source": "AIVisionPhoto",
  "timestamp": "2026-08-21T09:15:00Z",
  "evidence": { "photo_url": "string" },
  "conflicting_with": []
}
```
`conflicting_with` (array of hazard_id) is populated when this hazard is part of a conflicting-report group on the same segment (FR-038, Domain-Risk-Model §11.2); empty if there is no conflict.

**Status/Error:**
- `404` — hazard not found.

---

## 5. Destinations

Covers FR-002, FR-005 (SRS §4.1–§4.2).

### 5.1 `GET /api/v1/destinations`

**Purpose:** Retrieve the list of available shelters/medical facilities to display on the map and for user selection (FR-002, FR-005).

**Request (query params, optional):** `bbox` — same as §4.1.

**Response — `200 OK`:**
```json
{
  "destinations": [
    {
      "destination_id": "string",
      "name": "Shelter Balai Kota",
      "type": "Shelter",
      "location": { "lat": -6.21, "lng": 106.82 }
    }
  ]
}
```
`type`: `Shelter` \| `MedicalFacility` (per PRD/SRS — shelters and medical facilities, SRS §4.1).

**Status/Error:** — (no specific error conditions beyond §2).

---

## 6. Risk-Aware Routing & Dynamic Recalculation

Covers FR-005–FR-007, FR-030–FR-037 (SRS §4.2, §4.9–§4.10). These endpoints expose the **contract** of the Routing Module (cost graph in, Route out, Blocked = excluded — Domain-Risk-Model §16, Architecture Document §9) without prescribing the algorithm/engine behind it (FR-034, remains `TBD`).

### 6.1 `POST /api/v1/routes`

**Purpose:** Create a new route — used for the initial route after destination selection (FR-005, FR-006) and when the user changes destination (FR-007, replacing the previous route).

**Request:**
```json
{
  "destination_id": "string",
  "origin": { "lat": -6.199, "lng": 106.805 }
}
```
`origin` represents the user's current location (FR-001). User identity is assumed to come from `X-Session-Id` (see §1) to determine ownership of the "active route".

**Response — `201 Created`:**
```json
{
  "route_id": "string",
  "destination_id": "string",
  "status": "Active",
  "supersedes_route_id": "string|null",
  "total_cost": 128.4,
  "segments": [
    {
      "road_segment_id": "string",
      "base_travel_cost": 10.0,
      "hazard_penalty": 0.0,
      "uncertainty_penalty": 0.0,
      "segment_routing_cost": 10.0
    }
  ],
  "created_at": "2026-08-21T09:30:00Z"
}
```
Cost fields follow the skeleton `Route Cost = Base Travel Cost + Hazard Penalty + Uncertainty Penalty` (Domain-Risk-Model §13.2, §16.2) — actual numeric values depend on `TBD` parameters in the Risk Module. `supersedes_route_id` is populated when this request is a destination change/recalculation that replaces a previously active route (FR-007, FR-037).

**Status/Error:**
- `404` — `destination_id` not found.
- `422` — `origin` is outside the controlled road network.
- `409 UNROUTABLE` — no route is available (all candidates traverse a Blocked segment with no alternative) — this condition is valid per the model (Domain-Risk-Model §11.1: "absence of a route is an acceptable outcome") and must be distinguished from a system error.

---

### 6.2 `GET /api/v1/routes/{route_id}`

**Purpose:** Retrieve details for a specific route, including whether it is still active or has been superseded (FR-037).

**Request:** No body.

**Response — `200 OK`:** Same structure as the §6.1 response, plus:
```json
{
  "status": "Superseded",
  "superseded_by_route_id": "string"
}
```

**Status/Error:**
- `404` — `route_id` not found.

---

### 6.3 `GET /api/v1/routes/active`

**Purpose:** Retrieve the current user's active route — used by the Mobile App to detect recalculation (FR-036, FR-037). The update delivery mechanism (periodic polling vs. push/websocket) is intentionally not locked in the architecture (Architecture Document §7); this endpoint defines the **polling** shape as the minimum contract that must be available, without precluding an additional push mechanism outside this document.

**Request:** Header `X-Session-Id` (see §1). No body.

**Response — `200 OK`:** Same as §6.2. If the session has no active route:

**Status/Error:**
- `404 NO_ACTIVE_ROUTE` — user has no active route.

---

## 7. Uncertain / Conflicting Reports

Covers FR-038–FR-040 (SRS §4.11). No separate endpoint — this requirement is satisfied through fields already defined on the hazard endpoints (§4):

| Requirement | Satisfied Via |
|---|---|
| Detection of material disagreement among reports on the same segment (FR-038) | Internal Hazard Module process (Domain-Risk-Model §11.2) — not exposed as an endpoint, only its result (see rows below). |
| Segment marked uncertain/conflicting, not automatically blocked/cleared (FR-039) | `GET /api/v1/hazards` and `GET /api/v1/hazards/{hazard_id}` — field `status: "UncertainConflicting"` (§4.1, §4.2). |
| Uncertainty penalty on the related segment's routing cost (FR-040) | `GET /api/v1/routes/{route_id}` — field `uncertainty_penalty` per segment (§6.2). |
| Viewing which hazards conflict on a segment | `GET /api/v1/hazards/{hazard_id}` — field `conflicting_with` (§4.2). |

No additional endpoint is introduced here because this requirement is *state* on the Hazard/Route already covered, not a new *action*.

---

## 8. Emergency Simulation

Covers FR-041–FR-044 (SRS §4.12; Architecture Document §8). The Simulation Module replays the same production services (Hazard/AI/Risk/Routing) — not a separate logic path (Architecture Document §8, §10).

### 8.1 `GET /api/v1/simulation/scenarios`

**Purpose:** Retrieve the list of 6 supported controlled scenarios (FR-043).

**Request:** No body.

**Response — `200 OK`:**
```json
{
  "scenarios": [
    { "scenario_id": "no_hazard", "name": "No Hazard" },
    { "scenario_id": "blocked_road", "name": "Blocked Road" },
    { "scenario_id": "high_risk_hazard", "name": "High-Risk Hazard" },
    { "scenario_id": "new_hazard_during_navigation", "name": "New Hazard During Navigation" },
    { "scenario_id": "conflicting_reports", "name": "Conflicting Reports" },
    { "scenario_id": "ai_vision_hazard_report", "name": "AI Vision Hazard Report" }
  ]
}
```

**Status/Error:** — (no specific error conditions beyond §2).

---

### 8.2 `POST /api/v1/simulation/scenarios/{scenario_id}/run`

**Purpose:** Trigger execution of a programmed scenario (FR-041), which runs through the normal Hazard/AI/Risk/Routing Module path (Architecture Document §8) reproducibly (FR-042).

**Request:**
```json
{
  "origin": { "lat": -6.199, "lng": 106.805 },
  "destination_id": "string"
}
```
`origin`/`destination_id` are required so the scenario can produce a concrete baseline route and risk-aware route (FR-044) — the scenario itself (the list of injected Observations) is already defined as fixed data in the Simulation Module (Architecture Document §8), not part of this request.

**Response — `202 Accepted`:**
```json
{
  "run_id": "string",
  "scenario_id": "blocked_road",
  "status": "Running",
  "started_at": "2026-08-21T10:00:00Z"
}
```
Status `202` is used because the scenario runs an end-to-end flow (AI, risk, routing) that may not be instantaneous (Architecture Document §8) — results are fetched via §8.3.

**Status/Error:**
- `404` — `scenario_id` is unknown (not one of the 6 MVP scenarios).
- `422` — `destination_id` not found.

---

### 8.3 `GET /api/v1/simulation/runs/{run_id}`

**Purpose:** Retrieve the result of a running/completed scenario, including the baseline (shortest/fastest) vs. risk-aware route comparison (FR-044).

**Request:** No body.

**Response — `200 OK`:**
```json
{
  "run_id": "string",
  "scenario_id": "blocked_road",
  "status": "Completed",
  "hazards_created": [
    { "hazard_id": "string", "type": "RoadBlockage", "road_impact": "Blocked" }
  ],
  "baseline_route": {
    "route_id": "string",
    "total_cost": 90.0,
    "note": "Base Travel Cost only, Hazard/Uncertainty Penalty ignored (FR-044)"
  },
  "risk_aware_route": {
    "route_id": "string",
    "total_cost": 128.4,
    "note": "Base Travel Cost + Hazard Penalty + Uncertainty Penalty"
  },
  "completed_at": "2026-08-21T10:00:05Z"
}
```
Both routes are generated from the same cost graph, differing only in whether Hazard/Uncertainty Penalties are included (Architecture Document §8, "Key design decisions"), so the comparison remains fair per FR-044.

**Status/Error:**
- `404` — `run_id` not found.
- `202`-equivalent (`status: "Running"` in a `200 OK` body) — if the run has not finished, `baseline_route`/`risk_aware_route` are `null`; the client is expected to poll (exact mechanism **TBD**, same as §6.3).

---

## 9. Requirement → Endpoint Mapping Summary

| Requirement (from brief) | Endpoint |
|---|---|
| Hazard reporting & retrieval | §3 (`POST /hazard-reports/*`, `POST/PATCH /hazard-suggestions/*`), §4 (`GET /hazards`, `GET /hazards/{id}`) |
| AI hazard processing | Integrated in §3.1–§3.6 (AI is invoked internally by the Hazard Module, not exposed as a separate endpoint — per Architecture Document §2, §3: the AI Module is never accessed directly from outside the Hazard Module) |
| Destinations | §5 (`GET /destinations`) |
| Risk-aware routing | §6.1–§6.2 (`POST /routes`, `GET /routes/{id}`) |
| Dynamic route recalculation | §6.3 (`GET /routes/active`) |
| Uncertain/conflicting reports | §7 (fields `status`, `uncertainty_penalty`, `conflicting_with` on endpoints §4 and §6) |
| Emergency simulation | §8 (`GET /simulation/scenarios`, `POST /simulation/scenarios/{id}/run`, `GET /simulation/runs/{id}`) |

---

## 10. Out of Scope for This Specification

Consistent with SRS §9/§11 and Architecture Document §11:

- No endpoints for a dedicated Volunteer/Coordinator dashboard/tooling.
- No complex authentication/authorization endpoints — user identity remains **TBD** (§1).
- No endpoints that lock in a specific routing engine/algorithm — the `POST /routes` contract only defines the request/response shape, not how the Routing Module computes the route internally.
- No endpoints for multi-disaster or hazard types beyond the 6 MVP types.
- No separate endpoint for "view evidence" as a standalone feature — evidence is only a field on the hazard response (§4.2), per Domain-Risk-Model §6 which treats evidence as a data attribute, not a required UI feature.
- Real-time notification delivery (push/websocket) is not specified — only the minimum polling contract (§6.3, §8.3) is defined; **TBD** for further implementation.

---

**Document status:** API Specification for the QuakeRoute 10-day hackathon MVP, derived from `SRS.md`, `Domain-Risk-Model.md`, and `Architecture-Document.md`. No requirement, domain entity, risk-model formula, or architectural decision has been changed by this document. The routing engine remains intentionally `TBD`. Items marked `TBD` in the source documents remain `TBD` here.
