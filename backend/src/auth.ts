import type { NextFunction, Request, Response } from "express";
import { createClient } from "@supabase/supabase-js";
import { env } from "./config/env.js";

const supabaseAdmin = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
  auth: {
    persistSession: false,
    autoRefreshToken: false
  }
});

export type AuthenticatedRequest = Request & {
  userId: string;
  accessToken: string;
};

export async function requireAuth(req: Request, res: Response, next: NextFunction) {
  const header = req.header("authorization");
  const token = header?.startsWith("Bearer ") ? header.slice("Bearer ".length) : undefined;

  if (!token) {
    res.status(401).json({ error: "missing_bearer_token" });
    return;
  }

  const { data, error } = await supabaseAdmin.auth.getUser(token);
  if (error || !data.user) {
    res.status(401).json({ error: "invalid_bearer_token" });
    return;
  }

  const authenticated = req as AuthenticatedRequest;
  authenticated.userId = data.user.id;
  authenticated.accessToken = token;
  next();
}
