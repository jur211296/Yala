Yala
# Yala web: Grupos reconoce a los mismos miembros que la app, y la web en el móvil no se sale de la pantalla
---
toca: webapp/src/, webapp/test/, gateway/src/groups/, gateway/src/web/, gateway/test/, tickets/backlog/, tickets/done/
esfuerzo: high
cierre: cierra-sola
---

## Contexto
El barrido QA final de 2.3 (PR 985, `docs/qa/barrido-2-3-final/`, informe https://claude.ai/artifact/NcBeAxfFcFwg4i3aiuZf1a) encontró que la web y la app no reconocen a los mismos miembros en Grupos: saldo «Todo saldado» con deuda de 60, «Sin nombre», 4 personas en un grupo de 2, y el gasto de la web llega como «? pagó». Producción aún no tiene la web: hay que arreglarlo ANTES de encender Yala web en producción (Jürgen decidió el 15-nov encolar todos los bugs del barrido; Dan hace sus pasos de panel después de esto). También: la web en el móvil se sale por la derecha y corta importes (bug medio).

Las ramas y PR de producción (PR 984, en borrador) no se mergean aquí.

## Qué se pide
1. Encuentra la causa de las identidades distintas (web vs app: id de miembro, usuario de Supabase, columnas cifradas por el gateway) y arréglala. Prueba en staging de punta a punta: crear gasto en la web y verlo bien en la app del iPhone 14 por DeviceMCP, y al revés, con saldos correctos.
2. Arregla el desborde horizontal en el móvil (Safari del iPhone 14) en todas las páginas de la web.
3. Despliega solo en staging. Un PR a 2.3, mergeado si CI está verde. Cards a QA con evidencia.

## Entregable
Artifact visual corto de Claude: antes y después con capturas de la web y la app.

## Reglas
- Nada en producción (ni Supabase ni Workers ni gateway). Commits y PR sin firma de IA. No imprimas secretos.
- Si falta acceso a staging, pregunta; no lo inventes.
- Puedes usar un segundo simulador o el iPhone 14 por DeviceMCP.
- /cerrar-total al terminar.

## Paso 0 — decisiones (resueltas en semi, sin pregunta: todas menores y reversibles)

1. **Causa (medida en staging, no inferida).** La app no escribe la `member_key` en gastos, cuotas y pagos: escribe el id local del `SplitMember` (`SHA-256("SplitMemberBackend:<grupo>:<clave>")` → UUID en mayúsculas; namespace `SplitMember` para claves de la era iCloud). La web leía y escribía la clave cruda. Las 57 referencias vivas de grupos creados por la app resuelven por la forma derivada; ninguna por la cruda.
2. **Arreglo en la web, no en la app.** La app es lo publicado y su forma ya está en todos los grupos: se adapta la web. Leer: traducir cualquier referencia (forma de la app o clave cruda) a la `member_key` antes de calcular. Escribir: la forma de la app.
3. **Dónde vive la regla:** `shared-core` (la usan el Worker de la web y el gateway) + `public.web_member_ref` en la base, pinneada por un golden compartido con la app (`groups-parity.json`, test Swift y TS).
4. **La base solo acepta la forma de la app** al escribir desde la web (no también la cruda): aceptar la cruda dejaría reabrir el bug.
5. **SQL editado en sitio en `web3_02`** (no un `web3_03`): el generador de producción del PR de la salida a producción lee ese fichero, así que el arreglo viaja solo. En staging se aplica solo la función cambiada.
6. **Filas ya rotas en staging:** el gasto de la web del barrido ya está borrado desde el iPhone; no se migra nada.
7. **Desborde:** CSS de la web a 390 pt en todas las páginas; sin rediseñar.
8. **«Automatización» como origen del borrador web en la Bandeja:** es de diseño (README lote 1) y fuera de este encargo: se anota, no se toca.
9. **Sesión de producción (PR en borrador) toca `webapp/src/worker/config.ts`:** no lo toco; no espero (su sesión ya no está viva).
