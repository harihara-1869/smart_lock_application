# Smart Lock Mobile Application

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Flutter SDK](https://img.shields.io/badge/Flutter-%5E3.12.2-02569B?logo=flutter)](https://flutter.dev)
[![Tests](https://img.shields.io/badge/Tests-171%20passed-brightgreen)](test)
[![Firmware Repo](https://img.shields.io/badge/Firmware-smart__lock__firmware-black?logo=github)](https://github.com/harihara-1869/smart_lock_firmware)

A secure, high-assurance mobile application built with **Flutter** and **Dart**, designed to control and authenticate with the Smart Lock hardware over ISO-DEP NFC.

The mobile app acts as an NFC Initiator executing zero-trust mutual authentication, session key exchange, and end-to-end encrypted command transmission with the lock hardware.

For the ESP32 hardware and PN532 controller implementation details, see the companion repository: [Smart Lock Firmware (`smart_lock_firmware`)](https://github.com/harihara-1869/smart_lock_firmware).

---

## Table of Contents

- [Overview](#overview)
- [Application Architecture](#application-architecture)
- [NFC & Security Protocol Overview](#nfc--security-protocol-overview)
  - [APDU Framing](#apdu-framing)
  - [3-Message Mutual Authentication Handshake (`SLOCK-HS-v1`)](#3-message-mutual-authentication-handshake-slock-hs-v1)
  - [Cryptographic Specifications](#cryptographic-specifications)
  - [Status Word & Error Taxonomy](#status-word--error-taxonomy)
- [Current Project Status](#current-project-status)
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
- **Robust Error Handling**: Type-safe monadic result types (`Result<T, E>`) and sealed NFC error hierarchies (`NfcSessionError`).

---

## Application Architecture

The mobile application is structured around a modular, feature-first Flutter architecture:

```
lib/
├── app/                        # App configuration, router, and material design system
│   ├── app.dart
│   └── theme.dart
├── core/                       # Core shared patterns & utilities
│   ├── nfc_transport/          # ISO-DEP transport interfaces & FakeIsoDepTransport test double
│   └── result.dart             # Monadic Result<T, E> type for safe error handling
└── features/                   # Domain feature modules
    ├── nfc/                    # NFC transport, APDU models, and protocol constants
    │   ├── apdu.dart           # C-APDU construction & R-APDU parsing
    │   ├── nfc_errors.dart     # Sealed NfcSessionError taxonomy
    │   ├── protocol_constants.dart # Protocol parameters, INS codes, key sizes
    │   ├── status_word.dart    # SW1/SW2 status dictionary
    │   └── transport_state.dart# ISO-DEP state machine (idle -> activated -> handshake -> secureSession -> released)
    ├── session/                # Cryptographic handshake, secure channel, and session controller
    │   ├── commands/           # AppCommands (0x01-0x05) & LockStatus parsing
    │   ├── crypto/             # CryptoPrimitives (X25519, Ed25519, HKDF, AES-256-GCM)
    │   ├── facade/             # LockConnection high-level API
    │   ├── handshake.dart      # Pure handshake message builders & parsers
    │   ├── identity_keystore.dart # Phone long-term key management
    │   ├── secure_channel.dart # Directional payload encryption/decryption
    │   ├── session_controller.dart # Session lifecycle orchestration
    │   └── trusted_locks_store.dart # Trusted lock key storage
    └── lock/                   # Lock management & unlock user interface
```

### Key Architectural Patterns
- **State Management**: Reactive state management with [Riverpod](https://riverpod.dev/).
- **Immutable Data Models**: Code generation using [Freezed](https://pub.dev/packages/freezed) and [json_annotation](https://pub.dev/packages/json_annotation).
- **Type-Safe NFC Communications**: Strongly typed APDU representations (`Capdu` and `Rapdu`) with explicit short-APDU bounds checking ($L_c \le 255$).

---

## NFC & Security Protocol Overview

### APDU Framing

Communication with the lock hardware uses ISO 7816-4 short APDUs with proprietary Class byte `CLA = 0x80`:

- **Command APDU (C-APDU)**: `CLA (0x80) | INS | P1 (0x00) | P2 (0x00) | Lc | Data Payload | Le`
- **Response APDU (R-APDU)**: `Data Payload | SW1 | SW2`

#### Instruction (INS) Codes

| INS Code | Name | Transport State | Payload Description |
|---|---|---|---|
| `0x10` | `CMD_HANDSHAKE_INIT` | `ACTIVATED` | **M1**: Client Ephemeral Public Key (32B) + Challenge `c_P` (32B) |
| `0x11` | `CMD_HANDSHAKE_FINISH` | `HANDSHAKE` | **M3**: Client Signature `Sig_P` (64B) over transcript |
| `0x20` | `CMD_SECURE_PAYLOAD` | `SECURE_SESSION` | AES-256-GCM Encrypted Payload: Nonce (12B) + Ciphertext + Tag (16B) |
| `0x30` | `CMD_SESSION_ABORT` | `ANY` | Best-effort session teardown command |

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
         │                                                                   │ Sign transcript T1 with local_sk -> Sig_L
         │ ◄── M2: R-APDU [0x9000] (pk_eph_L || c_L || Sig_L) ────────────── │
         │                                                                   │
 2. Verify Sig_L with Lock's Public Key                                      │
    Sign transcript T2 with Mobile App's Private Key -> Sig_P                │
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
   - $L_c \le 227$ bytes total payload per APDU.
   - Overhead: 12B nonce + 16B tag = 28B. Max plaintext per frame = 199 bytes.

---

### Status Word & Error Taxonomy

| Status Word | Name | Description |
|---|---|---|
| `0x90 0x00` | `SUCCESS` | APDU executed successfully |
| `0x69 0x82` | `AUTH_FAILED` | Signature or AEAD authentication tag mismatch |
| `0x69 0x85` | `WRONG_STATE` | Command invalid for current transport state |
| `0x6A 0x80` | `INVALID_DATA` | Malformed APDU or invalid payload length |
| `0x6A 0x81` | `NOT_SUPPORTED` | Unsupported INS code or version byte |
| `0x6F 0x00` | `UNKNOWN` | Internal or unhandled error |

---

### Implementation Notes

- **QR Provision Secret format**: The spec (APP_Development.md §5) describes the QR payload as a "64-character uppercase hex string." The parser (`QrProvisionParser`) accepts both upper and lowercase hex for robustness against QR scanner normalization — this is intentionally more permissive than the spec.
- **M3 Ack validation**: The phone rejects an M3 ack R-APDU that carries any data bytes (firmware §7.3 step 5 requires empty data), tearing down the session immediately.

---

## Current Project Status

### Completed Core Components (189/189 Unit & Integration Tests Passing)
- [x] **C-APDU / R-APDU Serialization & Parsing** (`apdu.dart` / `apdu_test.dart`): Round-trip verification, short APDU bounds checks, status word extraction.
- [x] **Protocol Constants & Parameters** (`protocol_constants.dart` / `protocol_constants_test.dart`): CLA, P1, P2 defaults, INS codes, key lengths, HKDF info strings.
- [x] **Status Word Dictionary** (`status_word.dart` / `status_word_test.dart`): ISO-DEP and custom status word mapping and error evaluation.
- [x] **Transport State Machine Models** (`transport_state.dart` / `transport_state_test.dart`): Freezed union equality and state tracking representation.
- [x] **NFC Session Error Taxonomy** (`nfc_errors.dart` / `nfc_errors_test.dart`): Sealed `NfcSessionError` variants covering timeouts, link loss, status mismatches, and payload limits.
- [x] **Result Pattern & Foundation** (`lib/core/result.dart`): Monadic error handling types for clean async flows.
- [x] **Cryptographic Engine** (`crypto_primitives.dart` / `crypto_primitives_test.dart`): Pure X25519 key exchange, Ed25519 sign/verify, HKDF-SHA256 key derivation, AES-256-GCM payload encryption, and transcript generation.
- [x] **Handshake Protocol Runner** (`handshake.dart` / `handshake_test.dart`): M1/M2/M3 message assembly, verification, key derivation, and dual-deferred provisioning support.
- [x] **Secure Channel** (`secure_channel.dart` / `secure_channel_test.dart`): Directional key encryption (`K_p2e`/`K_e2p`), payload size validation, and GCM tag error mapping.
- [x] **Session Controller & Facade** (`session_controller.dart`, `lock_connection.dart`): Full state machine lifecycle orchestration, NFC discovery event handling, app commands (`unlock`, `lock`, `getStatus`, `revokeKey`), and error handling.
- [x] **Identity & Lock Key Persistence** (`identity_keystore.dart`, `trusted_locks_store.dart`): Secure storage integration for phone long-term identity seed/pubkey and trusted lock public keys.
- [x] **Provisioning Flow** (`provision_controller.dart`, `qr_provision_parser.dart`): QR secret parsing, dual-deferred handshake verification, and lock registration.
- [x] **End-to-End Integration Tests** (`full_session_test.dart`): 11 scripted scenarios through `FakeIsoDepTransport` covering handshake, provisioning, error paths, and the provision→unlock cycle.

### Remaining Implementation Roadmap
- [ ] **User Interface & UX**:
  - Lock scanning, NFC discovery UI, unlock dashboard, and key management views.

---

## Repository Structure

```
smartlock_application/
├── android/                        # Android native configuration & NFC permissions
├── lib/                            # Application Dart source code
│   ├── app/                        # Main entry widget & material theme
│   ├── core/                       # Result monad & core utilities
│   ├── features/                   # Feature modules (nfc, session, lock)
│   └── main.dart                   # Application main function
├── test/                           # Unit tests matching lib/ features
│   └── features/
│       └── nfc/                    # NFC protocol unit tests (60 tests)
├── analysis_options.yaml           # Lint options
├── pubspec.yaml                    # Flutter dependencies & metadata
├── LICENSE                         # GNU General Public License v3.0 (GPLv3)
└── README.md                       # Mobile app documentation
```

---

## Getting Started & Development

### Prerequisites

- **Flutter SDK**: `^3.12.2` (Dart `^3.12.2`)
- **Android Studio / VS Code** with Flutter and Dart extensions.
- **Physical Mobile Device**: NFC hardware required for live testing (Android device with ISO-DEP / Host Card Emulation support).

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

3. **Run code generation (Freezed & json_serializable)**:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

### Running Unit Tests

Execute the test suite to verify APDU framing, protocol parameters, and status word parsing:

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
