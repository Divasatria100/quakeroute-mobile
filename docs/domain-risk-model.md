# QuakeRoute — Domain Model and Risk Model

## 0. Document Purpose and Status

This document defines the **domain model** (the core entities and how they relate to each other) and the **risk model** (how those entities are turned into a routing cost) that underlie QuakeRoute.

- **Source of truth:** `PRD.md` and `SRS.md`. This document does not introduce new requirements, features, or product decisions. It elaborates on concepts that both source documents already describe (hazard, severity, confidence, status, road impact, risk-aware routing, dynamic recalculation, uncertainty/conflicting reports) so that they can be reasoned about consistently before any technical design (data model, API, code) is produced.
- **Not covered here:** database schema, API specification, or source code. Those are implementation artifacts that should be derived *from* this document, not folded into it.
- **Numbers:** Where the PRD/SRS mark a value as TBD (e.g. exact confidence weights, decay curves, penalty magnitudes), this document keeps it as `TBD` and instead specifies *what the value depends on* and *how it should be validated*. No threshold or parameter is invented without a stated basis in the PRD/SRS.
- **Conceptual vs. implementation:** This document is deliberately provider-agnostic and algorithm-agnostic, consistent with PRD §13 and SRS §7 (FR-034: the routing algorithm itself is an implementation detail). Where a concrete implementation choice would normally be needed (e.g., "which shortest-path variant"), this document stops at the level of *what the cost function must express*, not *how a routing library computes over it*.

---

## 1. End-to-End Domain Flow

QuakeRoute's core information flow, as defined in PRD §7 and SRS §2, is:

```
User Observation
   │
   ▼
Multimodal Reporting (Photo / Text / Quick Tap / [Voice])
   │
   ▼
AI Hazard Understanding
   │
   ▼
Structured Hazard (Type + Location + Road Impact)
   │
   ▼
Severity + Confidence
   │
   ▼
Uncertainty (status: single report vs. conflicting vs. corroborated)
   │
   ▼
Road Impact (effect on the segment: passable / partially blocked / blocked)
   │
   ▼
Risk (Hazard Penalty + Uncertainty Penalty, per affected segment)
   │
   ▼
Routing Cost (Base Travel Cost + Risk)
   │
   ▼
Route (risk-aware path selection)
```

This document walks the flow in this order — each section below builds on the previous one. The same flow re-enters at "Structured Hazard" whenever a *new* observation arrives, which is what drives dynamic recalculation (Section 12).

---

## 2. Domain Entities and Relationships

### 2.1 Entity Overview

| Entity | What it represents | Defined in PRD/SRS |
|---|---|---|
| **Observation / Report** | A single raw input from a person — a photo, a piece of free text, a quick-tap category selection, or (if implemented) a voice transcript. | PRD §7–§10; SRS §4.3–§4.6 |
| **AI Hazard Understanding output** | The AI layer's proposed structuring of one Observation into one or more candidate hazards (type, severity, road impact, confidence). Not yet an authoritative Hazard until it passes the applicable confirmation step. | PRD §11, §9.7; SRS §6, §4.7 |
| **Hazard** | A structured record of a reported or detected road-condition risk: type, location, severity, confidence, source, status, road impact, timestamp, evidence. | PRD §12; SRS §1.4 |
| **Road Segment** | An edge in the controlled road network that a route can traverse. Hazards attach to a location, which resolves to one or more road segments. | PRD §12 (Location), §13; SRS §4.9 |
| **Road Impact** | The effect of a Hazard (or the aggregate of multiple Hazards) on a Road Segment's usability: passable, partially blocked, or blocked. | PRD §12; SRS §1.4 |
| **Risk (segment-level)** | The combination of Hazard Penalty and Uncertainty Penalty computed for a Road Segment, derived from the Hazard(s) attached to it. | PRD §13; SRS §4.9 |
| **Routing Cost (segment-level)** | Base Travel Cost + Risk, for a given Road Segment. | PRD §9.9, §13; SRS §1.4, §4.9 |
| **Route** | An ordered sequence of Road Segments from the user's location to a selected destination, chosen by minimizing total Routing Cost. | PRD §8, §9.9; SRS §4.2, §4.9 |
| **Community Reporter** | The role that produces Observations. Not a separate account type — any user, including an Evacuee, can act as one. | SRS §3.2 |
| **Evacuee** | The role that consumes Routes and receives recalculated Routes when conditions change. | SRS §3.1 |

### 2.2 Relationship Diagram

```
 Community Reporter
        │ submits
        ▼
   Observation ──1..N──▶ AI Hazard Understanding ──1..N──▶ candidate Hazard(s)
                                                                   │ confirmation / default confidence
                                                                   ▼
                                                                Hazard ──attached to──▶ Location ──resolves to──▶ Road Segment(s)
                                                                   │                                                     │
                                                                   │ contributes to                                     │ has
                                                                   ▼                                                     ▼
                                                        Road Impact (per segment)                              Base Travel Cost
                                                                   │                                                     │
                                                                   ▼                                                     │
                                                        Risk = Hazard Penalty + Uncertainty Penalty                      │
                                                                   │                                                     │
                                                                   └──────────────────┬──────────────────────────────────┘
                                                                                      ▼
                                                                        Routing Cost (per segment)
                                                                                      │
                                                                                      ▼
                                                                          Route (min-cost path)
                                                                                      │
                                                                                      ▼
                                                                                  Evacuee
```

### 2.3 Cardinality Notes

- **One Observation → one or more candidate Hazards.** A single text or voice report can describe multiple hazards (PRD §9.5, FR-016). A photo report typically yields one candidate hazard (FR-011). A quick-tap report always yields exactly one (FR-019).
- **One Hazard → one Location → one or more Road Segments.** This document does not prescribe how a Location resolves to specific segments (that is a routing/data-model concern), but conceptually a hazard could affect the start/end of a segment, an intersection shared by several segments, or a single segment directly.
- **One Road Segment → zero or more active Hazards.** Multiple hazards can coexist on the same segment (Section 10). Road Impact and Risk for a segment are therefore always computed as an aggregate over *all* currently active hazards on that segment, not a single hazard in isolation.
- **One Route → many Road Segments**, each contributing its own Routing Cost; the Route's total cost is the sum across its segments (standard shortest/min-cost-path assumption, consistent with PRD §13's "Base Travel Cost + Hazard Penalty + Uncertainty Penalty" formula being defined per traversal).

---

## 3. Observation and Hazard

An **Observation** is what a person actually submits — it is *not yet* a Hazard. This distinction matters because the PRD is explicit that AI output is "an observation or prediction with associated uncertainty, not an absolute statement of ground truth" (PRD §11) and that the system "must not automatically treat AI-detected or user-reported hazards as verified fact" (PRD §6, §17; SRS §8).

A **Hazard** is the structured, routable record that results once an Observation (via AI Hazard Understanding, or directly for quick-tap reports) has been given the required structured fields. Per PRD §12 / SRS §1.4, every Hazard has:

| Attribute | Purpose |
|---|---|
| Type | Category — one of the MVP's supported types (Section 3.1) |
| Location | Where on the road network |
| Severity | Estimated impact level (Section 4) |
| Confidence | How certain the system is (Section 5) |
| Source | Which reporting mode produced it (AI Vision, text, quick report, voice) |
| Status | Lifecycle state (Section 7) |
| Road Impact | Effect on segment usability (Section 9) |
| Timestamp | When reported/last updated — the basis for staleness handling (Section 11.3) |
| Evidence | Supporting input — photo, report text (Section 6) |

### 3.1 Supported Hazard Types (MVP)

Per PRD §12, deliberately narrow for a 10-day build:

- Debris / Rubble
- Road Blockage
- Fire
- Flood
- Electrical Hazard
- Visible Building Damage

The risk model in this document treats hazard **type** as an input to severity estimation and to conflict detection (Section 11.2), but does not define type-specific formulas — the PRD does not specify that some types are inherently more dangerous than others, so no such weighting is assumed here. If future validation shows this is needed, it belongs in the risk model's severity step, not as a new domain concept.

---

## 4. Severity

**Definition (SRS §1.4):** Severity is the estimated impact level of a hazard on a road segment's usability/danger.

### 4.1 Where severity comes from

| Reporting mode | Severity source |
|---|---|
| Photo / AI Vision | AI-estimated (FR-011) |
| Text | AI-estimated from the description (FR-016/FR-017) |
| Quick tap | Not AI-estimated — a default appropriate to the selected category (FR-020), exact default **TBD** |
| Voice (if implemented) | AI-estimated via the text-extraction path (FR-023) |

### 4.2 Conceptual scale

The PRD/SRS do not fix a severity scale (numeric range, number of bands, or labels). To keep the model simple, explainable, and testable within a 10-day build, this document assumes an **ordinal scale** (e.g., Low / Medium / High) rather than a continuous score, because:

- It is easier to explain to a user or evaluator ("this hazard is High severity") than an opaque numeric score.
- It is easier for AI output and quick-tap defaults to agree on, since AI models are more reliable at coarse classification than at precise numeric estimation.
- It maps directly onto PRD §15 Scenario 3's language ("high-severity hazard").

The exact number of bands, their labels, and the numeric penalty each maps to are **TBD** — to be fixed during implementation and validated via the simulation scenarios (Section 13).

### 4.3 What severity does *not* determine alone

Severity by itself does not determine Road Impact or whether a segment is blocked. Per PRD §13, only **status = Blocked** removes a segment from consideration; a high-severity hazard on a segment that is still passable makes that segment expensive, not unusable (PRD §15 Scenario 3). Severity feeds into the Hazard Penalty (Section 14), and Road Impact is a related but distinct attribute of the hazard, set alongside severity by AI/quick-tap output (Section 9).

---

## 5. Confidence

**Definition (SRS §1.4):** Confidence is a value representing how certain the system is that a hazard report reflects actual conditions.

### 5.1 Where confidence comes from

- AI Vision and AI text extraction must produce a confidence value for every hazard they output (FR-011, FR-016/017, FR-024).
- Quick-tap reports receive a **default confidence** appropriate to a self-reported, non-AI-processed category selection (FR-020) — exact value **TBD**. Conceptually this default should be lower than a high-confidence AI/confirmed reading, since a quick tap carries no supporting evidence beyond the category itself (see Section 6).
- Confidence can change over time as new, related information arrives (FR-028) — e.g., a second matching report increases confidence; a contradicting report does not increase confidence and instead triggers the conflicting-reports path (Section 11.2).

### 5.2 Confidence vs. Severity — why both exist

These are two independent axes and must not be collapsed into one number:

- **Severity** answers: *if this hazard is real, how bad is it?*
- **Confidence** answers: *how sure are we that this hazard is real / accurately described?*

A hazard can be high-severity/low-confidence (e.g., a single unconfirmed report of a collapsed building) or low-severity/high-confidence (e.g., an AI-Vision-confirmed small debris pile). The risk model (Section 13) must combine both, not treat either as a proxy for the other. This directly reflects PRD §13's framing: "segments with high-severity, high-confidence hazards receive a large penalty" — the word "and" is load-bearing.

### 5.3 Confidence vs. Uncertainty — related but not identical

Confidence is a **per-hazard** value. **Uncertainty**, as used in this model, is a **per-segment** condition that arises specifically from *disagreement or lack of confirmation* across the report(s) affecting a segment — most concretely, conflicting reports (Section 11.2) or a status that has not yet reached "Confirmed" (Section 7). A segment can have a single hazard with only moderate confidence (ordinary uncertainty, reflected in that hazard's own confidence value) or it can have an elevated, distinctly-flagged uncertain/conflicting status because two or more reports disagree (a stronger, structurally different kind of uncertainty). The routing cost model treats these with the same mechanism — an Uncertainty Penalty — but the *status* field is what distinguishes "moderate confidence" from "explicitly conflicting" for the user (FR-029, NFR-004).

---

## 6. Evidence and Provenance

**Definition (PRD §12):** Evidence is the supporting input for a hazard — e.g., a photo, report text.

Evidence and Source together form the hazard's **provenance** — where it came from and what backs it up. This matters for three reasons the PRD/SRS make explicit:

1. **Explainability (NFR-004):** the system must communicate confidence/status in a way that distinguishes certainty levels. Evidence is part of what a user or coordinator would inspect to understand *why* a hazard has the confidence it does, even though the PRD does not require a dedicated "view evidence" feature — evidence is a data attribute of the Hazard record regardless of whether/how it is surfaced.
2. **AI output is not ground truth (PRD §6, §11, §17):** confirmation of AI-suggested hazards (FR-012/FR-013) is only meaningful because the evidence (the photo, or the text) is retained and reviewable alongside the AI's proposal — the user confirms *against the evidence*, not against the AI's label alone.
3. **Source affects the default confidence baseline (Section 5.1):** Source (AI Vision, text-extraction, quick-tap, voice) is not itself a confidence multiplier prescribed by the PRD, but it is the input that determines *which* confidence-assignment path a hazard goes through (AI-estimated vs. default).

This document does not define an evidence storage format, retention policy, or privacy handling — SRS §5 (NFR-006) marks privacy as TBD, and storage/format is an implementation detail.

---

## 7. Hazard Status Lifecycle

**Definition (PRD §12, SRS §1.4):** Status is the hazard's current lifecycle state. The exact status set is **TBD**, but per FR-027 it must, at minimum, distinguish "reported/unconfirmed" from "confirmed."

### 7.1 Conceptual states

Based on the PRD/SRS vocabulary actually used across both documents (Reported, Uncertain, Confirmed, Verified, and — specific to the conflicting-reports flow — a "Conflicting Reports" state), the following conceptual lifecycle is consistent with all stated requirements. Exact naming/set is still TBD for implementation, but the *behavioral* distinctions below are required by FR-025, FR-027, FR-028, FR-039:

```
 New Observation processed
          │
          ▼
     [Reported]  ──── AI/quick-tap output, not yet confirmed (FR-025)
          │
          ├── user confirms (photo flow, FR-013) ──────────────▶ [Confirmed]
          │
          ├── another report on same segment agrees ───────────▶ [Confirmed] (confidence increases, FR-028)
          │
          ├── another report on same segment disagrees ────────▶ [Uncertain / Conflicting] (FR-038, FR-039)
          │
          └── no further information ───────────────────────────▶ remains [Reported] (subject to staleness, Section 11.3)

     [Uncertain / Conflicting]
          │
          └── further corroborating reports/verification signals arrive (PRD §14) ──▶ may shift toward [Confirmed] or resolve
```

### 7.2 What status is *for*

Status exists so that the risk model and the UI can distinguish hazards that should be trusted more from those that shouldn't, independent of the numeric confidence value — it is the human/UI-facing label, while confidence is the machine-facing number the routing cost actually uses. Both are required to be present and visible (FR-026, FR-027, FR-029).

Status transitions are explicitly required to be possible (FR-028) but the PRD/SRS do not specify a state machine diagram, transition triggers beyond "new matching/conflicting information," or numeric thresholds for transitions. Those remain **TBD** for implementation; this document only asserts that the transitions must be capable of both directions (increasing and decreasing trust) as new information arrives.

---

## 8. Uncertainty (as a Modeled Quantity)

Uncertainty is not a separate entity — it is a **property of the current information state of a Road Segment**, expressed through the combination of:

1. The confidence values of the hazard(s) currently attached to it, and
2. Whether that segment's status is Reported/Uncertain/Conflicting rather than Confirmed/Verified.

The system's guiding stance (PRD §14): **do not resolve uncertainty by discarding information or by treating one report as absolute truth.** Concretely, this means the risk model must never let uncertainty *silently disappear* — it must always show up either as a lower effective hazard penalty (via confidence, Section 5.2) or as an explicit uncertainty penalty (Section 15), never as "hazard ignored" or "hazard treated as fully confirmed."

---

## 9. Road Segment and Road Impact

### 9.1 Road Segment

A Road Segment is the unit the routing engine reasons about — an edge of the controlled road network (PRD §12, §13; SRS §4.9). It has a **Base Travel Cost** (conventional distance/time-based cost, independent of hazards — SRS §1.4) and, at any point in time, zero or more active Hazards attached to it (directly, or via a Location that resolves to it).

### 9.2 Road Impact

**Definition (PRD §12, SRS §1.4):** Road Impact is the effect of a hazard on a road segment's usability — e.g., passable, partially blocked, blocked.

Road Impact is set per hazard (as one of AI/quick-tap's required output fields — FR-011, FR-017, FR-020, FR-024) but what actually matters for routing is the **segment-level aggregate** Road Impact, since a segment can carry multiple hazards (Section 10). This document treats segment-level Road Impact as derived from the most severe road-impact value among the segment's currently active hazards:

```
SegmentRoadImpact = worst( RoadImpact(h) for h in ActiveHazards(segment) )
```

where "worst" follows the ordering `Passable < Partially Blocked < Blocked`. This is the simplest rule consistent with PRD §13's requirement that a fully blocked segment must be excluded regardless of what else is true about it — a single blocking hazard should dominate. Whether "worst-of" is sufficient for the MVP or whether some combination (e.g., two "partially blocked" hazards escalating to "blocked") is needed is **TBD**, to be assessed via the multi-hazard scenario testing described in Section 13.

---

## 10. Multiple Hazards on One Road Segment

Neither the PRD nor SRS give an explicit rule for combining more than one hazard on the same segment — this is a gap this document must resolve conceptually (without inventing unfounded numbers) because Section 9's "worst road-impact" rule needs a matching rule for the *penalty*, not just the status.

Two candidate approaches, both explainable and testable:

| Approach | Rule | Rationale | Risk |
|---|---|---|---|
| **Max (worst-hazard-dominates)** | `HazardPenalty(segment) = max( HazardPenalty(h) for h in ActiveHazards(segment) )` | Simple, explainable ("this segment's risk is driven by its worst hazard"), consistent with how Road Impact is already aggregated (Section 9.2). | May understate risk when several independently-dangerous hazards coexist. |
| **Sum (cumulative)** | `HazardPenalty(segment) = Σ HazardPenalty(h) for h in ActiveHazards(segment)` | Reflects that more problems generally mean more risk. | Can produce runaway costs and is harder to explain/tune in a 10-day build; not clearly justified by any PRD/SRS statement. |

**Recommendation for MVP:** use **Max**, for consistency with the Road Impact aggregation rule (Section 9.2) and because it keeps the model easy to explain and to test against the six simulation scenarios (none of which requires cumulative stacking to produce their expected outcome). This is a *modeling recommendation*, not a requirement drawn directly from the PRD/SRS — it should be validated (Section 13) rather than assumed correct, and the exact aggregation rule remains open to revision (`TBD`) if scenario testing shows Max under-penalizes genuinely compounding hazards.

Uncertainty Penalty aggregation (Section 15) follows the same Max-based logic: a segment's uncertainty penalty is driven by its most uncertain/conflicting hazard, not summed across all hazards.

---

## 11. Special Handling Cases

### 11.1 Blocked vs. Dangerous Road

These are two distinct outcomes of the same underlying model and must not be conflated:

| | Blocked | Dangerous (but passable) |
|---|---|---|
| **Road Impact** | Blocked | Passable or Partially Blocked |
| **Routing treatment** | Excluded from route candidates — effectively infinite/unusable cost (FR-032, PRD §13, §15 Scenario 2) | Included, but with a large Hazard Penalty that makes it unattractive unless no better alternative exists (PRD §13, §15 Scenario 3) |
| **Can routing still use it?** | No — only if literally no other path exists is this ever revisited, and the PRD does not describe such a fallback; absence of a route is an acceptable outcome the model must be able to represent | Yes — it is simply expensive, and the routing engine may still select it if every alternative is even more expensive |
| **Example (PRD §15)** | Scenario 2 — segment C→D fully blocked by debris; system must find an alternative (A→B→E→F→D) | Scenario 3 — a segment is passable but carries a high-severity, high-confidence hazard; system prefers a slightly longer alternative |

The distinction exists precisely so the model doesn't over-react (treating "dangerous" as "impassable") or under-react (treating "blocked" as merely "expensive"). This is a deliberate product requirement (PRD §13, §17).

### 11.2 Conflicting Reports

Per PRD §14 and SRS §4.11 (FR-038–FR-040):

1. Two or more reports about the same segment are compared; **material disagreement** is detected (e.g., one says "blocked," another says "passable"). What counts as "material" (e.g., does a severity difference of one band count, or only a direct road-impact contradiction?) is **TBD** and needs an explicit, testable definition during implementation — this document only asserts that the detection must exist and must be based on comparing structured Road Impact / hazard-type claims about the *same* segment, not raw text similarity.
2. On detection, the segment's status becomes **Uncertain / Conflicting** — not automatically blocked, not automatically cleared (FR-039).
3. An **Uncertainty Penalty** proportional to the degree of disagreement is applied (FR-040) — exact weighting **TBD** (PRD §14 states this explicitly).
4. Additional corroborating reports or verification signals may shift status/confidence over time (FR-028) — the conflicting state is not necessarily permanent.

This is the clearest example in the whole model of the product's core stance: **preserve uncertainty rather than resolve it arbitrarily** (PRD §14).

### 11.3 Stale / Old Reports

The PRD and SRS require that every hazard carry a timestamp "for this reason" — i.e., because hazard information can become stale as conditions continue to change (PRD §17; SRS §8). Neither document specifies a decay formula, staleness threshold, or automatic status downgrade — this is explicitly left open.

This document therefore states the requirement conceptually, without inventing a formula:

- The Timestamp attribute (Section 3) must be sufficient to determine a hazard's age.
- Some function of age should be able to reduce a hazard's *effective* confidence over time (since an unconfirmed report about debris from six hours ago is less trustworthy now than when it was filed) — but the exact decay behavior (linear, step-function, or none at all for the MVP) is **TBD** and should only be added if it can be validated within the 10-day scope (Section 13). If no staleness decay is implemented for the MVP, the timestamp attribute is still required (it is a MUST-level data field per PRD §12) — it would simply not yet drive a computed effect, which is an acceptable, honestly-scoped outcome for a hackathon build.
- Staleness is a *confidence-side* concern, not a status-side one, unless a future decision explicitly ties an age threshold to a status transition (also TBD).

### 11.4 New Hazard Affecting an Active Route

Per PRD §8 (alternative path) and §9.10 / SRS §4.10 (FR-035–FR-037):

1. A new hazard is reported and processed (through the normal Observation → Hazard flow, Sections 3–9).
2. The risk model updates the affected Road Segment's Risk and Routing Cost (Section 13 onward).
3. The system checks whether the affected segment(s) are on the user's **active** route (FR-035).
4. If yes, the route is recalculated (FR-036) and the new route is presented in a way distinguishable from the original (FR-037).
5. If the hazard is not on the user's active route, the safety map and risk model still update, but no recalculation is triggered for that user (PRD §8) — other users navigating through that segment would trigger their own check independently.

---

## 12. Dynamic Risk Update and Route Recalculation

This section ties Sections 3–11 together as a repeatable cycle, which is the mechanism behind PRD's "Dynamic Recalculation" stage:

```
New Observation arrives
        │
        ▼
Hazard structured (Sections 3–7)
        │
        ▼
Segment Road Impact / Risk recomputed (Sections 9, 13–15)
        │
        ▼
   Is this segment on any active route(s)?
        │
   ┌────┴────┐
   No         Yes
   │           │
   ▼           ▼
Map/risk    Route recalculated (min-cost path recomputed
updates     over updated segment costs); new route flagged
only        as distinguishable from the prior one (FR-037)
```

Two properties of this cycle are required by the PRD/SRS and should be preserved by any implementation:

- **It is triggered by information, not by time.** Recalculation happens because a hazard changed the risk of a segment on the route — not on a fixed polling interval (this is implied throughout PRD §8–§10 and is what FR-035/036 describe).
- **It is scoped to affected users, not global.** Only users whose active route intersects the changed segment are recalculated for (PRD §8, "no recalculation is triggered for that user unless their route is affected").

---

## 13. Risk Model

### 13.1 Design goals

Per the task constraints: the risk model must be **simple**, **explainable**, and **realistic enough for a 10-day MVP**, must not invent unjustified numbers, and must reuse the exact formula skeleton already defined in PRD §13 / §9.9 and SRS §1.4:

```
Route Cost = Base Travel Cost + Hazard Penalty + Uncertainty Penalty
```

This document expands each term without changing this skeleton.

### 13.2 Term definitions

| Term | Scope | Definition |
|---|---|---|
| **Base Travel Cost** | per segment | Conventional distance/time-based cost, independent of hazards (SRS §1.4). Not part of the risk model itself — it is the routing engine's baseline input. |
| **Hazard Penalty** | per segment | An added cost derived from the severity and confidence of the segment's active hazard(s) (Section 14). |
| **Uncertainty Penalty** | per segment | An added cost applied while a segment's hazard status is unconfirmed or conflicting (Section 15), independent of the Hazard Penalty term. |
| **Segment Routing Cost** | per segment | `Base Travel Cost + Hazard Penalty + Uncertainty Penalty` |
| **Route Cost** | per route | Sum of Segment Routing Cost over every segment in the route (standard additive path-cost assumption for shortest/min-cost-path routing). |

### 13.3 Why two separate penalty terms (not one)

PRD §13 already specifies both terms exist; this document explains *why* that structure is the right one, so it isn't accidentally collapsed into a single "risk score" during implementation:

- **Hazard Penalty** answers "how bad is what we believe is there," scaled by how much we believe it (Section 14). It responds to severity + confidence of confirmed/likely hazards.
- **Uncertainty Penalty** answers "how much should we distrust our own picture of this segment right now," independent of any specific hazard's severity. It exists specifically so that a segment with a genuinely unclear situation (e.g., conflicting reports, Section 11.2) is penalized for the *ambiguity itself*, even before we know whether the true condition is mild or severe.

Keeping them separate is what lets the model satisfy PRD §15 Scenario 5: a segment with conflicting reports must be "neither treated as fully blocked nor fully safe" — a pure severity-based penalty could not produce that outcome on its own, because there is no confirmed severity to penalize; the Uncertainty Penalty is what fills that role.

---

## 14. Hazard Penalty

### 14.1 Formula shape

```
HazardPenalty(segment) = max( SeverityWeight(h) × ConfidenceFactor(h)  for h in ActiveHazards(segment) )
```

(using the Max aggregation rule from Section 10.)

- **SeverityWeight(h):** a monotonically increasing function of the hazard's severity band (Section 4.2) — higher severity → larger base penalty. Exact weight per band is **TBD**, to be set and tuned via the simulation scenarios.
- **ConfidenceFactor(h):** a value between 0 and 1 (or an equivalent scaling) that discounts the severity-based penalty according to how much the hazard is trusted. High confidence → factor near 1 (full penalty applied). Low confidence → factor closer to 0 (penalty heavily discounted, since we are not sure the hazard is real). Exact function is **TBD**.

This shape is directly justified by PRD §13's own language: *"segments with high-severity, high-confidence hazards receive a large penalty."* The multiplicative form is the simplest function that satisfies this: penalty is large only when *both* factors are large, and small if *either* factor is small — which is exactly the intended behavior (a high-severity but low-confidence hazard should not dominate routing the way a high-severity, high-confidence one does).

### 14.2 Why multiplicative, not additive

An additive form (`SeverityWeight + ConfidenceContribution`) would let a very low-confidence, very high-severity hazard still produce a large penalty (since severity alone could dominate the sum), which contradicts PRD §13's stated intent that confidence should meaningfully temper the penalty. A multiplicative form guarantees that low confidence suppresses the penalty regardless of severity — closer to the product's stated behavior and easier to explain in a demo ("we discount the severity by how sure we are").

### 14.3 What must be validated (not assumed)

- The exact severity bands and their weights.
- The exact confidence-to-factor mapping (linear? stepped?).
- Whether Max-aggregation (Section 10) or an alternative combination rule better matches expected behavior when multiple hazards are present.

All three are explicitly marked `TBD` and are candidates for the validation activity described in Section 17.

---

## 15. Uncertainty Penalty

### 15.1 Formula shape

```
UncertaintyPenalty(segment) = UncertaintyWeight(SegmentStatus)
```

where `SegmentStatus` is the aggregate status of the segment (Section 7), most notably distinguishing:

- **Confirmed / Verified** → little to no uncertainty penalty (the system is reasonably sure of the condition, whatever it is — its risk is already captured by the Hazard Penalty).
- **Reported (single, unconfirmed)** → a moderate uncertainty penalty.
- **Uncertain / Conflicting** → the largest uncertainty penalty, and — per PRD §14 — "proportional to the degree of disagreement" between the conflicting reports. What "degree of disagreement" means numerically (e.g., how far apart the reports' claimed severities or road-impact levels are) is **TBD** and needs a concrete, testable definition during implementation; conceptually, more sharply contradictory reports (e.g., "blocked" vs. "fully passable") should be penalized more than mildly differing ones (e.g., "moderate debris" vs. "minor debris").

### 15.2 Relationship to Hazard Penalty

The Uncertainty Penalty is **additive**, not multiplicative, with the Hazard Penalty (per the PRD §13 skeleton: `Base + Hazard Penalty + Uncertainty Penalty`). This is intentional: even a segment with *no* confirmed hazard (Hazard Penalty ≈ 0) but a conflicting status should still carry cost, because the ambiguity itself is the risk (Scenario 5, Section 11.2) — a multiplicative relationship would incorrectly zero out the uncertainty penalty whenever the hazard penalty is small.

### 15.3 What must be validated (not assumed)

- The exact per-status uncertainty weight.
- The exact function relating "degree of disagreement" to penalty magnitude.

Both are `TBD`, consistent with PRD §14's explicit statement that this weighting is TBD.

---

## 16. Blocked Road and Final Routing Cost

### 16.1 Blocked handling

```
if SegmentRoadImpact(segment) == Blocked:
    SegmentRoutingCost(segment) = ∞   (or: segment excluded from the routable graph)
else:
    SegmentRoutingCost(segment) = BaseTravelCost(segment) + HazardPenalty(segment) + UncertaintyPenalty(segment)
```

This directly implements FR-032 ("blocked segments treated as unusable / effectively infinite cost"). Whether an implementation literally uses an infinite cost value or removes the segment/edge from the graph entirely is an implementation detail (either satisfies FR-032); this document only requires that the *effect* — the segment is never selected by the routing engine — is guaranteed.

### 16.2 Final Routing Cost (per route)

```
RouteCost(route) = Σ SegmentRoutingCost(segment)   for segment in route
```

A **Route** is the sequence of segments, from the user's current location to the selected destination, that minimizes `RouteCost` subject to no segment in the route being Blocked. This is the min-cost-path problem that FR-033/FR-034 describe: the specific algorithm used to solve it is explicitly out of scope for both the PRD and this document.

---

## 17. Risk-Aware Routing

Putting Sections 13–16 together, risk-aware routing behaves as follows, matching PRD §13 and §15's scenario language directly:

- **No hazards anywhere:** Hazard Penalty and Uncertainty Penalty are ~0 everywhere; the risk-aware route matches the conventional shortest/fastest route (PRD §15 Scenario 1, FR-033).
- **A segment is fully blocked:** it is excluded; the engine finds the best remaining path (PRD §15 Scenario 2, FR-032).
- **A segment carries a high-severity, high-confidence hazard but is still passable:** its cost rises substantially (large Hazard Penalty), which may cause a longer-but-cheaper alternative to be preferred, without excluding the segment outright (PRD §15 Scenario 3, FR-033).
- **A segment has conflicting reports:** it is neither blocked nor free of cost; the Uncertainty Penalty raises its cost proportionally to the disagreement, and it remains selectable if no better alternative exists (PRD §15 Scenario 5, FR-038–040).
- **A new hazard appears on the active route:** the affected segment's cost is recomputed and, if the user's active route is affected, a new min-cost route is computed and shown distinguishably (PRD §15 Scenario 4, FR-035–037).
- **A hazard is reported via AI Vision and confirmed:** it enters the model exactly as any other confirmed hazard would, and affects routing according to its resulting severity/confidence (PRD §15 Scenario 6, FR-010–014).

This is not new behavior — it is the direct consequence of the formulas in Sections 13–16 applied to each scenario, and is included here to make the mapping from formula to expected product behavior explicit and checkable.

---

## 18. Assumptions and Limitations

### 18.1 Assumptions made in this document (beyond what PRD/SRS state verbatim)

These are modeling choices needed to make the risk model concrete enough to build and test; they are flagged so they can be revisited without confusing them with fixed requirements:

1. Severity and Confidence are modeled as **ordinal/discrete** values (e.g., bands), not continuous scores, for explainability (Section 4.2).
2. Multiple hazards on one segment are aggregated using a **Max** rule for both Road Impact and Hazard Penalty, not summed (Sections 9.2, 10).
3. Hazard Penalty is **multiplicative** in severity and confidence; Uncertainty Penalty is **additive** to Hazard Penalty (Sections 14.2, 15.2).
4. Staleness/decay of confidence over time is a candidate mechanism justified by PRD §17's mention of timestamps, but is not a confirmed MVP requirement — it is optional and TBD (Section 11.3).
5. "Material disagreement" between reports (needed to detect conflicts, Section 11.2) is assumed to be based on comparing structured Road Impact / severity claims about the same segment, not raw text similarity — the PRD/SRS do not specify the comparison mechanism.

### 18.2 Limitations inherited directly from the PRD/SRS

- **AI output is never ground truth** (PRD §6, §11, §17; SRS §6, §8) — the domain model above always keeps hazards as observations/predictions with confidence, never as asserted fact, until (and even after) confirmation.
- **No route is a safety guarantee** (PRD §6, §17; SRS §8) — the risk model informs route *selection*, it does not certify safety. This must be communicated to users (NFR-005) independent of anything in this document.
- **Single controlled scenario, limited hazard types, controlled road network** (PRD §6, §12, §18; SRS §1.2, §9, §11) — the risk model is validated only within that controlled scope; it is not claimed to generalize to arbitrary real-world road networks or hazard types without further work.
- **No coordinator/dashboard-specific domain concepts** — Volunteers/Coordinators use the same Evacuee/Community Reporter capabilities (SRS §3.3); this document does not define any coordinator-only entities.
- **Numeric parameters throughout this model (severity weights, confidence factors, uncertainty weights, disagreement scaling, staleness decay) are TBD** and are called out individually in Sections 14–15; this is a direct consequence of the PRD/SRS marking these as TBD rather than an omission in this document.

---

## 19. Validation Connection

A full Simulation & Validation document is a separate, subsequent deliverable and is intentionally not produced here. This section only states **which parts of this domain/risk model need to be exercised** by that later controlled-simulation work, and the causal chain that validation must trace.

### 19.1 Causal chain to validate

```
Hazard change  →  Risk change  →  Road (segment) cost change  →  Route decision change
```

Concretely, for each of the six scenarios already defined in PRD §15 / SRS §4.12 (FR-041–044), validation should confirm that:

| Step | What should be observably true |
|---|---|
| Hazard change | A new/updated/conflicting hazard is correctly structured (type, severity, confidence, road impact, status) per Sections 3–9. |
| Risk change | The affected segment's Hazard Penalty and/or Uncertainty Penalty change in the expected direction per Sections 13–15 (e.g., conflicting reports raise Uncertainty Penalty without changing Road Impact to Blocked). |
| Road cost change | The segment's Routing Cost changes accordingly, and — for a Blocked segment — the segment becomes unusable per Section 16. |
| Route decision change | The min-cost route recomputed over the updated costs matches the expected outcome per scenario (e.g., Scenario 2's alternative route, Scenario 3's slightly-longer-but-lower-risk route, Scenario 1's match to baseline). |

### 19.2 Model-specific items validation should resolve

Because this document deliberately leaves several parameters and aggregation choices `TBD` (Sections 10, 11.3, 14.3, 15.3, 18.1), controlled simulation is where those choices should actually be tested and tuned, specifically:

- Whether Max-aggregation (vs. an alternative) for multiple hazards on one segment produces the expected Road Impact / Hazard Penalty outcomes.
- Whether the chosen severity-band weights and confidence-factor mapping produce the "large penalty" behavior PRD §15 Scenario 3 describes, without over- or under-penalizing.
- Whether the uncertainty-penalty weighting correctly keeps a conflicting segment "neither fully blocked nor fully safe" (Scenario 5) across a range of disagreement severities.
- Whether the baseline-vs-risk-aware comparison (FR-044, PRD §16) shows the expected metrics: hazardous segments avoided, successful rerouting, route feasibility, route cost delta, and distance trade-off.

This section exists to hand off a clear starting point to the Simulation & Validation document — not to perform that validation here.

---

## 20. Traceability: PRD Problem → SRS Requirement → Domain/Risk Concept

| PRD Problem / Context | SRS Requirement(s) | Domain/Risk Concept in this document |
|---|---|---|
| Road conditions change dynamically after an earthquake (PRD §3) | FR-035, FR-036, FR-037 | Dynamic Risk Update and Route Recalculation (§12); New Hazard Affecting Active Route (§11.4) |
| Hazard information is incomplete / not every hazard is known (PRD §3) | FR-001–FR-004, FR-029 | Hazard status "Reported" as a first-class, visible state (§7); Road Impact / segment risk always computed from *currently known* hazards, never assumed complete (§9, §13) |
| Reports vary in reliability; not every report is confirmed fact (PRD §3) | FR-025, FR-026, FR-027, FR-028 | Confidence (§5); Hazard Status Lifecycle (§7); AI output as observation/prediction, not fact (§3, §6) |
| Community-generated reports affect trust (PRD §3) | FR-020, evidence/source fields (PRD §12) | Evidence and Provenance (§6); Source-dependent confidence assignment path (§5.1) |
| Emergency users need low-effort reporting (PRD §3, §4) | FR-008–FR-020 | Observation → Hazard structuring across all reporting modes (§3), feeding a single structured pipeline regardless of source |
| Two reports can conflict about the same segment (PRD §2, §14) | FR-038, FR-039, FR-040 | Conflicting Reports (§11.2); Uncertainty Penalty (§15) |
| Shortest route ≠ safest feasible route (PRD §3) | FR-030–FR-034 | Risk Model (§13); Hazard Penalty (§14); Final Routing Cost (§16); Risk-Aware Routing (§17) |
| Fully blocked segments must not be routed through (PRD §13) | FR-032 | Blocked vs. Dangerous Road (§11.1); Blocked Road handling (§16.1) |
| Hazard information can become stale (PRD §17) | Timestamp attribute (PRD §12, SRS §8) | Stale / Old Reports (§11.3) |
| System must not overreact to a single unverified report (PRD §13, §14) | FR-039, FR-040 | Uncertainty Penalty as a distinct, additive term (§15.2); "neither fully blocked nor fully safe" (§11.1, §11.2) |
| No route is a safety guarantee; AI is not ground truth (PRD §6, §17) | NFR-004, NFR-005 | Assumptions and Limitations (§18.2) — carried through as a constraint on how this model's output should be presented, not overridden by it |
| A controlled simulation is needed to demonstrate the above (PRD §15, §16) | FR-041–FR-044 | Validation Connection (§19) |

---

**Document status:** Domain and Risk Model derived from `PRD.md` and `SRS.md` for the QuakeRoute 10-day hackathon prototype. All items marked `TBD` mirror TBD items already present in the PRD/SRS, or are flagged as new modeling assumptions requiring validation (see §18.1) — none represent invented, unvalidated numeric requirements. This document does not modify, add to, or remove any requirement defined in the PRD or SRS.
