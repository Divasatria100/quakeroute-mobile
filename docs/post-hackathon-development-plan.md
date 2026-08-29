# QuakeRoute — Post-Hackathon Development Plan
*RescueHacks 2026 — Devpost Supplementary Document*

QuakeRoute is a 10-day hackathon prototype that explores risk-aware navigation for the period immediately after an earthquake. This plan outlines how the prototype could evolve responsibly beyond the hackathon without overstating its current capabilities.

---

## 1. Current Prototype

QuakeRoute currently demonstrates a complete, end-to-end decision loop in a controlled environment — not a production emergency system.

**Implemented and demonstrable:**

* **Flutter mobile application** — Dynamic Safety Map, destination selection (shelters/medical facilities), hazard reporting flows, route display, and Emergency Simulation. Built with `flutter_map`, `Riverpod`, `geolocator`, `dio`, and `image_picker`.
* **Laravel REST API** — Modular monolith (`/api/v1`) handling hazard reporting, hazard retrieval, destinations, routing, and simulation. Single deployable unit with `Hazard`, `AI`, `Risk`, `Routing`, and `Simulation` modules.
* **PostgreSQL + PostGIS** — Single spatial datastore for road nodes/segments (`geography` with `GIST` indexes), hazards, routes, and simulation runs.
* **OpenStreetMap** — Base map tiles and controlled road network substrate for the MVP; road network is seeded and stored in PostGIS, not consumed live at runtime.
* **Community hazard reporting** — Three modes feeding the same structured pipeline: **Photo** (AI Vision suggestion → user Confirm/Edit/Reject), **Text** (free text → AI extraction yielding 1..N hazards), and **Quick Report** (predefined category + default confidence). Voice is architected (`Voice`/`AIVoiceExtraction`) but returns `501 Not Implemented` and is disabled in the UI.
* **AI-assisted hazard understanding** — Provider-agnostic `AIProviderInterface` (`FakeAIProvider` for offline/tests, `HttpAIProvider` via OpenRouter/Featherless). AI converts raw observations into candidate hazards (`type`, `severity`, `confidence`, `road_impact`) but never decides routes or assigns lifecycle status.
* **Risk-aware routing** — In-app Dijkstra (`RiskAwareRoutingService` + `GraphBuilder`) over the formula `Segment Routing Cost = Base Travel Cost + Hazard Penalty + Uncertainty Penalty` (`Blocked` = excluded). Hazard penalty uses `max(SeverityWeight × ConfidenceFactor)`; uncertainty penalty is weighted by status.
* **Emergency Simulation** — GPS-free crosshair-based simulation center, deterministic synthetic 4×4 grid network (seed + rounded center → reproducible UUIDs), 5 synthetic destinations, and 6 seeded scenarios (`no_hazard`, `blocked_road`, `high_risk_hazard`, `new_hazard_during_navigation`, `conflicting_reports`, `ai_vision_hazard_report`) with side-by-side **baseline route vs. risk-aware route** comparison. Synthetic data is isolated per run and does not affect the home map.

All behaviors are reproducible in simulation without requiring a real disaster.

---

## 2. Immediate Next Steps

The next phase focuses on replacing synthetic assumptions with verifiable inputs and hardening the core loop — no new product category is introduced.

### Real World Data
Integrate verified external sources to complement community reports: official disaster feeds, road closure data from transportation authorities, emergency shelter/medical facility registries, and authoritative geographic datasets (e.g., city-scale OpenStreetMap extracts). This reduces reliance on the synthetic grid used for the demo and aligns with PRD §19 and `tech-stack` §4 (`PostgreSQL + PostGIS` already supports this extension).

### Hazard Verification
Make community reports more reliable without treating any single report as truth:
* AI assistance remains an observation, not a verdict — confidence stays separate from severity (`Domain-Risk-Model` §5.2) and photo suggestions stay `PendingConfirmation` until user confirmation.
* Reliability improves through multiple corroborating reports, timestamps for staleness handling, geographic context (Location → Road Segment resolution), and verification signals that promote `Reported` → `Confirmed` or produce `UncertainConflicting` with an uncertainty penalty when reports materially disagree.

### Routing Improvements
Calibrate the MVP assumptions (`RISK_SEVERITY_*`, `RISK_UNCERTAINTY_*`, staleness decay — all currently `TBD`/`MVP defaults`) against simulation results and historical data; refine uncertainty handling so conflicting reports scale proportionally; enable automatic dynamic rerouting when a new hazard intersects an active route; and expand road network coverage from the controlled grid to a larger PostGIS graph without changing the Risk/Routing contracts.

### Offline and Low Connectivity Support
Earthquake conditions often degrade connectivity. Post-hackathon work would add cached map tiles, cached emergency information (destinations, last known hazards), and on-device route fallback so users retain situational awareness when the network is unreliable. Offline design is explicitly scoped as future work in PRD §19 and `architecture-document` §11.

---

## 3. Validation Before Real Deployment

QuakeRoute **must not be used in real emergencies** in its current form. Any path to deployment requires staged validation:

```text
Prototype
   ↓
Controlled Testing
   ↓
Field Validation
   ↓
Partnership
   ↓
Real World Deployment
```

* **Prototype** — The current synthetic simulation on a controlled network, as validated by the 6 scenarios.
* **Controlled Testing** — Replay against historical disaster data and additional synthetic networks to tune severity/uncertainty weights and confirm `TBD` parameters do not produce unsafe detours.
* **Field Validation** — Limited, supervised field exercises with test routes and volunteer reporters to measure reporting friction, AI extraction accuracy, and rerouting latency in realistic conditions.
* **Partnership** — Collaboration with emergency response organizations, local authorities, and shelter/medical providers to align data standards, operational procedures, and legal requirements before any public use.
* **Real World Deployment** — Only after the above stages, and with continuous monitoring.

---

## 4. Responsible Deployment

QuakeRoute is a **decision support system**, not a replacement for emergency responders, official emergency services, doctors, or other trained professionals.

* Hazard information may be incomplete, outdated, or incorrect — especially when sourced from community reports.
* AI interpretation may contain errors and must not be treated as ground truth; the architecture already enforces this (AI output requires confirmation and carries confidence).
* Official emergency information and responder instructions remain authoritative whenever available.
* The system must communicate uncertainty clearly (confidence/status, distinct hazard visualization — never color alone) rather than presenting any route as "safe."
* Real-world deployment requires extensive validation, safety testing, and operational readiness beyond what a 10-day prototype can provide.

---

## 5. Long Term Vision

The long-term goal is a reliable **risk-aware emergency navigation layer** that helps people make faster, better-informed routing decisions when conventional navigation no longer reflects rapidly changing conditions.

Building on the existing Hazard → Risk → Routing abstraction (which does not need to be rebuilt to add data sources), potential future capabilities include:

* Verified real-time disaster data alongside community reports
* Up-to-date emergency shelters, medical facilities, and evacuation routes
* Offline emergency navigation for low-connectivity areas
* Improved hazard verification using corroboration and authoritative signals
* Integration with official disaster response systems and responder-facing dashboards

These extensions follow directly from PRD §19 and the current modular architecture. No capability is claimed as already implemented beyond what Section 1 describes.

---

*This plan is consistent with `README.md`, `PRD.md`, `SRS.md`, `Domain-Risk-Model.md`, `AI-Requirements.md`, `Architecture-Document.md`, `API-Specification.md`, `Database-Schema.md`, and `tech-stack.md`. Current capabilities and future plans are intentionally separated.*
