/** Utilidades de test sin `Buffer`: el tsconfig unitario es el de Workers, sin tipos de Node. */
export function b64url(bytes: Uint8Array): string {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function fromB64url(s: string): string {
  const b64 = s.replace(/-/g, "+").replace(/_/g, "/");
  return atob(b64 + "=".repeat((4 - (b64.length % 4)) % 4));
}

export function randHex(n = 16): string {
  return Array.from(crypto.getRandomValues(new Uint8Array(n)), (b) => b.toString(16).padStart(2, "0")).join("");
}

export function randB64url(n = 32): string {
  return b64url(crypto.getRandomValues(new Uint8Array(n)));
}

export async function sha256b64url(s: string): Promise<string> {
  return b64url(new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s))));
}

export function jwtPayload(jwt: string): Record<string, unknown> {
  return JSON.parse(fromB64url(jwt.split(".")[1] ?? ""));
}
