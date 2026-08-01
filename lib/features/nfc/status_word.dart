/// Known status words from the lock protocol.
///
/// Source: transport.md's actual status word table. Note that `wrongState`
/// uses the protocol's own meaning ("INS not valid in current state"), not the
/// generic ISO 7816-4 dictionary meaning for 69 85.
enum StatusWord {
  /// 90 00 — Success.
  ok(0x9000, 'OK', 'Success'),

  /// 69 82 — Signature or AEAD tag verification failed.
  authFailed(0x6982, 'AUTH_FAILED',
      'Signature or AEAD tag verification failed'),

  /// 69 85 — INS not valid in the current transport state.
  wrongState(0x6985, 'WRONG_STATE',
      'INS not valid in the current transport state'),

  /// 6A 80 — Lc mismatch or payload too large.
  invalidData(0x6A80, 'INVALID_DATA', 'Lc mismatch or payload too large'),

  /// 6A 81 — Unknown INS, or CLA != 0x80.
  notSupported(0x6A81, 'NOT_SUPPORTED', 'Unknown INS, or CLA != 0x80'),

  /// Unrecognized status word — not in the protocol's table.
  unknown(0x0000, 'UNKNOWN', 'Unrecognized status word');

  const StatusWord(this.code, this.mnemonic, this.description);

  /// The 16-bit status word value (SW1 << 8 | SW2).
  final int code;

  /// Short mnemonic identifier matching the firmware's naming.
  final String mnemonic;

  /// Human-readable description of the status word's meaning.
  final String description;

  /// Look up a [StatusWord] from raw SW1 and SW2 bytes.
  ///
  /// Returns [StatusWord.unknown] if the combined value doesn't match any
  /// known entry.
  static StatusWord fromBytes(int sw1, int sw2) {
    final code = (sw1 << 8) | sw2;
    return StatusWord.values.firstWhere(
      (s) => s.code == code,
      orElse: () => unknown,
    );
  }
}
