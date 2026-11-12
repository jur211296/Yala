# Pasar de app completa a solo grupos — implementación

Card `tablero-pasar-de-la-app-completa-a-solo-grupos-s-p0iu`. Versión 2.2. Base `origin/2.2`.
Lienzo con el diseño elegido: https://claude.ai/artifact/8BR6F2UisLqa81vyfaa8EZ

## Decisiones de Jürgen (2026-10-26)
1. **Entrada A.** Fila «Cómo usas Yala» en Preferencias de Ajustes (subtítulo con el modo actual) → pantalla con dos tarjetas: «Yala completo» / «Solo grupos». La fila sigue en Preferencias también en solo grupos.
2. **Ida**: hoja de confirmación «¿Usar Yala solo para grupos?» (textos del lienzo). **Se pausan recordatorios y pagos programados** mientras dure solo grupos; se reactivan al volver. Línea de Pro solo para quien tiene Pro.
3. **Vuelta**, tal como se recomendó:
   - Botón destacado de Ajustes en solo grupos: «Volver a Yala completo · Tus cuentas y registros te esperan» para quien ya tuvo la app completa; quien nunca la tuvo sigue con «Activar Yala completo».
   - **Sin registros** → sin pregunta, directo al Panel con aviso «Ya tienes Yala completo de nuevo». Cuentas y presupuestos vacíos se conservan.
   - **Con registros** → hoja «Tienes N movimientos guardados» (rango de fechas y nº de cuentas): «Seguir donde lo dejé» (por defecto) / «Empezar de cero» + «Exportar una copia antes».
   - «Empezar de cero» → segunda confirmación «¿Seguro? Esto es definitivo.» con el recuento → solo el paso «¿Cuál es tu cuenta principal?» con nombre y divisa de antes. No se repite la bienvenida.

## Nota técnica (medida en el código el 2026-10-26)
Hoy solo grupos = `!SessionState.shared.hasPrivateSession` (`ShellModeLogic.effective`). La ida NO puede apagar la sesión privada (eso arma el mount neutro y el bridge de solo-grupos): hace falta un estado de **vista** solo-grupos sobre una sesión privada viva, que alimente los gates de shell/visibilidad (`ShellModeLogic`, `GroupsOnlyVisibilityPolicy`, `ProfileView.isGroupsOnlyShell` / `isGroupsFocusedShell`) sin tocar los gates de datos. La vuelta no pasa por `FullModeActivationFlowLogic`. Merece review adversarial (sync, notificaciones, borrado).

## Cómo se sabe que está bien
Ida y vuelta en el simulador sin perder datos ni repetir la bienvenida; los tres casos de vuelta con capturas; recordatorios pausados y reactivados; gate verde; PR a 2.2.


## Cierre
Cierre autónomo: al terminar, cierra con `/cerrar-total` (card cierra-sola).

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Qué es «solo grupos» cuando ya tienes Yala completo?** → Un estado de VISTA propio del teléfono (`GroupsOnlyViewMark`, UserDefaults local, sin iCloud-KV), con espejo observable en `SessionState.prefersGroupsOnlyView`. La shell es solo grupos si no hay sesión privada **o** si esta marca está puesta. La marca muere con la sesión privada (`PrivateSessionMark.set(false)` / `clear()`): cerrar sesión o «Vaciar datos» no la dejan colgando para la siguiente persona.
Por qué: apagar la sesión privada arma el montaje neutro y el bridge de solo-grupos (nota técnica). Alternativa descartada: sincronizar la marca entre dispositivos — cada teléfono elige cómo se ve.

**D2 · ¿Qué gates pasan a leer el modo efectivo?** → Solo los de SHELL/visibilidad: `ShellModeLogic`, `SessionState.isGroupsFocusedShell`, `ProfileView`, `MoreView`, `ContentView.reduceToGroupsOnly`, Temas y Notificaciones de Ajustes, el widget (`publishSessionShell`) y la hoja de quien vuelve (Novedades/prueba Pro). Los de DATOS (bridge, borrados, cierre de sesión, la cuenta de los formularios de grupo) siguen leyendo el eje.
Por qué: el encargo lo pide así y es lo que hace la ida reversible sin tocar sync. Consecuencia asumida: en solo grupos los gastos de grupo **siguen llegando a tus registros** como hasta ahora, y están ahí al volver.

**D3 · ¿Cómo se pausan recordatorios y pagos programados?** → Con una puerta local leída por cada productor, **sin tocar `NotificationItem.isActive`** (esa fila viaja a los demás dispositivos del Apple ID, que siguen en completo). Pausa: recordatorios (fin del día, almuerzo, personalizados), informes, avisos y resúmenes de pagos programados y de tarjeta, alertas de presupuesto **personal**, y la creación de borradores de pagos programados. No se pausan los avisos de grupos (cambios, liquidaciones, presupuesto de grupo). Al entrar se retira lo pendiente que no es de grupos; al volver se reprograma y se procesan los pagos vencidos.
Por qué: «avisarían de pantallas que no ves» (lienzo). Alternativa descartada: apagar `isActive` — apagaría también el iPad que sigue en completo. Asumido: «recordatorios» incluye informes y alertas de presupuesto personal, por la misma razón.

**D4 · ¿Por dónde entra la vuelta?** → Por el mismo intent `.presentFullModeActivation`, y la misma hoja: con sesión privada viva y la marca puesta, la hoja enseña la vuelta en vez de la activación. Así la cubren a la vez Ajustes, Más, el widget, Siri/Centro de Control y el enlace `activate-full`, y hereda su sitio en la matriz de presentaciones y la absorción del borrado deliberado (`isShowingFullModeActivation`).
Por qué: una presentación nueva del ancla de `ContentView` es la trampa medida de `swiftui-ds.md`. La lógica de la vuelta no pasa por `FullModeActivationFlowLogic`.

**D5 · ¿Qué cuenta como «movimientos guardados»?** → Registros personales que no vienen de un grupo (`splitExpenseID`/`splitSettlementID` nulos) y no son ajuste de saldo. Cuentas: no de sistema y no líneas de tarjeta. Presupuestos: todos.
Por qué: lo puenteado vuelve solo tras el borrado (convergencia), y un saldo inicial no es un registro; contarlos haría preguntar a quien no tiene nada que perder.

**D6 · ¿Cómo borra «Empezar de cero»?** → `wipePersonalDataKeepingGroups` con un parámetro nuevo que conserva preferencias (nombre, divisa, tema, onboarding hecho) y resiembra categorías; **no** avisa al resto del Apple ID (ver D14). **El borrado ocurre al tocar «Empezar» en el paso de cuenta**, y la cuenta se crea en la misma vuelta del main actor.
Por qué: un kill entre «¿Seguro?» y la cuenta no deja una sesión sin cuentas; antes de «Empezar» no se ha borrado nada.

**D7 · ¿Cómo se presenta la doble confirmación?** → La hoja de la vuelta tiene fases (elegir → cuenta principal → borrando); el «¿Seguro? Esto es definitivo.» es un `.alert` colgado de la hoja, no de `ContentView`.
Por qué: el molde hoja → alerta de `UserDataResetView`, con contenedores distintos.

**D8 · Prefill de la cuenta principal** → La cuenta propia con más registros (ni de Grupos ni línea de tarjeta; no archivada si la hay; a igualdad, por nombre): su nombre, divisa, tipo e icono.
Por qué: `Account` no guarda fecha de alta, así que «la más antigua» no se puede medir; la más usada es la mejor señal de «principal».

**D9 · Aviso al volver** → El toast positivo de `ContentView` con «Ya tienes Yala completo de nuevo», en los tres desenlaces (sin registros, seguir, empezar de cero).

**D10 · Ida** → Desde «Cómo usas Yala» › «Solo grupos»: hoja con los textos del lienzo; la línea Pro solo con Pro. Al confirmar: marca, pausa, cerrar Ajustes y todas las ventanas a Grupos.

**D11 · Quien nunca tuvo Yala completo** → La fila «Cómo usas Yala» también le sale; elegir «Yala completo» abre la activación de siempre.

**D12 · Vocabulario del copy** → «registros» y no «movimientos» (L7-18, `docs/glosario.md`), y «este dispositivo» en vez de «este iPhone» (como «Vaciar datos»; la app corre también en iPad). El resto, literal del lienzo. La línea Pro dice «en los ajustes de tu dispositivo».
Por qué: el glosario ya fijó esas dos palabras y el lienzo las mezclaba. Alternativa descartada: el literal del lienzo, que contradice a la pantalla de al lado.

**D13 · «Solo grupos» como texto al usuario** → Se usa, porque es la opción que Jürgen eligió en el lienzo; `.claude/rules/l10n.md` decía que no aparecía en ningún texto y ahora anota la excepción.

**D14 · ¿«Empezar de cero» avisa a los demás dispositivos del Apple ID?** → No: las filas borradas viajan por el espejo o la nube, como en «Vaciar datos» con la nube.
Por qué: la señal de vaciado hace que el otro dispositivo se vacíe por su cuenta, repita la bienvenida, pierda sus preferencias y borre los avisos, que vuelven a este teléfono por el espejo (review adversarial). Alternativa descartada: la señal más un «onboarding hecho», que seguía llevándose los avisos. Residual: el otro dispositivo puede enseñar el aviso de «datos borrados en iCloud» mientras baja el borrado; es verdad y se mira en device-QA.

**D15 · Revisiones adversariales aplicadas** → resumen de pagos de hoy que se perdía al volver; pausa mirada también al agendar; el reconciliador no barre en pausa; aviso de Bandeja en espera; sin ráfaga de avisos al volver; resumen de la hoja en un estado observable; la vuelta espera a que Ajustes se cierre y comprueba que la hoja llegó; Buscar sin registros en solo grupos; el borrado desmonta las pestañas; «Vaciar datos» refresca la vista; el paso de cuenta tiene salida.
