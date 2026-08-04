# Smart Lock Mobile Application

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Flutter SDK](https://img.shields.io/badge/Flutter-%5E3.12.2-02569B?logo=flutter)](https://flutter.dev)
[![Tests](https://img.shields.io/badge/Tests-190%20passed-brightgreen)](test)
[![Firmware Repo](https://img.shields.io/badge/Firmware-smart__lock__firmware-black?logo=github)](https://github.com/harihara-1869/smart_lock_firmware)

A secure, high-assurance mobile application built with **Flutter** and **Dart**, designed to control and authenticate with the Smart Lock hardware over ISO-DEP NFC.

The mobile app acts as an NFC Initiator executing zero-trust mutual authentication, session key exchange, and end-to-end encrypted command transmission with the lock hardware.

For the ESP32 hardware and PN532 controller implementation details, see the companion repository: [Smart Lock Firmware (`smart_lock_firmware`)](https://github.com/harihara-1869/smart_lock_firmware). The wire contract between the two is specified by the [Firmware Engineering Specification](Smart_Lock.pdf) (in this repository) and the matching documentation in [`docs/`](docs/).

---

## Table of Contents

- [Overview](#overview)
- [Application Architecture](#application-architecture)
- [Comprehensive Documentation](#comprehensive-documentation)
- [NFC & Security Protocol Overview](#nfc--security-protocol-overview)
  - [APDU Framing](#apdu-framing)
  - [3-Message Mutual Authentication Handshake (`SLOCK-HS-v1`)](#3-message-mutual-authentication-handshake-slock-hs-v1)
  - [Cryptographic Specifications](#cryptographic-specifications)
  - [Status Word & Error Taxonomy](#status-word--error-taxonomy)
- [Repository Structure](#repository-structure)
- [Getting Started & Development](#getting-started--development)
  - [Prerequisites](#prerequisites)
  - [Installation & Build](#installation--build)
  - [Running Unit Tests](#running-unit-tests)
- [Related Repositories](#related-repositories)
- [License](#license)

---

## Overview

The Smart Lock mobile app provides a secure, contactless interface for unlocking and managing smart locks. It implements client-side ISO-DEP NFC transport, cryptographic session establishment, and encrypted payload exchange.

### Key Features
- **Zero-Trust Mutual Authentication**: 3-message protocol (`SLOCK-HS-v1`) using **Ed25519** digital signatures over domain-separated session transcripts.
- **Forward Secrecy**: Ephemeral **X25519** Diffie-Hellman key exchange per session with **HKDF-SHA256** key derivation (`K_p2e` and `K_e2p`).
- **Authenticated Payload Encryption**: **AES-256-GCM** encryption with 12-byte CSPRNG nonces and 16-byte authentication tags.
- **Robust Error Handling**: Type-safe monadic result types (`Result<T, E>`) and a sealed NFC error hierarchy (`NfcSessionError`).

---

## Application Architecture

The mobile application is structured around a modular, feature-first Flutter architecture:

```
lib/
├── app/                        # App configuration, router, and Material 3 design system
│   ├── app.dart                # Root widget & named-route generation
│   ├── app_colors.dart         # Obsidian Cyber-Secure & Crystal Secure palettes
│   ├── app_typography.dart     # Google Fonts (Inter / JetBrains Mono) typography
│   └── theme.dart              # Dark & light ThemeData configuration
├── core/                       # Core shared patterns & utilities
│   ├── nfc_transport/          # IsoDepTransport contract + Android & fake implementations
│   ├── providers/              # Riverpod dependency injection registry
│   ├── widgets/                # Reusable UI components (PrimaryButton, SecureCard)
│   └── result.dart             # Monadic Result<T, E> type for safe error handling
├── features/                   # Domain feature modules
│   ├── nfc/                    # APDU models, protocol constants, status words, errors, state
│   │   ├── apdu.dart           # C-APDU construction & R-APDU parsing
│   │   ├── nfc_errors.dart     # Sealed NfcSessionError taxonomy
│   │   ├── protocol_constants.dart # CLA/INS codes, key sizes, payload budgets
│   │   ├── status_word.dart    # SW1/SW2 status dictionary
│   │   └── transport_state.dart# ISO-DEP transport state machine
│   ├── session/                # Handshake, secure channel, identity & trusted-lock stores
│   │   ├── commands/           # AppCommands (0x01-0x05) & LockStatus parsing
│   │   ├── crypto/             # CryptoPrimitives (X25519, Ed25519, HKDF, AES-256-GCM)
│   │   ├── facade/             # LockConnection typed high-level API
│   │   ├── provisioning/       # QR parsing, deferred handshake, ProvisionController
│   │   ├── handshake.dart      # Pure M1/M2/M3 message builders, parsers & verification
│   │   ├── identity_keystore.dart # Phone long-term Ed25519 key management
│   │   ├── secure_channel.dart # Directional AES-256-GCM encryption/decryption
│   │   ├── session_controller.dart # Session lifecycle state machine
│   │   └── trusted_locks_store.dart # Trusted lock public-key storage
│   └── ui/                     # User interface screens
│       └── screens/
│           ├── actuate_lock_screen.dart # Tap-to-unlock NFC trigger screen
│           ├── my_keys_screen.dart      # Trusted locks dashboard
│           ├── step_1_press_button.dart # Provisioning: hardware interaction instructions
│           ├── step_2_scan_qr.dart      # Provisioning: QR code scanner via mobile_scanner
│           └── step_3_nfc_sync.dart     # Provisioning: NFC sync and key exchange
└── main.dart                   # Application entry point & Riverpod ProviderScope
```

### Key Architectural Patterns
- **State Management**: Reactive state management with [Riverpod](https://riverpod.dev/) (`Provider` / `StateNotifierProvider`), declared in a central registry in `lib/core/providers/nfc_providers.dart`.
- **Immutable Data Models**: Code generation using [Freezed](https://pub.dev/packages/freezed) for APDU/transport/error models (`*.freezed.dart`).
- **Type-Safe NFC Communications**: Strongly typed APDU representations (`Capdu` and `Rapdu`) with explicit short-APDU bounds checking ($L_c \le 255$).

---

## Comprehensive Documentation

For deep dives into specific system layers, please refer to the extensive documentation in the `docs/` directory:

- **[Master Reference](docs/Master_Reference.md)**: The top-level architectural blueprint, including the layer-to-firmware mapping, the shared wire contract, and end-to-end provisioning/unlock journeys.
- **[Protocol Specification](docs/Protocol.md)**: Full specification of `SLOCK-HS-v1` — APDU framing, M1-M3 message definitions, transcript, HKDF key derivation, AES-256-GCM framing, and the command/status tables.
- **[Session Orchestration](docs/Session.md)**: The `TransportState` machine (`idle` → `activated` → `handshake` → `secureSession` → `released`), transport contract, and the deferred provisioning handshake.
- **[State Management](docs/State_Management.md)**: The Riverpod dependency injection registry, the reactive `TrustedLocksNotifier`, and the global-vs-local state split.
- **[UI & Design System](docs/UI_Design.md)**: The dual-theme "Obsidian Cyber-Secure" and "Crystal Secure" design languages, reusable widgets, screen architecture, and routing.

---

## NFC & Security Protocol Overview

### APDU Framing

Communication with the lock hardware uses ISO/IEC 7816-4 short APDUs with proprietary Class byte `CLA = 0x80`:

- **Command APDU (C-APDU)**: `CLA (0x80) | INS | P1 (0x00) | P2 (0x00) | [Lc | Data Payload]` — no trailing `Le` byte; `Lc` is omitted when the payload is empty (Case 1).
- **Response APDU (R-APDU)**: `Data Payload | SW1 | SW2`

#### Instruction (INS) Codes

| INS Code | Name | Transport State | Payload Description |
|---|---|---|---|
| `0x10` | `CMD_HANDSHAKE_INIT` | `ACTIVATED` | **M1**: Client Ephemeral Public Key (32B) + Challenge `c_P` (32B) |
| `0x11` | `CMD_HANDSHAKE_FINISH` | `HANDSHAKE` | **M3**: Client Signature `Sig_P` (64B) over transcript |
| `0x20` | `CMD_SECURE_PAYLOAD` | `SECURE_SESSION` | AES-256-GCM Encrypted Payload: Nonce (12B) + Ciphertext + Tag (16B) |
| `0x30` | `CMD_SESSION_ABORT` | Any active state | Best-effort session teardown command |

---

### 3-Message Mutual Authentication Handshake (`SLOCK-HS-v1`)

```
Mobile App (Initiator)                                            Lock Hardware (Target)
         │                                                                   │
 1. Generate ephemeral X25519 keypair                                        │
    Generate challenge c_P (32B)                                             │
         │                                                                   │
         │ ─── M1: C-APDU [INS=0x10] (pk_eph_P || c_P) ────────────────────► │
         │                                                                   │ Validate pk_eph_P
         │                                                                   │ Generate Lock ephemeral keypair & c_L
         │                                                                   │ Sign transcript T with local_sk -> Sig_L
         │ ◄── M2: R-APDU [0x9000] (pk_eph_L || c_L || Sig_L) ────────────── │
         │                                                                   │
 2. Verify Sig_L with Lock's Public Key                                      │
    Sign transcript T with Mobile App's Private Key -> Sig_P                 │
         │                                                                   │
         │ ─── M3: C-APDU [INS=0x11] (Sig_P) ──────────────────────────────► │
         │                                                                   │ Verify Sig_P against candidate keys
         │                                                                   │ Derive SharedSecret & Session Keys
         │ ◄── M3 Ack: R-APDU [0x9000] (Empty Data) ──────────────────────── │
         │                                                                   │
  [SECURE SESSION ESTABLISHED]                                       [SECURE SESSION ESTABLISHED]
```

**Domain-Separated Transcript**:
$$\text{Transcript} = \text{"SLOCK-HS-v1"} \parallel 0\text{x01} \parallel pk_{eph,P} \parallel pk_{eph,L} \parallel c_P \parallel c_L$$

---

### Cryptographic Specifications

1. **Shared Secret Computation**:
   $$\text{SharedSecret} = \text{X25519}(sk_{eph,P}, pk_{eph,L})$$
2. **Pseudorandom Key (PRK)**:
   $$\text{PRK} = \text{HKDF-Extract}(\text{salt} = c_P \parallel c_L, \text{ikm} = \text{SharedSecret})$$
3. **Directional AES-256 Session Keys**:
   - Mobile App to Lock (`K_p2e`): $\text{HKDF-Expand}(\text{PRK}, \text{"phone->esp"}, 32)$
   - Lock to Mobile App (`K_e2p`): $\text{HKDF-Expand}(\text{PRK}, \text{"esp->phone"}, 32)$
4. **Payload Constraints**:
   - $L_c \le 227$ bytes total payload per APDU (enforced on the complete encrypted package).
   - Overhead: 12B nonce + 16B tag = 28B. Max plaintext per frame = 199 bytes.

---

### Status Word & Error Taxonomy

| Status Word | Name | Description |
|---|---|---|
| `0x90 0x00` | `SUCCESS` | APDU executed successfully |
| `0x69 0x82` | `AUTH_FAILED` | Signature or AEAD authentication tag mismatch |
| `0x69 0x85` | `WRONG_STATE` | Command invalid for current transport state |
| `0x6A 0x80` | `INVALID_DATA` | Malformed APDU or invalid payload length |
| `0x6A 0x81` | `NOT_SUPPORTED` | Unsupported INS code or CLA ≠ `0x80` |

On the application layer, the decrypted response carries a 1-byte status: `0x00` OK, `0x01` INVALID SECRET, `0x02` UNKNOWN CMD, `0x03` ACTUATOR FAULT. All expected failures are surfaced through the sealed `NfcSessionError` taxonomy (`tagLost`, `timeout`, `authenticationFailed`, `handshakeRejected`, `decryptionFailed`, `untrustedLock`, `nfcUnavailable`, `payloadTooLarge`, …).

---

### Implementation Notes

- **QR Provision Secret format**: The firmware spec describes the QR payload as a 64-character hex string. The parser (`QrProvisionParser`) accepts both upper and lowercase hex for robustness against QR scanner normalization — intentionally more permissive than the spec.
- **M3 Ack validation**: The phone rejects an M3 ack R-APDU that carries any data bytes (firmware requires empty data), tearing down the session immediately.
- **Provisioning signature verification is deferred, not skipped**: the phone caches the unverified lock signature during provisioning and verifies it against the lock public key returned by `CMD_PROVISION` before persisting the lock.

---

## Repository Structure

```
smartlock_application/
├── android/                        # Android native configuration & NFC permissions
├── docs/                           # Comprehensive architecture & protocol documentation
├── lib/                            # Application Dart source code
│   ├── app/                        # Root widget, router, theme & design system
│   ├── core/                       # Transport, providers, widgets & Result monad
│   ├── features/                   # Feature modules (nfc, session, ui)
│   └── main.dart                   # Application entry point
├── test/                           # Unit & integration tests (17 files, 190 tests)
│   ├── core/                       # Result & transport tests
│   └── features/                   # nfc, session (commands/crypto/integration/provisioning) tests
├── UI_Design/                      # Design mockups (stitch_nfc_smart_key_manager)
├── analysis_options.yaml           # Lint options
├── pubspec.yaml                    # Flutter dependencies & metadata
├── Smart_Lock.pdf                  # Firmware Engineering Specification (peer wire contract)
├── LICENSE                         # GNU General Public License v3.0 (GPLv3)
└── README.md                       # Mobile app documentation
```

---

## Getting Started & Development

### Prerequisites

- **Flutter SDK**: `^3.12.2` (Dart `^3.12.2`)
- **Android Studio / VS Code** with Flutter and Dart extensions.
- **Physical Mobile Device**: NFC hardware required for live testing (an Android device with ISO-DEP / Host Card Emulation support).

### Installation & Build

1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-org/smartlock_application.git
   cd smartlock_application
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run code generation (Freezed)**:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

### Running Unit Tests

Execute the test suite to verify APDU framing, protocol parameters, handshake verification, secure-channel encryption, and the full provisioning/unlock cycle:

```bash
flutter test
```

---

## Related Repositories

- **Smart Lock Firmware**: [https://github.com/harihara-1869/smart_lock_firmware](https://github.com/harihara-1869/smart_lock_firmware) — ESP32 lock firmware, PN532 drivers, FreeRTOS task handoff, and hardware lock control.

---

## License

This project is licensed under the **GNU General Public License v3.0 (GPLv3)** - see the [LICENSE](LICENSE) file for details.

```text
Smart Lock Mobile Application
Copyright (C) 2026 Smart Lock Project Contributors

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.
```
