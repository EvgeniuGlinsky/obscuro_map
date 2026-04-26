// Firestore collection / field names. Keep aligned with security rules in
// the Firebase Console (`match /users/{userId}/{document=**}`).
const kUsersCollection = 'users';

// Schema v2 (H3 cells). Each entry is a 64-bit signed int — H3 cell
// indices fit in int64 because cell-mode indices have bit 63 = 0.
const kFieldCells = 'cells';

const kFieldUpdatedAt = 'updatedAt';
const kFieldSchemaVersion = 'schemaVersion';

const kProgressSchemaVersion = 2;

// Legacy v1 fields — read once by the v1→v2 migration, then overwritten.
const kLegacyFieldPoints = 'points';
const kLegacyFieldFillPoints = 'fillPoints';
