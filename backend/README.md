# Finance Buddy Backend

Node/Express + TypeScript backend for the hackathon MVP.

## Setup

1. Copy `.env.example` to `.env`.
2. Fill in Supabase, Plaid Sandbox, and ngrok values.
3. Install dependencies: `npm install`.
4. Push the Drizzle schema to Supabase: `npm run db:push`.
5. Start locally: `npm run dev`.

## Demo endpoints

- `POST /onboarding`
- `POST /plaid/create_link_token`
- `POST /plaid/exchange_public_token`
- `POST /transactions/refresh`
- `GET /buddy`
- `POST /webhook`

Use `user_transactions_dynamic` with a non-OAuth Sandbox institution for the live demo.
