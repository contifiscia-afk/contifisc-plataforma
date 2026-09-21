import { NextResponse } from "next/server";
import { getSessionCookie } from "better-auth/cookies";
// Middleware (Next 14): triagem GROSSEIRA por EXISTENCIA do cookie. NAO valida a sessao (ver docs do Better Auth).
export function middleware(request) {
  const c = getSessionCookie(request);
  if (!c) return NextResponse.redirect(new URL("/", request.url));
  return NextResponse.next();
}
export const config = { matcher: ["/protected/:path*"] };
