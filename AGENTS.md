# Repository Guidelines

## Project Structure & Module Organization

This repo contains an iOS SwiftUI app and a Node/TypeScript backend.

- `finance-buddy/finance-buddy/`: SwiftUI source files, app config, views, models, and bundled assets such as `catfont2.otf`.
- `finance-buddy/finance-buddy/Assets.xcassets/`: app icons, colors, and image assets such as buddy frames.
- `finance-buddy/finance-buddy.xcodeproj/`: Xcode project and Swift Package Manager pins.
- `backend/src/`: Express app, Supabase auth middleware, Plaid integration, Drizzle schema, services, and scripts.
- `backend/tests/`: Vitest unit tests.

## Build, Test, and Development Commands

Run backend commands from `backend/`:

- `npm run dev`: start the Express backend with `tsx watch`.
- `npm run build`: typecheck TypeScript with `tsc --noEmit`.
- `npm test`: run Vitest tests.
- `npm run db:push`: push the Drizzle schema to Supabase Postgres.
- `npm run db:clear`: truncate app data tables; does not delete Supabase Auth users.

Build the iOS app with Xcode, or:

```bash
xcodebuild -project finance-buddy/finance-buddy.xcodeproj -scheme finance-buddy -destination 'generic/platform=iOS Simulator' build
```

## Coding Style & Naming Conventions

Use 2-space indentation for TypeScript and 4-space indentation for Swift. Keep backend modules small and domain-oriented: routes in `app.ts`, persistence in `db/`, Plaid logic in `services/` or `plaid/`. Swift views use `PascalCase` filenames matching their primary type, e.g. `HomeView.swift`. Use `camelCase` for variables and JSON fields unless matching database column names.

## Testing Guidelines

Backend tests use Vitest and live in `backend/tests/*.test.ts`. Add focused unit tests for pure logic, especially buddy mood mapping, allowance calculations, and sync behavior. Run `npm test` before commits. For iOS changes, run an Xcode build and manually verify onboarding, Plaid Link, realtime updates, and sign out.

## Commit & Pull Request Guidelines

The current history uses concise imperative commit messages, for example `Build finance buddy MVP prototype`. Keep commits focused and describe the user-visible change. Pull requests should include a short summary, test results, any schema/env changes, and screenshots for UI changes.

## Security & Configuration Tips

Never commit `backend/.env`, Plaid secrets, Supabase service role keys, or `node_modules/`. iOS may contain only public config such as Supabase anon key and backend URL. Use `backend/.env.example` as the template. For TestFlight, point `AppConfig.backendBaseURL` at the deployed HTTPS backend, not localhost.
