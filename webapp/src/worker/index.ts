import { createApp } from "./app";
import type { Env } from "./env";

export { SessionIndex } from "./sessionIndex";
export { QrPairing } from "./qrPairing";

const app = createApp();

export default {
  fetch(request: Request, env: Env): Promise<Response> {
    return app.fetch(request, env);
  },
} satisfies ExportedHandler<Env>;
