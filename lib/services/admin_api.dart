/// Base URL for the functions/index.js admin/claim API.
///
/// functions/index.js is a standalone Express server deployed to Render (see
/// render.yaml) — smhelmet-67 is on Firebase's free Spark plan, which can't
/// run Cloud Functions Gen2 (needs Blaze).
const String adminApiBaseUrl = 'https://helix-webhook.onrender.com';
