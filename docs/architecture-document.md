# QuakeRoute — Architecture Document

## 0. Status Dokumen dan Sumber Kebenaran

- **Source of truth:** `PRD.md`, `SRS.md`, `Domain-Risk-Model.md`, `AI-Requirements.md`, dan `tech-stack.md`. Dokumen ini **tidak** mengubah, menambah, atau menghapus requirement, entitas domain, formula risk model, atau keputusan teknologi apa pun yang sudah ditetapkan dokumen-dokumen tersebut.
- **Yang dilakukan dokumen ini:** menerjemahkan requirement (SRS), model domain/risiko (Domain-Risk-Model), scope AI (AI-Requirements), dan stack yang sudah diputuskan (tech-stack) menjadi struktur arsitektur yang **implementable** dalam hackathon 10 hari — komponen, tanggung jawab, alur interaksi, struktur modul, dan batas antar-lapisan.
- **Yang tidak dilakukan dokumen ini:** API specification, database schema, dan UI/UX specification detail — ini adalah dokumen terpisah yang diturunkan *dari* arsitektur ini, bukan bagian dari arsitektur ini.
- **Routing engine:** tetap `TBD` sesuai `tech-stack.md` §7 dan SRS FR-034. Dokumen ini mendefinisikan **kontrak** yang harus dipenuhi routing layer (lihat §4.4 dan §6), bukan engine/algoritma spesifik.
- **Angka/parameter:** semua parameter numerik yang masih `TBD` di Domain-Risk-Model (severity weight, confidence factor, uncertainty weight, staleness decay) tetap `TBD` di sini. Arsitektur ini hanya menyediakan *tempat* (module/interface) di mana parameter tersebut akan dikonfigurasi saat implementasi.

---

## 1. Architecture Overview

QuakeRoute MVP dibangun sebagai:

- **Backend:** Modular Monolith berbasis **Laravel 13**, satu deployable unit, dipecah secara **logis** (bukan secara jaringan/servis) menjadi module Hazard, AI, Risk, Routing, dan Simulation.
- **Mobile:** **Flutter**, Feature-Oriented Architecture — satu aplikasi, dipecah per fitur (map, reporting, routing, simulation) dengan lapisan `core/` bersama.
- **Database:** **PostgreSQL + PostGIS** — satu datastore relasional+spasial, dipakai backend saja (mobile tidak pernah mengakses database langsung).
- **AI:** diakses backend melalui **AI Service Abstraction** — provider-agnostic, sesuai `tech-stack.md` §3.3 dan `AI-Requirements.md`.
- **Routing:** diakses melalui satu **Routing Interface** di dalam backend; implementasi konkretnya (library graph in-process, atau service eksternal) **tidak dipilih** di sini — tetap `TBD` sesuai instruksi.

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
│   │  Module   │  (mengorkestrasi skenario lewat modul lain)   │
│   └───────────┘                                                │
└──────────────┬──────────────────────────┬────────────────────┘
               │                           │
    ┌──────────▼──────────┐     ┌──────────▼──────────────┐
    │ PostgreSQL + PostGIS │     │  External AI Provider    │
    │ (Hazard, RoadSegment,│     │  (LLM + Vision, TBD)      │
    │  Route, Simulation)  │     │  via AI Service Abstraction│
    └───────────────────────┘     └───────────────────────────┘
```

**Prinsip desain utama** (langsung dari instruksi & source docs):

1. **Modular monolith, bukan microservices** — satu proses/deployable, pemisahan tanggung jawab murni logis (namespace/folder + interface), agar tetap sederhana untuk 10 hari (`tech-stack.md` §10: "no production-scale infrastructure").
2. **Setiap module berkomunikasi lewat interface/contract yang eksplisit**, bukan saling memanggil Eloquent model milik module lain — ini yang membuat Risk, Routing, Hazard, AI, dan Simulation "terpisah secara logis" sesuai instruksi, sekaligus memenuhi NFR-008 (maintainability/extensibility — SRS §5).
3. **AI dan Routing adalah dua boundary yang paling ketat**, karena keduanya provider/engine yang `TBD`. Keduanya hanya boleh diakses lewat satu interface masing-masing.
4. **Domain flow dokumen-dokumen sumber (Observation → Hazard → Risk → Routing Cost → Route) menjadi urutan pemanggilan antar module**, bukan diagram yang berdiri sendiri.

---

## 2. System Components dan Tanggung Jawab

| Komponen | Tanggung Jawab | Tidak Bertanggung Jawab Atas |
|---|---|---|
| **Mobile App (Flutter)** | Menampilkan Dynamic Safety Map, menerima input reporting (photo/text/quick-tap/[voice]), menampilkan rute & rekalkulasi, memicu simulation trigger (untuk demo). | Logika AI, risk scoring, routing algorithm, penyimpanan data persisten. |
| **Backend — Hazard Module** | Menerima Observation dari semua mode reporting, menyimpan Hazard (struktur PRD §12 / Domain-Risk-Model §3), mengelola status lifecycle Hazard (§7), mendeteksi conflicting reports (§11.2). | Menentukan Severity/Confidence dari input mentah (itu tugas AI Module untuk photo/text), menghitung routing cost, memilih rute. |
| **Backend — AI Module (AI Service Abstraction)** | Mengubah Observation (photo/text/voice-transcript) menjadi candidate Hazard (Type, Severity, Confidence, Road Impact, Context, Evidence) sesuai `AI-Requirements.md` §5–§6. Menyembunyikan provider AI konkret di balik satu interface. | Menyimpan Hazard final, menentukan Status lifecycle, menghitung Risk/Routing Cost, memilih rute (`AI-Requirements.md` §2, §11). |
| **Backend — Risk Module** | Menghitung Hazard Penalty dan Uncertainty Penalty per Road Segment dari Hazard aktif (Domain-Risk-Model §13–§16), menghasilkan Segment Routing Cost. | Menyimpan/mengelola Hazard itu sendiri, memilih algoritma pathfinding, memanggil AI provider. |
| **Backend — Routing Module** | Menyediakan Routing Interface yang menerima cost graph (dari Risk Module) dan mengembalikan Route (min-cost path, tidak melewati segment Blocked). Implementasi engine di baliknya **TBD**. | Menghitung Hazard/Uncertainty Penalty (itu tugas Risk Module), menentukan kapan rekalkulasi dipicu (itu tugas Hazard Module + orchestrator, lihat §7). |
| **Backend — Simulation Module** | Menyimpan & menjalankan 6 skenario terkontrol (FR-041–044), memicu Observation/Hazard secara terprogram melalui jalur yang sama seperti reporting normal, menyediakan perbandingan baseline vs risk-aware route. | Tidak punya logika risk/AI/routing sendiri — murni orchestrator yang memanggil module lain. |
| **PostgreSQL + PostGIS** | Menyimpan seluruh entitas domain persisten: Observation, Hazard, Road Segment (geometry), Route, Simulation scenario/state. | Logika bisnis apa pun (tidak ada stored procedure kompleks; logika tetap di Laravel). |
| **External AI Provider** | Melakukan inferensi LLM (text) dan Vision (photo), dipanggil hanya oleh AI Module. | Segala hal di luar hazard understanding (lihat `AI-Requirements.md` §2). |
| **OSM-compatible Tile Provider** | Menyuplai tile peta dasar untuk `flutter_map`. | Data road network terkontrol (itu ada di PostGIS, diseed dari OSM saat setup, bukan dikonsumsi live). |

---

## 3. Interaction / Alur Utama Antar Komponen

Diagram berikut memetakan flow inti dari `Domain-Risk-Model.md` §1 ke pemanggilan antar komponen arsitektur:

```
Mobile App
   │  (1) submit Observation (photo/text/quick-tap/[voice])
   ▼
Backend REST Layer
   │  (2) route ke Hazard Module
   ▼
Hazard Module
   │  (3) jika photo/text/voice → delegasikan ke AI Module
   │      jika quick-tap → langsung buat Hazard (default confidence, tanpa AI)
   ▼
AI Module ──(4) panggil AI Service Abstraction──▶ External AI Provider
   │
   ▼ (5) candidate Hazard (Type, Severity, Confidence, Road Impact, Context, Evidence)
Hazard Module
   │  (6) simpan Hazard (Status: Reported/pending confirmation sesuai FR-025),
   │      jalankan pengecekan conflicting reports (§11.2) bila relevan
   ▼
Risk Module
   │  (7) hitung ulang Segment Routing Cost untuk segment yang terdampak
   ▼
Routing Module
   │  (8) jika segment terdampak berada pada active route user manapun →
   │      minta Route baru lewat Routing Interface
   ▼
Backend REST Layer ──(9)── notifikasi/response ──▶ Mobile App
   │
   ▼ (10) tampilkan Hazard di map (NFR-004) dan/atau Route baru (FR-037)
```

Catatan penting yang mengikat urutan ini (langsung dari source docs, tidak boleh dilonggarkan saat implementasi):

- Hazard Module **tidak pernah** memanggil AI Module untuk quick-tap (`AI-Requirements.md` §4: quick-tap "Unsupported (not an AI input)").
- AI Module **tidak pernah** memanggil Risk atau Routing Module secara langsung — outputnya hanya lewat ke Hazard Module (`AI-Requirements.md` §2: "AI does not determine routes").
- Risk Module **tidak pernah** memilih rute — ia hanya menghasilkan cost per segment; pemilihan rute murni tanggung jawab Routing Module (Domain-Risk-Model §13.1).
- Untuk photo report, Hazard baru berstatus final/confirmed setelah user melakukan confirm/reject/edit (FR-012–FR-014) — langkah ini terjadi di Mobile App + Hazard Module, sebelum Risk Module menghitung ulang cost untuk Hazard tersebut.

---

## 4. Backend Module Structure (Laravel Modular Monolith)

Struktur folder di bawah adalah **panduan implementasi**, bukan API/DB spec. Setiap module adalah namespace terpisah di dalam satu aplikasi Laravel; module saling berkomunikasi lewat **Contract (interface)**, bukan lewat pemanggilan langsung ke class internal module lain.

```
app/
├── Modules/
│   ├── Hazard/
│   │   ├── Domain/            # Entity: Observation, Hazard, Evidence (POPO/DTO, bukan Eloquent langsung)
│   │   ├── Models/            # Eloquent models (Hazard, Observation)
│   │   ├── Services/          # HazardService: create, confirm, reject, detect conflict
│   │   ├── Contracts/         # HazardRepositoryInterface, ConflictDetectorInterface
│   │   └── Http/              # Controllers untuk endpoint reporting (detail di API Spec terpisah)
│   │
│   ├── AI/
│   │   ├── Contracts/         # AIProviderInterface (satu-satunya pintu ke provider eksternal)
│   │   ├── Services/          # AIHazardUnderstandingService (implements pipeline AI-Requirements §5–§6)
│   │   ├── Providers/         # Implementasi konkret AIProviderInterface (LLM, Vision) — provider TBD
│   │   └── DTO/                # CandidateHazardDTO (Type, Severity, Confidence, Road Impact, Context, Evidence)
│   │
│   ├── Risk/
│   │   ├── Services/          # RiskCalculationService: HazardPenalty(), UncertaintyPenalty(), SegmentRoutingCost()
│   │   ├── Contracts/         # RiskCalculatorInterface
│   │   └── Config/            # tempat konfigurasi parameter TBD (severity weight, confidence factor, dst.)
│   │
│   ├── Routing/
│   │   ├── Contracts/         # RoutingEngineInterface (compute route dari cost graph) — engine TBD
│   │   ├── Services/          # RoutingOrchestrator: bangun cost graph dari Risk Module, panggil engine,
│   │   │                      #   deteksi dampak ke active route (FR-035), trigger rekalkulasi
│   │   └── Models/            # RoadSegment, Route (Eloquent, PostGIS geometry)
│   │
│   ├── Simulation/
│   │   ├── Scenarios/         # Definisi 6 skenario (No Hazard, Blocked Road, High-Risk, New Hazard,
│   │   │                      #   Conflicting Reports, AI Vision) — data terstruktur, bukan hardcode logic
│   │   ├── Services/          # SimulationRunnerService: replay skenario lewat jalur normal
│   │   │                      #   (Hazard/AI/Risk/Routing Module), bukan jalur pintas/mock terpisah
│   │   └── Http/              # Controller untuk trigger & baseline-vs-risk-aware comparison (FR-044)
│   │
│   └── Shared/
│       ├── Location/          # value object Location + resolusi ke Road Segment (PostGIS query)
│       └── ValueObjects/      # Severity, Confidence, RoadImpact, Status (enum/ordinal, sesuai §4.2 Domain-Risk-Model)
│
├── Http/                      # REST entrypoint tipis, delegasi ke Module Services
└── Providers/                 # Service Container bindings: bind setiap *Interface* ke implementasi konkretnya
                                #   (di sinilah AIProviderInterface & RoutingEngineInterface "dicolokkan")
```

**Aturan boundary (wajib dijaga selama implementasi):**

- Module lain **hanya** boleh bergantung pada `Contracts/` milik module lain, tidak pernah pada `Models/` atau `Services/` internal module lain secara langsung.
- `AIProviderInterface` dan `RoutingEngineInterface` adalah satu-satunya titik di mana vendor/engine eksternal "bocor" ke dalam kode — sesuai `tech-stack.md` §10 ("AI must remain provider-agnostic") dan SRS FR-034 (routing algorithm = implementation detail).
- Parameter numerik yang masih `TBD` (severity weight, confidence factor, uncertainty weight, staleness decay, default confidence quick-tap) hidup di `Modules/Risk/Config` dan `Modules/Hazard` sebagai nilai yang bisa diubah tanpa mengubah struktur kode — bukan hardcoded di banyak tempat.

---

## 5. Flutter Project Structure (Feature-Oriented)

```
lib/
├── core/
│   ├── network/            # dio client, interceptors, base API client
│   ├── state/              # Riverpod providers global (mis. active route, connectivity)
│   ├── models/             # DTO bersama: Hazard, RoadSegment, Route (mirror struktur backend, read-only di client)
│   ├── theme/               # styling bersama
│   └── utils/
│
├── features/
│   ├── map/                 # Dynamic Safety Map (FR-001–004)
│   │   ├── presentation/    # widget map (flutter_map), overlay hazard, severity/confidence indicator (NFR-004)
│   │   ├── application/     # Riverpod providers/state untuk map & hazard layer
│   │   └── data/            # pemanggilan REST untuk fetch hazard/road network state
│   │
│   ├── destination/         # Destination Selection (FR-005–007)
│   │
│   ├── reporting/           # Hazard Reporting — semua mode (FR-008–020)
│   │   ├── photo/           # image_picker + alur confirm/reject/edit (FR-012–014)
│   │   ├── text/            # free-text input
│   │   ├── quick_tap/       # predefined category list
│   │   └── voice/           # [opsional/SHOULD HAVE — hanya jika diimplementasikan]
│   │
│   ├── routing/             # Route display, dynamic recalculation (FR-006, FR-035–037)
│   │   ├── presentation/    # tampilan rute aktif vs rute baru (distinguishable, FR-037)
│   │   ├── application/     # Riverpod state untuk active route + listener perubahan
│   │   └── data/
│   │
│   └── simulation/          # Trigger skenario & lihat baseline vs risk-aware (FR-041–044)
│                             #   — untuk demo/evaluator, bisa berupa screen terpisah dalam app yang sama
│
└── main.dart                # bootstrap Riverpod ProviderScope, routing antar feature
```

**Prinsip Feature-Oriented di sini:**

- Setiap folder di `features/` berdiri sendiri (presentation + application/state + data), sehingga bisa dikerjakan paralel oleh anggota tim berbeda selama hackathon tanpa saling mengunci file.
- `core/` hanya berisi hal yang benar-benar dipakai lintas fitur (network client, model bersama, state global seperti active route) — tidak menjadi tempat "semua logika campur aduk".
- Mobile app **tidak** menghitung Severity/Confidence/Routing Cost sendiri — semua nilai itu murni ditampilkan dari response backend, konsisten dengan pemisahan tanggung jawab di §2.

---

## 6. Data Flow: Hazard Reporting → AI → Risk Assessment → Routing

Alur ini adalah implementasi konkret dari `Domain-Risk-Model.md` §1 dan §12, dipetakan ke module backend:

```
[Mobile] Observation submitted (photo / text / quick-tap / [voice])
   │
   ▼
[Hazard Module] terima Observation, tentukan jalur berdasarkan mode:
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
   │      ▼ (photo report: butuh confirm/reject/edit user        │
   │         sebelum lanjut — FR-012–014)                        │
   │      │                                                     │
   └──────┴─────────────────────────────────────────────────────┘
              │
              ▼
[Hazard Module] simpan Hazard dengan Status awal (Reported/Confirmed sesuai FR-025,
   default confidence untuk quick-tap — Domain-Risk-Model §5.1), attach ke Location
              │
              ▼
[Hazard Module] cek apakah ada Hazard lain aktif pada Road Segment yang sama →
   jika ada material disagreement → set Status = Uncertain/Conflicting (§11.2)
              │
              ▼
[Risk Module] untuk setiap Road Segment terdampak:
   SegmentRoadImpact = worst(RoadImpact(h) untuk semua Hazard aktif)      (Domain-Risk-Model §9.2)
   HazardPenalty     = max(SeverityWeight(h) × ConfidenceFactor(h))       (§14.1)
   UncertaintyPenalty = UncertaintyWeight(SegmentStatus)                  (§15.1)
   SegmentRoutingCost = ∞ jika Blocked, else BaseTravelCost + HazardPenalty + UncertaintyPenalty  (§16.1)
              │
              ▼
[Routing Module] cost graph (semua Segment Routing Cost) tersedia untuk permintaan rute
              │
              ▼
Route dihitung on-demand ketika:
   (a) user memilih destination (FR-006) → initial route, atau
   (b) segment terdampak berada di active route user (lihat §7 di bawah)
```

**Poin yang wajib dijaga saat implementasi** (langsung dari source docs):

- Severity dan Confidence **tidak pernah digabung** menjadi satu angka di module manapun — keduanya tetap dua field terpisah dari AI Module sampai Risk Module (AI-Requirements §8; Domain-Risk-Model §5.2).
- Uncertainty **tidak pernah "hilang diam-diam"** — setiap Hazard dengan confidence rendah atau status conflicting harus tetap menghasilkan penalty yang terlihat (Domain-Risk-Model §8), bukan diabaikan oleh Risk Module.
- Risk Module menghitung ulang cost **per segment yang terdampak saja**, bukan seluruh graph, agar tetap murah untuk rekalkulasi (lihat §7).

---

## 7. Dynamic Route Recalculation Flow

Mengimplementasikan FR-035–037 dan Domain-Risk-Model §11.4/§12, dengan dua sifat wajib: **triggered by information (bukan polling)** dan **scoped hanya ke user yang terdampak**.

```
Hazard baru/berubah tersimpan (dari alur §6)
              │
              ▼
[Risk Module] hitung ulang Segment Routing Cost HANYA untuk segment terdampak
              │
              ▼
[Routing Module] — Impact Detector:
   untuk setiap active Route yang sedang berjalan (disimpan di PostgreSQL):
       apakah salah satu segment Route ini termasuk segment yang baru berubah?  (FR-035)
              │
        ┌─────┴─────┐
        │           │
       Tidak         Ya
        │             │
        ▼             ▼
  tidak ada       [Routing Module] minta Route baru dari titik posisi user
  aksi untuk      saat ini ke destination yang sama, lewat Routing Interface,
  user ini —      menggunakan cost graph terbaru (FR-036)
  map/hazard             │
  layer tetap             ▼
  ter-update       Route baru disimpan, ditandai berbeda dari Route lama
  (map global      (mis. flag `superseded_by` / versi rute) — FR-037
  tetap refresh)          │
                          ▼
                  [Backend REST] kirim notifikasi/response Route baru ke
                  Mobile App user yang bersangkutan saja
                          │
                          ▼
                  [Mobile — routing feature] tampilkan Route baru secara
                  visual berbeda dari Route sebelumnya (FR-037)
```

**Catatan arsitektural:**

- "Impact Detector" bukan module terpisah — ia adalah bagian dari **Routing Module** (`RoutingOrchestrator`), karena satu-satunya entitas yang tahu "siapa yang sedang aktif di route mana" adalah Routing Module (pemilik data Route).
- Mekanisme pengiriman notifikasi ke Mobile App (polling REST berkala vs push/websocket) adalah detail implementasi yang **tidak dikunci** di sini — SRS tidak menentukan mekanisme; yang wajib adalah *efeknya* (user yang route-nya terdampak menerima Route baru, user lain tidak menerima rekalkulasi yang tidak perlu).
- Rekalkulasi tidak pernah dipicu oleh jadwal/interval tetap — hanya oleh event "Hazard baru/berubah tersimpan", konsisten dengan Domain-Risk-Model §12.

---

## 8. Simulation Architecture

Emergency Simulation (FR-041–044) **bukan** engine terpisah dengan logika sendiri — ia adalah **orchestrator tipis di atas alur produksi yang sama** (§6–§7), agar hasil simulasi benar-benar mencerminkan perilaku sistem nyata (dan agar tidak perlu membangun dua jalur logika berbeda dalam 10 hari).

```
[Simulation Module] — Scenario Definition (data, bukan kode logic)
   Setiap skenario (No Hazard, Blocked Road, High-Risk Hazard, New Hazard During
   Navigation, Conflicting Reports, AI Vision Hazard Report) didefinisikan sebagai
   data terstruktur: daftar Observation yang akan "disuntikkan", ke Road Segment
   mana, dan (untuk AI Vision) contoh photo/text tetap yang dipakai berulang
   demi reproducibility (FR-042/NFR-002).
              │
              ▼
[Simulation Module] — Scenario Runner:
   1. Reset/siapkan state road network terkontrol yang sama tiap run
   2. Untuk tiap Observation dalam skenario: kirim ke [Hazard Module] persis
      seperti Observation dari Mobile App sungguhan (memanggil Service yang
      sama, BUKAN endpoint/mock terpisah)
   3. Alur §6 berjalan apa adanya: AI Module (jika mode photo/text) → Hazard
      Module → Risk Module → Routing Module
   4. Setelah semua Observation skenario diproses, minta 2 Route dari
      [Routing Module]:
         a. Baseline Route  = Route dihitung dengan Routing Cost = Base Travel
            Cost saja (Hazard/Uncertainty Penalty diabaikan)  — FR-044
         b. Risk-Aware Route = Route dihitung dengan Routing Cost penuh
            (Base + Hazard Penalty + Uncertainty Penalty)     — alur normal
   5. Simpan kedua Route + hazard/risk state yang terjadi, untuk ditampilkan
      berdampingan ke evaluator (FR-044)
```

**Keputusan desain kunci:**

- **Baseline route bukan engine terpisah** — ia adalah pemanggilan yang sama ke Routing Interface, hanya dengan cost graph yang di-strip dari Hazard/Uncertainty Penalty (`BaseTravelCost` saja). Ini menghindari duplikasi logika routing dan menjaga baseline tetap "adil" dibanding risk-aware route.
- **Reproducibility (FR-042/NFR-002)** dicapai dengan: (a) skenario didefinisikan sebagai data tetap (seed), bukan random; (b) road network yang sama di-reset/diseed ulang tiap run (didukung Docker per `tech-stack.md` §8.1); (c) AI Module dipanggil dengan input tetap yang sama tiap run — variasi non-determinisme dari provider AI (jika ada) adalah risiko yang diketahui dan tidak dihindari secara arsitektural di sini, karena provider AI adalah dependency eksternal (`TBD`, di luar kendali arsitektur ini).
- Simulation Module **tidak menyimpan salinan logika Risk/Routing** — jika formula risk model berubah saat tuning (parameter `TBD` di §4 dan §6), simulasi otomatis ikut berubah tanpa perlu disinkronkan manual.

---

## 9. External Dependencies / Integrations

Sesuai `tech-stack.md` §9, dipetakan ke module yang menjadi satu-satunya konsumennya:

| Dependency | Diakses oleh | Arah | Catatan |
|---|---|---|---|
| **External AI Provider** (LLM untuk text/voice, Vision untuk photo — provider `TBD`) | `AI Module` (lewat `AIProviderInterface`) saja | Outbound | Tidak ada module lain yang boleh memanggil provider ini langsung. |
| **Routing Engine/Library** (`TBD`) | `Routing Module` (lewat `RoutingEngineInterface`) saja | In-process call (jika library) atau outbound (jika service) — bentuknya sendiri masih `TBD` | Kontrak yang wajib dipenuhi: terima cost graph, kembalikan min-cost Route, hormati segment Blocked (§16.1 Domain-Risk-Model). |
| **OSM-compatible Tile Provider** | `Mobile — features/map` (lewat `flutter_map`) | Outbound dari Mobile langsung, tidak lewat Backend | Hanya untuk tile visual dasar peta, bukan sumber data road network terkontrol saat runtime. |
| **OpenStreetMap data (untuk setup road network)** | Proses seed/setup awal (bukan runtime) | Data source saat inisialisasi PostGIS | Road network yang benar-benar dipakai saat runtime adalah data yang sudah diseed ke PostGIS, bukan query live ke OSM. |
| **PostgreSQL + PostGIS** | Semua Module backend | Bidirectional | Satu-satunya datastore; tidak ada database terpisah per module (tetap satu monolith data-wise). |
| **Docker** | Seluruh environment (Backend, DB) | Development-time | Memastikan environment konsisten antar anggota tim dan mendukung reproducibility simulasi (NFR-002). |

Tidak ada dependency eksternal baru yang diperkenalkan di luar yang sudah ditetapkan `tech-stack.md`.

---

## 10. Architectural Decisions dan Alasan Singkat

| Keputusan | Alasan Singkat |
|---|---|
| **Modular Monolith (bukan microservices)** | 10 hari tidak cukup untuk mengelola overhead deployment, network call, dan observability microservices; requirement (SRS §9, §11) juga eksplisit "no production-scale infrastructure". Pemisahan tanggung jawab tetap dicapai lewat module + interface, bukan lewat batas jaringan. |
| **Komunikasi antar module lewat Contract/Interface, bukan pemanggilan langsung** | Ini satu-satunya cara membuat AI dan Routing benar-benar *provider-agnostic* dan *algorithm-agnostic* (tech-stack §10, SRS FR-034) di dalam satu proses monolith — tanpa interface, "provider-agnostic" hanya jadi klaim di dokumen, bukan kenyataan di kode. |
| **Routing Interface didefinisikan sekarang, engine di baliknya tidak dipilih** | Memenuhi instruksi eksplisit ("jangan mengunci routing engine") sekaligus tetap memberi tim arah implementasi yang jelas — kontrak (cost graph in, Route out, Blocked = tidak dilewati) sudah cukup untuk mulai coding sisi Risk/Hazard tanpa menunggu keputusan engine. |
| **Simulation Module memanggil ulang Service produksi yang sama, bukan membangun jalur logika sendiri** | Mengurangi risiko "simulasi bohong" (hasil simulasi tidak mencerminkan sistem nyata) dan menghemat waktu implementasi — sejalan dengan tujuan FR-043 (skenario dijalankan end-to-end lewat sistem yang sesungguhnya). |
| **AI Module tidak pernah menyentuh Status lifecycle Hazard** | Langsung mengikuti `AI-Requirements.md` §5 ("AI output does not include a hazard lifecycle Status") dan §11 (AI output bukan ground truth) — Status tetap tanggung jawab Hazard Module. |
| **Baseline route dihitung dari cost graph yang sama dengan risk-aware, hanya minus penalty** | Memastikan FR-044 (perbandingan baseline vs risk-aware) adalah perbandingan yang adil (base travel cost identik), bukan dua sumber data terpisah yang bisa drift. |
| **Flutter Feature-Oriented dengan `core/` minimal** | Memungkinkan kerja paralel antar anggota tim hackathon per fitur (map, reporting, routing, simulation) tanpa saling mengunci file yang sama, sambil tetap punya satu sumber state/network layer bersama untuk konsistensi (NFR-008 secara analog di sisi mobile). |
| **PostgreSQL + PostGIS sebagai satu-satunya datastore** | Sudah diputuskan di `tech-stack.md` §4 — dokumen ini hanya menegaskan tidak ada datastore tambahan per module diperkenalkan, agar monolith tetap benar-benar satu unit deployable. |

---

## 11. MVP Boundaries — Hal yang Sengaja Tidak Dibuat untuk Hackathon

Konsisten dengan `PRD`/`SRS` §9/§11 dan `tech-stack.md` §12, arsitektur ini **secara sengaja tidak mencakup**:

- **Tidak ada microservices, message broker, atau service mesh** — semua module hidup dalam satu proses Laravel.
- **Tidak ada API Gateway atau load balancer** — satu instance backend cukup untuk demo/hackathon.
- **Tidak ada database terpisah per module** — satu PostgreSQL+PostGIS untuk semua data.
- **Tidak memilih routing engine/algoritma** — hanya kontrak interface yang didefinisikan; pemilihan engine adalah keputusan implementasi terpisah (per FR-034).
- **Tidak memilih provider AI (LLM/Vision) konkret** — hanya `AIProviderInterface` yang didefinisikan.
- **Tidak ada dashboard/tooling khusus Volunteer/Coordinator** — role ini memakai kapabilitas Evacuee/Community Reporter yang sama (SRS §3.3), tidak ada module backend atau feature Flutter terpisah untuknya.
- **Tidak ada mekanisme autentikasi/otorisasi kompleks** — di luar scope requirement yang diberikan; jika dibutuhkan identifikasi minimal untuk membedakan user/active route, itu adalah detail implementasi ringan, bukan bagian dari arsitektur module ini.
- **Tidak ada offline mode, push notification infra, atau caching layer khusus** — tidak diminta oleh SRS/tech-stack; mekanisme pengiriman update route (§7) sengaja dibiarkan sebagai detail implementasi.
- **Tidak ada penanganan staleness/decay confidence otomatis** — tetap `TBD` sesuai Domain-Risk-Model §11.3; arsitektur hanya menyediakan field Timestamp, bukan job/cron penurun confidence.
- **Tidak ada dukungan multi-disaster atau hazard type di luar 6 tipe MVP** — AI Module, Risk Module, dan skema data dibatasi ketat ke 6 tipe (`PRD` §12).
- **Tidak ada production-grade reliability/scaling** (retry policy canggih, circuit breaker, autoscaling) — cukup penanganan gagal-sederhana (mis. AI gagal → tidak ada candidate Hazard, sesuai `AI-Requirements.md` §12), karena ini prototype demo, bukan sistem produksi (SRS §8, §11, NFR-007).
- **Tidak ada API specification, database schema, atau UI/UX specification detail di dokumen ini** — ketiganya adalah dokumen turunan terpisah, sesuai batasan yang diberikan.

---

**Status Dokumen:** Architecture Document untuk QuakeRoute MVP hackathon 10 hari, diturunkan dari `SRS.md`, `Domain-Risk-Model.md`, `AI-Requirements.md`, dan `tech-stack.md`. Tidak ada requirement, entitas domain, formula risk model, atau keputusan teknologi yang diubah, ditambah, atau dihapus oleh dokumen ini. Routing engine tetap `TBD` secara sengaja. Item yang ditandai `TBD` di dokumen-dokumen sumber tetap `TBD` di sini.
