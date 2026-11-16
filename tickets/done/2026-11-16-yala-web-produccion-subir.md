---
id: 2026-11-16-yala-web-produccion-subir
status: done
priority: high
area: web
created: 2026-11-16
updated: 2026-11-16
source: encargo 2026-11-16-yala-web-produccion-subir (Jürgen, 16-nov: «podemos ir subiéndolo y lo voy probando con mi cuenta personal»)
---
# Yala web en producción (app.yala-app.pe)

Sube a producción los lotes 0 a 3 de Yala web, escritura en Grupos incluida, sin enlazarla desde la web pública.
Continúa el PR del 15-nov, que lo dejó preparado y esperando decisiones; las decisiones son del lote del 15-nov.

## Qué quedó

- Supabase producción: `mcp0_01`–`03` (conector con id nulo) y los cuatro SQL de la web, ensayados antes dentro de
  producción en una transacción deshecha. Hook de token y servidor OAuth encendidos, cliente «Yala web», Apple y Google
  con sus clientes web, vuelta `https://app.yala-app.pe/auth/callback`.
- Worker `yala-web-production` en `https://app.yala-app.pe`, con Turnstile real (widget de Dan).
- Gateway de producción desplegado desde 2.3 con Grupos de la web encendido: Jürgen eligió quitar la condición del
  código que lo apagaba en producción (opción A, 16-nov).
- La marcha atrás de `web3_02` retira `web_member_ref` (fallo cazado por el ciclo de staging).

## Prueba

App de producción del iPhone 14 (test@yala-app.pe) renovó su sesión con el hook encendido y sigue sincronizada; login y
renovación reales con una cuenta desechable. Web en el Safari del iPhone 14: entrar con Google, mismo saldo que la app,
apuntar un borrador (en la cola de producción), Grupos en lectura; y con Apple (Face ID de Jürgen) la misma cuenta y
el mismo saldo. Detalle: `webapp/README.md`, sección «Producción», e informe `docs/web-app/produccion/index.html`.

## Queda fuera

- Que la app publicada recoja lo apuntado en la web: `ConnectedBrowsersConfig.baseURL` fuera de `DEV_BUILD` (2.3 del iPhone).
