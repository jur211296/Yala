/** La cola del gateway (`ConnectorDrafts`) en las pruebas del conector: apunta lo que recibe y responde lo que se le pida. */
import type { QueuedDraftView } from "../src/inboxTool";
import type { ConnectorDraftPayload, ConnectorDraftsBinding, EnqueueOptions, EnqueueOutcome } from "../src/writeTool";

export class FakeQueue implements ConnectorDraftsBinding {
  calls: { userId: string; payload: ConnectorDraftPayload }[] = [];
  /** Las opciones de cada llamada, aparte: las pruebas de antes del lote 5 comparan `calls` tal cual. */
  options: (EnqueueOptions | undefined)[] = [];
  next: EnqueueOutcome | Error = { ok: true, id: "11111111-1111-4111-8111-111111111111" };
  queued: QueuedDraftView[] | null = [];
  pendingCalls: string[] = [];
  async enqueue(userId: string, payload: ConnectorDraftPayload, options?: EnqueueOptions): Promise<EnqueueOutcome> {
    this.calls.push({ userId, payload });
    this.options.push(options);
    if (this.next instanceof Error) throw this.next;
    return this.next;
  }
  async pending(userId: string): Promise<QueuedDraftView[] | null> {
    this.pendingCalls.push(userId);
    return this.queued;
  }
}
