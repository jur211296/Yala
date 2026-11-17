Yala
# Actualizar la guía de novedades 2.3 para recorrerla como usuario nuevo o antiguo
---
toca: docs/guias/novedades-2-3/
esfuerzo: medium
cierre: cierra-sola
---

## Pedido de Jürgen (16-nov, 15:59 Lima)
«una sesion que actualice el artifact de novedades 2.3 para probar como usuario nuevo o antiguo». La guía existe desde el 15-nov, con la fuente en `docs/guias/novedades-2-3/` (`inventario.json`, `armar_datos.py`, `plantilla.html`, `README.md`). Desde entonces entró mucho en 2.3: tarjetas de cuentas personalizables, la ficha de una cuenta con las gráficas, importar desde Splitwise y Tricount si ya se mergeó, el video de verificación y otros. Además va a salir la build 2.3 (2) a TestFlight.

## Qué se pide
1. Actualiza el inventario con TODO lo que cambió entre la 2.2 publicada en el App Store y lo último de `2.3`. Usa como fuentes `git log` y los PR mergeados desde el corte de 2.2, las cards done e in qa de 2.3 (`tablero listar --proyecto yala --version 2.3`) y tickets/done. Nada se omite por pequeño y no se inventa nada que no esté en el código.
2. Mantén las dos rutas: **usuario nuevo**, desde la instalación, con la bienvenida, la cuenta y los primeros pasos, y **usuario antiguo**, que actualiza desde 2.2. Para cada ruta, un recorrido guiado en orden.
3. Marca qué hay en qué build: la 2.3 (1), la 2.3 (2) si ya subió cuando trabajes, o «todavía no en TestFlight». Para cada función activable, indica si ya se prueba en producción con su teléfono y cómo activarla, o por qué todavía no.
4. Marca lo nuevo desde la versión anterior de la guía, para que Jürgen vea primero lo que no revisó.
5. Conserva lo que ya tenía: filtros por sección y estado, «me gusta / mejorar / bug» con comentario y exportar los comentarios en un bloque.
6. Explica en una línea cómo probar como usuario nuevo sin perder sus datos reales. Por ejemplo, otro Apple ID, el simulador o el iPhone 14 de pruebas. No le pidas borrar su app.

## Entrega
- Artifact visual de Claude, no Markdown ni PDF, en español neutro latinoamericano y pensado para el teléfono. El link va en el cierre.
- Si cambias la fuente, abre un PR chico a 2.3, sin firma de IA. Es de solo lectura para el código de la app, el tablero, CloudKit y Supabase.
- Para confirmar algo en la app, en la Max puedes usar un segundo simulador, además del de otra sesión, o el iPhone 14 por DeviceMCP.
- Lo menor y reversible se decide y se anota en «Decidido sin consultar». El cierre conserva las secciones «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada una con motivo o «Nada».
- Cierre según el modo fijado al arrancar. En semi, si queda completo, `/cerrar-total`.

## Paso 0 — decisiones (resueltas en semi, sin consultar)

1. **Corte de cada build, medido.** 2.3 (1) = merge del barrido final (`a64a2bafb`, como dice el README). 2.3 (2) = base del PR del número de build: el merge de Yala web en producción, que es la punta de `2.3` hoy. Subida a TestFlight a las 16:30 (cuerpo del PR del build).
2. **Lo que está en cola de auto-merge** (importar de Splitwise/Tricount, captura de Grupos como personal, filtros rápidos de Registros) va como «todavía no en TestFlight».
3. **Mismos ids** que la guía del 15-nov: el artifact se actualiza en su URL y las notas que Jürgen deje siguen pegadas a su ítem. Los PR que antes estaban «fuera» conservan su id.
4. **Nuevo en la guía** = ítem nuevo o que cambió de estado/texto respecto al 15-nov. Sale primero (filtro por defecto).
5. **Estado en producción re-medido hoy:** `/config` del gateway (Otra cuenta de Apple 0 %), conector de IA de producción inexistente (Cloudflare 1042), Yala web 200 en app.yala-app.pe. El cupo de Grupos se da por desplegado porque el gateway de producción salió hoy desde 2.3 (deducido, se dice así).
6. **Sin simulador ni iPhone:** todo sale de PR mergeados y de la medición; no hace falta abrir la app para inventariar.
7. **La decisión pendiente «Yala web debe parecerse a Yala móvil»** ya la registra el PR del build 2.3 (2) en `docs/DECISIONS.md`; no se duplica aquí.
8. **Fuente:** `actualizar_2026_11_16.py` aplica el delta sobre `inventario.json`; `construir.py` arma la página con las capturas sacadas del artifact publicado (no se guardan en el repo).
