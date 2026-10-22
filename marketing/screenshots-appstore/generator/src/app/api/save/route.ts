import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";

export async function POST(req: Request) {
  const { name, dataUrl, dir } = (await req.json()) as { name: string; dataUrl: string; dir?: string };
  if (!name || !dataUrl?.startsWith("data:image/png;base64,")) {
    return Response.json({ ok: false, error: "bad payload" }, { status: 400 });
  }
  const safeName = name.replace(/[^a-zA-Z0-9._-]/g, "_");
  const safeDir = (dir ?? "").replace(/[^a-zA-Z0-9._/-]/g, "_").replace(/\.\./g, "");
  const base = path.join(process.cwd(), "..", "export");
  const target = path.join(base, safeDir);
  if (!target.startsWith(base)) {
    return Response.json({ ok: false, error: "bad dir" }, { status: 400 });
  }
  await mkdir(target, { recursive: true });
  const buf = Buffer.from(dataUrl.split(",")[1], "base64");
  await writeFile(path.join(target, safeName), buf);
  return Response.json({ ok: true, file: path.join(target, safeName) });
}
