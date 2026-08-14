/// Base URL for the functions/index.js admin/claim API.
///
/// functions/index.js is a standalone Express server deployed to Render (see
/// render.yaml) — smhelmet-67 is on Firebase's free Spark plan, which can't
/// run Cloud Functions Gen2 (needs Blaze). This still points at the local dev
/// server; once deployed to Render, replace it with the printed service URL
/// (e.g. `https://helix-webhook.onrender.com`), which isn't known until after
/// that deploy runs.
const String adminApiBaseUrl = 'http://localhost:3000';
