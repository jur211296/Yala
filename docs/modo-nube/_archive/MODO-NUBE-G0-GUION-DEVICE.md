---
created: 2026-07-14
updated: 2026-07-14
tags: [modo-nube, grupos, backend, g0, spike, device-qa]
---

# G0 — Guion device: prueba live de APNs (Spike A paso 7) + matriz de entrega del silent push (Spike C)

Corrida del owner sobre **iPhone físico** (el token de simulador NO vale contra el APNs real; el sim solo acepta `xcrun simctl push`). Diseño: [[MODO-NUBE-GRUPOS-BACKEND-V1-DISENO]] §7 y §11 (G0); plan de implementación en `~/.claude/plans/validated-twirling-goblet.md`.

## Prerequisitos

- [ ] **APNs Auth Key creada** (Apple Developer portal → Certificates → Keys → Apple Push Notifications service). Anotar el **Key ID** (10 chars). Una sola key sirve sandbox y producción.
- [ ] Secret cargado y var configurada (desde `gateway/`):
  ```sh
  npx wrangler secret put APNS_AUTH_KEY < AuthKey_<KEYID>.p8   # SIN --env (staging es el default)
  # + editar wrangler.toml [vars]: APNS_KEY_ID = "<KEYID>"  → npm run deploy:staging
  ```
- [ ] Build **Yala Dev por Xcode** en el iPhone (la env var `YALA_DEV_SHARED_SECRET` del scheme es necesaria para el botón del panel; sin Xcode el panel degrada con mensaje y se usa curl con el token copiado).
- [ ] Console.app conectada al device con filtro `subsystem:com.yala category:Push` — **streaming ANTES de reproducir** (Console no muestra logs retroactivos).

## Fase A — Prueba live (LA incógnita HTTP/2, paso 7 del plan)

1. [ ] Abrir Yala Dev → Perfil → Almacenamiento → "Modo Nube · Auth" (panel DEBUG) → card **Push (spike G0)**: el token APNs aparece (`PUSH TOKEN_OK` en Console al boot). Copiarlo si hará falta curl.
2. [ ] Tocar **"Enviar push de prueba (staging)"**.
   - **Veredicto POSITIVO:** `lastMessage` muestra `HTTP 200` con `"delivered":true` y `apnsId` → el fetch de Workers negoció el transporte con APNs. **G8 construye sobre esto.**
   - **Veredicto NEGATIVO:** `"transportError":"..."` → el fetch NO negoció (probable ALPN/HTTP-2) → anotar el error EXACTO y parar: la decisión de pivote (proxy HTTP/2 / proveedor push) se toma ANTES de G8, con esta evidencia.
   - Si `"reason":"BadDeviceToken"`: verificar que el build es Debug (aps-environment=development ⇒ sandbox=true, que es el default del botón).
3. [ ] Con la app en background (ir al Home): repetir el envío vía curl desde la Mac:
   ```sh
   curl -s -X POST https://yala-gateway-staging.misty-surf-6866.workers.dev/v1/debug/push \
     -H "content-type: application/json" -H "X-Yala-Dev-Secret: $YALA_DEV_SHARED_SECRET" \
     -d '{"deviceToken":"<token copiado>","sandbox":true}'
   ```
   → en Console debe aparecer `PUSH RECEIVED kind=yala(g0-spike)`.
4. [ ] **Regresión CK (gate 7c):** en el panel de Grupos forzar un sync (o crear un gasto en un grupo desde otro device) → los breadcrumbs de `SplitSync*`/CloudSync siguen fluyendo normal y, si llega push de CloudKit al handler, se loggea `PUSH RECEIVED kind=cloudkit` SIN efectos raros. El engine NO debe degradarse.

## Fase C — Matriz de entrega del silent push (Spike C)

N=5 pushes por celda, espaciados ≥1 min (APNs colapsa/throttlea background pushes — es un RESULTADO a documentar, no un bug). Anotar entregas (¿llegó `PUSH RECEIVED kind=yala`?) y latencia aproximada (timestamp del curl vs timestamp del breadcrumb).

| Estado de la app | Entregados /5 | Latencia típica | Notas |
|---|---|---|---|
| Foreground | | | |
| Background reciente (<1 min) | | | |
| Suspendida (horas) | | | |
| **Killed por swipe** | | | iOS NO entrega content-available a apps matadas por el usuario — se documenta como límite de plataforma (igual aplica a CloudKit hoy) |
| Low Power Mode ON | | | |
| Focus / No molestar | | | |

**Entregable:** tabla rellenada + veredicto en [[MODO-NUBE-GRUPOS-BACKEND-V1-DISENO]] §7 — ¿la entrega en background basta para las notifs de grupo de v1, o se adelanta la evaluación de push visible (NSE)?

## Cierre de G0

- [ ] Veredicto Spike A (HTTP/2) anotado en el diseño §7 / plan G8.
- [ ] Veredicto Spike B (`bash qa/cloud/pgcrypto-spike-test.sh` todo PASS + auditoría manual de logs) anotado en §3/§8/R2. Cleanup: aplicar `qa/cloud/g0_pgcrypto_spike_cleanup.sql` en staging.
- [ ] Matriz de la Fase C rellenada.
- [ ] `groups-backend-v1.md`: marcar G0 cerrado → `/spec` de G1.
