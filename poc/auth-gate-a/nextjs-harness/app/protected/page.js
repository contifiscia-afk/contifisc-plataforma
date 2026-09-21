import { headers } from "next/headers";
import { auth } from "../../lib/auth";
export const dynamic = "force-dynamic";
export default async function Protected() {
  const s = await auth.api.getSession({ headers: await headers() });
  if (!s) return <p id="prot">UNAUTHORIZED-SERVER-SIDE</p>;      // a autoridade e o servidor, nao o proxy
  return <p id="prot">PROTECTED-OK:{s.user.id}</p>;
}
