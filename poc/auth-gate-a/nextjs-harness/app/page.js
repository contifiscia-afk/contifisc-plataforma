import { headers } from "next/headers";
import { auth } from "../lib/auth";
import { signInAction, whoAmIAction } from "./actions";
export const dynamic = "force-dynamic";
export default async function Page() {
  const s = await auth.api.getSession({ headers: await headers() });   // RSC valida a sessao no servidor
  return (
    <main>
      <p id="who">{s ? `session:${s.user.id}` : "no-session"}</p>
      <form action={signInAction}>
        <input name="email" /><input name="password" type="password" /><button id="signin" type="submit">entrar</button>
      </form>
      <form action={async () => { "use server"; const r = await whoAmIAction(); console.log("ACTION_RESULT", JSON.stringify(r)); }}>
        <button id="whoami" type="submit">whoami</button>
      </form>
    </main>
  );
}
