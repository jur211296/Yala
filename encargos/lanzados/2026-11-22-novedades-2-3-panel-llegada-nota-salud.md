Yala
# Novedades 2.3 con el anuncio del iPhone Duo, Panel con llegada solo desde Primeros pasos y nota de salud «lo que te queda del mes»
---
toca: Yala/App/Views/WhatsNew/,Yala/App/Logic/WhatsNewLaunchLogic.swift,Yala/App/Views/Panel/Sheets/AccountDetailSheet.swift,Yala/App/Logic/Calculators/AccountDetailCalculator.swift,Yala/App/Views/Panel/PrimerosPasosPanelPresentations.swift,Yala/App/Logic/Calculators/FinancialScoreCalculator.swift,Yala/Resources/,YalaTests/NovedadesPanelNota/,tickets/backlog/2026-11-21-novedades-2-3-panel-llegada-nota-salud.md,tickets/done/2026-11-21-novedades-2-3-panel-llegada-nota-salud.md
esfuerzo: high
cierre: cierra-sola
---

Jürgen aprobó el 21-nov (08:39 Lima, decisión t1868-reconfirma) este lote de la auditoría `docs/auditorias/2026-11-21-decisiones-vs-2-3.md`. Decisiones:
- 118 (t1767u, 17-nov): «En 2.3 se anuncia la compatibilidad con iPhone Duo (ya soportada desde 2.2): novedades y notas de versión…».
- 137 y 117 (Panel): t1811u «Panel progresivo… al entrar solo se ven los Primeros pasos» y t1763u «La hoja de cuenta del Panel debe mostrar arriba la tarjeta personalizada de la cuenta… con monto y uso de línea».
- 30 (t1575u, nota de salud): lote 1 ya hecho; falta el lote 2, «lo que te queda del mes». Card existente: «Nota de salud · lo que te queda del mes» (reutiliza esa card, no la dupliques).
Antes de empezar verifica con `git log origin/2.3` y el código qué ya está hecho; las capturas del anuncio de Duo en App Store Connect las hace Dan, no tú.

## Qué hacer
1. Novedades 2.3 completas: todas las tarjetas de lo nuevo de 2.3 y la del iPhone Duo, en los 16 idiomas.
2. Panel: la llegada se hace solo desde Primeros pasos; la hoja de cuenta muestra arriba la tarjeta con monto y uso de línea.
3. Nota de salud lote 2: «lo que te queda del mes», con el tono amable del lote 1.
4. Pruebas nuevas en `YalaTests/NovedadesPanelNota/`.

## Criterios de aceptación
- Novedades muestra el anuncio de iPhone Duo y todo lo de 2.3 en los 16 idiomas.
- El Panel nuevo solo muestra Primeros pasos al entrar; la hoja de cuenta muestra el uso de línea.
- La nota de salud muestra lo que queda del mes sin desanimar.
- Capturas antes y después en iPhone y iPad.

## Cómo verificar y entregar
- Puedes usar un segundo simulador en la Max o el iPhone 14 por DeviceMCP.
- Capturas antes y después en el cierre.
- La entrega visual se hace como artifact de Claude.
- Trabajo solo en tu rama de encargo; no toques archivos que no estén en `toca:`.

Índices compartidos: `docs/TICKETS.md` y `qa/coverage-index.json` no van en `toca:`; edítalos solo al final, justo antes del PR, tras `git rebase origin/2.3`, resolviendo por fila o área sin pisar lo de otra sesión.

Termina con /cerrar-total cuando el PR esté dentro de 2.3.
## Cómo trabajar
- iPhone 14 (Jürgen, 19-nov): queda conectado a la Mini para cualquier sesión de cualquier máquina vía DeviceMCP. Antes de recurrir al simulador, verifica de verdad si está libre (que responda y que ninguna otra sesión lo esté usando en ese momento); no lo des por ocupado sin comprobarlo. Si lo usas, suéltalo al terminar.
- Textos nuevos en su propia tabla, nunca en Localizable.strings. Nunca un botón debajo de otro.
- En la Max puedes usar un segundo simulador además del de otra sesión, o el iPhone 14 por DeviceMCP; en la Mini, uno solo. No uses `-derivedDataPath /tmp/claude-*`.
- Nada en producción (ni CloudKit ni Supabase).
- Commit y PR sin firma de IA, contra 2.3. Deja el auto merge activado y no cierres hasta ver el PR dentro de 2.3. Si hay conflicto o el CI falla por tu PR, arréglalo tú. Si tras unos 45 minutos el CI sigue rojo por algo ajeno, cierra y anota el motivo.
- Lo menor y reversible se decide con la opción recomendada y se anota. Lo vital, según el modo fijado al arrancar: en semi (05:30–20:00) preguntas y esperas con la sesión viva; en nocturno (20:00–05:30) dejas un checkpoint recuperable y una card «Espera decisión» para Jürgen, sin cerrar como completo, sin mergear ni desplegar lo incompleto.
- Entregable del cierre: artifact visual de Claude (capturas antes y después y mediciones), nunca Markdown ni PDF.
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones (resueltas en autónomo, modo nocturno)

Medido en `origin/2.3` (70cc3e146):

- Novedades 2.3 solo trae «Tu nota de salud, más precisa»; nada del iPhone Duo.
- El Panel con el mazo a medias ya oculta cuentas, widgets, filtros y consejos (PR 1078), pero deja el saldo grande en
  cero sobre el mazo (aquel PR lo dejó «decidido sin consultar»).
- La hoja de cuenta ya abre con la tarjeta personalizada arriba (PR 1052). No tiene «% usado» de la línea: Yala no
  guarda el límite de la tarjeta (no hay campo en `Account`).
- La nota de salud tiene tres partes; la cuarta («lo que te queda») no existe. Card: `tablero-nota-de-salud-lo-que-te-queda-del-mes-dx0t`.

Decisiones:

1. **Novedades 2.3: ocho tarjetas**, solo de lo que la app publicada hace en producción: iPhone Duo, tarjetas
   personalizadas, Grupos (recibo con IA, saldar, traer de Splitwise/Tricount), Registros (filtros rápidos, calendario,
   hacer recurrente), gastos hormiga y «Ver proyectado», «Hoy puedes gastar» y suscripciones, el ojo para ocultar
   montos y la nota de salud (con la parte nueva). Fuera a propósito: Yala web y navegadores conectados (la fila solo
   existe en Yala Dev), Yala IA ampliada (0 % en producción), «Tu IA registra en Yala» (conector sin desplegar en
   producción), «Conectar Gmail» (retirado) y correo/atajo del banco (sin verificar en producción). Tabla propia
   `Novedades23.strings`, 16 idiomas.
2. **Panel, llegada:** con el mazo a medias y antes de que abra la cuenta, el saldo grande no sale: al entrar solo están
   los Primeros pasos. El saldo vuelve con la cuenta.
3. **Nota de salud, parte «Lo que te queda»:** (entró − salió) del período sobre lo que entró, con la regla del hero del
   Panel (`HeroBucketsCalculator`, sin filtros de sesión). 20 % o más → 100; de 0 a 20 % → de 50 a 100 en línea; gastar
   más de lo que entra baja de 50 con suelo de 30 (el de un presupuesto). Sin ingresos en el período no cuenta (no
   castiga el mes en que aún no llega el sueldo); en «Solo gastos», nunca. Pesos 32 · 28 · 20 · 20 (Presupuestos,
   Compromisos, Ritmo, Te queda): sin la parte nueva la nota es exactamente la de antes.
4. **«Uso de línea»: espera decisión de Jürgen.** Necesita guardar el límite de la tarjeta: campo nuevo en la cuenta
   (modelo, esquema de iCloud en producción, nube de Yala), fuera del `toca:`. En nocturno no se decide solo: card
   «Espera decisión» con opciones; el resto del lote queda listo en su rama.
5. Fuera de `toca:` pero imprescindible, y sin otra sesión viva que los toque (`turno_merge.py ver`): `PanelView.swift`,
   `FinancialScoreView.swift`, `FinancialScoreCopy.swift`, `FinancialScoreDetailSheet.swift`, `SaludFinanciera/*`,
   `PanelViewModel` e `InsightsViewModel` (solo el parámetro de «Solo gastos»).
