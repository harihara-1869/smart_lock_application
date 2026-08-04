# UI Design & Design System — Mobile Application Specification

This document specifies the visual design system and screen architecture of the Smart Lock mobile application. The interface is built entirely with vanilla Flutter components styled by a strict, dual-mode Material 3 design system, avoiding heavy third-party UI libraries in favor of tailored, highly specific theme data.

---

## 1. The Two Design Languages

The application supports two complete themes, selected automatically by the platform brightness (`ThemeMode` defaults to system):

| Mode | Identity | Character |
|---|---|---|
| **Obsidian Cyber-Secure** (dark) | The primary identity | Deep navy surfaces, glowing electric-blue accents, subtle glassmorphism — a high-tech, military-grade aesthetic. |
| **Crystal Secure** (light) | Clean clinical alternative | High contrast and accessibility, crisp whites and a muted teal primary. |

Both themes are derived from Material 3 `ColorScheme`s and use the same typography system.

---

## 2. Color System

All colors are sourced strictly from [`lib/app/app_colors.dart`](file:///workspaces/mobile_application/smartlock_application/lib/app/app_colors.dart) — arbitrary hardcoded hex values in UI files are avoided.

### 2.1 Obsidian Palette (dark)

Defined in `ObsidianColors`. Key tokens:

| Token | Value | Usage |
|---|---|---|
| `surface` | `0xFF051424` | Deep navy app background |
| `surfaceContainerHighest` | `0xFF273647` | Card-level surfaces |
| `onSurface` | `0xFFD4E4FA` | Primary text on navy |
| `primary` / `primaryContainer` | `0xFFC3F5FF` / `0xFF00E5FF` | Accents |
| `electricBlue` | `0xFF00DAF3` | Brand accent / CTA |
| `cyberLime` | `0xFFCCFF00` | Status accent |
| `alertRed` | `0xFFFF4B4B` | Destructive / error |
| `level1Card` | `0xFF32353E` | Elevated card fill |
| `error` / `onError` | `0xFFFFB4AB` / `0xFF690005` | Error surface |

### 2.2 Crystal Palette (light)

Defined in `CrystalColors`:

| Token | Value | Usage |
|---|---|---|
| `primary` | `0xFF007A99` | Teal primary |
| `background` | `0xFFF8FAFC` | App background |
| `onBackground` / `onSurface` | `0xFF0F172A` | Primary text |
| `surfaceVariant` | `0xFFF1F5F9` | Card surfaces |
| `error` | `0xFFDC2626` | Error |
| `safeGreen` | `0xFF16A34A` | Success state |
| `shadow` | `0xFF94A3B8` | Card shadow (10% opacity) |

### 2.3 Usage Rules

- Theme files and widgets reference `AppColors` constants only; no literal hex in screens.
- Brightness-dependent decisions are made via `Theme.of(context).brightness == Brightness.dark`.

---

## 3. Typography

Defined in [`lib/app/app_typography.dart`](file:///workspaces/mobile_application/smartlock_application/lib/app/app_typography.dart) using `GoogleFonts.inter()` for the body/display set and `GoogleFonts.jetBrainsMono()` for technical labels.

| Style | Font | Size / Weight | Use |
|---|---|---|---|
| `displayLarge` | Inter | 32 / w700 | Hero numbers |
| `displayMedium` | Inter | 28 / w700 | Headline-lg-mobile |
| `headlineMedium` | Inter | 24 / w600 | Screen titles |
| `headlineSmall` | Inter | 20 / w600 | Section headings |
| `bodyLarge` | Inter | 18 / w400 | Primary body text |
| `bodyMedium` | Inter | 16 / w400 | Secondary text |
| `labelMedium` | JetBrains Mono | 14 / w500, +0.05 tracking | Dense technical IDs |
| `labelSmall` | JetBrains Mono | 12 / w500, +0.08 tracking | Captions / error strings |

Both themes use the same `TextTheme` factory (`_buildTextTheme`) with the theme's `onSurface` color as the default text color.

---

## 4. Theme Data (`theme.dart`)

[`AppTheme`](file:///workspaces/mobile_application/smartlock_application/lib/app/theme.dart) exposes `darkTheme` and `lightTheme`:

- **Dark**: `ColorScheme.dark` sourced from `ObsidianColors`, `scaffoldBackgroundColor = 0xFF051424`, Material 3 enabled, `CardThemeData` with `level1Card` fill, 0 elevation, and 16 px rounded corners.
- **Light**: `ColorScheme.light` sourced from `CrystalColors`, `scaffoldBackgroundColor = 0xFFF8FAFC`, Material 3 enabled, `CardThemeData` with `surface` fill and 16 px rounded corners.
- Both set `useMaterial3: true`.

Shape language: buttons, cards, and snackbars use globally consistent border radii of 12–16 px.

---

## 5. Core Reusable Widgets

### 5.1 `PrimaryButton`

[`lib/core/widgets/primary_button.dart`](file:///workspaces/mobile_application/smartlock_application/lib/core/widgets/primary_button.dart) — the application's single CTA component.

- Handles disabled states, loading spinners (`CircularProgressIndicator`), and optional leading icons.
- **Pulsing glow (dark mode)**: a 1.5 s repeating `AnimationController` drives a `BoxShadow` blur/spread on the `electricBlue` CTA while enabled — a signature "cyber" affordance.
- Brightness-aware colors: `electricBlue` fill on dark, `CrystalColors.primary` on light.
- 12 px radius, 24×16 padding, no elevation.

### 5.2 `SecureCard`

[`lib/core/widgets/secure_card.dart`](file:///workspaces/mobile_application/smartlock_application/lib/core/widgets/secure_card.dart) — the styled elevated container used in the "My Keys" dashboard.

- **Dark**: `BackdropFilter` glassmorphism (`ImageFilter.blur`, σ=20) over a semi-transparent `level1Card` fill with a subtle `outline` border.
- **Light**: solid `background` fill with an `outlineVariant` border and a soft `shadow` (10% opacity, 10 px blur, 4 px offset).
- Optional `onTap` wraps content in an `InkWell` with a 16 px radius.

---

## 6. Screen Architecture

The UI is divided into five screens under [`lib/features/ui/screens/`](file:///workspaces/mobile_application/smartlock_application/lib/features/ui/screens/).

### 6.1 `MyKeysScreen` — Dashboard

The landing screen. Uses `ref.watch(trustedLocksNotifierProvider)` to render the trusted-lock list reactively:

- **Loading** → centered `CircularProgressIndicator`.
- **Empty** → `Icons.key_off` empty state with onboarding copy.
- **Data** → `ListView.separated` of `SecureCard`s, each showing a door icon, the lock ID, a "Stored securely" status row, and a delete (revoke) action that confirms via `AlertDialog` before calling `TrustedLocksNotifier.revokeKey`.
- Tapping a card navigates to `/actuate` with the lock ID.
- A full-width floating `PrimaryButton` ("Begin Provisioning") navigates to `/provision_step_1`.

### 6.2 `Step1PressButtonScreen` — Provisioning: Physical Trigger

Static instructional screen. Explains that the user must press the physical button on the lock to put it into provision mode, then a `PrimaryButton` ("Next") advances to step 2.

### 6.3 `Step2ScanQrScreen` — Provisioning: Secret Acquisition

Integrates `mobile_scanner` to read the lock's provisioning QR:

- `QrProvisionParser.parse(code)` validates a 64-character hex string and returns a 32-byte `provisionSecret`; invalid codes show a snackbar and resume scanning after a 2 s debounce.
- **Manual fallback**: a `TextField` (max 64 chars) + "Submit Manual Secret" button for emulator/testing scenarios without a physical QR.
- On success, stops the scanner and `pushReplacementNamed` to `/provision_step_3` passing the secret via `RouteSettings.arguments`.

### 6.4 `Step3NfcSyncScreen` — Provisioning: NFC Synchronization

The culmination of provisioning. Orchestrates `ProvisionController.provisionLock(lockId, provisionSecret)`:

- Auto-starts provisioning on load (`addPostFrameCallback`).
- Shows a large pulsing `Icons.nfc` glyph while syncing, an error state on failure ("Sync Failed" + message), and a `PrimaryButton` that becomes "Retry Sync".
- A "Cancel" `TextButton` calls `ProvisionController.abort()` to cleanly kill a hanging RF field.
- On success, refreshes `trustedLocksNotifierProvider` and pops to the dashboard with a success snackbar.
- The generated `lockId` is derived from the current timestamp (`"Lock-" + millis suffix`) — a placeholder identity for the prototype.

### 6.5 `ActuateLockScreen` — Unlock Actuation

The core utility screen for a selected trusted lock:

- Displays a large animated circular trigger (160 px) that turns green on success (`Icons.lock_open`) or red on error (`Icons.error_outline`), with a status headline ("Ready to Unlock" / "Unlocked!" / "Unlock Failed").
- The `PrimaryButton` ("Tap to Unlock" / "Actuating...") drives `LockConnection.unlock(lockId)`.
- A "Cancel" `TextButton` calls `LockConnection.abort()`.

**Design Decision: Asynchronous Actuation UX.**
The UI displays a green "Unlocked!" success state as soon as the digital `CMD_UNLOCK` round-trip completes, *before* the physical motor has finished actuating. Because NFC connections are fragile, requiring the user to hold the phone against the door for the 2–3 s mechanical actuation would cause premature pull-away and timeout errors. Decoupling the digital response from the physical actuation gives immediate feedback and lets the user lower the phone safely; the firmware reports the true mechanical state on the next `CMD_GET_STATUS`.

---

## 7. Flow & Navigation

Navigation strictly uses named routes defined in [`lib/app/app.dart`](file:///workspaces/mobile_application/smartlock_application/lib/app/app.dart) via `onGenerateRoute`:

| Route | Screen | Arguments |
|---|---|---|
| `/` | `MyKeysScreen` | — |
| `/provision_step_1` | `Step1PressButtonScreen` | — |
| `/provision_step_2` | `Step2ScanQrScreen` | — |
| `/provision_step_3` | `Step3NfcSyncScreen` | `Uint8List provisionSecret` |
| `/actuate` | `ActuateLockScreen` | `String lockId` |

Cryptographic payloads (the QR provision secret) are passed between screens via `RouteSettings.arguments`, never through global state. Unknown routes render a fallback scaffold.
