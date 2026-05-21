# pixelcrafts-sdk

Monorepo of client SDKs for the pixelcrafts platform. One repo, one release cadence, one place to fix shared bugs. Each SDK is a thin, opinionated package — no UI, no state-management opinion, no analytics.

## Packages

| Package | Folder | Status | What it owns |
|---|---|---|---|
| `pixelcrafts_auth` (Flutter) | [`flutter/auth/`](./flutter/auth) | v0.1.0 | Firebase / Supabase / native sign-in → gateway token exchange → platform-JWT storage + Bearer attach + 401 single-flight refresh + onSessionExpired |
| `@pixelcrafts/auth` (Web) | [`web/auth/`](./web/auth) | v0.1.0 | Same flow, Next.js / React shape. Provider-agnostic (Firebase + Supabase wired) |
| `pixelcrafts_audio` (Flutter) | [`flutter/audio/`](./flutter/audio) | v0.1.0 | Mic permission, recording (with VAD), authenticated multipart upload to STT endpoint, transcript return. Seed extracted from mintly's `voice_service.dart` |

Future tenants of this monorepo (planned, not built):

- `pixelcrafts_payments` — RevenueCat / Razorpay client wiring + entitlements
- `@pixelcrafts/audio` — web counterpart if/when a brand needs browser-side recording with STT

## Why a monorepo, not multiple repos

Before: `pixelcrafts-auth-sdk` + (someday) `pixelcrafts-audio-sdk` + (someday) `pixelcrafts-payments-sdk`. Three repos. Three CI pipelines. Three versioning timelines. A change that touches "all client SDKs use the same internal HTTP client" lands as three PRs.

After: one repo, one release tag covers everything. Cross-package refactors are a single diff. New apps install a known set of versions in one go.

The cost is a slightly more complex `pubspec.yaml`/`package.json` path (`path: flutter/auth` instead of `path: flutter`). Worth it.

## Versioning

Each package SemVers independently. The repo tags as `<package>-vX.Y.Z`:

- `auth-flutter-v0.1.0`
- `auth-web-v0.1.0`
- `audio-flutter-v0.1.0`

Consumers pin their own combinations:

```yaml
# Flutter consumer (pubspec.yaml)
dependencies:
  pixelcrafts_auth:
    git:
      url: https://github.com/pixelcrafts-app/pixelcrafts-sdk
      path: flutter/auth
      ref: auth-flutter-v0.1.0
  pixelcrafts_audio:
    git:
      url: https://github.com/pixelcrafts-app/pixelcrafts-sdk
      path: flutter/audio
      ref: audio-flutter-v0.1.0
```

```json
// Web consumer (package.json)
"dependencies": {
  "@pixelcrafts/auth": "github:pixelcrafts-app/pixelcrafts-sdk#auth-web-v0.1.0"
}
```

For local development (and the current state of the world before this repo is pushed), consumers use a `file:` path:

```json
"@pixelcrafts/auth": "file:../../pixelcrafts/pixelcrafts-sdk/web/auth"
```

## Shared platform

Every SDK in this repo targets the same platform stack:

- **Gateway**: `auth.pixelcrafts.app` for identity + entitlements
- **AI gateway**: `pixelcrafts-api-ai` for STT, text completion, embedding, etc. — all SDKs that hit AI go through this single backend (centralized billing, caching, quotas)
- **Brand backends**: `pixelcrafts-api-mobile` (multi-tenant) and per-brand `*-api-core` repos; SDKs hit these for domain features

The SDKs never embed a specific provider (OpenAI / Anthropic / Whisper). Provider choice lives in `pixelcrafts-api-ai`'s adapter registry; SDK consumers see one stable interface.

## Locked-scope principle (per package)

Each package is **narrow, opinionated, and dumb**:

| In scope | Out of scope |
|---|---|
| The flow itself (token exchange, audio capture, etc.) | UI |
| Local storage / state for the flow's data | App-specific business logic |
| Error normalization + retry | Analytics / crash reporting |
| Auth header injection | Feature flags |
| Single-flight refresh / backoff | State-management opinion (works alongside Riverpod / Bloc / React) |

If you find yourself wanting to add UI to a package — push back. The SDK is the floor; consumers paint the rest.

## Docs

- [`docs/AUTH_INTEGRATION_GUIDE.md`](./docs/AUTH_INTEGRATION_GUIDE.md) — migrating an existing app onto `pixelcrafts_auth` / `@pixelcrafts/auth`
- [`docs/AUDIO_INTEGRATION_GUIDE.md`](./docs/AUDIO_INTEGRATION_GUIDE.md) — wiring `pixelcrafts_audio` for STT-based features
- [`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md) — why each design choice across all packages
- [`CHANGELOG.md`](./CHANGELOG.md) — release notes per package

## License

MIT, internal. Repo private — pixelcrafts apps only.
