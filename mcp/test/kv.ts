/**
 * KV en memoria con lo que usa la librería OAuth: `get` (texto o JSON), `put` con caducidad y metadatos, `delete` y
 * `list` por prefijo. La caducidad se mira contra `Date.now()`, así que los relojes falsos de vitest la mueven.
 */
interface Entry {
  value: string;
  expiration?: number;
  metadata?: unknown;
}

export class MemoryKV {
  readonly store = new Map<string, Entry>();

  private alive(key: string): Entry | undefined {
    const e = this.store.get(key);
    if (!e) return undefined;
    if (e.expiration !== undefined && e.expiration * 1000 <= Date.now()) {
      this.store.delete(key);
      return undefined;
    }
    return e;
  }

  async get(key: string, opts?: { type?: string } | string): Promise<unknown> {
    const e = this.alive(key);
    if (!e) return null;
    const type = typeof opts === "string" ? opts : opts?.type;
    return type === "json" ? JSON.parse(e.value) : e.value;
  }

  async put(key: string, value: string, opts: { expiration?: number; expirationTtl?: number; metadata?: unknown } = {}): Promise<void> {
    const expiration = opts.expiration ?? (opts.expirationTtl !== undefined ? Math.floor(Date.now() / 1000) + opts.expirationTtl : undefined);
    this.store.set(key, { value, expiration, metadata: opts.metadata });
  }

  async delete(key: string): Promise<void> {
    this.store.delete(key);
  }

  async list(opts: { prefix?: string; limit?: number; cursor?: string } = {}) {
    const names = [...this.store.keys()].filter((k) => k.startsWith(opts.prefix ?? "") && this.alive(k)).sort();
    const start = opts.cursor ? Number(opts.cursor) : 0;
    const limit = opts.limit ?? 1000;
    const page = names.slice(start, start + limit);
    const done = start + limit >= names.length;
    return {
      keys: page.map((name) => ({ name, expiration: this.store.get(name)?.expiration, metadata: this.store.get(name)?.metadata })),
      list_complete: done,
      ...(done ? {} : { cursor: String(start + limit) }),
    };
  }
}
