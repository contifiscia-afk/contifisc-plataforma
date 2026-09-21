// Config usada SOMENTE pela CLI para gerar o schema Prisma do Better Auth (Gate A, PoC descartavel).
import { betterAuth } from "better-auth";
import { prismaAdapter } from "@better-auth/prisma-adapter";
import { twoFactor, admin, genericOAuth } from "better-auth/plugins";
import { passkey } from "@better-auth/passkey";
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();
export const auth = betterAuth({
  database: prismaAdapter(prisma, { provider: "postgresql" }),
  emailAndPassword: { enabled: true },
  plugins: [twoFactor(), admin(), passkey(), genericOAuth({ config: [] })],
});
