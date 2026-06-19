import { describe, expect, it } from "vitest";
import { jsonError } from "../src/errors";

describe("envelopes de error OpenAI-compatibles", () => {
  it("shape {error:{message,type,param,code}} que el SDK MacPaw sabe decodificar", async () => {
    const res = jsonError("yala_quota_daily", "límite", 429, { "X-Yala-Limit": "daily" });
    expect(res.status).toBe(429);
    expect(res.headers.get("content-type")).toContain("application/json");
    expect(res.headers.get("X-Yala-Limit")).toBe("daily");
    const body = (await res.json()) as { error: { message: string; type: string; param: string | null; code: string | null } };
    expect(body.error.type).toBe("yala_quota_daily");
    expect(body.error.message).toBe("límite");
    expect(body.error.code).toBe("yala_quota_daily");
    expect(body.error.param).toBeNull();
  });

  it("status y type se respetan por tipo", async () => {
    const res = jsonError("yala_pro_required", "pro", 403);
    expect(res.status).toBe(403);
    expect(((await res.json()) as { error: { type: string } }).error.type).toBe("yala_pro_required");
  });
});
