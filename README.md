# Pawket Change

**A budgeting app you actually feel something about — a hand-drawn cat that lives on your Home Screen, Lock Screen, and Dynamic Island, watches your spending, and roasts you in real time using an AI that runs entirely on your iPhone.**

> Connect your bank. A cartoon cat reacts to how you spend — *cheesing* when you're flush, *worried* as you near your limit, *broke* when you blow it — and drops a one-line roast about the specific thing you bought. The roast is written by a language model running **100% on-device**. No transaction you make ever touches a cloud AI.

*Live Activity in the Dynamic Island · Home Screen widgets · on-device agentic AI · Plaid-linked spending · hand-drawn everything*

---

## The problem we set out to solve

Budgeting apps fail for two boring reasons:

1. **You never open them.** A spreadsheet that lives behind three taps is a spreadsheet you ignore. Spending damage happens *in the moment* — at the till, mid-checkout — not on Sunday when you finally review a dashboard.
2. **"AI finance" apps are a privacy trap.** Every app that promises to "analyze your spending with AI" ships your entire transaction history off to a cloud LLM. Your bank statements become someone else's training data.

**Pawket Change** is our answer to a genuinely personal pain point: *I overspend without noticing, and I refuse to open a finance app to find out.*

So we put the feedback where your eyes already are — the **Lock Screen, Dynamic Island, and Home Screen** — in the form of a pet you can't help but care about, and we made the analysis **private by construction**: the model that judges you never leaves your phone.

It's a Tamagotchi for your bank account. Keep the cat happy, keep your budget intact.

---

## Why this isn't the project you're expecting

This is a 24-hour hackathon build, so here's the honest pitch for what's actually novel — not another chatbot with an API key.


| The usual hackathon "AI app"                                | Pawket Change                                                                                                                           |
| ----------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Wraps a single cloud prompt (`gpt-*`, Claude, etc.)         | Runs a **multi-tool agentic loop on Apple's on-device foundation model** (iOS 26 `FoundationModels`) — no AI server exists in our stack |
| Sends your data to a third party                            | **Spending analysis never leaves the device.** The model has no network access                                                          |
| Asks the LLM to "calculate" your budget (and gets it wrong) | **All math is deterministic Swift.** The model only *decides what's interesting* and *phrases it*                                       |
| Returns a string you regex-parse                            | Returns a **typed `@Generable` struct**, streamed token-by-token into a live speech bubble                                              |
| Ships a screenshot of a chat UI                             | Ships a **Dynamic Island Live Activity, three Home Screen widgets, and a custom hand-drawn animated character**                         |


If you only read one file, read `[FinanceCatAgent.swift](finance-buddy/finance-buddy/FinanceCatAgent.swift)`.

---

## The on-device AI, in detail

The cat's verdict is produced by a real **plan-and-act agent** running on Apple's on-device foundation model, not a one-shot prompt.

### 1. The model gets a toolbox, not a data dump

We hand the model six local tools and a system prompt, then let it decide which to call based on what it finds. This is genuine tool-use / function-calling on a ~3B-parameter model running on the Neural Engine:


| Tool                                              | What it returns                                                                                                                                                            |
| ------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `getBudgetStatus`                                 | Today / week / month spend, daily allowance, streak, current mood                                                                                                          |
| `getTodaysTransactions` / `getRecentTransactions` | Raw recent activity                                                                                                                                                        |
| `getMonthlyBreakdown`                             | Top merchants this month                                                                                                                                                   |
| `getRecurringCharges`                             | **Computes** repeat merchants *after normalizing noisy card-network names* (`SQ *BLUE BOTTLE #42` ≈ `BLUE BOTTLE LA`) — this is how it catches death-by-a-thousand-coffees |
| `getAnomalies`                                    | **Computes** statistical outliers via population **z-score** against *your own* spending distribution                                                                      |
| `getMonthEndProjection`                           | **Computes** a deterministic run-rate projection and budget pace                                                                                                           |


### 2. The math is in Swift; the language is in the model

Small language models are unreliable at arithmetic, so we never ask the model to do any. Every projection, average, z-score, and run-rate lives in `[FinanceCatAnalytics.swift](finance-buddy/finance-buddy/FinanceCatAnalytics.swift)` as pure, deterministic Swift:

- **Recurring-charge detection** groups transactions by a normalized merchant key and surfaces repeat offenders by total spend.
- **Anomaly detection** uses a population z-score (threshold 1.8σ, min sample size 5) so it flags *your* unusual purchases — and stays quiet on sparse data instead of crying wolf.
- **Month-end projection** is a linear run-rate: `(spend so far ÷ days elapsed) × days in month`, compared against your budget.

The month-end number shown to the user is the **Swift-computed value, merged into the model's output after generation** — the model literally cannot fabricate it. It decides *which* analysis matters and how to say it; the numbers are ground truth.

### 3. Structured, streaming output

The verdict is a `@Generable` Swift struct (`mood`, `severity 0–10`, `headline`, `roast`, `biggestCulprit`, `tip`). Because it's `@Generable`, the framework synthesizes a `PartiallyGenerated` type with optional fields — which is exactly what lets us **stream the verdict token-by-token**. The headline *types itself out live* in the cat's speech bubble while it "reads the receipts," via a punctuation-aware `[TypewriterText](finance-buddy/finance-buddy/TypewriterText.swift)` view (longer pauses after periods, subtle per-character jitter, a blinking cursor).

Generation is tuned for determinism and latency: greedy sampling, `temperature 0.2`, `maximumResponseTokens 220`.

### 4. It never strands the user

- **Availability is checked at every entry point.** On a device without Apple Intelligence, the feature degrades cleanly — the rest of the app works untouched.
- **Streaming has a one-shot fallback.** If a stream ends before all required fields arrive, the app falls back to a single `respond(...)` generation.
- **Verdicts are cached** (30 minutes, keyed by transaction count) so the cat doesn't re-think on every glance.
- The model is **prewarmed** on a finance snapshot so the first verdict is fast.

---

## Where the cat lives (this is the fun part)

Pawket Change isn't trapped inside the app. It uses the entire iOS surface area.

### 🏝️ Dynamic Island & Lock Screen — a live, animated pet (ActivityKit)

A **Live Activity** (`[FinanceBuddyWidgetLiveActivity.swift](finance-buddy/FinanceBuddyWidget/FinanceBuddyWidgetLiveActivity.swift)`) puts the cat in your Dynamic Island and on your Lock Screen:

- The hand-drawn cat **animates** (frame-swapped every second) right inside the Island.
- A **daily-budget pace bar** with 50% / 80% / 100% markers, color-shifting with the cat's mood.
- Compact, minimal, and expanded presentations all rendered with the custom art and color.

### 🧩 Three Home Screen widgets (WidgetKit)


| Widget       | Sizes         | Shows                                                                     |
| ------------ | ------------- | ------------------------------------------------------------------------- |
| **Buddy**    | small, medium | Your cat's mood + today's spend vs. daily budget                          |
| **Spending** | medium        | Day / week / month totals next to your cat                                |
| **Crew**     | large         | You *and up to four friends'* cats, moods, and hats arranged on the couch |


Widgets and the app share state through an **App Group** (`group.cursor-calgary.finance-buddy`); the app writes a `BuddyWidgetSnapshot` and calls `WidgetCenter.reloadTimelines` whenever your mood, color, hats, or friends change.

### 🐱 The app itself

Four tabs — **Home** (the cat + its roast), **Spending**, **Friends**, **Hats** — with a custom hand-drawn font, an opening "thinking" animation, and looping lobby music.

---

## Everything else under the hood

### Real spending, real categories (Plaid)

- Bank linking via **Plaid Link**, with incremental `**transactionsSync`** (cursor-based, paginated) and a **webhook** that re-syncs the moment new transactions land.
- The **Spending tab** renders a category donut chart + legend driven by Plaid's `personal_finance_category` (Food & Drink, Transportation, Entertainment, Rent & Utilities, Travel, and more — each with its own hand-tuned color), plus a merchant breakdown and a Today / This Month / Earlier transaction feed.
- All category, merchant, and total aggregations are computed in SQL against Postgres.

### The mood engine

A spend-to-allowance ratio maps to the cat's mood, with a **daily streak** that resets the moment you blow your allowance (`[engine.ts](backend/src/buddy/engine.ts)`, covered by Vitest unit tests):


| Spend vs. daily budget | Mood       | The cat is…                |
| ---------------------- | ---------- | -------------------------- |
| < 50%                  | "flexing"  | thrilled, rolling in money |
| 50–80%                 | "cheesing" | happy and relaxed          |
| 80–100%                | "worried"  | getting nervous            |
| ≥ 100%                 | "broke"    | devastated                 |


### Realtime, no polling

The app subscribes to **Supabase Realtime** Postgres-change events on the `buddy_states` table (filtered to the current user). When the backend recomputes your mood after a sync, the change **pushes straight to the app** — and onward to the widgets and Live Activity — with no polling loop.

### Social

Add friends by **buddy code** (a unique username), then see their cats' moods, streaks, and equipped hats — including all four of them living on the couch in your large **Crew widget**.

### Make the cat yours

- **Color**: full HSB customization of the cat's fill, synced to the backend and reflected everywhere (app, widgets, Live Activity, and your friends' Crew widgets).
- **Hats**: nine hand-drawn hats (headphones, halo, party, Santa, sprout, and more), owned/equipped server-side with frame-aware placement so the hat sits right in every animation frame.

### Hand-drawn, frame-by-frame

**Every visual asset is original and hand-drawn** — 50+ image assets, custom fonts, and multi-frame animation sets per mood. The character is composited at runtime from a **line-art layer + a template-tinted fill layer**, which is what lets one drawing become any color the user picks while staying crisp (nearest-neighbor scaling, no interpolation).

---

## Architecture

```
┌──────────────────────────────────────┐         ┌─────────────────────────────────┐
│  iOS app  (SwiftUI, iOS 18+)          │         │  Backend  (Node · TS · Express)  │
│                                       │         │  deployed on Railway             │
│  ┌─────────────────────────────┐      │  HTTPS  │                                  │
│  │ On-device AI agent          │      │◀───────▶│  • Plaid transactionsSync        │
│  │  FoundationModels (iOS 26)  │      │  Bearer │    (cursor-based + webhook)      │
│  │  • 6 tools, plan-and-act    │      │  (Supa- │  • Mood / allowance / streak     │
│  │  • @Generable, streaming    │      │   base  │    engine                        │
│  └─────────────────────────────┘      │   JWT)  │  • Drizzle ORM → Postgres        │
│  ┌─────────────────────────────┐      │         │  • Category & merchant rollups   │
│  │ Deterministic analytics      │     │         │                                  │
│  │  (Swift: z-score, run-rate)  │     │         │                                  │
│  └─────────────────────────────┘      │         └─────────────────────────────────┘
│  • WidgetKit ×3  • ActivityKit        │                       │
│  • App Group snapshot share           │              Supabase Postgres + Auth
│                                       │                        │
│  Supabase Realtime (buddy_states) ◀───┼────────────────────────┘
└──────────────────────────────────────┘   push mood changes, no polling
```

**The on-device model is intentionally outside the network boundary.** Plaid and our backend handle bank linking and transaction storage — standard for any bank-connected app — but the AI layer that *reads and judges* your spending runs only on your iPhone.

### Key files for a code review


| File                                                                                                            | Why it's worth a look                                                               |
| --------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| `[FinanceCatAgent.swift](finance-buddy/finance-buddy/FinanceCatAgent.swift)`                                    | The agent: `@Generable` verdict, six on-device tools, streaming + one-shot fallback |
| `[FinanceCatAnalytics.swift](finance-buddy/finance-buddy/FinanceCatAnalytics.swift)`                            | Deterministic recurring-charge / z-score anomaly / run-rate math                    |
| `[FinanceBuddyWidgetLiveActivity.swift](finance-buddy/FinanceBuddyWidget/FinanceBuddyWidgetLiveActivity.swift)` | Dynamic Island + Lock Screen animated Live Activity                                 |
| `[FinanceBuddyWidget.swift](finance-buddy/FinanceBuddyWidget/FinanceBuddyWidget.swift)`                         | The three Home Screen widgets, incl. the Crew layout                                |
| `[AppState.swift](finance-buddy/finance-buddy/AppState.swift)`                                                  | Streaming orchestration, Supabase Realtime, widget/Live-Activity sync               |
| `[TypewriterText.swift](finance-buddy/finance-buddy/TypewriterText.swift)`                                      | Punctuation-aware live-typing speech bubble                                         |
| `[backend/src/services/transactionSync.ts](backend/src/services/transactionSync.ts)`                            | Plaid cursor-based incremental sync                                                 |
| `[backend/src/buddy/engine.ts](backend/src/buddy/engine.ts)`                                                    | Mood / allowance / streak logic (unit-tested)                                       |
| `[backend/src/app.ts](backend/src/app.ts)`                                                                      | REST API, Zod-validated, Supabase-JWT-guarded                                       |


---

## Tech stack

**iOS** · `SwiftUI` · Apple `FoundationModels` (on-device LLM) · `WidgetKit` · `ActivityKit` (Live Activities) · App Groups · Supabase Swift SDK (Auth + Realtime) · `AVFoundation` · custom `CoreText` fonts

**Backend** · `Node` · `TypeScript` · `Express` · `Drizzle ORM` · `PostgreSQL` (Supabase) · `Plaid` · `Zod` · `Helmet` · `Vitest` · deployed on **Railway**

---

## Getting started

### Backend

```bash
cd backend
cp .env.example .env      # Supabase, Plaid Sandbox, and public base URL (ngrok / Railway)
npm install
npm run db:push           # push the Drizzle schema to Supabase Postgres
npm run dev               # Express on tsx watch
npm test                  # Vitest unit tests (mood engine)
```

### iOS

Open `finance-buddy/finance-buddy.xcodeproj` in **Xcode 26+** and run.

- The app builds and runs on **iOS 18+**.
- The **on-device AI verdict requires iOS 26 on an Apple Intelligence–capable device** with Apple Intelligence enabled (it does not run in the Simulator). Everywhere else, the feature degrades gracefully and the rest of the app is fully usable.
- Live Activities require iOS 16.2+.
- `AppConfig.backendBaseURL` points at our live Railway deployment out of the box; repoint it for your own backend.

---

## A note on privacy

The **spending analysis and roast generation happen entirely on-device** via Apple Foundation Models — no transaction text is ever sent to an AI service. Account linking and transaction sync are handled by Plaid and our own backend (standard for any bank-connected app); the on-device guarantee is specifically about the AI layer that reads what you bought.

---

## Built in 24 hours

Our team shipped, in one build window: an on-device agentic AI with tool-calling and streaming, a Dynamic Island Live Activity, three Home Screen widgets, full Plaid bank integration with incremental sync, a realtime mood/social backend on Postgres, and a complete set of original hand-drawn art and animation. The hardest stretch goal — getting a *streaming, tool-using language model to run privately on the phone and drive a live UI* — is the part we're proudest of.

