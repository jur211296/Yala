import { createApp } from "./app";
import type { Env } from "./env";

const app = createApp();

export default {
  fetch(request: Request, env: Env): Promise<Response> {
    return app.fetch(request, env);
  },
} satisfies ExportedHandler<Env>;
