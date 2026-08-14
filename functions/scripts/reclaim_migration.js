/**
 * functions/scripts/reclaim_migration.js
 * ────────────────────────────────────────────────────────────────────────────
 * D13/D7 rollout step: wipe every helmet claim that was established under the
 * OLD self-registration model (arbitrary-ID arrayUnion, no verification) so
 * every user must re-claim via the new pairing-code flow.
 *
 * Concretely, for every users/{uid} doc with a non-empty helmetIds array,
 * AND every helmets/{helmetId} doc with claimed === true:
 *   - clears users/{uid}.helmetIds to []
 *   - clears helmets/{helmetId}.claimed/claimedByUid/claimedAt
 *
 * This does NOT delete any helmet's telemetry (lat/lng/battery/etc.) or any
 * alert history — only claim/ownership state. Re-provisioning (fresh pairing
 * codes) is a separate, deliberate step via POST /admin/helmets/provision —
 * this script does not generate new codes, so nothing becomes claimable again
 * until an admin explicitly re-provisions it.
 *
 * SAFE BY DEFAULT: dry-run unless --execute is passed. Dry-run only reads and
 * reports counts/IDs — it never writes.
 *
 * Usage:
 *   node scripts/reclaim_migration.js              # dry run (default)
 *   node scripts/reclaim_migration.js --execute     # actually wipe
 * ────────────────────────────────────────────────────────────────────────────
 */

require("dotenv").config();
const admin = require("firebase-admin");
const path = require("path");

const EXECUTE = process.argv.includes("--execute");

const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS
  || path.join(__dirname, "..", "smhelmet-67-firebase-adminsdk-fbsvc-5cfc7ee572.json");
admin.initializeApp({
  credential: admin.credential.cert(require(serviceAccountPath)),
});
const db = admin.firestore();

async function main() {
  console.log(`[RECLAIM-MIGRATION] Mode: ${EXECUTE ? "EXECUTE (writes will happen)" : "DRY RUN (read-only)"}`);

  // ── Users with existing (old-model) helmetIds ──────────────────────────────
  const usersSnap = await db.collection("users").get();
  const usersToClear = usersSnap.docs.filter((doc) => {
    const ids = doc.data().helmetIds;
    return Array.isArray(ids) && ids.length > 0;
  });

  console.log(`[RECLAIM-MIGRATION] Users with non-empty helmetIds: ${usersToClear.length}`);
  for (const doc of usersToClear) {
    console.log(`  - users/${doc.id}: ${JSON.stringify(doc.data().helmetIds)}`);
  }

  // ── Helmets currently marked claimed ────────────────────────────────────────
  const helmetsSnap = await db.collection("helmets").get();
  const helmetsToClear = helmetsSnap.docs.filter((doc) => doc.data().claimed === true);

  console.log(`[RECLAIM-MIGRATION] Helmets currently claimed: ${helmetsToClear.length}`);
  for (const doc of helmetsToClear) {
    console.log(`  - helmets/${doc.id}: claimedByUid=${doc.data().claimedByUid}`);
  }

  if (!EXECUTE) {
    console.log("[RECLAIM-MIGRATION] Dry run complete. No writes made. Re-run with --execute to apply.");
    return;
  }

  const batch = db.batch();
  for (const doc of usersToClear) {
    batch.update(doc.ref, { helmetIds: [] });
  }
  for (const doc of helmetsToClear) {
    batch.update(doc.ref, { claimed: false, claimedByUid: null, claimedAt: null });
  }
  await batch.commit();

  console.log(`[RECLAIM-MIGRATION] Cleared ${usersToClear.length} user(s) and ${helmetsToClear.length} helmet(s).`);
  console.log("[RECLAIM-MIGRATION] Nothing is claimable again until an admin re-provisions fresh pairing codes.");
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("[RECLAIM-MIGRATION] Error:", err);
    process.exit(1);
  });
