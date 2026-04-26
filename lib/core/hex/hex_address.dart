import 'hex_index.dart';

/// Human-readable address codec for [HexIndex] — the `BB-A-D-C-…` form
/// from the design doc.
///
/// Format: `<base>-<digit>-<digit>-…` where
///   * `<base>` is two hex chars (00–7A) for the H3 base cell (0–121)
///   * each `<digit>` is one of `A`–`G` (or `0` for unused — only at coarse
///     resolutions). The N-th digit is the H3 child position at resolution N.
///
/// At the storage resolution ([kHexStorageResolution] = 11) the address is
/// `<2>-A-…-A` with 11 letter components → 13 tokens, ~25 characters with
/// hyphens. We never persist this — it's a pure presentation layer over the
/// 64-bit H3 index. Indices remain canonical for storage and equality.
class HexAddress {
  const HexAddress._();

  static const _digits = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];

  /// Encodes [cell] as `BB-A-D-…`. Pure pure-Dart bit math — no h3 calls.
  static String encode(HexIndex cell) {
    // H3 index bit layout (high → low): [0][mode:4][rsv:3][res:4][base:7][digits:45]
    // Each digit is 3 bits; 15 digits total, indexed 0..14. Digits at indices
    // ≥ resolution are unused (set to 7).
    final res = (cell >> 52) & 0xF;
    final base = (cell >> 45) & 0x7F;

    final buf = StringBuffer();
    buf.write(base.toRadixString(16).toUpperCase().padLeft(2, '0'));
    for (var i = 0; i < res; i++) {
      // Digit i lives at bits 42-44 (i=0) … 0-2 (i=14).
      final shift = 42 - (i * 3);
      final d = (cell >> shift) & 0x7;
      buf.write('-');
      buf.write(d <= 6 ? _digits[d] : '0');
    }
    return buf.toString();
  }

  /// Inverse of [encode]. Throws [FormatException] on malformed input.
  static HexIndex decode(String address) {
    final parts = address.split('-');
    if (parts.isEmpty) {
      throw const FormatException('empty hex address');
    }
    final base = int.parse(parts.first, radix: 16);
    if (base < 0 || base > 121) {
      throw FormatException('base cell out of range: $base');
    }
    final res = parts.length - 1;
    if (res < 0 || res > 15) {
      throw FormatException('resolution out of range: $res');
    }

    var cell = 0;
    cell |= 1 << 59; // mode = 1 (cell)
    cell |= res << 52;
    cell |= base << 45;
    // Initialise all 15 digits to 7 (unused).
    for (var i = 0; i < 15; i++) {
      cell |= 7 << (42 - i * 3);
    }
    for (var i = 0; i < res; i++) {
      final token = parts[i + 1];
      final d = _digits.indexOf(token);
      if (d < 0) throw FormatException('invalid digit: $token');
      final shift = 42 - i * 3;
      // Clear the slot (it currently holds 7) then set the digit.
      cell &= ~(7 << shift);
      cell |= d << shift;
    }
    return cell;
  }
}
