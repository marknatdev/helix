# Graph Report - helix  (2026-08-12)

## Corpus Check
- 141 files · ~69,140 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1401 nodes · 1657 edges · 117 communities (111 shown, 6 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 14 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `f9492d24`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Win32Window
- dev_config_page.dart
- helmet.dart
- fleet_map.dart
- package.json
- command_header.dart
- login_page.dart
- app_theme.dart
- main.dart
- functions/package.json
- StatelessWidget
- settings_dialog.dart
- helmet_detail.dart
- helmet_model_test.dart
- alert_feed.dart
- helmet_feed.dart
- auth_service.dart
- user_service.dart
- index.js
- live_view.dart
- Firebase Authentication Web SDK
- fleet_stats.dart
- wWinMain
- App Hosting CLI Commands
- reports_view.dart
- register_helmet_dialog.dart
- State
- manifest.json
- App.jsx
- UserService
- firestore_helmet_service.dart
- ../models/helmet.dart
- package:flutter/material.dart
- Firebase AI Logic Basics
- vercel.json
- MainActivity
- Advanced Features Reference
- String?
- Key Attributes
- Configuration Reference
- Security Reference
- SDK Reference
- Native SQL Examples
- .prompt Files (Dotprompt)
- Web SDK Usage
- firebase-basics/SKILL.md
- Firestore Indexes Reference
- HELIX Firmware — LoRa Point-to-Point
- Schema Reference
- Genkit Core Framework
- Firestore Web SDK Usage Guide
- HTTP Handlers
- Getting Started
- Tools
- Genkit v1.x vs Pre-1.0 Migration
- Genkit Examples
- Writing Data
- developing-genkit-dart/SKILL.md
- Generation
- Genkit Best Practices
- Genkit JS
- Native SQL Operations
- firebase-data-connect/SKILL.md
- Operations Reference
- Templates
- Document Data Model
- Firestore Indexes Reference
- auth_gate.dart
- Firebase Auth Setup
- Schemantic
- developing-genkit-go/SKILL.md
- Alternative: Manual MCP Configuration (Project Scope)
- Queries
- Native SQL Examples
- Manual Initialization
- Advanced Validation for Business Logic
- Workflow
- Genkit Google GenAI Plugin (`genkit_google_genai`)
- Model Providers
- developing-genkit-js/SKILL.md
- Deployment
- Manual Initialization
- Assessment: Security Validator (Red Team Edition)
- Genkit MCP (`genkit_mcp`)
- Genkit Dart
- Firebase CLI Commands
- Genkit Documentation & CLI
- Firebase Local Environment Setup
- Recommended: Global Setup
- Recommended: Global Setup
- Firebase Web Setup Guide
- Workflow
- Firestore Enterprise Native Mode
- Advanced Validation for Business Logic
- Genkit Middleware (`genkit_middleware`)
- Genkit OpenAI Plugin (`genkit_openai`)
- Antigravity Setup
- Recommended Method: Using Plugins
- Cursor Setup
- Queries
- Writing Data
- Firestore Standard Edition
- Helix Smart Helmet - Authentication System Documentation
- Genkit Anthropic Plugin (`genkit_anthropic`)
- Genkit Shelf Plugin (`genkit_shelf`)
- DefineStreamingFlow
- helix_command_center
- rules/graphify.md
- workflows/graphify.md

## God Nodes (most connected - your core abstractions)
1. `Win32Window` - 22 edges
2. `UserService` - 17 edges
3. `Firebase Authentication Web SDK` - 15 edges
4. `HelmetFeed` - 12 edges
5. `MessageHandler` - 12 edges
6. `AuthService` - 11 edges
7. `Genkit Core Framework` - 11 edges
8. `FlutterWindow` - 10 edges
9. `Create` - 10 edges
10. `WndProc` - 10 edges

## Surprising Connections (you probably didn't know these)
- `wWinMain()` --calls--> `CreateAndAttachConsole()`  [INFERRED]
  old-version/windows/runner/main.cpp → old-version/windows/runner/utils.cpp
- `Win32Window::Win32Window()` --calls--> `Destroy`  [INFERRED]
  old-version/windows/runner/win32_window.cpp → old-version/windows/runner/win32_window.h
- `_LoginPageState` --references--> `AuthService`  [EXTRACTED]
  old-version/lib/auth/login_page.dart → old-version/lib/auth/auth_service.dart
- `_submit` --references--> `AuthService`  [EXTRACTED]
  old-version/lib/auth/login_page.dart → old-version/lib/auth/auth_service.dart
- `_CommandCenterPageState` --references--> `AuthService`  [EXTRACTED]
  old-version/lib/main.dart → old-version/lib/auth/auth_service.dart

## Import Cycles
- None detected.

## Communities (117 total, 6 thin omitted)

### Community 0 - "Win32Window"
Cohesion: 0.06
Nodes (54): FlutterViewController, RegisterPlugins(), DartProject, HWND, LPARAM, LRESULT, UINT, WPARAM (+46 more)

### Community 1 - "dev_config_page.dart"
Cohesion: 0.05
Nodes (44): dart:async, dart:convert, dart:math, _batteryCtrl, build, _buildEditor, createState, _db (+36 more)

### Community 2 - "helmet.dart"
Cohesion: 0.05
Nodes (38): DateTime, AlertKind, alertKindColor, alertKindIcon, alertKindLabel, battery, crew, diff (+30 more)

### Community 3 - "fleet_map.dart"
Cohesion: 0.07
Nodes (32): ../data/helmet_data.dart, EdgeInsetsGeometry, MapController, build, _c, child, color, createState (+24 more)

### Community 4 - "package.json"
Cohesion: 0.07
Nodes (27): lucide-react, dependencies, lucide-react, react, react-dom, @supabase/supabase-js, devDependencies, @types/react (+19 more)

### Community 5 - "command_header.dart"
Cohesion: 0.09
Nodes (23): AnimationController?, live_clock.dart, _ac, active, activeTab, build, children, count (+15 more)

### Community 6 - "login_page.dart"
Cohesion: 0.13
Nodes (14): dart:html, FormState, build, _busy, createState, _decoration, dispose, _email (+6 more)

### Community 7 - "app_theme.dart"
Cohesion: 0.10
Nodes (19): accent, AppColors, background, base, border, buildAppTheme, card, foreground (+11 more)

### Community 8 - "main.dart"
Cohesion: 0.11
Nodes (18): auth/auth_gate.dart, firebase_options.dart, _buildTab, createState, _filter, HelixApp, kSiteName, main (+10 more)

### Community 9 - "functions/package.json"
Cohesion: 0.11
Nodes (17): cors, dotenv, express, firebase-admin, dependencies, cors, dotenv, express (+9 more)

### Community 10 - "StatelessWidget"
Cohesion: 0.07
Nodes (31): HelmetStatus, _Label, _SecretBadge, _Badge, CommandHeader, _NavItem, _HudIconBtn, _HudPill (+23 more)

### Community 11 - "settings_dialog.dart"
Cohesion: 0.13
Nodes (14): ../auth/auth_service.dart, _ActionTile, destructive, icon, onTap, _RowTile, _SectionLabel, subtitle (+6 more)

### Community 12 - "helmet_detail.dart"
Cohesion: 0.13
Nodes (14): Color?, _ActionButton, build, color, helmet, HelmetDetail, icon, label (+6 more)

### Community 13 - "helmet_model_test.dart"
Cohesion: 0.13
Nodes (14): DocumentReference, DocumentSnapshot, Map, _data, exists, FakeDocumentSnapshot, _id, main (+6 more)

### Community 14 - "alert_feed.dart"
Cohesion: 0.14
Nodes (13): AlertEvent, _ActiveAlertTile, alert, AlertFeed, alerts, build, filled, label (+5 more)

### Community 15 - "helmet_feed.dart"
Cohesion: 0.13
Nodes (14): acknowledge, acknowledgeAll, _activeIds, alerts, _alertsSub, _connected, dispose, _error (+6 more)

### Community 16 - "auth_service.dart"
Cohesion: 0.14
Nodes (13): FirebaseAuth, _auth, _authSub, dispose, isSignedIn, messageFor, signIn, signOut (+5 more)

### Community 17 - "user_service.dart"
Cohesion: 0.15
Nodes (12): bool get, clear, _db, dispose, _helmetIds, listen, _loaded, registerHelmet (+4 more)

### Community 18 - "index.js"
Cohesion: 0.15
Nodes (8): admin, ALLOWED_ORIGINS, app, cors, db, express, path, IMPORTANT: If no secret is configured the endpoint rejects ALL requests.

### Community 19 - "live_view.dart"
Cohesion: 0.07
Nodes (30): Helmet, build, filter, FleetView, helmets, onClose, onFilterChange, onSelect (+22 more)

### Community 20 - "Firebase Authentication Web SDK"
Cohesion: 0.06
Nodes (33): Connect to Emulator, Email Link Authentication, Firebase Authentication Web SDK, Initialization, Observe Auth State, Sign In Anonymously, Sign In with Apple (Popup), Sign In with Facebook (Popup) (+25 more)

### Community 21 - "fleet_stats.dart"
Cohesion: 0.17
Nodes (11): IconData, build, FleetStats, helmets, icon, label, _Stat, sub (+3 more)

### Community 22 - "wWinMain"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16() (+1 more)

### Community 23 - "App Hosting CLI Commands"
Cohesion: 0.06
Nodes (30): App Hosting CLI Commands, Automated deployment via GitHub (CI/CD), Backend Management, Initialization, `npx -y firebase-tools@latest apphosting:backends:create`, `npx -y firebase-tools@latest apphosting:backends:delete <backend-id>`, `npx -y firebase-tools@latest apphosting:backends:get <backend-id>`, `npx -y firebase-tools@latest apphosting:backends:list` (+22 more)

### Community 24 - "reports_view.dart"
Cohesion: 0.17
Nodes (11): alerts, build, child, helmets, _InlineStat, label, _ReportCard, ReportsView (+3 more)

### Community 25 - "register_helmet_dialog.dart"
Cohesion: 0.20
Nodes (10): build, _busy, _controller, createState, dispose, _error, RegisterHelmetDialog, _RegisterHelmetDialogState (+2 more)

### Community 26 - "State"
Cohesion: 0.27
Nodes (10): LoginPage, _LoginPageState, CommandCenterPage, _CommandCenterPageState, _UserHelmetBridge, _UserHelmetBridgeState, DevConfigPage, _DevConfigPageState (+2 more)

### Community 27 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 28 - "App.jsx"
Cohesion: 0.37
Nodes (9): App(), LoginModal(), SupervisorDevModal(), fetchLiveHelmetsFromSupabase(), fetchLiveIncidentsFromSupabase(), initialIncidents, initialWorkers, isSupabaseConfigured() (+1 more)

### Community 29 - "UserService"
Cohesion: 0.24
Nodes (13): ChangeNotifier, MaterialPageRoute, AuthService, _submit, build, _openSettings, UserService, HelmetFeed (+5 more)

### Community 30 - "firestore_helmet_service.dart"
Cohesion: 0.22
Nodes (8): FirebaseFirestore, acknowledgeAlert, acknowledgeAllAlerts, alertsStream, _db, FirestoreHelmetService, helmetsStream, package:cloud_firestore/cloud_firestore.dart

### Community 31 - "../models/helmet.dart"
Cohesion: 0.25
Nodes (7): LatLng, ../models/helmet.dart, buildInitialAlerts, buildInitialHelmets, kSiteCenter, now, package:latlong2/latlong.dart

### Community 32 - "package:flutter/material.dart"
Cohesion: 0.18
Nodes (9): List, showComingSoon, build, helmets, onSelect, selectedId, ZonesView, package:flutter/material.dart (+1 more)

### Community 33 - "Firebase AI Logic Basics"
Cohesion: 0.07
Nodes (28): Advanced Features, Chat Session (Multi-turn), Core Capabilities, Firebase AI Logic Basics, Initialization Pattern, Multimodal (Text + Images/Audio/Video/PDF input), Streaming Responses, Advanced Features (+20 more)

### Community 34 - "vercel.json"
Cohesion: 0.50
Nodes (3): builds, routes, version

### Community 36 - "Advanced Features Reference"
Cohesion: 0.07
Nodes (26): Advanced Features Reference, Basic Trigger (Node.js), Basic Trigger (Python), Clear All Data, Cloud Functions Integration, Contents, Custom Embeddings, Data Seeding & Bulk Operations (+18 more)

### Community 44 - "Key Attributes"
Cohesion: 0.08
Nodes (23): `cleanUrls` (Optional), Full Example, `headers` (Optional), Hosting Configuration (`firebase.json`), `ignore` (Optional), Key Attributes, `public` (Required), `redirects` (Optional) (+15 more)

### Community 45 - "Configuration Reference"
Cohesion: 0.14
Nodes (14): Cloud SQL Configuration, Configuration Reference, Connect from SDK, connector.yaml, Contents, dataconnect.yaml, Emulator, Emulator Configuration (firebase.json) (+6 more)

### Community 46 - "Security Reference"
Cohesion: 0.08
Nodes (24): Access Levels, Anti-Patterns, @auth Directive, auth.token Fields, Authorization Data Lookup, Authorization Patterns, Available Bindings, CEL Expressions (+16 more)

### Community 47 - "SDK Reference"
Cohesion: 0.09
Nodes (22): Admin SDK, Android SDK, Calling Operations, Calling Operations, Calling Operations, Combine Publisher, Contents, Dependencies (build.gradle.kts) (+14 more)

### Community 48 - "Native SQL Examples"
Cohesion: 0.17
Nodes (11): Blog with Permissions, E-Commerce Store, Examples, Movie Review App, Mutations, Operations, Operations with Role Checks, Queries (+3 more)

### Community 49 - ".prompt Files (Dotprompt)"
Cohesion: 0.14
Nodes (13): Basic .prompt File, DefineDataPrompt (Typed Input/Output), DefineSchema (manual JSON Schema), DefineSchemaFor (from Go type), Execute (typed), ExecuteStream (typed), Load and Use, LoadPrompt (Explicit Path) (+5 more)

### Community 50 - "Web SDK Usage"
Cohesion: 0.11
Nodes (17): Add a Document with Auto-ID, Get a Single Document, Get Multiple Documents, Handle Changes, Initialization, Listen to a Document or Query, Order and Limit, Pipeline Queries (+9 more)

### Community 51 - "firebase-basics/SKILL.md"
Cohesion: 0.12
Nodes (10): Exploring Commands, Initialization, Refresh Antigravity Local Environment, Refresh Claude Code Local Environment, Refresh Gemini CLI Local Environment, Refresh Other Local Environment, Common Issues, Firebase Usage Principles (+2 more)

### Community 52 - "Firestore Indexes Reference"
Cohesion: 0.13
Nodes (15): 1. High Write Rates (Sequential Values), 2. Large String/Map/Array Fields, 3. TTL Fields, Automatic vs. Manual Management, Best Practices & Exemptions, CLI Commands, Composite Indexes, Config files (+7 more)

### Community 53 - "HELIX Firmware — LoRa Point-to-Point"
Cohesion: 0.15
Nodes (12): Architecture, Arduino IDE Setup (both boards), Configuration, GPS Wiring (when ready), Hardware, HELIX Firmware — LoRa Point-to-Point, Heltec V2 Pinout, LoRa Settings (must match on both boards) (+4 more)

### Community 54 - "Schema Reference"
Cohesion: 0.10
Nodes (20): @col, Contents, Core Directives, Customizing Tables, Data Types, @default, Defining Types, Enumerations (+12 more)

### Community 55 - "Genkit Core Framework"
Cohesion: 0.17
Nodes (12): Calling remote Flows from a dart client, Calling remote Flows from a Javascript client, Data Models, Define Flows, Define Tools, Embed Text, Generate Text, Genkit Core Framework (+4 more)

### Community 56 - "Firestore Web SDK Usage Guide"
Cohesion: 0.17
Nodes (11): Firestore Web SDK Usage Guide, Get a Single Document (`getDoc`), Get Multiple Documents (`getDocs`), Handle Changes (Added/Modified/Removed), Initialization, Listen to a Document/Query (`onSnapshot`), Order and Limit, Queries (+3 more)

### Community 57 - "HTTP Handlers"
Cohesion: 0.33
Nodes (6): Context Providers, genkit.Handler, genkit.HandlerFunc, HTTP Handlers, ListFlows, Request/Response Format

### Community 58 - "Getting Started"
Cohesion: 0.18
Nodes (10): Developer UI, Embedding Prompts, Genkit CLI, Getting Started, Import Paths, Init Options, Initialization, Project Setup (+2 more)

### Community 59 - "Tools"
Cohesion: 0.18
Nodes (10): Checking Resume State, DefineMultipartTool, DefineTool, Handling Interrupts, Interrupting, Max Turns, Tool Choice, Tool Interrupts (+2 more)

### Community 60 - "Genkit v1.x vs Pre-1.0 Migration"
Cohesion: 0.20
Nodes (10): Common Errors & Pitfalls, Flow Definitions, Genkit v1.x vs Pre-1.0 Migration, Initialization, Model References, Model Selection (Gemini), Package Imports, Response Access (+2 more)

### Community 61 - "Genkit Examples"
Cohesion: 0.20
Nodes (10): Advanced Configuration, Basic Text Generation, Genkit Examples, Google Search Grounding, Image Generation / Editing, Multimodal Generation, Speech Generation (TTS), Streaming (+2 more)

### Community 62 - "Writing Data"
Cohesion: 0.20
Nodes (9): Add a Document with Auto-ID, Get a Single Document, Get Multiple Documents, Python SDK Usage, Reading Data, Set a Document, Transactions, Update a Document (+1 more)

### Community 63 - "developing-genkit-dart/SKILL.md"
Cohesion: 0.22
Nodes (4): Genkit Chrome AI Plugin (`genkit_chrome`), Usage, Genkit Firebase AI Plugin (`genkit_firebase_ai`), Usage

### Community 64 - "Generation"
Cohesion: 0.13
Nodes (15): By Format String, By Go Type, Callback-Based Streaming, Combining Format + Schema, Common Options, Custom Output Instructions, Enum Output, Generate (+7 more)

### Community 65 - "Genkit Best Practices"
Cohesion: 0.22
Nodes (8): Configuration, Development, Flow & Tool Design, Genkit Best Practices, Model Selection (Google AI), Model Selection (Other Providers), Project Structure, Schema Definition

### Community 66 - "Genkit JS"
Cohesion: 0.22
Nodes (9): CLI Usage, Critical: Do Not Trust Internal Knowledge, Development Workflow, Error Troubleshooting Protocol, Finding Documentation, Genkit JS, Hello World, Prerequisites (+1 more)

### Community 67 - "Native SQL Operations"
Cohesion: 0.17
Nodes (8): Core Agent Constraints, Mutation Fields (DML), Native SQL Operations, Native SQL Root Fields, PostgreSQL Extensions, Query Fields (Read-Only), ⚠️ Security: Stored Procedures & Dynamic SQL, Syntax rules & limitations

### Community 68 - "firebase-data-connect/SKILL.md"
Cohesion: 0.18
Nodes (11): 1. Define Data Model (`schema/schema.gql`), 2. Define Operations (`connector/queries.gql`, `connector/mutations.gql`), 3. Secure Your App (`connector/` files), 4. Generate & Use SDKs, Deployment & CLI, Development Workflow, Examples, Feature Capability Map (+3 more)

### Community 69 - "Operations Reference"
Cohesion: 0.08
Nodes (25): Aliases, Basic Query, Contents, Create, Create with Server Values, Delete, Embedded Queries, Expression Operators (Compare with Server Values) (+17 more)

### Community 70 - "Templates"
Cohesion: 0.22
Nodes (8): Basic CRUD Schema, connector.yaml Template, dataconnect.yaml Template, Firebase Init Commands, Many-to-Many Relationship, SDK Initialization (Web), Templates, User-Owned Resources

### Community 71 - "Document Data Model"
Cohesion: 0.22
Nodes (8): Collection Group Support, Collections, Document Data Model, Documents, Examples, Firestore Data Model Reference, Subcollections, Use Cases

### Community 72 - "Firestore Indexes Reference"
Cohesion: 0.22
Nodes (9): CLI Commands, Config files, Firestore Indexes Reference, Index Density, Index Ordering, Index Structure, Management, Query Support Examples (+1 more)

### Community 73 - "auth_gate.dart"
Cohesion: 0.25
Nodes (7): auth_service.dart, login_page.dart, AuthGate, build, child, package:provider/provider.dart, Widget

### Community 74 - "Firebase Auth Setup"
Cohesion: 0.25
Nodes (7): 1. Create a Firebase project, 2. Register a Web app and copy the config, 3. Fill in `.env`, 4. Run the app, 5. Create the tester account, Firebase Auth Setup, Troubleshooting

### Community 75 - "Schemantic"
Cohesion: 0.25
Nodes (8): Basic Usage, Core Concepts, Field Annotations, Installation, Primitive Schemas, Recursive Schemas, Schemantic, Union Types (AnyOf)

### Community 76 - "developing-genkit-go/SKILL.md"
Cohesion: 0.25
Nodes (5): Core Features, Genkit CLI, Genkit Go, Hello World, Key Guidance

### Community 77 - "Alternative: Manual MCP Configuration (Project Scope)"
Cohesion: 0.25
Nodes (7): 1. Configure and Verify Firebase MCP Server, 1. Install and Verify Firebase Extension, 2. Restart and Verify Connection, 2. Restart and Verify Connection, Alternative: Manual MCP Configuration (Project Scope), Gemini CLI Setup, Recommended: Installing Extensions

### Community 78 - "Queries"
Cohesion: 0.50
Nodes (4): DefinePrompt, Execute, ExecuteStream, Override Options at Execution

### Community 79 - "Native SQL Examples"
Cohesion: 0.25
Nodes (8): Advanced aggregation with RANK, Advanced CTE with upserts (atomic get-or-create), Basic SELECT with field aliasing, Basic UPDATE, Multi-statement Transactions, Native SQL Examples, UPDATE with RETURNING and Auth Context, Use of extensions (e.g. PostGIS for geospatial data)

### Community 80 - "Manual Initialization"
Cohesion: 0.25
Nodes (8): 1. Create a Firestore Enterprise Database, 2. Create `firebase.json`, 2. Create `firestore.rules`, 3. Create `firestore.indexes.json`, Deploy rules and indexes, Local Emulation, Manual Initialization, Provisioning Firestore Enterprise Native Mode

### Community 81 - "Advanced Validation for Business Logic"
Cohesion: 0.25
Nodes (8): 1. Generate Firestore Rules, 3. Strict Path and Relationship Scoping, 4. Secure Counter Updates, 5. **CRITICAL** Ensure Application Validity, Advanced Validation for Business Logic, Critical Constraints, Phase-3: Devil's Advocate Attack, Phase-4: Syntactic Validation

### Community 82 - "Workflow"
Cohesion: 0.33
Nodes (6): Critical Directives for Secure Generation, **CRITICAL** RBAC Guidelines, Mandatory: User Data Separation (The "No Mixed Content" Rule), Phase-1: Codebase Analysis, Phase-2: Security Rules Generation, Workflow

### Community 83 - "Genkit Google GenAI Plugin (`genkit_google_genai`)"
Cohesion: 0.29
Nodes (6): Embeddings, Example (Nano Banana), Genkit Google GenAI Plugin (`genkit_google_genai`), Image Generation, Text-to-Speech (TTS), Usage

### Community 84 - "Model Providers"
Cohesion: 0.29
Nodes (7): Anthropic (Claude), Google AI (Gemini), Model Providers, Multiple Providers, Ollama (Local Models), OpenAI-Compatible (compat_oai), Vertex AI

### Community 86 - "Deployment"
Cohesion: 0.40
Nodes (5): Breaking Changes, CI/CD Integration, Deploy Workflow, Deployment, Schema Migrations

### Community 87 - "Manual Initialization"
Cohesion: 0.29
Nodes (7): 1. Create `firebase.json`, 2. Create `firestore.rules`, 3. Create `firestore.indexes.json`, Deploy rules and indexes, Local Emulation, Manual Initialization, Provisioning Cloud Firestore

### Community 88 - "Assessment: Security Validator (Red Team Edition)"
Cohesion: 0.29
Nodes (6): Admin Bootstrapping & Privileges:, Assessment: Security Validator (Red Team Edition), Mandatory Audit Checklist:, Overview, Scoring Criteria, Scoring Criteria (1-5):

### Community 89 - "Genkit MCP (`genkit_mcp`)"
Cohesion: 0.33
Nodes (5): Genkit MCP (`genkit_mcp`), MCP Client (Advanced / Single Server), MCP Host (Recommended), MCP Server, Streamable HTTP Transport

### Community 90 - "Genkit Dart"
Cohesion: 0.33
Nodes (6): Best Practices, Core Features and Usage, External Dependencies, Genkit CLI (recommended), Genkit Dart, Plugin Ecosystem

### Community 91 - "Firebase CLI Commands"
Cohesion: 0.40
Nodes (5): Deployment, Firebase CLI Commands, Initialize Data Connect, Local Development, Schema Management

### Community 92 - "Genkit Documentation & CLI"
Cohesion: 0.33
Nodes (6): Development Workflow, Documentation, Evaluation, Flow Execution, Genkit Documentation & CLI, Prerequisites:

### Community 93 - "Firebase Local Environment Setup"
Cohesion: 0.33
Nodes (5): 1. Verify Node.js, 2. Verify Firebase CLI, 3. Verify Firebase Authentication, 4. Install Agent Skills and MCP Server, Firebase Local Environment Setup

### Community 94 - "Recommended: Global Setup"
Cohesion: 0.33
Nodes (5): 1. Install and Verify Firebase Skills, 2. Configure and Verify Firebase MCP Server, 3. Restart and Verify Connection, GitHub Copilot Setup, Recommended: Global Setup

### Community 95 - "Recommended: Global Setup"
Cohesion: 0.33
Nodes (5): 1. Install and Verify Firebase Skills, 2. Configure and Verify Firebase MCP Server, 3. Restart and Verify Connection, Other Agents Setup, Recommended: Global Setup

### Community 96 - "Firebase Web Setup Guide"
Cohesion: 0.33
Nodes (5): 1. Create a Firebase Project and App, 2. Installation, 3. Initialization, 4. Using Services, Firebase Web Setup Guide

### Community 97 - "Workflow"
Cohesion: 0.33
Nodes (6): Critical Directives for Secure Generation, **CRITICAL** RBAC Guidelines, Mandatory: User Data Separation (The "No Mixed Content" Rule), Phase-1: Codebase Analysis, Phase-2: Security Rules Generation, Workflow

### Community 98 - "Firestore Enterprise Native Mode"
Cohesion: 0.33
Nodes (6): Data Model, Firestore Enterprise Native Mode, Indexes, Provisioning, SDK Usage, Security Rules

### Community 99 - "Advanced Validation for Business Logic"
Cohesion: 0.25
Nodes (8): 1. Generate Firestore Rules, 3. Strict Path and Relationship Scoping, 4. Secure Counter Updates, 5. **CRITICAL** Ensure Application Validity, Advanced Validation for Business Logic, Critical Constraints, Phase-3: Devil's Advocate Attack, Phase-4: Syntactic Validation

### Community 100 - "Genkit Middleware (`genkit_middleware`)"
Cohesion: 0.40
Nodes (4): Filesystem Middleware, Genkit Middleware (`genkit_middleware`), Skills Middleware, Tool Approval Middleware

### Community 101 - "Genkit OpenAI Plugin (`genkit_openai`)"
Cohesion: 0.40
Nodes (4): Basic Usage, Genkit OpenAI Plugin (`genkit_openai`), Groq API override, Options

### Community 102 - "Antigravity Setup"
Cohesion: 0.40
Nodes (4): 1. Install and Verify Firebase Skills, 2. Configure and Verify Firebase MCP Server, 3. Restart and Verify Connection, Antigravity Setup

### Community 103 - "Recommended Method: Using Plugins"
Cohesion: 0.40
Nodes (4): 1. Install and Verify Plugins, 2. Restart and Verify Connection, Claude Code Setup, Recommended Method: Using Plugins

### Community 104 - "Cursor Setup"
Cohesion: 0.40
Nodes (4): 1. Install and Verify Firebase Skills, 2. Configure and Verify Firebase MCP Server, 3. Restart and Verify Connection, Cursor Setup

### Community 105 - "Queries"
Cohesion: 0.50
Nodes (4): Order and Limit, Pipeline Queries, Queries, Simple and Compound Queries

### Community 106 - "Writing Data"
Cohesion: 0.40
Nodes (5): Add a Document with Auto-ID (`addDoc`), Set a Document (`setDoc`), Transactions, Update a Document (`updateDoc`), Writing Data

### Community 107 - "Firestore Standard Edition"
Cohesion: 0.40
Nodes (5): Firestore Standard Edition, Indexes, Provisioning, SDK Usage, Security Rules

### Community 108 - "Helix Smart Helmet - Authentication System Documentation"
Cohesion: 0.50
Nodes (3): 🔐 Features & Workflow, Helix Smart Helmet - Authentication System Documentation, 🛠 Setting Up Supabase Authentication

### Community 109 - "Genkit Anthropic Plugin (`genkit_anthropic`)"
Cohesion: 0.50
Nodes (3): Claude Thinking Configurations, Genkit Anthropic Plugin (`genkit_anthropic`), Usage

### Community 110 - "Genkit Shelf Plugin (`genkit_shelf`)"
Cohesion: 0.50
Nodes (3): Existing Shelf Application, Genkit Shelf Plugin (`genkit_shelf`), Standalone Server

### Community 111 - "DefineStreamingFlow"
Cohesion: 0.22
Nodes (8): DefineFlow, DefineStreamingFlow, Flows & HTTP, Named Sub-Steps, Pattern 1: Passthrough Streaming, Pattern 2: Manual String Streaming, Running a Flow Directly, Typed Streaming Flows

## Knowledge Gaps
- **860 isolated node(s):** `admin`, `express`, `cors`, `path`, `db` (+855 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **6 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `AuthService` connect `UserService` to `login_page.dart`, `main.dart`, `settings_dialog.dart`, `auth_service.dart`, `State`?**
  _High betweenness centrality (0.006) - this node is a cross-community bridge._
- **Why does `UserService` connect `UserService` to `dev_config_page.dart`, `main.dart`, `settings_dialog.dart`, `user_service.dart`, `register_helmet_dialog.dart`, `State`?**
  _High betweenness centrality (0.006) - this node is a cross-community bridge._
- **Why does `HelmetFeed` connect `UserService` to `main.dart`, `settings_dialog.dart`, `helmet_feed.dart`, `live_view.dart`, `State`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **What connects `admin`, `express`, `cors` to the rest of the system?**
  _860 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Win32Window` be split into smaller, more focused modules?**
  _Cohesion score 0.05837173579109063 - nodes in this community are weakly interconnected._
- **Should `dev_config_page.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.04541062801932367 - nodes in this community are weakly interconnected._
- **Should `helmet.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.05128205128205128 - nodes in this community are weakly interconnected._