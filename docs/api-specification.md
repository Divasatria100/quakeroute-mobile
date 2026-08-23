# QuakeRoute — API Specification (MVP)

## 0. Status Dokumen dan Sumber Kebenaran

- **Source of truth:** `SRS.md`, `Domain-Risk-Model.md`, `Architecture-Document.md`. Dokumen ini **tidak** mengubah, menambah, atau menghapus requirement, entitas domain, formula risk model, atau keputusan arsitektur apa pun yang sudah ditetapkan dokumen-dokumen tersebut.
- **Yang dilakukan dokumen ini:** menerjemahkan requirement (SRS §4), domain/risk model (Domain-Risk-Model §2–§16), dan alur antar-modul (Architecture Document §3, §6–§8) menjadi kontrak REST API yang dapat diimplementasikan oleh Backend (Laravel Modular Monolith) dan dikonsumsi oleh Mobile App (Flutter).
- **Yang tidak dilakukan dokumen ini:** mengubah arsitektur modul, mengubah formula risk model, atau menentukan routing engine/algoritma konkret. Endpoint routing di bawah ini hanya mendefinisikan kontrak request/response yang harus dipenuhi Routing Module — bukan cara Routing Module menghitung rute secara internal (tetap `TBD` sesuai SRS FR-034 dan Architecture Document §9, §11).
- **Angka/parameter:** seluruh parameter numerik yang masih `TBD` di Domain-Risk-Model (severity weight, confidence factor, uncertainty weight, staleness decay, default confidence quick-tap) tetap `TBD` di sini. API hanya mengekspos *field* untuk nilai-nilai tersebut, bukan nilainya.
- **Scope:** hanya endpoint yang diperlukan MVP sesuai SRS §9 (MVP Scope). Tidak ada endpoint untuk fitur di luar MVP (mis. dashboard Volunteer/Coordinator, autentikasi kompleks, multi-disaster).

---

## 1. Konvensi Umum

| Aspek | Ketentuan |
|---|---|
| **Base path** | `/api/v1` (versi API — konvensi umum; tidak ditentukan sumber dokumen, ditambahkan sebagai praktik REST standar) |
| **Format data** | JSON untuk request dan response body. Upload foto menggunakan `multipart/form-data` (lihat §3.1). |
| **Autentikasi/identitas user** | **TBD.** SRS/Architecture Document secara eksplisit tidak mendefinisikan mekanisme autentikasi/otorisasi kompleks untuk MVP (Architecture Document §11: "Tidak ada mekanisme autentikasi/otorisasi kompleks"). Endpoint yang memerlukan identifikasi user (mis. active route milik user tertentu) mengasumsikan adanya identifier ringan (mis. `session_id` atau `device_id`) yang dikirim lewat header `X-Session-Id` — mekanisme pastinya **TBD**, ini hanya placeholder kontrak. |
| **Waktu** | Seluruh timestamp dalam format ISO 8601 UTC (mis. `2026-08-21T09:15:00Z`), sesuai kebutuhan field Timestamp pada Hazard (Domain-Risk-Model §3, §11.3). |
| **Lokasi** | Titik koordinat dikirim sebagai `{ "lat": number, "lng": number }`. Resolusi Location → Road Segment adalah proses internal (PostGIS, Architecture Document §4 — `Shared/Location`), tidak diekspos sebagai langkah API terpisah. |
| **Paginasi** | List endpoint yang berpotensi besar (mis. `GET /hazards`) mendukung `?limit=` dan `?cursor=` atau `?page=` — mekanisme pasti **TBD**, tidak dispesifikasikan sumber dokumen. |
| **Format error umum** | Lihat §2. |
| **Enum nilai domain** | `severity`: `Low` \| `Medium` \| `High` (band final dan jumlah band **TBD**, Domain-Risk-Model §4.2). `road_impact`: `Passable` \| `PartiallyBlocked` \| `Blocked` (Domain-Risk-Model §9.2). `status`: minimal membedakan `Reported` \| `Confirmed` dari kondisi lain; set final **TBD** (SRS FR-027) — nilai konseptual yang dipakai di dokumen ini: `Reported`, `Confirmed`, `UncertainConflicting` (Domain-Risk-Model §7.1). `type` (hazard): salah satu dari 6 tipe MVP (§3.1 Domain-Risk-Model): `DebrisRubble`, `RoadBlockage`, `Fire`, `Flood`, `ElectricalHazard`, `VisibleBuildingDamage`. `source`: `AIVisionPhoto` \| `AITextExtraction` \| `QuickTap` \| `AIVoiceExtraction` (voice, kondisional — SHOULD, hanya jika diimplementasikan, FR-023). |

---

## 2. Format Error Standar

Semua error menggunakan struktur berikut, dengan HTTP status code yang sesuai:

```json
{
  "error": {
    "code": "string (mesin-terbaca, mis. VALIDATION_ERROR)",
    "message": "string (untuk ditampilkan/di-log)",
    "details": { }
  }
}
```

| HTTP Status | Kapan dipakai |
|---|---|
| `400 Bad Request` | Body/parameter request tidak valid secara struktur (mis. JSON malformed). |
| `422 Unprocessable Entity` | Validasi gagal (mis. field wajib kosong, `type` bukan salah satu dari 6 tipe MVP). |
| `404 Not Found` | Resource (hazard, route, destination, suggestion, scenario, run) tidak ditemukan. |
| `409 Conflict` | Aksi tidak valid untuk state resource saat ini (mis. konfirmasi ulang suggestion yang sudah di-reject). |
| `502 Bad Gateway` / `503 Service Unavailable` | AI provider eksternal atau routing engine gagal merespons (keduanya dependency eksternal `TBD`, Architecture Document §9). Sesuai `AI-Requirements.md` §12 (dirujuk Architecture Document §10): kegagalan AI berarti "tidak ada candidate Hazard" — bukan error yang menghentikan seluruh alur reporting; response harus menjelaskan bahwa AI gagal, bukan hazard tidak valid. |
| `500 Internal Server Error` | Kegagalan tak terduga lainnya. |

---

## 3. Hazard Reporting

Mencakup FR-008–FR-024 (SRS §4.3–§4.7) dan alur Observation → AI Hazard Understanding → Hazard (Domain-Risk-Model §1–§9; Architecture Document §3, §6). Semua mode reporting bermuara ke struktur Hazard yang sama (FR-009).

### 3.1 `POST /api/v1/hazard-reports/photo`

**Purpose:** Mengirim foto sebagai dasar hazard report (FR-010), memicu AI Vision (FR-011, FR-021), dan mengembalikan **suggestion** yang menunggu konfirmasi user (FR-012) — belum menjadi Hazard aktif (FR-025).

**Request:**
- Content-Type: `multipart/form-data`
- Fields:
  - `photo` (file, wajib) — gambar hazard.
  - `location` (object, wajib) — `{ "lat": number, "lng": number }`.
  - `note` (string, opsional) — catatan tambahan dari reporter.

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
Field `proposed_hazard` sesuai output minimum AI (FR-024): type, severity, road_impact, confidence. Belum ada `hazard_id` karena belum masuk hazard dataset (FR-025).

**Status/Error:**
- `422` — foto tidak ada / lokasi tidak valid.
- `502/503` — AI Vision provider gagal (lihat §2); response memuat `error.code = "AI_PROVIDER_UNAVAILABLE"`, tidak ada `proposed_hazard` yang dihasilkan.

---

### 3.2 `POST /api/v1/hazard-suggestions/{suggestion_id}/confirm`

**Purpose:** User mengonfirmasi (opsional dengan edit) suggestion hasil AI Vision (FR-013), sehingga hazard menjadi bagian dataset terstruktur (FR-014).

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
`edits` opsional — jika dikirim, field yang disertakan menggantikan nilai hasil AI sebelum hazard disimpan (FR-013 "edit"). Confidence tidak dapat diedit manual oleh user (nilainya tetap berasal dari AI atau default sistem — tidak ada requirement sumber yang mengizinkan override manual atas confidence).

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
Hazard baru masuk dengan status awal sesuai FR-025 (bukan otomatis "Verified" hanya karena dikonfirmasi user — status final tetap mengikuti Domain-Risk-Model §7.1, exact status set TBD).

**Status/Error:**
- `404` — `suggestion_id` tidak ditemukan.
- `409` — suggestion sudah dikonfirmasi/di-reject sebelumnya.
- `422` — `edits` berisi nilai di luar enum yang diizinkan.

---

### 3.3 `POST /api/v1/hazard-suggestions/{suggestion_id}/reject`

**Purpose:** User menolak suggestion AI Vision (FR-013) — suggestion dibuang, tidak pernah masuk hazard dataset.

**Request:** Tidak ada body wajib.

**Response — `200 OK`:**
```json
{ "suggestion_id": "string", "status": "Rejected" }
```

**Status/Error:**
- `404` — `suggestion_id` tidak ditemukan.
- `409` — suggestion sudah dikonfirmasi/di-reject sebelumnya.

---

### 3.4 `POST /api/v1/hazard-reports/text`

**Purpose:** Mengirim laporan teks bebas (FR-015), memicu AI text extraction (FR-016, FR-022) yang dapat menghasilkan satu atau lebih hazard terstruktur (FR-017), langsung ditambahkan ke hazard dataset (tidak ada langkah confirm/reject eksplisit di SRS untuk mode teks — berbeda dengan mode foto §3.1–§3.3, sesuai Architecture Document §3).

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
Array `hazards` mengakomodasi kemungkinan satu laporan teks menghasilkan lebih dari satu hazard (FR-016, Domain-Risk-Model §2.3).

**Status/Error:**
- `422` — `text` kosong / `location` tidak valid.
- `502/503` — AI extraction provider gagal; tidak ada hazard yang dibuat (`hazards: []`), `error.code = "AI_PROVIDER_UNAVAILABLE"`.

---

### 3.5 `POST /api/v1/hazard-reports/quick`

**Purpose:** Mengirim quick-tap report (FR-018, FR-019) — tanpa AI, langsung menjadi hazard terstruktur dengan default confidence (FR-020).

**Request:**
```json
{
  "type": "Fire",
  "location": { "lat": -6.20, "lng": 106.81 }
}
```
`type` wajib salah satu dari 6 kategori MVP yang ditampilkan di daftar quick-tap (FR-018).

**Response — `201 Created`:**
```json
{
  "hazard_id": "string",
  "status": "Reported",
  "type": "Fire",
  "severity": "TBD",
  "confidence": "TBD (default quick-tap, nilai pasti belum ditentukan)",
  "road_impact": "TBD",
  "location": { "lat": -6.20, "lng": 106.81 },
  "source": "QuickTap",
  "timestamp": "2026-08-21T09:25:00Z",
  "evidence": null
}
```
Nilai `severity`, `confidence`, dan `road_impact` default untuk quick-tap belum ditentukan sumber dokumen (Domain-Risk-Model §4.1, §5.1: "exact default TBD") — API tetap mewajibkan field ini ada di response begitu nilai default ditetapkan saat implementasi.

**Status/Error:**
- `422` — `type` bukan salah satu dari 6 kategori MVP, atau `location` tidak valid.

---

### 3.6 `POST /api/v1/hazard-reports/voice` *(kondisional — SHOULD, hanya jika voice reporting diimplementasikan)*

**Purpose:** Mengirim rekaman suara sebagai hazard report (FR-023) — transkrip diproses lewat jalur ekstraksi teks yang sama dengan §3.4.

**Request:**
- Content-Type: `multipart/form-data`
- Fields: `audio` (file, wajib), `location` (object, wajib).

**Response — `201 Created`:** Struktur sama dengan §3.4 (`hazards[]`), dengan `source: "AIVoiceExtraction"`.

**Status/Error:** Sama seperti §3.4. Tambahan:
- `501 Not Implemented` — jika voice reporting tidak diimplementasikan pada build tertentu (fitur ini **SHOULD**, bukan **MUST** — SRS §9).

---

## 4. Hazard Retrieval (Dynamic Safety Map)

Mencakup FR-001–FR-004, FR-026–FR-029 (SRS §4.1, §4.8).

### 4.1 `GET /api/v1/hazards`

**Purpose:** Mengambil daftar hazard aktif untuk ditampilkan di Dynamic Safety Map, termasuk severity dan confidence/status (FR-003, FR-029).

**Request (query params):**
| Param | Wajib | Keterangan |
|---|---|---|
| `bbox` | Tidak | `minLng,minLat,maxLng,maxLat` — filter area peta yang sedang ditampilkan. |
| `status` | Tidak | Filter berdasarkan status, mis. `UncertainConflicting` (mendukung kebutuhan uncertain/conflicting reports, §7 dokumen ini). |
| `updated_since` | Tidak | ISO 8601 timestamp — untuk client melakukan refresh incremental (mekanisme pengiriman update, polling vs push, **TBD** sesuai Architecture Document §7). |

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

**Purpose:** Mengambil detail satu hazard, termasuk evidence (FR-014, Domain-Risk-Model §6) — dipakai saat user ingin melihat dasar sebuah hazard di map.

**Request:** Tidak ada body.

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
`conflicting_with` (array hazard_id) diisi bila hazard ini bagian dari conflicting-report group pada segment yang sama (FR-038, Domain-Risk-Model §11.2); kosong bila tidak ada konflik.

**Status/Error:**
- `404` — hazard tidak ditemukan.

---

## 5. Destinations

Mencakup FR-002, FR-005 (SRS §4.1–§4.2).

### 5.1 `GET /api/v1/destinations`

**Purpose:** Mengambil daftar shelter/fasilitas medis yang tersedia untuk ditampilkan di map dan dipilih user (FR-002, FR-005).

**Request (query params, opsional):** `bbox` — sama seperti §4.1.

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
`type`: `Shelter` \| `MedicalFacility` (sesuai PRD/SRS — shelter dan fasilitas medis, SRS §4.1).

**Status/Error:** — (tidak ada kondisi error khusus di luar §2).

---

## 6. Risk-Aware Routing & Dynamic Recalculation

Mencakup FR-005–FR-007, FR-030–FR-037 (SRS §4.2, §4.9–§4.10). Endpoint ini mengekspos **kontrak** Routing Module (cost graph in, Route out, Blocked = tidak dilewati — Domain-Risk-Model §16, Architecture Document §9) tanpa menentukan algoritma/engine di baliknya (FR-034, tetap `TBD`).

### 6.1 `POST /api/v1/routes`

**Purpose:** Membuat rute baru — dipakai untuk rute awal setelah pemilihan destinasi (FR-005, FR-006) maupun saat user mengganti destinasi (FR-007, menggantikan rute sebelumnya).

**Request:**
```json
{
  "destination_id": "string",
  "origin": { "lat": -6.199, "lng": 106.805 }
}
```
`origin` merepresentasikan lokasi user saat ini (FR-001). Identitas user diasumsikan berasal dari `X-Session-Id` (lihat §1) untuk menentukan kepemilikan "active route".

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
Field cost mengikuti skeleton `Route Cost = Base Travel Cost + Hazard Penalty + Uncertainty Penalty` (Domain-Risk-Model §13.2, §16.2) — nilai numerik aktual bergantung pada parameter `TBD` di Risk Module. `supersedes_route_id` diisi bila request ini adalah pergantian destinasi/rekalkulasi yang menggantikan rute aktif sebelumnya (FR-007, FR-037).

**Status/Error:**
- `404` — `destination_id` tidak ditemukan.
- `422` — `origin` di luar controlled road network.
- `409 UNROUTABLE` — tidak ada rute yang tersedia (semua kandidat melewati segment Blocked tanpa alternatif) — kondisi ini valid secara model (Domain-Risk-Model §11.1: "absence of a route is an acceptable outcome") dan harus dibedakan dari error sistem.

---

### 6.2 `GET /api/v1/routes/{route_id}`

**Purpose:** Mengambil detail rute tertentu, termasuk apakah rute ini masih aktif atau sudah digantikan (FR-037).

**Request:** Tidak ada body.

**Response — `200 OK`:** Struktur sama seperti response §6.1, ditambah:
```json
{
  "status": "Superseded",
  "superseded_by_route_id": "string"
}
```

**Status/Error:**
- `404` — `route_id` tidak ditemukan.

---

### 6.3 `GET /api/v1/routes/active`

**Purpose:** Mengambil rute aktif milik user saat ini — digunakan Mobile App untuk mendeteksi rekalkulasi (FR-036, FR-037). Mekanisme pengiriman update (polling berkala vs push/websocket) sengaja tidak dikunci arsitektur (Architecture Document §7); endpoint ini mendefinisikan bentuk **polling** sebagai kontrak minimum yang harus tersedia, tanpa melarang mekanisme push tambahan di luar dokumen ini.

**Request:** Header `X-Session-Id` (lihat §1). Tidak ada body.

**Response — `200 OK`:** Sama seperti §6.2. Jika belum ada rute aktif untuk session tersebut:

**Status/Error:**
- `404 NO_ACTIVE_ROUTE` — user belum memiliki rute aktif.

---

## 7. Uncertain / Conflicting Reports

Mencakup FR-038–FR-040 (SRS §4.11). Tidak ada endpoint terpisah — kebutuhan ini dipenuhi melalui field yang sudah didefinisikan di endpoint hazard (§4):

| Kebutuhan | Dipenuhi lewat |
|---|---|
| Deteksi disagreement material antar report pada segment yang sama (FR-038) | Proses internal Hazard Module (Domain-Risk-Model §11.2) — tidak diekspos sebagai endpoint, hanya hasilnya (lihat baris di bawah). |
| Segment ditandai uncertain/conflicting, bukan otomatis blocked/cleared (FR-039) | `GET /api/v1/hazards` dan `GET /api/v1/hazards/{hazard_id}` — field `status: "UncertainConflicting"` (§4.1, §4.2). |
| Uncertainty penalty pada routing cost segment terkait (FR-040) | `GET /api/v1/routes/{route_id}` — field `uncertainty_penalty` per segment (§6.2). |
| Melihat hazard mana saja yang saling konflik pada satu segment | `GET /api/v1/hazards/{hazard_id}` — field `conflicting_with` (§4.2). |

Tidak ada endpoint tambahan yang diperkenalkan di sini karena requirement ini bersifat *state* pada Hazard/Route yang sudah dicakup, bukan *aksi* baru.

---

## 8. Emergency Simulation

Mencakup FR-041–FR-044 (SRS §4.12; Architecture Document §8). Simulation Module memanggil ulang service produksi yang sama (Hazard/AI/Risk/Routing) — bukan jalur logika terpisah (Architecture Document §8, §10).

### 8.1 `GET /api/v1/simulation/scenarios`

**Purpose:** Mengambil daftar 6 skenario terkontrol yang didukung (FR-043).

**Request:** Tidak ada body.

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

**Status/Error:** — (tidak ada kondisi error khusus di luar §2).

---

### 8.2 `POST /api/v1/simulation/scenarios/{scenario_id}/run`

**Purpose:** Memicu eksekusi skenario terprogram (FR-041), yang berjalan lewat jalur normal Hazard/AI/Risk/Routing Module (Architecture Document §8) secara reproducible (FR-042).

**Request:**
```json
{
  "origin": { "lat": -6.199, "lng": 106.805 },
  "destination_id": "string"
}
```
`origin`/`destination_id` diperlukan agar skenario dapat menghasilkan baseline route dan risk-aware route yang konkret (FR-044) — skenario itu sendiri (daftar Observation yang disuntikkan) sudah didefinisikan sebagai data tetap di Simulation Module (Architecture Document §8), bukan bagian dari request ini.

**Response — `202 Accepted`:**
```json
{
  "run_id": "string",
  "scenario_id": "blocked_road",
  "status": "Running",
  "started_at": "2026-08-21T10:00:00Z"
}
```
Status `202` dipakai karena skenario menjalankan alur end-to-end (AI, risk, routing) yang berpotensi tidak instan (Architecture Document §8) — hasil diambil lewat §8.3.

**Status/Error:**
- `404` — `scenario_id` tidak dikenal (bukan salah satu dari 6 skenario MVP).
- `422` — `destination_id` tidak ditemukan.

---

### 8.3 `GET /api/v1/simulation/runs/{run_id}`

**Purpose:** Mengambil hasil skenario yang sudah/sedang berjalan, termasuk perbandingan baseline (shortest/fastest) vs risk-aware route (FR-044).

**Request:** Tidak ada body.

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
    "note": "Base Travel Cost saja, Hazard/Uncertainty Penalty diabaikan (FR-044)"
  },
  "risk_aware_route": {
    "route_id": "string",
    "total_cost": 128.4,
    "note": "Base Travel Cost + Hazard Penalty + Uncertainty Penalty"
  },
  "completed_at": "2026-08-21T10:00:05Z"
}
```
Kedua rute dihasilkan dari cost graph yang sama, hanya berbeda pada penyertaan Hazard/Uncertainty Penalty (Architecture Document §8, "Keputusan desain kunci"), sehingga perbandingan tetap adil sesuai FR-044.

**Status/Error:**
- `404` — `run_id` tidak ditemukan.
- `202`-equivalent (`status: "Running"` dalam body `200 OK`) — bila run belum selesai, `baseline_route`/`risk_aware_route` bernilai `null`; client diharapkan melakukan polling (mekanisme pasti **TBD**, sama seperti §6.3).

---

## 9. Ringkasan Pemetaan Requirement → Endpoint

| Kebutuhan (dari instruksi) | Endpoint |
|---|---|
| Hazard reporting & retrieval | §3 (`POST /hazard-reports/*`, `POST/PATCH /hazard-suggestions/*`), §4 (`GET /hazards`, `GET /hazards/{id}`) |
| AI hazard processing | Terintegrasi dalam §3.1–§3.6 (AI dipanggil secara internal oleh Hazard Module, tidak diekspos sebagai endpoint terpisah — sesuai Architecture Document §2, §3: AI Module tidak pernah diakses langsung dari luar Hazard Module) |
| Destinations | §5 (`GET /destinations`) |
| Risk-aware routing | §6.1–§6.2 (`POST /routes`, `GET /routes/{id}`) |
| Dynamic route recalculation | §6.3 (`GET /routes/active`) |
| Uncertain/conflicting reports | §7 (field `status`, `uncertainty_penalty`, `conflicting_with` pada endpoint §4 dan §6) |
| Emergency simulation | §8 (`GET /simulation/scenarios`, `POST /simulation/scenarios/{id}/run`, `GET /simulation/runs/{id}`) |

---

## 10. Batasan (Out of Scope untuk Spesifikasi Ini)

Konsisten dengan SRS §9/§11 dan Architecture Document §11:

- Tidak ada endpoint untuk dashboard/tooling khusus Volunteer/Coordinator.
- Tidak ada endpoint autentikasi/otorisasi kompleks — identifikasi user tetap **TBD** (§1).
- Tidak ada endpoint yang mengunci routing engine/algoritma tertentu — kontrak `POST /routes` hanya mendefinisikan bentuk request/response, bukan cara Routing Module menghitung rute secara internal.
- Tidak ada endpoint untuk multi-disaster atau hazard type di luar 6 tipe MVP.
- Tidak ada endpoint terpisah untuk "melihat evidence" sebagai fitur berdiri sendiri — evidence hanya field pada response hazard (§4.2), sesuai Domain-Risk-Model §6 yang menyebut evidence sebagai atribut data, bukan fitur UI wajib.
- Mekanisme pengiriman notifikasi real-time (push/websocket) tidak dispesifikasikan — hanya kontrak polling minimum (§6.3, §8.3) yang didefinisikan; **TBD** untuk implementasi lebih lanjut.

---

**Status Dokumen:** API Specification untuk QuakeRoute MVP hackathon 10 hari, diturunkan dari `SRS.md`, `Domain-Risk-Model.md`, dan `Architecture-Document.md`. Tidak ada requirement, entitas domain, formula risk model, atau keputusan arsitektur yang diubah oleh dokumen ini. Routing engine tetap `TBD` secara sengaja. Item yang ditandai `TBD` di dokumen-dokumen sumber tetap `TBD` di sini.
