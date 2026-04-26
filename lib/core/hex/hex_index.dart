/// A 64-bit H3 cell index.
///
/// Native H3 indices are uint64, but cell-mode indices have bit 63 = 0 and
/// fit in Dart's signed int64 without truncation. We use `int` directly for
/// in-memory storage; BigInt is only used at the FFI boundary into the
/// `h3_flutter` package.
///
/// On Flutter web Dart `int` is 53-bit and would lose precision — this app is
/// mobile-only so we accept that tradeoff for a tighter representation.
typedef HexIndex = int;

/// H3 resolution at which all explored cells are stored *and* rendered.
///
/// res 11 → ~25 m edge, ~2,150 m² area, our ~30 m design target. Rendering
/// uses the same resolution unconditionally — never aggregate to a coarser
/// parent for display, or the apparent footprint of an explored region will
/// change with zoom.
const int kHexStorageResolution = 11;
