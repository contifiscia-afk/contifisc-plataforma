// Autenticador WebAuthn POR SOFTWARE (PoC): ES256, attestation "none". Serve so para testar o servidor. Nao e produto.
import crypto from "node:crypto";

const b64u = (buf) => Buffer.from(buf).toString("base64url");
// --- CBOR minimo (inteiros, bytes, texto, mapas) ---
function head(major, n) {
  if (n < 24) return Buffer.from([(major << 5) | n]);
  if (n < 256) return Buffer.from([(major << 5) | 24, n]);
  if (n < 65536) return Buffer.from([(major << 5) | 25, n >> 8, n & 255]);
  throw new Error("cbor: valor grande");
}
function cbor(v) {
  if (Buffer.isBuffer(v)) return Buffer.concat([head(2, v.length), v]);
  if (typeof v === "string") { const b = Buffer.from(v, "utf8"); return Buffer.concat([head(3, b.length), b]); }
  if (typeof v === "number") return v >= 0 ? head(0, v) : head(1, -1 - v);
  if (v instanceof Map) return Buffer.concat([head(5, v.size), ...[...v.entries()].flatMap(([k, x]) => [cbor(k), cbor(x)])]);
  throw new Error("cbor: tipo nao suportado");
}

export class SoftAuthenticator {
  constructor({ rpId = "localhost", origin, uv = true } = {}) {
    this.rpId = rpId; this.origin = origin; this.uv = uv;
    const { publicKey, privateKey } = crypto.generateKeyPairSync("ec", { namedCurve: "P-256" });
    this.priv = privateKey;
    const jwk = publicKey.export({ format: "jwk" });
    this.x = Buffer.from(jwk.x, "base64url"); this.y = Buffer.from(jwk.y, "base64url");
    this.credId = crypto.randomBytes(32); this.counter = 0;
  }
  rpHash() { return crypto.createHash("sha256").update(this.rpId).digest(); }
  flags({ attested }) { return (this.uv ? 0x04 : 0) | 0x01 | (attested ? 0x40 : 0); }
  cose() { return cbor(new Map([[1, 2], [3, -7], [-1, 1], [-2, this.x], [-3, this.y]])); }
  register(challenge, { transports = ["internal"] } = {}) {
    const ctr = Buffer.alloc(4); ctr.writeUInt32BE(this.counter);
    const idLen = Buffer.alloc(2); idLen.writeUInt16BE(this.credId.length);
    const authData = Buffer.concat([this.rpHash(), Buffer.from([this.flags({ attested: true })]), ctr, Buffer.alloc(16), idLen, this.credId, this.cose()]);
    const attestationObject = cbor(new Map([["fmt", "none"], ["attStmt", new Map()], ["authData", authData]]));
    const clientDataJSON = Buffer.from(JSON.stringify({ type: "webauthn.create", challenge, origin: this.origin, crossOrigin: false }));
    return { id: b64u(this.credId), rawId: b64u(this.credId), type: "public-key", authenticatorAttachment: "platform", clientExtensionResults: {}, response: { clientDataJSON: b64u(clientDataJSON), attestationObject: b64u(attestationObject), transports } };
  }
  assert(challenge, { bumpCounter = true, overrideOrigin } = {}) {
    if (bumpCounter) this.counter += 1;
    const ctr = Buffer.alloc(4); ctr.writeUInt32BE(this.counter);
    const authData = Buffer.concat([this.rpHash(), Buffer.from([this.flags({ attested: false })]), ctr]);
    const clientDataJSON = Buffer.from(JSON.stringify({ type: "webauthn.get", challenge, origin: overrideOrigin ?? this.origin, crossOrigin: false }));
    const toSign = Buffer.concat([authData, crypto.createHash("sha256").update(clientDataJSON).digest()]);
    const signature = crypto.sign("sha256", toSign, { key: this.priv, dsaEncoding: "der" });
    return { id: b64u(this.credId), rawId: b64u(this.credId), type: "public-key", authenticatorAttachment: "platform", clientExtensionResults: {}, response: { clientDataJSON: b64u(clientDataJSON), authenticatorData: b64u(authData), signature: b64u(signature) } };
  }
}
