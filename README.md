# SwipeCleaner: Spec-Driven Development (100% Local & Private)

> A native iOS photo and video gallery manager engineered for high-speed media triage, 100% on-device privacy, and zero network transmission—built using Spec-Driven Development (SDD), Agentic AI Skills, and Swift 6 software engineering.

<p align="center">
  <img src="https://github.com/user-attachments/assets/6a3d773f-0f7d-4df1-b335-50102db14638" alt="IMG_4640" width="45%" />
  <img src="https://github.com/user-attachments/assets/a27a44fa-ecbe-491c-90c1-23ceeac77100" alt="IMG_4641" width="45%" />
</p>

---

## Why This Project?

**SwipeCleaner** grew out of a practical personal need as an iPhone user: I wanted a fast, gesture-based app to clean up an overflowing photo library—with a strict requirement of **100% local, zero-network privacy**, ensuring not a single byte of media ever leaves the device.

Taking advantage of this real-world need, I made a conscious decision to pursue self-directed learning through online courses to master modern software engineering breakthroughs—such as **Spec-Driven Development (SDD)**, **Prompt Engineering**, **Agentic AI Skills** (`.agents/skills`), and **Model Context Protocol (MCP)**. Because technology advances at an exponential rate, traditional university curricula cannot always keep pace with these emerging tools. Building SwipeCleaner served as a hands-on lab for autonomous education, combining cutting-edge AI engineering workflows with **Swift 6 strict concurrency** and native iOS development.

---

## Overcoming Hardware & License Barriers: Developing iOS Apps on Windows

Developing native iOS applications traditionally requires owning a Mac computer and paying a $99/year Apple Developer membership. As a student working on a Windows PC without these hardware and subscription resources, I refused to let those barriers limit what I could build.

Instead, I actively researched alternative cloud engineering workflows to create a zero-cost, fully autonomous iOS development solution:

- **Windows as the Primary Workstation**: Writing code, defining executable specifications (`/spec`), and orchestrating AI agents locally on Windows.
- **Cloud Mac Compiler via GitHub Actions**: Leveraging hosted `macos-latest` cloud runners equipped with Xcode to compile and run tests on every commit.
- **Unsigned IPA Build Strategy**: Configuring `xcodebuild` with `CODE_SIGNING_REQUIRED=NO` and `CODE_SIGN_IDENTITY=""` to automatically package release-ready `.ipa` binaries (`SwipeCleaner-unsigned.ipa`).
- **Direct iPhone Sideloading**: Downloading the cloud-built `.ipa` artifact and installing it onto a physical iPhone using free sideloading tools (such as AltStore or Sideloadly) with a standard free Apple ID.

This personal research allowed me to build, test, and deploy a native iOS app directly to a physical iPhone using my existing Windows setup—completely bypassing hardware and paid license restrictions.

---

## Spec-Driven Development (SDD) & Agentic Skills Architecture

Rather than relying on unguided code generation—often called **"vibe coding"**, a trend that popularizes unmaintainable code lacking architectural rigor—SwipeCleaner anchors every implementation detail in executable specifications (`/spec`).

To achieve production-grade quality, AI agents are equipped with modular **Agentic Skills** (`.agents/skills/`) covering PhotoKit asynchronous caching, SwiftUI performance profiling, Apple HIG standards, and Swift 6 concurrency invariants.

The repository structure reflects this specification-first architecture:

```text
SwipeCleaner/  (Workspace Root)
│
├── AGENTS.md                               # Operational Contract & AI Engineering Guidelines
│
├── .agents/                                # Specialized AI Domain Knowledge & Guidelines
│   └── skills/
│       ├── github-actions/                 # CI/CD Workflows & IPA Packaging Patterns
│       ├── ios-swift-development/          # Swift 6 Concurrency & Architecture Patterns
│       ├── mobile-ios-design/              # Apple HIG Standards & SwiftUI UX Patterns
│       ├── photokit/                       # PhotoKit Asset Caching & Asynchronous Requests
│       ├── swiftui-animation/              # Physics-Based Animations & Gesture Handling
│       └── swiftui-performance/            # Memory Benchmarks & Performance Optimization
│
├── spec/                                   # Spec-Driven Development (SDD) Core Specifications
│   ├── constitution/                       # Core System Guidelines & Global Constraints
│   │   ├── mission.md                      # Privacy Invariants & System Objectives
│   │   ├── tech-stack.md                   # iOS 17+, Swift 6 & Xcode Target Specifications
│   │   └── roadmap.md                      # Milestone Engineering Roadmap
│   └── features/                           # Executable Feature Specifications
│       ├── 001-setup-y-cicd/               # Feature 001: CI/CD Pipeline & Build Target
│       │   ├── spec.md                     # System Requirements & User Scenarios
│       │   ├── plan.md                     # Technical Implementation Architecture
│       │   └── tasks.md                    # Verification & Task Checklist
│       ├── 002-interfaz-galeria/           # Feature 002: Grid Gallery & PhotoKit Integration
│       │   ├── spec.md
│       │   ├── plan.md
│       │   └── tasks.md
│       ├── 003-motor-swipe/                # Feature 003: Gesture-Based Swipe Engine & Video Playback
│       │   ├── spec.md
│       │   ├── plan.md
│       │   └── tasks.md
│       ├── 004-eliminacion-photokit/       # Feature 004: Batch Deletion & Summary Review
│       │   ├── spec.md
│       │   ├── plan.md
│       │   └── tasks.md
│       └── 005-persistencia-sesion/        # Feature 005: State Persistence & Session Resume
│           ├── spec.md
│           ├── plan.md
│           └── tasks.md
│
├── .github/
│   └── workflows/
│       └── build.yml                       # GitHub Actions Automated CI/CD Pipeline
│
└── codigo/                                 # iOS Source Code & Verification Suites
    ├── SwipeCleaner.xcodeproj/             # Xcode Project & Build Target Configurations
    ├── SwipeCleaner/                       # Application Implementation (App, Features, Resources)
    ├── SwipeCleanerTests/                  # XCTest & Swift Testing Suites
    └── scripts/                            # Privacy Guardrail Verification Scripts (lint_network.sh)
```

---

## Key Capabilities

### 1. High-Performance Swipe Engine
- **Gesture-Driven Triage**: Swipe cards right to retain assets or left to mark items for batch deletion using spring physics and haptic feedback.
- **Transactional Undo**: Instantly revert previous classification decisions with full state restoration.
- **Double-Buffered Memory Prefetching**: Maintains a bounded 3-card prefetch window in RAM to ensure seamless card transitions without UI stutter.

### 2. Dual Presentation Modes & Session Retention
- **Grid Gallery Mode**: Browse the complete media library sorted chronologically using lazy loading containers.
- **Full-Screen Review Mode**: Perform focused, card-by-card media classification.
- **Automatic State Persistence**: Preserves active classification progress across app lifecycle events via local `UserDefaults` storage.

### 3. High-Definition Decoding & Native Video Playback
- **Progressive Asset Loading**: Renders high-quality downsampled representations (`900x1200`) instantaneously in 10-20ms without blurry preview delays.
- **Aspect-Fit Matte Framing**: Renders landscape (16:9), portrait (9:16), and square (1:1) assets completely uncropped within a black container frame.
- **Integrated Video Engine**: Automatically loops video playback on top-level cards with audio controls.

### 4. Zero-Network Privacy Architecture
- **Volatile In-Memory Execution**: Decoded image buffers and video items exist exclusively in volatile RAM.
- **Network Isolation**: Complete absence of networking modules (`URLSession`, telemetry, analytics, or external SDKs).
- **Native PhotoKit Deletion**: Batch deletion delegates directly to system PhotoKit APIs, moving items safely to the iOS "Recently Deleted" album.

---

## Privacy & Security Architecture

| Security Guarantee | Implementation Detail | Automated Enforcement |
|---|---|---|
| **Complete Network Isolation** | No network frameworks imported (`URLSession`, `Network`, `WebKit`) | Enforced by `lint_network.sh` in CI & `NetworkGuardrailTests` |
| **Volatile RAM Storage** | Downsampled `UIImage` and `AVPlayerItem` instances kept only in memory | Enforced by bounded cache invariants (`count <= 3`) |
| **Jetsam Crash Prevention** | Fast resize modes with highQualityFormat image delivery | Prevents memory allocation spikes under heavy load |
| **Sandboxed Access** | Media accessed strictly via PhotoKit local identifiers | Enforced by iOS PhotoKit authorization scope |

---

## Technical Stack

- **Methodology & AI Architecture**: Spec-Driven Development (SDD), Agentic Domain Skills (`.agents/skills/`) & Operational Contracts (`AGENTS.md`)
- **Programming Language**: Swift 6 (`SWIFT_STRICT_CONCURRENCY = complete`)
- **UI Framework**: SwiftUI + `@Observable` (Observation framework)
- **Media Framework**: PhotoKit (`PHCachingImageManager`, `PHPhotoLibraryChangeObserver`)
- **Video Engine**: AVFoundation (`AVPlayer`, `AVPlayerLayer`, `AVPlayerItem`)
- **State Storage**: `UserDefaults` (Encodable session state)
- **CI/CD Pipeline**: GitHub Actions (`macos-latest`, `xcodebuild test`, `.ipa` packaging)

---

## Development & Build Instructions

### Option A: Building & Installing Without a Mac (Windows + GitHub Actions)

If you don't have a Mac or a paid developer account, you can build and install **SwipeCleaner** directly on your physical iPhone via GitHub Actions:

1. **Trigger Cloud Build**: Push changes to your repository or go to the **Actions** tab in GitHub and click **CI & Build Pipeline > Run workflow**.
2. **Download the Unsigned IPA**: Once the workflow finishes, scroll to the bottom of the run summary under **Artifacts** and download `SwipeCleaner-unsigned-ipa`. Unzip the file to extract `SwipeCleaner-unsigned.ipa`.
3. **Sideload to iPhone (Windows)**:
   - Connect your iPhone to your Windows PC via USB.
   - Use a free sideloading app like [AltStore / AltServer](https://altstore.io/) or [Sideloadly](https://sideloadly.io/).
   - Select the downloaded `SwipeCleaner-unsigned.ipa` file and sign it with your free Apple ID.
4. **Trust Certificate on iPhone**: On your device, go to **Settings > General > VPN & Device Management**, select your Apple ID, and tap **Trust "SwipeCleaner"**.

### Option B: Building Locally with Xcode (macOS)

1. Clone the repository:
   ```bash
   git clone https://github.com/your-repo/SwipeCleaner.git
   cd SwipeCleaner
   ```
2. Open the project configuration:
   ```bash
   open codigo/SwipeCleaner.xcodeproj
   ```
3. Select an iOS 17.0+ Simulator or physical device and run (`Cmd + R`).

### Executing Automated Guardrails

To run the automated network privacy verification locally:

```bash
chmod +x ./codigo/scripts/lint_network.sh
./codigo/scripts/lint_network.sh
```
