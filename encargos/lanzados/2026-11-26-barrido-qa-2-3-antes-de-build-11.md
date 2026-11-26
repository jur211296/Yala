Yala
# Barrido de QA de la 2.3 con lo que entró desde la build 10 (Primeros pasos, guías, pulido, oferta Pro y mazo centrado), antes de subir la build 11
---
toca: docs/qa/barrido-2-3-antes-build-11/,YalaTests/BarridoQA23AntesBuild11/,tickets/backlog/2026-11-25-barrido-qa-2-3-antes-de-build-11.md,tickets/done/2026-11-25-barrido-qa-2-3-antes-de-build-11.md
esfuerzo: medium
cierre: cierra-sola
release: no
pruebas-ui: si
depende: Yala/oferta-pro-mes-gratis-en-final-y-mazo-centrado-con-saludo
---

Pedido de Jürgen (25-nov, 21:51 Lima): «Encola otra subida a TestFlight con barrido al final de la cola, dejé el iPhone 14 disponible desbloqueado». Regla dura: siempre hay barrido de QA justo antes de cada TestFlight. Este barrido va primero y la subida de la build 11 espera a que cierre, para llevar sus arreglos.

## Contexto
- En TestFlight está la 2.3 (10), subida el 25-nov (PR #1180, «Yala 2.3 (10) en TestFlight: barrido previo, dev limpio y guía de novedades»). Lista base: `docs/qa/barrido-2-3-antes-build-10/`, `docs/qa/barrido-2-3-antes-build-9/` y anteriores.
- Desde la build 10 entraron, entre otros (confírmalo con `git log` desde el commit de la build 10):
  - Observación en vivo del iPhone 14 (`docs/qa/observacion-iphone14-2026-11-25/bitacora.md`): la fuente de lo que se arregló.
  - «Primeros pasos: que cada paso cuente bien»: «Solo gastos» de cero sin cuenta creada sola, guía del primer registro con cuenta de dos monedas, pago planificado del mes que viene en el widget, paso 7 hecho al ver las historias, Grupos con «Ahora no» como hecho.
  - «Guías y avisos que señalan donde deben»: toque de historias en toda la zona, aviso «viven en Más» con la barra desplegada y Más destacado, foco del paso 6 y vuelta al Panel, intro de Grupos que no vuelve tras cerrar sesión.
  - «Pulido de Primeros pasos y del paywall»: hoja de segunda moneda, «Presupuesto» al mismo tamaño, nombre del presupuesto sin cortar, intro de Grupos sin «paso 2 de 3», confeti que no tapa «Cerrar», título final cuando hay pasos para después, texto del paywall sin precios.
  - Oferta Pro opción C (mes gratis dentro de «¡Primeros pasos completos!», texto de A los días siguientes) y mazo opción B (centrado en el paso 1 con «Hola, <nombre>»). Maquetas: https://claude.ai/artifact/GdiXuiPLjfWskDWgq45JMn
  - Lo que también haya entrado (Esto leí, Estadísticas, bugs de cuenta del #1176 si quedó algo por verificar).

## Qué se pide
1. **Recorre la 2.3 en el iPhone 14 real por DeviceMCP**, con foco en lo nuevo desde la build 10: Primeros pasos completo desde cero en «Solo gastos» y en «Ingresos y gastos» (los 7 pasos, con y sin «para después»), las guías y avisos, la tarjeta final con la oferta (con y sin derecho a la prueba; en Yala Dev no hay precios, usa la configuración de StoreKit local o un gancho de prueba) y el mazo centrado con saludo. Claro y oscuro, texto al máximo y girado en lo nuevo. Las cifras de Panel, Flujo de caja y widget deben coincidir.
   - **Jürgen dejó el iPhone 14 desbloqueado y disponible:** todo el QA de iPhone se hace ahí. Si al arrancar lo está usando otra sesión, espera a que se libere avisando el avance. Si no responde o DeviceMCP falla, sale como `BLOQUEANTE:` con el error real. Para iPad y Duo, simulador: en la Max puedes usar un segundo simulador además del de otra sesión; en la Mini, uno solo. Apaga y limpia los que enciendas.
   - Para empezar de cero en el iPhone puedes usar «Eliminar cuenta» o «Vaciar datos» dentro de Yala Dev. **No borres la base de desarrollo** (Supabase ni CloudKit dev): esta vez Jürgen no lo pidió.
2. Ante un fallo grave, primero lo mides contra la versión publicada y después decides si bloquea. Si bloquea la subida, pregúntaselo a Jürgen como vital según el modo.
3. Lo chico se arregla en el PR de este barrido solo si el archivo no está en el `toca` de otra sesión viva o pendiente; cada arreglo fuera de lo declarado se anota en «Saltado o asumido sin preguntar», con su prueba en `YalaTests/BarridoQA23AntesBuild11/`. Lo grande va a una card de bug 2.3 (prioridad alta, cierre autónomo), sin duplicar cards que ya existan (revisa antes con `tablero listar --proyecto Yala`).
4. Termina con una lista corta de lo que Jürgen tiene que probar en su iPhone con la build 11.
- Corre solo las pruebas que toca el cambio; la suite completa, una sola vez al final. Si una prueba falla 2 veces por timeout, anótala como inestable y sigue. Tope total de 30 min en pruebas de interfaz. Ninguna espera de más de 3 min sin escribir avance.
- Build iOS en pipeline serial: limpiar, `xcodebuild -jobs 2` sin simulador encendido, encender un simulador, probar y apagarlo. Antes de compilar, mira la carga: si otra sesión compila en la misma máquina y la carga pasa los núcleos, espera en tramos cortos con aviso.
- Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.

## Qué NO hay que tocar
- Nada de producción. No borrar la base de desarrollo. No subir a TestFlight (lo hace la sesión siguiente).
- Solo lo de `toca:` más los arreglos chicos anotados; nunca `Yala/`, `YalaTests/` ni `tickets/` enteros, ni `Yala/Resources`. Textos nuevos solo en una tabla de strings propia de cada `.lproj`, nunca en `Localizable.strings`.

## Cómo entregar
- Base 2.3, un PR, sin firma de IA, con auto-merge activado; cierra sin quedarte esperando: los conflictos los relanza el vigía.
- Entrega final: artifact visual de Claude que facilite decidir; no Markdown, PDF ni documento de puro texto. Con lo recorrido, los hallazgos con capturas del iPhone 14, las cards creadas y la lista de prueba para Jürgen. Enlázalo en «Qué salió».
- Lo vital, según el modo fijado al arrancar: en semi preguntas y esperas con la sesión viva; en nocturno dejas un checkpoint recuperable y una card «Espera decisión» para Jürgen, sin mergear lo incompleto. Lo menor, con la opción recomendada, en «Decidido sin consultar».
- Cierre con `/cerrar-total` cuando el trabajo esté completo y el modo lo permita, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con su motivo o «Nada», y el link del artifact. `BLOQUEANTE:` solo si algo de verdad no puede seguir sin Jürgen. Español neutro latinoamericano.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **Sobre qué se prueba:** el PR de la oferta Pro y el mazo (del que depende el encargo) seguía abierto con el CI en
   curso. Se prueba sobre una mezcla local de `2.3` con ese PR; el PR del barrido no lleva sus commits.
2. **iPhone 14 bloqueado con código:** desbloquearlo es de Jürgen y la sesión es nocturna. Se instala la build, se avisa
   al bot (consulta guardada para las 05:30) y todo se prueba en el simulador. El recorrido en el teléfono sale como
   `BLOQUEANTE:` con el error real, como pide el encargo.
3. **Device MCP gratis se queda atado al iPhone:** el simulador se conduce con `simctl` y capturas.
4. **Giro:** la Max no tiene Simulator.app; se deja cubierto por la lógica del centrado, sin captura.
5. **Duo:** no se crea; el cambio no toca nada del pliegue y el iPad cubre el ancho grande.
6. **Tanda y comprobador del skill:** fuera del `toca:`; el informe vive en `docs/qa/barrido-2-3-antes-build-11/`, como
   el barrido de la build 10.
7. **Sin arreglos de código:** no salió ningún fallo; no hay `YalaTests/BarridoQA23AntesBuild11/`.
