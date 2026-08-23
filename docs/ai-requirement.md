# QuakeRoute — AI Requirements

## 0. Document Status and Source of Truth

- **Source of truth:** `PRD.md`, `SRS.md`, `Domain-Risk-Model.md`, and `Simulation-Validation.md`. This document does not introduce new product concepts, features, capabilities, or numeric thresholds beyond what those four documents already define or explicitly leave `TBD`.
- **What this document is:** a detailed specification of how AI is used inside QuakeRoute — what AI must do, what AI must not do, AI inputs/outputs, AI constraints, and how AI output is consumed downstream by the domain and risk model.
- **What this document is not:** it does not modify the product concept (PRD), the system requirements (SRS), or the risk model (Domain-Risk-Model). It does not define source code, an API specification, or a database schema — those are implementation artifacts to be derived later.
- **Provider-agnostic:** no requirement in this document is tied to a specific AI vendor, model, or inference provider. Where the PRD/SRS describe an "AI inference service" as an external dependency (SRS §7), this document treats it the same way.
- **Numbers:** where a capability, threshold, or parameter is not fixed by the source documents, it is marked `TBD` here as well, rather than invented.

---

## 1. Purpose

This document defines, in implementable and testable terms, how AI is used inside QuakeRoute. It exists because the PRD and SRS establish *that* AI is scoped as a multimodal hazard understanding layer (PRD §11; SRS §6), and the Domain-Risk-Model explains *how* the resulting Hazard entity is structured and consumed by the risk model (Domain-Risk-Model §3–§9) — but none of the three documents specify AI behavior at the level of individual, testable requirements with IDs, or exhaustively define how AI should behave under ambiguity, conflicting evidence, or failure.

This document fills that gap. It:

- Translates PRD §11 ("AI can / AI cannot") and SRS §6 ("AI is responsible for / AI is explicitly not responsible for") into concrete `AI-FR-XXX` requirements (Section 6).
- Elaborates on how AI should handle hazard understanding edge cases (single/multiple/ambiguous/incomplete/conflicting) that the PRD only illustrates by example (PRD §2, §9.5).
- Makes explicit the relationship between AI output and the Hazard entity already defined in Domain-Risk-Model §3, without changing that entity's structure.
- Connects AI behavior to the six validation scenarios already defined in PRD §15 / SRS §4.12 / Simulation-Validation §6–§7, so AI-specific behavior is evaluable using the same validation activity, not a separate one.

This document complements the SRS and the Domain-Risk-Model; it does not replace or supersede either. Where this document and an earlier source document appear to overlap (e.g., hazard attributes, safety constraints), the earlier document remains authoritative and this document only adds AI-specific detail.

---

## 2. AI Role in QuakeRoute

AI's position in QuakeRoute's architecture, per PRD §7 and SRS §2, is:

```
User Report
    ↓
AI Hazard Understanding
    ↓
Structured Hazard
    ↓
Risk Model
    ↓
Routing Engine
```

AI occupies exactly one stage of this flow: **AI Hazard Understanding**. It converts a raw Observation (photo, text, or — if implemented — a voice transcript routed through the text path) into one or more candidate structured Hazards (Domain-Risk-Model §2.1, §3). It does not participate in any stage after that.

**AI does not determine routes.** Route selection is the output of the Routing Engine operating on Routing Cost, which is itself computed by the Risk Model from Severity, Confidence, and Road Impact (Domain-Risk-Model §13–§16). AI has no visibility into, and no influence over, the routing algorithm, route candidates, or final route selection. This separation is a deliberate architectural boundary stated in PRD §7 ("AI does not decide routes directly") and SRS §2 ("AI does not decide routes"), and this document does not weaken it.

---

## 3. AI Capabilities

Per PRD §11 and SRS §6, the following capabilities are needed for the MVP. No capability beyond this list is required by the source documents, and none is added here.

| Capability | Description | Applies to |
|---|---|---|
| Hazard extraction | Identify that a hazard (or hazards) is/are being described in the input, as distinct from irrelevant content. | Text, Photo |
| Hazard classification | Assign a hazard Type from the MVP's supported set (PRD §12: Debris/Rubble, Road Blockage, Fire, Flood, Electrical Hazard, Visible Building Damage). | Text, Photo |
| Severity estimation | Estimate the hazard's Severity (Domain-Risk-Model §4). | Text, Photo |
| Confidence estimation | Produce a Confidence value reflecting how certain the AI is that the hazard is real and correctly characterized (Domain-Risk-Model §5). | Text, Photo |
| Road impact interpretation | Determine the hazard's effect on the segment's usability — passable, partially blocked, or blocked (Domain-Risk-Model §9.2). | Text, Photo |
| Contextual information extraction | Extract relevant contextual details present in the input that support the hazard (e.g., a location reference mentioned in text) without inventing details not present in the input. | Text, Photo (where applicable) |
| Multimodal input (image/vision) | Analyze a photo to propose a hazard, limited to the MVP's supported visually identifiable hazard types (PRD §9.4). | Photo |

AI is **not** required, for the MVP, to: verify a hazard against other reports (that is the system/domain-model's Conflicting Reports mechanism, Domain-Risk-Model §11.2), assign or transition hazard Status (that is a system-level lifecycle, Domain-Risk-Model §7), or compute routing cost or select a route (Section 2).

---

## 4. AI Inputs

| Input | MVP Status | Notes |
|---|---|---|
| Text report (free text) | **Required / Supported** | Primary text-mode input (PRD §9.5; SRS §4.5). May describe one or more hazards in a single report (FR-016). |
| Photo / image | **Required / Supported (limited hazard set)** | Primary photo-mode input (PRD §9.4; SRS §4.4). Limited to the MVP's supported visual hazard types (Section 3). |
| Voice transcript | **Optional / Conditional** | Only relevant if voice reporting is implemented (SHOULD HAVE, not MUST HAVE — PRD §10; SRS §4.7 FR-023). If implemented, the transcript is processed through the same text-extraction path as a text report; voice audio itself is not a distinct AI input. |
| Structured metadata: location | **Optional, when available** | Used to attach the resulting Hazard to a Location (Domain-Risk-Model §3), but AI's hazard-understanding output (type, severity, confidence, road impact) does not depend on location being present. |
| Structured metadata: timestamp | **Optional, when available** | Used for the Hazard's Timestamp attribute (PRD §12) and potential staleness handling (Domain-Risk-Model §11.3); not itself part of what AI must interpret. |
| Quick-tap category selection | **Unsupported (not an AI input)** | Quick reports do not go through AI processing at all — a category selection is already structured and receives a default confidence (FR-020; Domain-Risk-Model §4.1, §5.1). |
| Video, sensor data, official/verified data feeds | **Unsupported / Out of scope for MVP** | Not defined as an input by the PRD/SRS; introducing these would expand AI capability beyond what the project requires (PRD §19 lists this kind of expansion as future potential only). |

---

## 5. AI Outputs

AI must produce one or more **candidate Hazard** objects per processed input. Conceptually:

```
Hazard
├── Type
├── Severity
├── Confidence
├── Road Impact
├── Context
└── Evidence / Source
```

| Field | Meaning |
|---|---|
| **Type** | The hazard category, drawn from the MVP's supported set (Section 3). Required. |
| **Severity** | AI's estimate of the hazard's impact level (Domain-Risk-Model §4). Required. Exact scale/bands are `TBD` at the domain-model level and are not redefined here. |
| **Confidence** | AI's estimate of how certain it is that the hazard is real and correctly characterized (Domain-Risk-Model §5). Required. Independent of Severity (Section 8). |
| **Road Impact** | AI's estimate of the hazard's effect on segment usability — passable, partially blocked, or blocked (Domain-Risk-Model §9.2). Required. |
| **Context** | Any relevant supporting detail extracted from the input (e.g., a location phrase mentioned in text, or a visually evident detail in a photo) that helps a human or the system understand the basis for the proposed hazard. Optional; must not be invented if not present in the input (Section 7). |
| **Evidence / Source** | A reference back to the original input (the photo, or the report text) and the reporting mode that produced it (Domain-Risk-Model §6). Required — this is what makes AI output explainable and reviewable (Section 15). |

This document does not define the API schema or database representation of this structure — that is an implementation concern, deferred per this document's own scope (Section 0) and the SRS's provider-agnostic stance (SRS §7).

**Note on Status:** AI output does not include a hazard lifecycle Status assignment. Status (e.g., Reported, Confirmed, Uncertain/Conflicting) is assigned and transitioned by the system, not by AI (Domain-Risk-Model §7.2; PRD §11 "AI cannot... automatically convert its own prediction into verified fact"). Every AI-produced candidate hazard enters the system in an unconfirmed state until the applicable confirmation step occurs (FR-025).

---

## 6. AI Functional Requirements

### AI-FR-001 — Text Hazard Extraction

**Description**
The system must extract one or more candidate hazards from a free-text report.

**Input**
Free-text hazard description (Section 4).

**Expected Output**
One or more candidate Hazard objects (Section 5), each with Type, Severity, Confidence, and Road Impact.

**Behavior**
AI parses the text and identifies each distinct hazard described, rather than collapsing multiple hazards into one, or ignoring hazards beyond the first (Section 7.2).

**Acceptance Criteria**
Given a text report describing at least one hazard, when processed, then at least one structured candidate hazard is produced with Type, Severity, Confidence, and Road Impact (traces to FR-016, FR-017).

---

### AI-FR-002 — Photo Hazard Detection (AI Vision)

**Description**
The system must analyze a submitted photo and propose a candidate hazard, limited to the MVP's supported visually identifiable hazard types.

**Input**
Photo/image (Section 4).

**Expected Output**
One candidate Hazard object (Section 5) with Type, Severity, Confidence, and Road Impact.

**Behavior**
AI Vision analyzes the image for evidence of one of the MVP's supported hazard types (Section 3). If no supported hazard type is visually evident, AI must not fabricate a hazard (Section 11).

**Acceptance Criteria**
Given a photo depicting one of the MVP's supported visual hazard types, when analyzed, then the system proposes a hazard with Type, Severity, Road Impact, and a Confidence value (traces to FR-011).

---

### AI-FR-003 — Severity Estimation

**Description**
The system must estimate hazard Severity as part of processing any supported input.

**Input**
Text or photo input already identified as describing a hazard (AI-FR-001 / AI-FR-002).

**Expected Output**
A Severity value attached to the candidate hazard.

**Behavior**
Severity estimation reflects the estimated impact level of the hazard on the road segment, independent of how certain the AI is that the hazard is real (Domain-Risk-Model §4.3, §5.2 — Severity and Confidence must not be collapsed into one value; see Section 8 of this document).

**Acceptance Criteria**
Given any candidate hazard produced by AI-FR-001 or AI-FR-002, when output is inspected, then a Severity value is present (traces to FR-024).

---

### AI-FR-004 — Confidence Estimation

**Description**
The system must produce a Confidence value for every AI-generated candidate hazard.

**Input**
Text or photo input already identified as describing a hazard.

**Expected Output**
A Confidence value attached to the candidate hazard.

**Behavior**
Confidence reflects how certain the AI is that the hazard is real and correctly characterized, based on the clarity and completeness of the input (Section 9). Confidence must not be used as a substitute for Severity, or vice versa (Section 8).

**Acceptance Criteria**
Given any candidate hazard produced by AI-FR-001 or AI-FR-002, when output is inspected, then a Confidence value is present (traces to FR-024, FR-026).

---

### AI-FR-005 — Road Impact Interpretation

**Description**
The system must determine the hazard's effect on the road segment's usability.

**Input**
Text or photo input already identified as describing a hazard.

**Expected Output**
A Road Impact value (passable, partially blocked, or blocked) attached to the candidate hazard.

**Behavior**
AI interprets whether the described/depicted hazard renders the segment fully blocked, partially blocked, or still passable, based on the input's content — it does not default to any single value when evidence is ambiguous (Section 9).

**Acceptance Criteria**
Given any candidate hazard produced by AI-FR-001 or AI-FR-002, when output is inspected, then a Road Impact value is present (traces to FR-011, FR-017, FR-024).

---

### AI-FR-006 — Structured Hazard Output Formatting

**Description**
AI output must be structured into the system's common hazard data format regardless of input mode.

**Input**
Any candidate hazard produced by text or photo processing.

**Expected Output**
A structured object conforming to Section 5 of this document (Type, Severity, Confidence, Road Impact, Context, Evidence/Source).

**Behavior**
Text-derived and photo-derived candidate hazards are structured identically, so downstream consumers (Section 13) do not need to distinguish by source when consuming hazard fields.

**Acceptance Criteria**
Given a candidate hazard from any supported input mode, when compared to one from another mode, then both conform to the same structured field set (traces to FR-009, FR-024).

---

### AI-FR-007 — Contextual Information Extraction

**Description**
The system should extract relevant contextual information present in the input that supports the proposed hazard.

**Input**
Text or photo input.

**Expected Output**
Optional Context content attached to the candidate hazard (Section 5).

**Behavior**
AI extracts only information actually present in the input (e.g., a location phrase in text, a visibly relevant detail in a photo). AI must not infer or invent contextual details not supported by the input (Section 11).

**Acceptance Criteria**
Given an input containing relevant contextual detail, when processed, then that detail is reflected in the candidate hazard's Context field without additions not present in the source input.

---

### AI-FR-008 — Multiple Hazards from a Single Report

**Description**
The system must be able to identify more than one distinct hazard from a single text report.

**Input**
Free-text report describing more than one hazard (e.g., the PRD §9.5 example: *"Jalan depan sekolah tertutup reruntuhan dan ada kabel listrik jatuh"*).

**Expected Output**
One candidate Hazard object per distinct hazard identified.

**Behavior**
AI does not merge distinct hazards into a single generic hazard, nor does it report only the first hazard mentioned. Each identified hazard receives its own Type, Severity, Confidence, and Road Impact (Section 7.2).

**Acceptance Criteria**
Given a text report describing two distinct hazards, when processed, then two structured candidate hazards are produced, each independently populated (traces to FR-016).

---

### AI-FR-009 — Uncertainty Representation for Ambiguous or Incomplete Input

**Description**
The system must represent uncertainty explicitly rather than force a confident classification when evidence is insufficient.

**Input**
Text or photo input that is ambiguous, vague, or incomplete.

**Expected Output**
A candidate hazard (if a hazard is plausibly identifiable at all) with a Confidence value reflecting the input's insufficiency, rather than an artificially high Confidence.

**Behavior**
AI must not force a specific Type, Severity, or Road Impact classification when the input does not clearly support one; see Section 9 for the full uncertainty-handling requirement.

**Acceptance Criteria**
Given an ambiguous or incomplete input, when processed, then any resulting candidate hazard carries a Confidence value that is lower than it would be for a clear, unambiguous input describing the same hazard type (qualitative; exact thresholds `TBD`).

---

### AI-FR-010 — Voice Transcript Processing (Conditional)

**Description**
If voice reporting is implemented, a voice transcript must be processed through the same path as text input.

**Input**
Speech-to-text transcript (voice reporting is SHOULD HAVE / limited scope — PRD §10; SRS §9).

**Expected Output**
Same as AI-FR-001, applied to the transcript.

**Behavior**
No AI capability specific to voice/audio characteristics (tone, background noise, etc.) is required; the transcript is treated as text.

**Acceptance Criteria**
Given voice reporting is implemented and a transcript is available, when processed, then it is handled by the same extraction path as a text report and produces the same structured output shape (traces to FR-023).

---

## 7. Hazard Understanding Requirements

AI's hazard-understanding behavior must handle the following input conditions, consistent with the multi-hazard example already given in PRD §9.5.

### 7.1 Single Hazard
A report describing exactly one hazard produces exactly one candidate Hazard object (AI-FR-001, AI-FR-002).

### 7.2 Multiple Hazards in One Report
A text report may describe more than one hazard (e.g., debris *and* a fallen power line in the same sentence). AI must identify each distinct hazard separately (AI-FR-008), rather than:
- merging them into a single hazard with an averaged or dominant classification, or
- reporting only the first or most salient hazard and silently dropping the rest.

### 7.3 Ambiguous Descriptions
When the input's wording (text) or visual content (photo) does not clearly indicate a specific hazard Type, Severity, or Road Impact, AI must reflect that ambiguity through a lower Confidence value (Section 9) rather than guessing a specific value with unwarranted certainty.

### 7.4 Incomplete Reports
When the input lacks enough detail to support a full structured hazard (e.g., a report mentions "something is wrong on the road" with no further detail), AI must not fabricate the missing fields. If a plausible candidate hazard cannot be constructed at all, this is a failure case handled per Section 12.

### 7.5 Irrelevant Information
Input content unrelated to any hazard (e.g., commentary not describing road conditions) must not be forced into a hazard classification. AI is not required to explain *why* content was irrelevant — only to avoid producing a spurious hazard from it.

### 7.6 Potentially Conflicting Information Within a Single Report
A single report may contain internally inconsistent statements (e.g., a hint that a road is both passable and blocked within the same message). This is distinct from conflicting *reports* from different sources (Section 10). Where a single input is internally inconsistent, AI should reflect that inconsistency through a lower Confidence and/or a Road Impact value that does not overstate certainty (e.g., "partially blocked" rather than an emphatic "blocked" or "passable" when the input itself is unclear), rather than arbitrarily picking one interpretation and discarding the other signal.

---

## 8. Severity & Confidence Requirements

These are two independent axes and must not be collapsed into one number, consistent with Domain-Risk-Model §5.2:

- **Severity** = the estimated impact level of the hazard, *if it is real*.
- **Confidence** = how certain the system is that the hazard is real and accurately characterized.

```
High Severity ≠ High Confidence
```

A hazard can legitimately be high-severity/low-confidence (e.g., a single, vaguely worded report of a collapsed building) or low-severity/high-confidence (e.g., a clear photo of a small, unambiguous debris pile). AI must estimate each independently:

- AI must not use Confidence as a proxy for Severity (e.g., treating "I'm not sure how bad it is" as a signal to lower the reported Severity rather than lower the Confidence).
- AI must not use Severity as a proxy for Confidence (e.g., treating "this sounds very dangerous" as grounds to report high Confidence when the description itself is vague).

This mirrors PRD §13's framing that a large routing penalty requires hazards that are *both* high-severity *and* high-confidence — the risk model (Domain-Risk-Model §14) depends on AI keeping these two values genuinely independent.

---

## 9. Uncertainty Requirements

AI must not force a classification when the available evidence does not support one with reasonable certainty.

- If an input's evidence is weak, vague, or minimal, the resulting Confidence value must reflect that weakness — AI must not compensate for insufficient evidence by defaulting to a moderate or high Confidence value.
- If AI cannot determine a specific Type, Severity, or Road Impact with reasonable certainty, it must not silently pick one value that happens to be typical or common; the resulting output's low Confidence is what communicates this uncertainty to the rest of the system (Section 5, Section 13).
- Uncertainty is never resolved by AI discarding the report — even a low-confidence candidate hazard should still be produced where a plausible hazard is identifiable at all (see Domain-Risk-Model §8: "uncertainty must never silently disappear").
- Where evidence is so insufficient that no plausible candidate hazard can be constructed, this is a failure case (Section 12), not a forced low-confidence guess.

The exact numeric thresholds distinguishing "sufficient" from "insufficient" evidence are `TBD` (consistent with Domain-Risk-Model §14.3, §15.3 marking related weights as `TBD`) and must be defined and tuned during implementation, validated via the scenarios in Section 16.

---

## 10. Conflicting Evidence

This section addresses two distinct situations, matching Domain-Risk-Model §11.2's distinction between within-report and across-report conflict.

### 10.1 Conflicting Reports (Across Multiple Observations)
Detecting and resolving disagreement between two or more *separate* reports about the same road segment (e.g., PRD §14's "Report A: blocked" vs. "Report B: passable" example) is a **system-level / domain-model responsibility**, not an AI responsibility. AI processes each report independently and produces independently structured output for each; it is the system (via the mechanism defined in Domain-Risk-Model §11.2, FR-038–FR-040) that compares structured outputs across reports and applies the Uncertain/Conflicting status and Uncertainty Penalty.

AI's role in supporting this mechanism is limited to producing consistent, comparable structured output (Section 6, AI-FR-006) — reliable Type and Road Impact values are what let the system-level comparison detect disagreement accurately. AI does not decide that two reports conflict, and does not adjudicate which report is correct.

### 10.2 Inconsistent Descriptions Within One Report
See Section 7.6 — internally inconsistent single-report input is an AI-level concern, handled through lower Confidence and a non-overstated Road Impact value, not through arbitration between two "sides."

### 10.3 Insufficient Evidence
Where a single report's evidence is too weak to support any classification with reasonable certainty, this is handled per Section 9 (Uncertainty Requirements) and, if no plausible hazard can be constructed at all, per Section 12 (Failure Handling).

AI must never treat a single report — regardless of how strongly it is worded — as absolute, unquestionable truth. This is consistent with PRD §6's non-goal: *"Automatically treat AI-detected or user-reported hazards as verified fact."*

---

## 11. AI Safety Constraints

The following constraints apply to AI's behavior in QuakeRoute at all times, per PRD §6, §11, §17 and SRS §6, §8:

- AI output is **not** ground truth. Every AI-produced hazard remains an observation/prediction with an associated Confidence value until (and even after) any applicable confirmation step.
- AI does **not** guarantee that any road is safe, passable, or accurately characterized.
- AI does **not** replace emergency responders, medical personnel, or official authorities.
- AI does **not** make medical or emergency-response decisions of any kind, authoritatively or otherwise.
- AI must **not** state certainty (via Confidence, Type, Severity, or Road Impact) that is not supported by the evidence in its input.
- AI output must, where possible, remain traceable back to its input/evidence (Section 5, Evidence/Source field; Section 15) so it can be reviewed and understood, not treated as an opaque assertion.

These constraints are not new requirements — they restate PRD §11 ("AI cannot / does not") and SRS §6 ("AI is explicitly not responsible for") in constraint form so they can be checked directly against AI behavior during implementation and testing.

---

## 12. Failure Handling

The following are the failure/edge conditions AI processing must account for. Fallback behavior is described conceptually; this document does not prescribe a specific technical retry, timeout, or error-code mechanism, since none is specified by the PRD/SRS.

| Condition | Expected Fallback Behavior (conceptual) |
|---|---|
| AI fails to process the input at all (e.g., inference failure) | No candidate hazard is produced; the failure must be surfaced to the reporting flow so the user is not silently left with no feedback (exact UX handling `TBD`, outside this document's scope). |
| AI produces output that does not conform to the required structure (Section 5) | The malformed output must not be passed downstream as a valid candidate hazard; it is treated as a processing failure, not as a hazard with missing fields. |
| AI cannot determine any plausible hazard from the input | No candidate hazard is produced. The user is not told a hazard exists when AI found no supportable evidence of one. This is distinct from a low-confidence hazard (Section 9), which *is* produced when a hazard is plausible but uncertain. |
| Confidence is below a usable threshold | The candidate hazard may still be produced (per Section 9), but the system downstream is expected to treat very-low-confidence hazards accordingly via the risk model's existing Confidence handling (Domain-Risk-Model §14); this document does not introduce a separate "reject below threshold" rule not already implied by the risk model. Exact threshold, if any is needed, is `TBD`. |
| Input is irrelevant to hazard reporting | No candidate hazard is produced (Section 7.5). |
| Photo is not clear enough to support any of the MVP's supported hazard types | No candidate hazard is produced, or a very-low-confidence candidate is produced if some plausible partial evidence exists — the exact cutoff between these two outcomes is `TBD` and is a candidate for evaluation (Section 16). |
| AI produces multiple plausible interpretations of the same input | AI should surface the most-supported interpretation as its output; producing multiple competing candidate hazards for the *same* underlying hazard is not required by the source documents and is not introduced here — this differs from Section 7.2 (genuinely distinct hazards), where multiple candidates *are* required. |

---

## 13. AI Output → Risk Model

AI output is consumed by the domain and risk model exactly as follows, and the AI layer's responsibility ends where this flow begins:

```
AI Output
    ↓
Hazard
    ↓
Severity + Confidence
    ↓
Uncertainty
    ↓
Road Impact
    ↓
Risk Model
```

- AI's structured output (Section 5) becomes a candidate **Hazard** once it is accepted into the system's data (immediately for text/photo per FR-014, pending the confirmation step for photo reports per FR-012/FR-013).
- **Severity** and **Confidence** feed the Hazard Penalty calculation (Domain-Risk-Model §14): `HazardPenalty(segment) = max(SeverityWeight(h) × ConfidenceFactor(h) for h in ActiveHazards(segment))`.
- **Uncertainty** (a segment-level condition arising from a hazard's Confidence and/or Status, Domain-Risk-Model §5.3, §8) feeds the Uncertainty Penalty (Domain-Risk-Model §15).
- **Road Impact** determines whether the segment is excluded outright (Blocked) or included with a penalty (Passable/Partially Blocked), per Domain-Risk-Model §16.1.
- The **Risk Model** combines these into Segment Routing Cost and Route Cost (Domain-Risk-Model §13.2), which the Routing Engine uses to select a route.

AI provides hazard understanding only. Risk calculation and route selection remain entirely the responsibility of the domain/risk model and routing engine (Section 2); this document does not alter that boundary.

---

## 14. AI Requirements for Multimodal Input

Per PRD §9.4 and SRS §4.4, photo-based AI Vision **is** part of the MVP (MUST HAVE, limited hazard set), so this section defines requirements rather than deferring them as future scope.

### 14.1 Supported Image Evidence
AI Vision is limited to the MVP's supported visually identifiable hazard types (Section 3): Debris/Rubble, Road Blockage, Fire, Flood, Electrical Hazard, Visible Building Damage — where "clearly identifiable" (PRD §9.4). AI Vision is not required to detect any hazard type outside this set.

### 14.2 Possible Hazard Detection
AI Vision proposes a candidate hazard (Type, Severity, Road Impact, Confidence) from the photo, per AI-FR-002. It must not claim to detect hazard types outside the MVP's supported set.

### 14.3 Confidence for Image Input
Confidence for photo-derived hazards follows the same principle as text (Section 8, Section 9): it reflects how clearly the image supports the proposed classification, not how visually dramatic the image is.

### 14.4 Ambiguous Images
Where an image is unclear, partially obscured, poorly lit, or otherwise difficult to interpret, AI must reflect this through lower Confidence (Section 9) rather than a confident guess.

### 14.5 Insufficient Visual Evidence
Where an image does not contain evidence of any MVP-supported hazard type, no candidate hazard is produced (Section 12).

### 14.6 Image + Text Combination
The source documents do not define a requirement for AI to jointly interpret an image and accompanying text as a single combined input (the MVP's reporting modes — photo, text, quick-tap — are treated as parallel, independent modes per PRD §10, all feeding the same downstream pipeline separately). Combined image+text interpretation is therefore **not** an MVP requirement; if a photo report includes optional caption text in the future, joint interpretation is `TBD` / future scope (see Section 19).

### 14.7 Explicit Limitation
Consistent with PRD §9.4, this document does not claim AI Vision can always correctly detect a hazard from a photo, nor that a photo without a detected hazard means the road is safe. This limitation must be preserved in any implementation and communicated to users per NFR-005.

---

## 15. AI Explainability

To support debugging, validation, and user trust, the following information should be available for any AI-produced hazard:

```
Input:
"Jalan tertutup reruntuhan."

AI Interpretation:
Hazard: Debris
Severity: High
Confidence: 0.82
Road Impact: Blocked
```

At minimum, this means:

- The original input (or a reference to it — the Evidence field, Section 5) remains associated with the resulting candidate hazard, so the interpretation can be checked against its source.
- The structured output fields (Type, Severity, Confidence, Road Impact) are presented together, not just a final classification with no supporting values — this is what lets a developer, evaluator, or (per FR-012/FR-013) the reporting user assess whether the AI's interpretation is reasonable.
- Explainability here is scoped to *what* AI concluded and *from what input* — it does not require a step-by-step reasoning trace or model-internal explanation, since neither the PRD nor SRS require that level of detail.

This directly supports the confirmation step already required for photo reports (FR-012, FR-013) and the general non-ground-truth stance of AI output (Section 11).

---

## 16. AI Evaluation

AI-specific behavior is evaluated as part of the same controlled simulation activity defined in `Simulation-Validation.md`, not as a separate evaluation track. The following AI-relevant aspects should be evaluated:

| What to evaluate | Relevant scenario(s) / mechanism | Status |
|---|---|---|
| Hazard extraction correctness | Underlies hazard setup for all six scenarios (Simulation-Validation §5.6–§5.7); most directly exercised wherever a scenario's predefined hazard is created via AI Vision or text extraction (PRD §15 Scenario 6, referenced in Simulation-Validation §6 note) | Metric/target: `TBD` |
| Classification correctness (Type, Road Impact) | Scenario 2 (Blocked Road), Scenario 3 (High-Risk Hazard) | Metric/target: `TBD` |
| Severity consistency | Scenario 3 (High-Risk Hazard) | Metric/target: `TBD` |
| Confidence behavior | Scenario 5 (Uncertain Report) — a low-confidence report must not be treated as Confirmed/Blocked (Simulation-Validation §7, Scenario 5) | Categorical pass/fail per Simulation-Validation §10 |
| Handling of ambiguous reports | Section 7.3, Section 9 of this document | Metric/target: `TBD` |
| Handling of multiple hazards in one report | Section 7.2 of this document (AI-FR-008) | Metric/target: `TBD` |
| Invalid/failed output handling | Section 12 of this document | Categorical: failure is surfaced, not silently converted into a valid hazard |

No evaluation result is reported or assumed in this document — consistent with Simulation-Validation §0 and §13, results are recorded only once scenarios are actually executed. Where a metric or numeric target is not already defined in `Simulation-Validation.md`, it is marked `TBD` here rather than invented.

---

## 17. AI Testability

Every AI functional requirement in Section 6 is testable using the same pattern:

```
Input
 ↓
AI
 ↓
Structured Output
 ↓
Expected Output
 ↓
Pass / Fail
```

For each `AI-FR-XXX`, a corresponding test case should:

1. Supply a defined input (text, photo, or transcript) matching the requirement's **Input** field.
2. Run it through AI processing.
3. Capture the structured output (Section 5).
4. Compare against the requirement's **Acceptance Criteria**.
5. Record Pass/Fail.

This mirrors the scenario-based validation method already defined in Simulation-Validation §9, and AI-FR test cases are expected to be created as part of the test case set that follows this document (per this document's own instruction scope) rather than being fully enumerated here.

---

## 18. AI Limitations

The following limitations are relevant to AI's role in QuakeRoute and must be acknowledged rather than hidden or minimized:

- **Hallucination:** AI may propose a hazard, detail, or contextual element not actually supported by the input.
- **Misclassification:** AI may assign an incorrect Type, Severity, or Road Impact.
- **Insufficient evidence:** AI may be asked to interpret input that simply does not contain enough information to classify reliably (Section 9).
- **Ambiguous language:** Natural-language reports, especially under emergency stress, may be vague, informal, or incomplete (PRD §2).
- **Image quality:** Photos may be blurry, poorly lit, partially obscured, or otherwise visually ambiguous (Section 14.4).
- **Stale reports:** AI has no inherent way to know whether a described condition still holds by the time it is processed; staleness is addressed at the domain-model level via Timestamp (Domain-Risk-Model §11.3), not by AI re-evaluating old input.
- **Conflicting reports:** AI processes each report independently and has no visibility into other reports about the same segment (Section 10.1).
- **Confidence estimation limitations:** Confidence values are themselves estimates, not guarantees — a "high confidence" output is not a certainty claim, and the exact reliability of AI's confidence estimates is not established by any source document and is not claimed here.

No performance claim (e.g., accuracy percentages, expected error rates) is made in this document, consistent with the instruction not to invent results without data, and with PRD §16 / Simulation-Validation §14's position that such claims require actual evaluation data not yet produced.

---

## 19. MVP vs Future AI Capabilities

| Capability | MVP | Future | Reason |
|---|---|---|---|
| Text hazard extraction (single/multiple hazards) | ✅ | — | Required for Text Reporting (PRD §9.5; SRS §4.5) |
| Photo hazard detection (limited hazard set) | ✅ | — | Required for Photo Reporting / AI Vision (PRD §9.4; SRS §4.4) |
| Severity, Confidence, Road Impact estimation | ✅ | — | Required minimum AI output fields (FR-024) |
| Voice transcript processing (via text path) | Limited / Conditional | — | Only if voice reporting is implemented (SHOULD HAVE — PRD §10) |
| Contextual information extraction | ✅ (best-effort) | — | Supports explainability (Section 15); not a hard blocking requirement |
| Image + text combined interpretation | — | Future | Not required by current reporting-mode design (Section 14.6) |
| Full AI Vision coverage of all damage types | — | Future | Explicitly out of scope for MVP (PRD §18) |
| Cross-report conflict resolution by AI | — | Not planned as AI capability | Conflict handling is a system/domain-model responsibility by design (Section 10.1; Domain-Risk-Model §11.2) |
| AI-driven route suggestion or routing decisions | — | Not planned | Explicitly excluded from AI's role (Section 2; PRD §11; SRS §6) |
| Additional hazard categories beyond the MVP set | — | Future | Listed as future potential (PRD §19); would require re-scoping AI Vision and extraction |
| Multi-disaster-type hazard understanding | — | Future | Earthquake-only for MVP (PRD §6, §19) |

---

## 20. Traceability

```
PRD
 ↓
SRS Requirement
 ↓
AI Requirement
 ↓
Domain/Risk Model
 ↓
Validation / Test
```

| PRD Reference | SRS Requirement(s) | AI Requirement (this document) | Domain/Risk Model Concept | Validation |
|---|---|---|---|---|
| §9.4 Photo-Based Hazard Reporting / AI Vision | FR-010–FR-014, FR-021 | AI-FR-002, Section 14 | Hazard, Evidence (§3, §6) | Scenario 6 note (Simulation-Validation §6) |
| §9.5 Text Hazard Reporting | FR-015–FR-017, FR-022 | AI-FR-001, AI-FR-008 | Hazard (§3); Multiple Hazards on One Segment (§10) | Underlies hazard setup for Scenarios 3, 5, 6 |
| §9.7 AI Hazard Understanding | FR-021–FR-025 | Section 6 (all AI-FR items) | Observation and Hazard (§3) | All six scenarios (indirectly, via hazard setup) |
| §11 AI Requirements (role, can/cannot) | §6 AI Requirements | Section 2, Section 11 | AI output as observation/prediction (§3) | N/A (constraint, not a scenario) |
| §13 Risk-Aware Routing Requirements | FR-030–FR-034 | Section 13 (AI Output → Risk Model) | Risk Model (§13–§16) | Scenario 2, Scenario 3 |
| §14 Uncertainty and Conflicting Reports | FR-038–FR-040 | Section 9, Section 10 | Conflicting Reports (§11.2); Uncertainty Penalty (§15) | Scenario 6 (Simulation-Validation §7) |
| §17 Safety Requirements | NFR-004, NFR-005 | Section 11 (AI Safety Constraints) | Assumptions and Limitations (§18.2) | N/A (constraint, not a scenario) |
| §15 Emergency Simulation / §16 Validation | FR-041–FR-044 | Section 16, Section 17 | Validation Connection (§19) | All six scenarios (Simulation-Validation §6–§13) |

---

## 21. Summary

AI in QuakeRoute is scoped strictly as a **multimodal hazard understanding layer**: it converts photo and text (and, conditionally, voice-transcript) input into structured candidate hazards — Type, Severity, Confidence, Road Impact, Context, and Evidence — and does nothing beyond that. It does not decide routes, does not verify hazards against other reports, does not assign hazard status, and does not guarantee that any road is safe.

AI's capabilities are deliberately limited to what the MVP's reporting modes require: text extraction (including multiple hazards from one report) and photo-based detection over a narrow, predefined hazard set. Its outputs are always treated as observations or predictions with associated uncertainty — never as verified fact — and Severity and Confidence are always kept as independent axes so the risk model can combine them meaningfully.

AI's output feeds directly into the Hazard entity and Risk Model already defined in `Domain-Risk-Model.md`: Severity and Confidence drive the Hazard Penalty, Road Impact determines whether a segment is excluded or penalized, and any resulting uncertainty is preserved — never silently discarded — through to the routing cost. AI will be validated using the same six controlled scenarios already defined in `PRD.md` and operationalized in `Simulation-Validation.md`, with a focus on hazard extraction correctness, classification and severity consistency, confidence behavior under low-evidence conditions, and correct handling of failure cases — no performance claims are made ahead of that evaluation actually being run.

---

**Document status:** AI Requirements derived from `PRD.md`, `SRS.md`, `Domain-Risk-Model.md`, and `Simulation-Validation.md` for the QuakeRoute 10-day hackathon prototype. All items marked `TBD` mirror TBD items already present in the source documents, or are flagged as AI-specific detail requiring definition during implementation. This document does not modify, add to, or remove any product concept, system requirement, or risk model definition established by the earlier documents.
