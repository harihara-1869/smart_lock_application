# UI Design & Design System

The application's interface is built entirely using vanilla Flutter components styled with a strict, dual-mode Material 3 design system. It avoids heavy third-party UI libraries in favor of tailored, highly specific theme data.

## 1. The Aesthetics
The design language is categorized into two modes:

- **Obsidian Cyber-Secure (Dark Mode)**: The primary identity of the app. It relies on deep navy tones (`#0a0f18`), glowing electric blues (`#00f0ff`), and subtle glassmorphism to project a high-tech, military-grade aesthetic. 
- **Crystal Secure (Light Mode)**: A clean, clinical alternative prioritizing high contrast and accessibility, relying on crisp whites and a muted teal primary (`#006079`).

## 2. Global ThemeData (`theme.dart`)
All colors, font families, and shape definitions are centrally defined in [`lib/app/theme.dart`](file:///workspaces/mobile_application/smartlock_application/lib/app/theme.dart).
- **Colors**: Sourced strictly from `AppColors` (defined in [`lib/app/app_colors.dart`](file:///workspaces/mobile_application/smartlock_application/lib/app/app_colors.dart)). We avoid arbitrary hardcoded hex values in UI files.
- **Typography**: Uses the `GoogleFonts.inter()` text theme globally. Inter provides incredible legibility on mobile screens, especially for dense technical IDs or error strings.
- **Shape Overrides**: Buttons, Cards, and Snackbars have globally defined border radii (`12.0` to `16.0`) to ensure absolute consistency across the app.

## 3. Core Reusable Widgets (`core/widgets/`)
To keep screens declarative and clean, complex stylistic elements are abstracted into core widgets:
- **`PrimaryButton`** ([`lib/core/widgets/primary_button.dart`](file:///workspaces/mobile_application/smartlock_application/lib/core/widgets/primary_button.dart)): A dynamic button that automatically handles disabled states, loading spinners (`CircularProgressIndicator`), and robust touch targets.
- **`SecureCard`** ([`lib/core/widgets/secure_card.dart`](file:///workspaces/mobile_application/smartlock_application/lib/core/widgets/secure_card.dart)): A styled, elevated container specifically used in the "My Keys" dashboard. It features subtle colored borders and gradient undertones based on the active theme.

## 4. Screen Architecture
The UI is divided into 5 distinct screens under [`lib/features/ui/screens/`](file:///workspaces/mobile_application/smartlock_application/lib/features/ui/screens/):
1. **`MyKeysScreen`**: The dashboard. Uses Riverpod to dynamically list all provisioned locks.
2. **`Step1PressButtonScreen`**: A static instructional screen to begin the provisioning flow.
3. **`Step2ScanQrScreen`**: Integrates `mobile_scanner` to fetch the 32-byte hardware secret from the lock's box. Also features a manual fallback `TextField` for emulator testing.
4. **`Step3NfcSyncScreen`**: The culmination of provisioning. Shows a pulsing NFC icon while it orchestrates the `ProvisionController` handshake. Features manual abort buttons to cleanly terminate hanging RF fields.
5. **`ActuateLockScreen`**: The core utility screen. Displays a massive, animated, glowing circular trigger. Changes to green upon a successful `Unlock` APDU, or red on cryptographic failures.

**Design Decision: Asynchronous Actuation UX**
In `ActuateLockScreen`, the UI immediately displays a green "Unlocked!" success animation as soon as the digital `CMD_UNLOCK` handshake completes, *before* the physical motor has finished actuating. 
Why? Because NFC connections are incredibly fragile. If the user had to hold the phone against the door for the 2-3 seconds it takes the mechanical motor to actuate, they would inevitably pull the phone away prematurely, causing a timeout error. By decoupling the digital response from the physical actuation, the user gets immediate feedback and can lower their phone safely.

## 5. Flow & Navigation
Navigation strictly uses named routes defined in [`lib/app/app.dart`](file:///workspaces/mobile_application/smartlock_application/lib/app/app.dart) (`/provision_step_1`, `/actuate`, etc.). Cryptographic payloads (like the QR provision secret) are passed securely between screens via `RouteSettings.arguments`.
