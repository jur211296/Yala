# Barrido de QA de la 2.3 antes de la build 8 (24-nov-2026)

Base: `origin/2.3` en `472b7d780` (con Pagos planificados, Éxito de Grupos y Bandeja, Avisos y Correos del banco y
Hacer recurrente ya mergeados). El PR de «Estadísticas › Resumen: opción B · Decidir» seguía abierto, con el CI en
curso y auto-merge puesto: no entra en este recorrido. Lista base: los barridos de la build 7, final, post-flujo y el del
iPhone del 14-nov.

Evidencia (capturas y vídeo): `~/Claude/entregas/2026-11-24-barrido-qa-2-3-antes-build-8/evidencia/` (`iphone14/`,
`ipad/`, `duo/`).

## Cómo se probó

- **iPhone 14 real** (iOS 27.2.1, por cable a la Max, Device MCP). Yala Dev de `472b7d780`, primero en Debug y luego en
  `Release-Dev` con `DEBUG` (la semilla solo existe con `DEBUG`), que es lo más parecido a la build 8. Semillas
  `realista` y `pesado` (diez años de datos).
- **iPad Pro 13** simulado (iOS 27.2): las 8 pantallas principales en oscuro, claro y texto al máximo.
- **iPhone Duo** simulado, cerrado: las 8 pantallas en oscuro. Abierto no: la postura se cambia con clics en Device Hub
  sobre la pantalla de la Max.
- **Interfaz automática:** `ExitoGruposBandejaCapturasUITests` (gasto de grupo y aprobar varios en la Bandeja) en el
  iPhone 17 Pro simulado, porque Grupos pide sesión de nube y en el iPhone no la había.

## Lo nuevo desde la build 7, en el iPhone 14

| Qué | Resultado | Evidencia |
|---|---|---|
| Estadísticas: cambiar de chip y el scroll (fluidez) | Bien. Con unas tres veces la semilla `pesado` y la build optimizada, volver a Tendencias, Distribución o Resumen enseña las tarjetas ya en la captura inmediata al toque (3 de 3). El scroll largo responde. La primera visita a cada pestaña tarda 4-9 s con el esqueleto, como dice el ticket. «Mes pasado» llega a las tres pestañas | `iphone14/26-…`, `27-…` |
| Reportes: la parte de arriba sin rebote (Comparativa y Flujo de caja) | Bien con gesto sintético: dedo quieto 4 s en el umbral, sin vaivén; bajar al final y subir de golpe, un solo movimiento. El temblor del dedo de Jürgen no se reproduce con toques sintéticos | `iphone14/04-reportes-sin-rebote.mp4` |
| Hacer recurrente: hoja sólida y copia de campos | Bien. Fondo sólido, resumen del registro (Netflix, S/ 45, cuenta · categoría › subcategoría), tres frecuencias en una tarjeta. «Cada mes» guarda y el éxito dice «Mensual». Sin cuenta elegida no abre: marca lo que falta (a propósito) | `05-…`, `25-…` |
| Selector de cuenta por moneda | Bien: con un monto en soles solo salen las cuentas en soles | `21-…` |
| Registros: filtro de categoría a pantalla completa | Bien: al tocar Alimentación la hoja sube y baja hasta sus 4 subcategorías | `18-…` |
| Pagos planificados: vista recordada e ícono sin logo | Bien: «Línea de tiempo» se recuerda tras cerrar y abrir la app; los pagos sin logo llevan su ícono | `20-…` |
| Bandeja: éxito de aprobar uno | Bien: «Gasto guardado», nota sobre el monto, tarjeta y «Guardar el siguiente» junto a «Aceptar»; «Guardar el siguiente» abre el siguiente borrador | `06-…` |
| Grupos y Bandeja: éxito de un gasto de grupo y de aprobar varios | En el simulador, con su XCUITest de capturas (ver abajo) | `exito.xcresult` |
| Nuevo presupuesto: «¿Cuáles?» con subcategorías | Bien en claro: al elegir Alimentación salen sus subcategorías para quitar | `22-…` |
| Sankey: «Ver subcategorías +» | Bien: despliega la columna de subcategorías y «Ver menos» vuelve | `19-…` |
| Avisos del banco | Lista, ejemplo, «Aún no está activo», «Ya lo configuré» → Activos, aviso de ejemplo y «Quitar de Activos» bien. **La guía de Atajos no casa con iOS 27.2** (hallazgo 1) | `15-…`, `23-…`, `24-…`, `10-…` a `14-…` |
| Esto leí (aire de la tarjeta) y Correos del banco | No se recorrieron en el iPhone: piden una foto y una cuenta de Yala con sesión. Sus PR traen capturas antes y después del simulador | — |

## Cifras que tienen que coincidir

| Comprobación | Resultado |
|---|---|
| Panel = curva de Saldo = Flujo de caja «Tienes hoy» (datos pesados) | S/ 650,694.60 en las tres |
| Panel = widget «Saldo» de inicio (semilla `realista`) | S/ 70,038.89 y S/ 70,039 (el widget redondea) |
| Panel = Estadísticas «Tu dinero hoy» = Registros (iPad, Duo y iPhone) | S/ 72,980.60 / S/ 70,038.89 según la semilla, igual en cada pantalla |
| Comparativa de octubre = Estadísticas › Mes pasado | Ingresos S/ 25,061.04 y gastos S/ 16,962.00 en las dos |
| Tras guardar Netflix S/ 45 | El saldo baja de 70,126.39 a 70,081.39 en Estadísticas |

## Hallazgos

1. **Avisos del banco: la guía de Atajos describe iOS 26, no iOS 27.2.** «Automatización» es una fila de Biblioteca, el
   «+» está abajo al centro y abre «Nuevo atajo»; el disparador se elige en la pestaña «Automatización» de la hoja de
   acciones y queda en línea; no existen «Ejecutar inmediatamente», «Siguiente», «Nueva automatización en blanco» ni
   «Agregar acción». Para borrar, pulsación larga. → card `zyaf`, prioridad alta, cierre autónomo.
2. **Panel: tocar «Ver detalle ›» oculta los montos en vez de abrir Estadísticas** (3 de 3). Igual en la build 7, y el
   ojo está desde la 2.2 publicada: no es regresión. → card `j9mb`, prioridad alta, cierre autónomo.
3. **Con texto de accesibilidad, la cifra grande de Estadísticas, Registros y «Te falta pagar» sale más pequeña que sus
   líneas de debajo** (iPhone 14 e iPad). El Panel sí la agranda. Accesibilidad: no se abre card, va al backlog del pase
   de estrés. → `tickets/backlog/2026-11-24-cifra-del-hero-pequena-con-texto-de-accesibilidad.md`.
4. **Con escrituras seguidas en el almacén, el saldo grande del Panel no sale**: mientras la semilla pesada escribía
   (minutos), el Panel enseñaba todo menos el saldo grande; al parar, salió a los 46 s (en Release, con ~3 veces
   `pesado`). Cada guardado reinicia su cálculo por tramos. Un import grande de la nube podría hacerlo igual
   (inferido, sin medir con la nube). Va en «Encontrado».
5. **`-uitest-reset` sobre un almacén de diez años pasa del límite de 20 s del arranque** y iOS cierra Yala Dev (tres
   veces). Solo afecta al gancho de pruebas. El almacén de pruebas vive en el grupo de apps y sobrevive a desinstalar;
   se vació copiando ficheros vacíos con `devicectl device copy to`. Va en «Encontrado».
6. **Cambiar de período en Estadísticas con datos pesados deja unos segundos el ingreso y el gasto del período
   anterior bajo el rótulo nuevo** (sin esqueleto). Con datos normales no se ve. Va en «Encontrado».

## Lo que no se pudo

- **iPhone girado**: el iPhone 14 no giró (bloqueo de rotación o de pie: es un ajuste del sistema). Lo girado lo cubren
  `ExitoGruposBandejaCapturasUITests`, `PagosChipsVistaCapturasUITests` e `IPhoneLandscapeUITests`.
- **Tamaño SE**: no se cambió el «Zoom de pantalla» del iPhone 14 (ajuste del sistema que reinicia la pantalla). El SE
  se miró en el simulador en el barrido de la build 7.
- **Duo abierto**: necesita Device Hub con la pantalla de la Max.
- **Suite completa de interfaz**: no se corrió en local (tope de 30 min); vale la nocturna.
