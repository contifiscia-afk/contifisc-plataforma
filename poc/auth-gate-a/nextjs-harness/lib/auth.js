import { betterAuth } from "better-auth";
import { nextCookies } from "better-auth/next-js";
import { Pool } from "pg";
// PoC: usa o pool `pg` do Better Auth (sem Prisma) sobre as tabelas ja existentes no PG descartavel.
export const auth = betterAuth({
  baseURL: process.env.BETTER_AUTH_URL,
  secret: process.env.BETTER_AUTH_SECRET,
  trustedOrigins: [process.env.BETTER_AUTH_URL],
  database: new Pool({ connectionString: process.env.DATABASE_URL }),
  emailAndPassword: { enabled: true, minPasswordLength: 12 },
  plugins: [nextCookies()],
});
