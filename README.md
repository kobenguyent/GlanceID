# GlanceID 👁️
> **Bionic Face ID Biometric Simulation for macOS**

**GlanceID** brings the seamless, glance-and-unlock iOS Face ID experience to macOS using Apple's native **Vision** and **AVFoundation** frameworks. Designed specifically for Apple silicon & Intel MacBooks, it enables real-time facial landmark detection, biometric feature print comparison, and an authentic iOS-style Face ID HUD—completely functional without a paid Apple Developer Account.

---

## 🌟 Name Ideas & Rationale

*   **GlanceID** *(Recommended)*: Catchy, intuitive, Apple-esque, evoking the subtle glance at the MacBook camera to authenticate.
*   *Alternative Options*:
    *   **Visage**: Elegant, French-inspired, minimalist.
    *   **AuraID**: Futuristic, sleek, premium.
    *   **LookUnlock**: Direct and action-oriented.

---

## ⚡ Key Features

1. **MacBook Full-Screen Face ID Lock & Unlock**:
   * Lock your entire MacBook screen with `⌘L` or via the **Lock MacBook** tab.
   * Renders an authentic macOS Sonoma/Sequoia style lock screen (clock, date, frosted wallpaper, user profile).
   * Glancing at the camera verifies your facial biometrics, morphs the top pill into a checkmark, plays the chime, and unlocks the screen with a smooth upward slide.
   * Includes password fallback field.

2. **Terminal `sudo` Face ID (PAM Integration)**:
   * Like Touch ID (`pam_tid.so`), GlanceID includes a native PAM module (`pam_glanceid.so`).
   * When you run `sudo` in Terminal, GlanceID glances at your camera and authenticates root privileges with Face ID!

3. **Authentic iOS Face ID Experience**:
   * Iconic 4-bracket corner scanning HUD with expanding/contracting radar animations.
   * Smooth vector morphing into the green checkmark upon match.
   * Dual-tone synthesized chime matching the iOS Face ID feedback tone.
   * Spring-animated failure shake on mismatch.

4. **Strict On-Demand Camera Power Management**:
   * Camera hardware remains completely off (⚪ green LED off) until actively needed.
   * Powers on for ~0.4s during a glance and immediately cuts power the millisecond a match occurs.

5. **Native Vision Biometrics Pipeline**:
   * `VNDetectFaceLandmarksRequest`: Real-time tracking of eyes, nose, lips, and facial contour geometry.
   * `VNGenerateImageFeaturePrintRequest`: Extracts 512-dimension mathematical feature prints (`VNFeaturePrintObservation`).
   * `computeDistance(_:to:)`: Euclidean/Cosine distance comparison (Threshold ~0.42) for biometric verification.

6. **Biometric Vault Demo**:
   * A mock protected vault (API keys, SSH credentials, private notes) that locks and unlocks via GlanceID.

---

## 🚀 How to Install & Test on MacBook Pro (Zero Developer Account Needed)

As an iOS/macOS developer without an Apple Developer Account ($99/year), you can test and run **GlanceID** locally using **Ad-Hoc Code Signing** or **Free Xcode Personal Team**.

### Method 1: Automated Local Build & Install (Recommended)

Run the included installation script from the project root:

```bash
cd /Users/kobet/Desktop/projects/GlanceID
./scripts/install.sh
```

#### What this does under the hood:
1. Compiles the project using Swift Package Manager in release mode (`swift build -c release`).
2. Constructs the macOS bundle structure (`GlanceID.app/Contents/MacOS`, `Info.plist`, `PkgInfo`).
3. Embeds `NSCameraUsageDescription` and `com.apple.security.device.camera` entitlements.
4. Performs **Ad-Hoc Signing** via `codesign --force --deep --sign - --entitlements Resources/GlanceID.entitlements build/GlanceID.app`. Ad-hoc signing (`-`) requires **zero developer certificates or provisioning profiles** while still satisfying macOS TCC requirements.
5. Clears quarantine attributes via `xattr -cr`.
6. Copies `GlanceID.app` to `/Applications` (or `~/Applications`).

To launch the app:
```bash
open /Applications/GlanceID.app
# or
./scripts/run.sh
```

---

### Method 2: Xcode with Free Apple ID (Personal Team)

You can also run directly in Xcode with any standard free Apple ID:

1. Open `Package.swift` in Xcode:
   ```bash
   open /Users/kobet/Desktop/projects/GlanceID/Package.swift
   ```
2. In Xcode, go to **Settings > Accounts** (`⌘,`) and sign in with your normal (free) Apple ID.
3. Xcode provisions a local **Personal Team** certificate automatically.
4. Press `⌘R` to build and run directly on your Mac!

---

## 🔒 macOS Camera Permissions (TCC) Setup

When launching GlanceID for the first time:
1. macOS will display a prompt:
   > *"GlanceID would like to access the camera."*
2. Click **OK**.
3. If you accidentally clicked Don't Allow, enable it in:
   **System Settings > Privacy & Security > Camera > GlanceID [ON]**.

---

## 🏗️ Architecture

```
GlanceID/
├── Package.swift                    # Swift 5.9+ SPM Manifest (macOS v13+)
├── Resources/
│   ├── Info.plist                   # App metadata & NSCameraUsageDescription
│   └── GlanceID.entitlements        # Camera entitlement definition
├── scripts/
│   ├── build_app.sh                 # Builds release bundle & performs ad-hoc signing
│   ├── install.sh                   # Installs to /Applications & removes quarantine
│   └── run.sh                       # Quick build & launch script
└── Sources/GlanceID/
    ├── App/
    │   ├── GlanceIDApp.swift        # Main App entry point & sidebar layout
    │   └── AppState.swift           # Central state machine & biometric orchestration
    ├── Core/
    │   ├── CameraManager.swift      # AVFoundation session & video output handler
    │   ├── FaceRecognitionEngine.swift # Apple Vision landmarks & feature print matching
    │   ├── BiometricStorage.swift   # Local profile persistence in Application Support
    │   └── SoundManager.swift       # Synthesized Face ID chime & feedback tones
    └── UI/
        ├── Components/
        │   ├── FaceIDGlyphView.swift # Iconic scanning brackets & checkmark morph
        │   ├── CameraPreviewView.swift # NSViewRepresentable for AVCaptureVideoPreviewLayer
        │   └── FaceMeshOverlay.swift # Bionic facial landmark wireframe
        └── Views/
            ├── AuthenticationView.swift # Face ID prompt HUD & simulator controls
            ├── ScannerView.swift        # Live telemetry feed & feature vector inspector
            ├── EnrollmentView.swift     # Interactive face registration
            ├── VaultView.swift          # Protected developer vault demonstration
            └── SettingsView.swift       # Sensitivity sliders & developer documentation
```

---

## 🧠 Biometric Matching Mechanics

MacBooks lack the TrueDepth hardware infrared dot projector of iPhones. GlanceID simulates Face ID using a two-tier biometric verification pipeline:

1. **Liveness & Quality Filter**:
   `VNDetectFaceCaptureQualityRequest` analyzes illumination, blur, and head orientation. If the quality is below 40% or head yaw is too steep, the scan requests the user to look straight ahead.
2. **Feature Print Vector Distance**:
   `VNGenerateImageFeaturePrintRequest` extracts a normalized feature print representation of the face.
   $$\text{Distance} = \| \vec{v}_{\text{enrolled}} - \vec{v}_{\text{live}} \|$$
   * Distance $< 0.35$: Very strong match
   * Distance $0.35 - 0.42$: Standard match (Default threshold: 0.42)
   * Distance $> 0.45$: Unrecognized face (triggers rejection buzz)

---

## 🛠️ Testing Workflow

1. Launch `GlanceID`.
2. Go to **Enroll Face** tab, type your name, and click **Start Enrollment**.
3. Go to **Face ID HUD** tab and click **Glance to Authenticate** to see the iconic iOS Face ID HUD.
4. Go to **Protected Vault** tab and unlock simulated developer secrets.
5. Inspect the **Neural Scanner** to watch real-time facial feature vector telemetry.
