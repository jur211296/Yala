/**
 * El Durable Object de UN código QR (`idFromName(<código>)`). Ver `pairing.ts` para el flujo. Va en un objeto y no en el
 * KV porque la aprobación del iPhone tiene que verse en el acto desde el navegador (el KV es eventual: la beta lo midió
 * con la lista de sesiones). Una alarma lo vacía al caducar: no queda nada guardado de un código viejo.
 *
 * La lógica vive en `PairingCell` (`pairing.ts`), sin dependencias de Cloudflare: las pruebas la usan tal cual.
 */
import { DurableObject } from "cloudflare:workers";
import { PairingCell, type PairingApi, type PairingRecord } from "./pairing";

const KEY = "rec";

export class QrPairing extends DurableObject implements PairingApi {
  private readonly cell: PairingCell;
  private readonly storage: DurableObjectStorage;

  constructor(ctx: DurableObjectState, env: unknown) {
    super(ctx, env as never);
    this.storage = ctx.storage;
    this.cell = new PairingCell({
      read: async () => (await this.storage.get<PairingRecord>(KEY)) ?? null,
      write: async (rec) => {
        await this.storage.put(KEY, rec);
        await this.storage.setAlarm((rec.expira + 60) * 1000);
      },
      drop: async () => {
        await this.storage.deleteAll();
      },
    });
  }

  override async alarm(): Promise<void> {
    const rec = (await this.storage.get<PairingRecord>(KEY)) ?? null;
    if (rec && rec.expira + 60 > Math.floor(Date.now() / 1000)) {
      await this.storage.setAlarm((rec.expira + 60) * 1000);
      return;
    }
    await this.storage.deleteAll();
  }

  create(rec: PairingRecord) {
    return this.cell.create(rec);
  }
  claim(sub: string, now: number) {
    return this.cell.claim(sub, now);
  }
  approve(sub: string, auth: string, now: number) {
    return this.cell.approve(sub, auth, now);
  }
  status(bh: string, now: number) {
    return this.cell.status(bh, now);
  }
  retire(bh: string, now: number) {
    return this.cell.retire(bh, now);
  }
}
