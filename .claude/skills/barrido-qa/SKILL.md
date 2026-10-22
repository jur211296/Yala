---
name: barrido-qa
description: Barrido de QA de Yala — vaciar la cola «in qa» antes de una tanda de Jürgen probando en el simulador lo que se pueda y dejándole solo lo que pide su iPhone o su aprobación. Úsala al pedir un barrido de QA o preparar la tanda de Jürgen.
---

# Barrido de QA

El objetivo es que a Jürgen **solo le llegue lo que de verdad necesita su mano o su ojo**. Todo lo demás se cierra
en el barrido: con la evidencia que ya existía, o con la que el barrido produce.

El error que corrige esta skill (medido el 2026-10-15): los barridos del 10 y del 12 de octubre trabajaban sin
simulador y solo cerraban lo que ya traía pruebas. Así, lo que se podía probar en el simulador pero nadie había probado
se quedaba en la tanda de Jürgen. **Un barrido que no prueba nada no filtra nada.**

## 1. Inventario

1. `tablero listar --proyecto Yala --todas` → todas las cards en `in qa`.
2. `tickets/qa/` en `origin/<rama de release>`.
3. PRs mergeados desde el último barrido: `gh pr list --state merged --base <rama> --search "merged:>=AAAA-MM-DD"`.
4. Para cada item, anota **en qué build está su arreglo**: el último TestFlight (`asc` o la nota del encargo de
   subida) o solo `origin/<rama>`. Lo que no está en TestFlight se prueba en Yala Dev.

## 2. Decisión por item: el primer caso que encaje gana

| # | Caso | Destino |
|---|---|---|
| 1 | Es de **accesibilidad**: Dynamic Type, tamaños de texto, VoiceOver, contraste, Reducir movimiento | **done** sin probar. Jürgen confía en el código para esto. Motivo: «accesibilidad, criterio de Jürgen». |
| 2 | Es un **edge case imposible o muy difícil de provocar a mano**: techos de horas o días, fallos inyectados, carreras, kills en un instante preciso | **done** si lo fija un test unitario o de integración con su mutante muerto. Si no hay test, escríbelo: el barrido no lo deja a Jürgen. |
| 3 | **Ya hay evidencia**: un XCUITest del flujo real, un test de integración contra el código real, goldens, o capturas del antes y el después | **done**, citando el test o la ruta de la captura. |
| 4 | **Se puede probar en el simulador** | **Pruébalo tú en el barrido** (§3). Si pasa, **done** con la evidencia. Si falla, card de bug y el item sigue en qa. |
| 5 | Necesita **aprobación visual o de identidad** de Jürgen: un rediseño, copy nuevo, una pantalla que él no ha visto | **No va a la tanda del iPhone.** Haz las capturas en el simulador y mándaselas en un solo lote para que las apruebe. Queda en qa hasta que diga que sí. |
| 6 | Solo es posible en un **dispositivo real** (lista de §4) | **Se queda para Jürgen**, con guion (§5). |
| 7 | Es una **decisión** suya (card «Decidir …») | Si ya está tomada e implementada, **done**. Si no, se queda y se dice qué falta decidir. |

**El paso termina cuando cada item tiene destino, motivo y evidencia** (test, captura o la pasada de §3). Un item sin
evidencia no está decidido: vuelve a la tabla.

**Lo que toca dinero, migraciones o borrado de datos ya no se queda solo por eso.** Necesita evidencia fuerte, y esa
evidencia la produce el barrido: un test de integración o una pasada en el simulador con el antes y el después. Se queda
para Jürgen solo si además cae en §4.

## 3. Cómo se prueba en el simulador

- **Un simulador como máximo.** Antes de encender uno, mira si otra sesión lo está usando
  (`xcrun simctl list devices booted` y las sesiones vivas). Si está ocupado, espera; no lo apagues tú.
- Las herramientas y el arranque del simulador, como en `/qa`.
- Siembra con `DevSeed*` / `-uitest-*`. Nunca contra CloudKit de producción.
- Para cada item probado guarda: el paso, lo que se esperaba, lo que salió y la captura en `_capturas/<slug>/`.
- Si el flujo merece red permanente y es determinista, escribe el XCUITest en vez de conducirlo a mano.
- Al terminar: `xcrun simctl shutdown all` y borrar los simuladores que creaste.

## 4. Lo único que se queda para el iPhone de Jürgen

Solo esto, y cada item de la tanda dice cuál de estos motivos lo retiene:

- Cuenta real de **iCloud / CloudKit**: cambiar de Apple ID, apagar iCloud Drive, la importación real del espejo.
- **Inicio de sesión real** con Apple o Google, **Face ID**, **App Attest**.
- **Dos dispositivos físicos** (grupos, sincronización entre teléfonos).
- **Actualizar encima** de un build anterior de TestFlight.
- **Compras reales** con StoreKit en sandbox.
- **Notificaciones push**, Apple Pay, Atajos o widgets cuando el simulador no reproduce la integración.
- **App Store Connect**, legal o la ficha: van aparte, al final, sin iPhone.

Si dudas entre §4 y «se puede en el simulador», prueba en el simulador primero. Si el simulador no reproduce la parte
que importa, entonces sí se queda.

## 5. El guion de lo que se queda

Cada paso se **verifica contra el código antes de escribirlo**. El 15-oct una prueba pedía «un pago programado con
fecha de ayer», y el editor no permite fechas pasadas en un pago nuevo (`minDate: today`): el paso era imposible.

- Lenguaje de usuario, sin jerga. Rutas con los textos reales de la app (`es.lproj/Localizable.strings`).
- Solo pasos de función: la accesibilidad ya salió en §2.1.
- Por item: qué build usar, cuánto tarda, si bloquea el lanzamiento y por qué no se pudo cerrar en el barrido.
- Agrupa por **montaje**: el mismo estado del teléfono, una sola vez. Orden: lo que bloquea primero, luego Yala Dev
  contra staging, luego TestFlight, luego dos dispositivos, y al final lo que no pide iPhone.
- Datos de prueba ya preparados en `~/Claude/entregas/<slug>/` (CSV, PDFs, imágenes), y dicho cómo pasarlos al
  teléfono.

## 6. Cierre

1. Tickets cerrados: `git mv tickets/qa/X.md tickets/done/` con la línea
   «Cerrado en el barrido de QA AAAA-MM-DD: <motivo>». Tickets nuevos de QA, con su guion. `docs/TICKETS.md` al día.
2. Cards cerradas: `tablero mover <id> --a done --agente frank`. **`--nota` sustituye la nota entera**: léela antes con
   `tablero ver` y repite lo que había.
3. Escribe `docs/qa/tanda-qa-jurgen-<versión>.md` con:
   - resumen: revisados, cerrados, probados en el simulador, para capturas y para el iPhone, y el tiempo total;
   - la tabla de bloqueantes;
   - las pruebas por grupo;
   - **dos tablas al final:** lo que pasó a done (id, motivo y evidencia) **y lo que se queda (id y cuál de §4 o §5
     lo retiene)**. Sin esta segunda tabla no se puede auditar el barrido.
4. Las capturas de §2.5, en un solo envío a Jürgen.
5. PR a la rama de release y `/cerrar-total`. En MODO AUTÓNOMO, en cola de auto-merge.
6. En el aviso de cierre, di que la tanda está lista para `/qa-guiado`: esa sesión la lanza Jürgen cuando vaya a probar.

**Señal de que el barrido salió mal:** que en la tanda haya una prueba que se puede hacer entera en el simulador y no
toca nada de §4. Si al repasar la tanda encuentras una, vuelve a §3 con ella.
