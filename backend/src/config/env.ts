import "dotenv/config";
import { z } from "zod";

const envSchema = z.object({
  PORT: z.coerce.number().default(3000),
  DATABASE_URL: z.string().min(1),
  SUPABASE_URL: z.string().url(),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(1),
  PLAID_CLIENT_ID: z.string().min(1),
  PLAID_SECRET: z.string().min(1),
  PLAID_ENV: z.enum(["sandbox", "development", "production"]).default("sandbox"),
  PLAID_PRODUCTS: z.string().default("transactions"),
  PLAID_COUNTRY_CODES: z.string().default("US"),
  PUBLIC_BASE_URL: z.string().url(),
  APP_TIME_ZONE: z.string().default("America/Edmonton")
});

export const env = envSchema.parse(process.env);
