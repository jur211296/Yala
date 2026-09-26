/**
 * Supabase falso, CON ESTADO, para recorrer el baile entero sin red: el servidor OAuth (autorizaciones, consentimiento,
 * canje con cliente confidencial y PKCE, refresh con rotación), las sesiones que GoTrue carga en `GET /user`, el
 * logout y PostgREST. Apunta cada petición para poder comprobar qué salió del Worker y con qué credencial.
 *
 * Lo que simula del hook: los tokens emitidos al cliente OAuth salen con `role = roleForOAuth` (por defecto
 * `yala_mcp_reader`) y con su `client_id`.
 */
import { createLocalJWKSet, exportJWK, generateKeyPair, jwtVerify, SignJWT, type JWTVerifyGetKey } from "jose";
import { fromB64url, randHex, sha256b64url } from "./b64";

export const SB_URL = "https://proyecto.supabase.co";
export const SB_ISSUER = `${SB_URL}/auth/v1`;
export const WORKER_SB_CLIENT = "0b6f1c5e-6a55-4e0b-9d9c-1f7a3d2e4c10";
export const WORKER_SB_SECRET = "secreto-del-cliente-del-worker";

export interface TestUser {
  id: string;
  email: string;
  password: string;
}
export const USER_A: TestUser = { id: "11111111-1111-4111-8111-111111111111", email: "a@test.yala", password: "pass-a" };
export const USER_B: TestUser = { id: "22222222-2222-4222-8222-222222222222", email: "b@test.yala", password: "pass-b" };

interface Authz {
  id: string;
  state: string;
  challenge: string;
  redirectUri: string;
  clientId: string;
  userId?: string;
  code?: string;
  used?: boolean;
}

interface Session {
  id: string;
  userId: string;
  clientId?: string;
  refresh: string;
  previousRefresh?: string;
}

export interface Call {
  method: string;
  path: string;
  search: string;
  auth: string | null;
  body: string;
}

const rand = (n = 16) => randHex(n);

export class FakeSupabase {
  readonly calls: Call[] = [];
  readonly authorizations = new Map<string, Authz>();
  readonly sessions = new Map<string, Session>();
  readonly users = new Map<string, TestUser>([USER_A, USER_B].map((u) => [u.email, u]));

  // ─── Palancas de los tests ──────────────────────────────────────────────
  /** Lo que pone «el hook» en los tokens del cliente OAuth. `authenticated` = hook apagado. */
  roleForOAuth = "yala_mcp_reader";
  /** Si está, los tokens OAuth salen con este `client_id` en vez del real. */
  clientIdInToken: string | undefined;
  accessTtlSeconds = 3600;
  failExchange: { status: number; code: string } | undefined;
  failRefresh: { status: number; code: string } | undefined;
  /** Si está, `GET /auth/v1/user` responde esto en vez de mirar la sesión. */
  userEndpoint: { status: number; code?: string } | undefined;
  /** Si está, la verificación del JWT (el JWKS) lanza esto: simula que las claves de Supabase no responden. */
  jwksThrows: Error | undefined;
  /** Supabase ya tenía permiso de este usuario al cliente: GET de la autorización devuelve solo `redirect_url`. */
  alreadyConsented = false;
  /** Cambia los detalles de la autorización que ve la pantalla de login. */
  detailsOverride: ((a: Authz) => Record<string, unknown>) | undefined;
  /** Si está, la aprobación devuelve esta URL en vez del callback con el código. */
  consentRedirectOverride: string | undefined;
  rows: Record<string, unknown[]> = {};
  postgrestStatus: number | undefined;

  private constructor(
    private readonly signer: (claims: Record<string, unknown>, expSec: number) => Promise<string>,
    readonly jwks: JWTVerifyGetKey,
  ) {}

  static async create(): Promise<FakeSupabase> {
    const { publicKey, privateKey } = await generateKeyPair("ES256");
    const jwk = { ...(await exportJWK(publicKey)), kid: "k1", alg: "ES256" };
    const jwks = createLocalJWKSet({ keys: [jwk] });
    const signer = (claims: Record<string, unknown>, expSec: number) =>
      new SignJWT(claims).setProtectedHeader({ alg: "ES256", kid: "k1" }).setIssuer(SB_ISSUER).setIssuedAt().setExpirationTime(expSec).sign(privateKey);
    return new FakeSupabase(signer, jwks);
  }

  /** Firma un token cualquiera con la clave del proyecto (para tests de verificación). */
  sign(claims: Record<string, unknown>, expSec = Math.floor(Date.now() / 1000) + 3600): Promise<string> {
    return this.signer(claims, expSec);
  }

  /** Lo que hace el navegador al visitar `/oauth/authorize` de Supabase: crea la autorización y manda a la Site URL. */
  visitAuthorize(url: string, siteUrl: string): string {
    const u = new URL(url);
    if (u.origin + u.pathname !== `${SB_ISSUER}/oauth/authorize`) throw new Error(`no es el authorize de Supabase: ${url}`);
    const clientId = u.searchParams.get("client_id") ?? "";
    const redirectUri = u.searchParams.get("redirect_uri") ?? "";
    if (clientId !== WORKER_SB_CLIENT) throw new Error("cliente desconocido en Supabase");
    if (redirectUri !== `${siteUrl}/oauth/supabase/callback`) throw new Error("vuelta no registrada en Supabase");
    if (u.searchParams.get("code_challenge_method") !== "S256") throw new Error("PKCE sin S256");
    const id = `az_${rand(8)}`;
    this.authorizations.set(id, {
      id,
      state: u.searchParams.get("state") ?? "",
      challenge: u.searchParams.get("code_challenge") ?? "",
      redirectUri,
      clientId,
    });
    return `${siteUrl}/oauth/consent?authorization_id=${id}`;
  }

  /** Lo que hace `DELETE /auth/v1/user/oauth/grants?client_id=…` desde la cuenta del usuario. */
  revokeOAuthSessions(userId: string): void {
    for (const [id, s] of this.sessions) if (s.userId === userId && s.clientId) this.sessions.delete(id);
  }

  oauthSessions(userId?: string): Session[] {
    return [...this.sessions.values()].filter((s) => s.clientId && (!userId || s.userId === userId));
  }

  webSessions(): Session[] {
    return [...this.sessions.values()].filter((s) => !s.clientId);
  }

  private async issue(userId: string, clientId?: string): Promise<{ access_token: string; refresh_token: string; session: Session }> {
    const user = [...this.users.values()].find((u) => u.id === userId)!;
    const session: Session = { id: `ses_${rand(8)}`, userId, clientId, refresh: `rt_${rand()}` };
    this.sessions.set(session.id, session);
    return { ...(await this.tokensFor(session, user)), session };
  }

  private async tokensFor(session: Session, user: TestUser) {
    const oauth = !!session.clientId;
    const claims: Record<string, unknown> = {
      sub: user.id,
      aud: "authenticated",
      email: user.email,
      role: oauth ? this.roleForOAuth : "authenticated",
      session_id: session.id,
    };
    if (oauth) claims.client_id = this.clientIdInToken ?? session.clientId;
    const access_token = await this.signer(claims, Math.floor(Date.now() / 1000) + this.accessTtlSeconds);
    return { access_token, refresh_token: session.refresh, token_type: "bearer", expires_in: this.accessTtlSeconds };
  }

  private async sessionOf(auth: string | null): Promise<{ session?: Session; error?: Response }> {
    const token = auth?.replace(/^Bearer /, "") ?? "";
    let payload: Record<string, unknown>;
    try {
      ({ payload } = await jwtVerify(token, this.jwks, { issuer: SB_ISSUER }));
    } catch {
      return { error: Response.json({ code: 403, error_code: "bad_jwt", msg: "invalid JWT" }, { status: 403 }) };
    }
    const session = this.sessions.get(String(payload.session_id));
    if (!session) return { error: Response.json({ code: 403, error_code: "session_not_found", msg: "Session not found" }, { status: 403 }) };
    return { session };
  }

  readonly fetcher = async (input: Request | string | URL, init?: RequestInit): Promise<Response> => {
    const url = new URL(input instanceof Request ? input.url : String(input));
    const method = (init?.method ?? "GET").toUpperCase();
    const headers = new Headers(init?.headers);
    const body = typeof init?.body === "string" ? init.body : "";
    this.calls.push({ method, path: url.pathname, search: url.search, auth: headers.get("Authorization"), body });
    const path = url.pathname;

    if (path.startsWith("/rest/v1/")) {
      if (this.postgrestStatus) return new Response("{}", { status: this.postgrestStatus });
      const all = this.rows[path.slice("/rest/v1/".length)] ?? [];
      const offset = Number(url.searchParams.get("offset") ?? 0);
      const limit = Number(url.searchParams.get("limit") ?? all.length);
      return Response.json(all.slice(offset, offset + limit));
    }

    if (method === "POST" && path === "/auth/v1/token" && url.searchParams.get("grant_type") === "password") {
      const { email, password } = JSON.parse(body) as { email: string; password: string };
      const user = this.users.get(email);
      if (!user || user.password !== password) return Response.json({ error_code: "invalid_credentials" }, { status: 400 });
      const t = await this.issue(user.id);
      return Response.json({ access_token: t.access_token, refresh_token: t.refresh_token });
    }

    const authz = /^\/auth\/v1\/oauth\/authorizations\/([^/]+)(\/consent)?$/.exec(path);
    if (authz) {
      const { session, error } = await this.sessionOf(headers.get("Authorization"));
      if (error) return error;
      const a = this.authorizations.get(authz[1]!);
      if (!a || a.used) return Response.json({ error_code: "oauth_authorization_not_found" }, { status: 404 });
      a.userId = session!.userId;
      const redirect = () => {
        a.code = `code_${rand()}`;
        const r = new URL(a.redirectUri);
        r.searchParams.set("code", a.code);
        r.searchParams.set("state", a.state);
        return this.consentRedirectOverride ?? r.toString();
      };
      if (!authz[2] && method === "GET") {
        if (this.alreadyConsented) return Response.json({ redirect_url: redirect() });
        const user = [...this.users.values()].find((u) => u.id === session!.userId)!;
        return Response.json(
          this.detailsOverride?.(a) ?? {
            authorization_id: a.id,
            redirect_uri: a.redirectUri,
            client: { id: a.clientId, name: "Yala para Claude" },
            user: { id: user.id, email: user.email },
            scope: "email",
          },
        );
      }
      if (authz[2] && method === "POST") return Response.json({ redirect_url: redirect() });
    }

    if (method === "POST" && path === "/auth/v1/oauth/token") {
      const basic = headers.get("Authorization") ?? "";
      const [id, secret] = fromB64url(basic.replace(/^Basic /, "")).split(":").map(decodeURIComponent);
      if (id !== WORKER_SB_CLIENT || secret !== WORKER_SB_SECRET) {
        // Formato REAL de GoTrue v2.197 cuando el secreto del cliente no cuadra (internal/api/middleware.go): la
        // envoltura estándar con `error_code`, no la de OAuth. Importa: `invalid_credentials` NO debe cerrar la conexión.
        return Response.json({ code: 400, error_code: "invalid_credentials", msg: "Invalid client credentials" }, { status: 400 });
      }
      const form = new URLSearchParams(body);
      if (form.get("grant_type") === "authorization_code") {
        if (this.failExchange) return Response.json({ error_code: this.failExchange.code }, { status: this.failExchange.status });
        const a = [...this.authorizations.values()].find((x) => x.code === form.get("code"));
        if (!a || a.used || !a.userId) return Response.json({ error: "invalid_grant" }, { status: 400 });
        if (form.get("redirect_uri") !== a.redirectUri) return Response.json({ error: "invalid_grant" }, { status: 400 });
        const challenge = await sha256b64url(form.get("code_verifier") ?? "");
        if (challenge !== a.challenge) return Response.json({ error: "invalid_grant" }, { status: 400 });
        a.used = true;
        const t = await this.issue(a.userId, a.clientId);
        return Response.json({ access_token: t.access_token, refresh_token: t.refresh_token, expires_in: this.accessTtlSeconds });
      }
      if (form.get("grant_type") === "refresh_token") {
        if (this.failRefresh) {
          // Un 5xx real de GoTrue no trae `error_code` (es una página de error): readError cae a `http_<status>`.
          if (this.failRefresh.status >= 500) return new Response("upstream error", { status: this.failRefresh.status });
          return Response.json({ code: this.failRefresh.status, error_code: this.failRefresh.code }, { status: this.failRefresh.status });
        }
        const rt = form.get("refresh_token");
        const s = [...this.sessions.values()].find((x) => x.clientId && (x.refresh === rt || x.previousRefresh === rt));
        if (!s) return Response.json({ code: 400, error_code: "refresh_token_not_found" }, { status: 400 });
        const user = [...this.users.values()].find((u) => u.id === s.userId)!;
        if (s.refresh !== rt) {
          // rt es el PADRE (previousRefresh). GoTrue, dentro de su ventana de reúso (10 s), devuelve el hijo activo en
          // vez de revocar: es lo que permite recuperarse de una respuesta perdida. El falso modela esa gracia y no la
          // caduca por tiempo (los tests no avanzan 10 s a mitad de un refresh).
          return Response.json(await this.tokensFor(s, user));
        }
        s.previousRefresh = s.refresh;
        s.refresh = `rt_${rand()}`;
        return Response.json(await this.tokensFor(s, user));
      }
      return Response.json({ error: "unsupported_grant_type" }, { status: 400 });
    }

    if (method === "GET" && path === "/auth/v1/user") {
      if (this.userEndpoint) {
        return Response.json({ error_code: this.userEndpoint.code }, { status: this.userEndpoint.status });
      }
      const { session, error } = await this.sessionOf(headers.get("Authorization"));
      if (error) return error;
      return Response.json({ id: session!.userId });
    }

    if (method === "POST" && path === "/auth/v1/logout") {
      const { session } = await this.sessionOf(headers.get("Authorization"));
      if (session) this.sessions.delete(session.id);
      return new Response(null, { status: 204 });
    }

    return Response.json({ error: "no simulado" }, { status: 404 });
  };
}
