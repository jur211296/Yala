# Auditoría UX 2.2 · decidido por Jürgen · 04 · Tu cuenta, cerrar sesión, eliminar la cuenta y Ajustes en modo solo grupos

Base y PR: **2.2** (no 2.1). `lanzar-sesion` te deja sobre origin/2.1: antes del primer commit haz `git fetch origin && git switch -C encargo-tmp origin/2.2` (o rebasa tu rama sobre origin/2.2) y comprueba que `git log origin/2.2..HEAD` sale vacío. El PR va contra **2.2**.

## Contexto
Jürgen respondió el 18-oct (18:41–21:18 Lima, sesión «preguntas-auditoria-ux-2-2») todas las cards de la auditoría UX 2.2 que esperaban decisión. Resumen completo: `~/Claude/entregas/Yala--preguntas-auditoria-ux-2-2/decisiones.md`. Esta sesión implementa las de abajo, que están en «ready to launch» asignadas a frank, con la decisión en la nota de cada card.
Fuentes: la card (nota = decisión; contexto con capturas), el informe del lote en `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-19-grupos-iii/informe.md`, `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-20-tus-datos/informe.md`, el HTML `~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html` (opciones A/B/C/D y variantes) y los «Criterios UX/UI permanentes de Jürgen» del brief madre `~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md` (léelos: sin degradados, etc.). Las variantes elegidas (p. ej. «L17-2-B.png») están en `capturas/` de esa misma carpeta del lote.

## Cards de esta sesión (8)
- **L20-6** · `tablero-ux-2-2-l20-6-cerrar-sesion-a-quien-nunca-lpj1`
  UX 2.2 · L20-6 · «Cerrar sesión» a quien nunca inició sesión, entre «Calificar» y la ayuda
  Decisión de Jürgen: opción B (recomendada). Sin cuenta de Yala, «Quitar mis datos de este iPhone · Siguen en tu iCloud» en sección propia al final.
- **L20-7** · `tablero-ux-2-2-l20-7-cerrar-sesion-espera-45-seg-wtme`
  UX 2.2 · L20-7 · Cerrar sesión espera 45 segundos con un pie gris, y el aviso ofrece «Cerrar sesión igualmente» primero, sin exportar
  Decisión de Jürgen: opción B (recomendada). Tarjeta de progreso durante la espera y aviso con «Exportar mis movimientos» primero, «Esperar» y «Cerrar sesión igualmente» al final.
- **L20-9** · `tablero-ux-2-2-l20-9-tu-cuenta-de-yala-no-dice-q-vlc4`
  UX 2.2 · L20-9 · «Tu cuenta de Yala» no dice qué cuenta es, y contradice a la pantalla de entrar
  Decisión de Jürgen: opción B (recomendada). Correo/nombre con icono del proveedor, una sola frase del método igual en las dos pantallas (medir en el backend cuál de las dos es la verdad antes de escribirla) y «Dónde viven tus datos» como fila.
- **L20-10** · `tablero-ux-2-2-l20-10-la-hoja-y-la-alerta-de-eli-4dwv`
  UX 2.2 · L20-10 · La hoja y la alerta de eliminar la cuenta se contradicen
  Decisión de Jürgen: opción B (recomendada). Alerta final por celda, «tu nombre pasa a «Usuario eliminado»» y «Usa Vaciar datos».
- **L19-15** · `tablero-ux-2-2-l19-15-en-modo-solo-grupos-ajuste-0kj5`
  UX 2.2 · L19-15 · En modo solo grupos, Ajustes habla de iCloud y esconde «Activar Yala completo»
  Decisión de Jürgen: opción B (recomendada). Ocultar «Sincronización iCloud» y «Dónde viven tus datos» en modo solo grupos y destacar «Activar Yala completo».
- **L19-17** · `tablero-ux-2-2-l19-17-volver-a-tus-grupos-inicia-7jxn`
  UX 2.2 · L19-17 · Volver a tus grupos: «Iniciar sesión» es un enlace pequeño y la hoja ofrece «Crear cuenta con Google»
  Decisión de Jürgen: opción B (recomendada). Botón relleno «Entrar en mi cuenta» y «Continuar con Apple/Google» (como L12-7).
- **L19-18** · `tablero-ux-2-2-l19-18-el-error-de-sincronizacion-yxsc`
  UX 2.2 · L19-18 · El error de sincronización y el aviso de «este teléfono no sincroniza» hablan como el código
  Decisión de Jürgen: opción B (recomendada). Los dos avisos reescritos diciendo qué pasó y qué hacer.
- **L19-19** · `tablero-ux-2-2-l19-19-un-grupo-migrado-se-explic-zvwe`
  UX 2.2 · L19-19 · Un grupo migrado se explica en tres frases, y su botón parece texto
  Decisión de Jürgen: opción B (recomendada). Una frase y botón relleno «Volver a entrar».

## Avisos de esta sesión
- **L20-9**: antes de escribir la frase única sobre el método (Apple/Google), mide en el backend cuál de las dos versiones es la verdad y cita en el PR dónde lo comprobaste.
- L19-17 usa «Continuar con Apple/Google» como L12-7: si L12-7 aún no está en 2.2, crea los textos aquí con las mismas claves para que la sesión de Grupos los reutilice.
- Nada de despliegues a producción (Supabase, Worker).

## Cómo mover las cards
- Al empezar con cada una: `tablero mover <id> --a "in progress" --agente frank`. No uses `--nota` en `tablero editar` salvo para AÑADIR: `--nota` reemplaza la nota entera, así que copia la decisión de Jürgen que ya está y añade debajo lo tuyo.
- Al cerrar: a `done` (`--agente frank`) las que queden hechas y mergeadas sin nada que probar en el teléfono; a `in qa` asignadas a `jurgen` con un guion corto de iPhone en la nota si hay algo que él deba probar en el teléfono.
- Todo ticket nuevo lleva su card.

## La UI sigue la decisión al pie de la letra
- Implementa exactamente lo que dice la decisión de cada card (y la variante con captura si la hay). No inventes UI ni «mejores» la opción elegida. Los detalles que la decisión no fija y que el sistema de diseño ya resuelve (márgenes, tipografía, componentes existentes) se toman de lo que ya hay en la app.
- Si al implementar aparece algo de verdad sin decidir (dos caminos que cambian lo que ve el usuario y ninguno sale de la decisión), NO elijas tú: deja 2–3 propuestas con capturas o mock y tu recomendación en la nota de esa card, muévela a «espera decisión» asignada a `jurgen` con `--pregunta`, y sigue con las demás. Solo se para ese ítem, no la sesión.
- Ningún texto de la app escribe «OpenAI»: se dice «un servicio de IA» (con enlace a la política de privacidad, que es el único sitio que nombra al proveedor).
- Todo texto nuevo o cambiado, en los **16 idiomas**, y `/l10n-check` limpio.

## Reglas
- **Sin esperar el CI de ningún PR** (tampoco el tuyo): `git fetch origin && git rebase origin/2.2` justo antes de abrir el PR.
- Pipeline serial en la Mini: limpiar, build con `xcodebuild -jobs 2` sin simulador encendido, encender 1 simulador, tests, apagarlo. 1 simulador a la vez. Mira `df -h /` antes de compilar. Usa los simuladores iOS 27.0. Al cerrar, apaga y borra (erase) el simulador que usaste.
- Al lanzar y al cerrar borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen; no toques las de un worktree vivo.
- En `~/Yala` (árbol principal) no toques, commitees ni descartes `Cloudkit Schemas/yala_dev-*.ckdb`, `Yala.xcscheme` ni `encargos/pendientes/`.
- Nada de salud ni de clínicas. No toques tmux `salud--*`, `sat-lab--*`, `ruum--*`, `clinicas-dentales-bi--*`, `Yala--qa-guiado-2-1-tf17` ni otros `Yala--` vivos.
- Nada de despliegues a producción (Worker/gateway, Supabase, CloudKit Production, web). Si algo hace falta, déjalo listo con los pasos en una card a `jurgen` (o a `lola` si es CloudKit) y sigue.
- No cambies cuota, modelo ni proveedor de IA, precios ni productos de StoreKit.
- Prueba la sesión tú misma con **/barrido-qa** en el simulador (tests de lo que cambie, flujos tocados de punta a punta, VoiceOver en lo nuevo). Hay cambio visible: capturas de antes y después en `capturas/` del worktree, copiadas también a `~/Claude/entregas/<sesión>/capturas/`, con sus rutas en el resumen de cierre.
- Cierra sola con **/cerrar-total** (merge incluido). No esperes a nadie.

## Cómo se sabe que está bien
Cada card hecha tal como la decidió Jürgen (o, si algo no estaba decidido, con sus propuestas en la card a `jurgen` y solo ese ítem parado), textos en los 16 idiomas, tests en verde (`/gate`, `YalaTests`), /barrido-qa pasado, capturas de antes y después, cards movidas, y PR mergeado en 2.2 explicando en lenguaje de usuario qué verá la persona.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · L20-9: ¿qué frase del método es la verdad?** → «Si usas el mismo correo, Apple y Google abren esta misma cuenta.»
Por qué: medido el 2026-10-19 con la Management API de Supabase (solo lectura): producción (`kefvaiymtgytemwbltlz`) y staging tienen Apple y Google activos y `security_manual_linking_enabled = false`, así que GoTrue vincula por correo verificado; en staging hay 1 usuario con identidades Apple y Google en la misma cuenta (el H4 del 16-jul). Producción tiene 0 usuarios. Alternativa descartada: «queda ligada al método que elijas», que contradice al backend. Las dos pantallas leen la MISMA key (`settings.yalaAccountLinkingNote`).

**D2 · L20-9: ¿de dónde sale el correo/nombre?** → correo de la sesión de Supabase; si no, el capturado al entrar; si no, el nombre capturado; si no, la línea de método de antes. Icono: `apple.logo` o el asset `GoogleG`.
Por qué: Apple solo entrega el correo la primera vez; la sesión lo trae siempre. Alternativa descartada: solo el capturado (vacío en la mayoría de Apple).

**D3 · L20-9 + L19-15: «Dónde viven tus datos» como fila en «Tu cuenta de Yala», ¿también en solo grupos?** → fila que abre la pantalla salvo en solo grupos, donde queda como texto sin enlace.
Por qué: L19-15 decide ocultar esa pantalla en solo grupos; enlazarla desde «Tu cuenta» la reabriría por otra puerta.

**D4 · L19-15: predicado de «modo solo grupos»** → `isGroupsFocusedShell`, el mismo que enseña «Activar Yala completo». En solo grupos la sección de Grupos es `.notApplicable`, así que ocultar la fila no quita la puerta de desasociar. Cierra el ticket `groups-only-session-storage-screen-says-data-lives-in-icloud` (opción 1).

**D5 · L19-15: cómo se destaca «Activar Yala completo»** → la tarjeta rellena con `theme.accent` (el relleno de `YalaPrimaryButton`), texto e iconos blancos. Sin degradado ni brillo.

**D6 · L20-6: qué cuenta como «sin cuenta de Yala»** → el camino `.privateSignOut` (sesión privada sin sesión en la nube). Con cuenta sigue «Cerrar sesión» donde está. El subtítulo «Siguen en tu iCloud» solo con copia en iCloud (`privateCopyChannel() == .iCloud`); sin copia, sin subtítulo (sería falso). La «sección propia» es una tarjeta suelta al final de Ajustes, sin cabecera (no hay título decidido).

**D7 · L20-6: la hoja que abre la fila renombrada** → en esa celda, título «¿Quitar tus datos de este iPhone?» y botón «Quitar mis datos». Completa el objeto que nombra la decisión (fila → su confirmación). Los avisos de después («Cerrar sesión y borrar», «Cerrar sesión igualmente») no se tocan: L20-7 fija ese texto; queda anotado en la card.

**D8 · L20-7: botón de exportar** → «Exportar mis registros» (la key del aviso equivalente de la nube; L7-18 cambió «movimientos» por «registros»), con la exportación de todo sin asistente de L20-8. Al cerrar la hoja de compartir vuelve el aviso. Orden: Exportar · Esperar · Cerrar sesión igualmente (ninguno con rol `.cancel`, que iOS manda al final).

**D9 · L20-7: la tarjeta de progreso** → solo durante la espera del export a iCloud (`CloudSessionSignOut` publica `iCloudExportWaitPending`, la cifra que ya cuenta); «Subiendo tus cambios a iCloud…» y «Faltan N cambios» (sin cifra si no la hay). Las demás esperas conservan el pie de siempre: no suben a iCloud.

**D10 · L20-10: alerta final por celda** → `deleteAccountGroupsOnly` (cuenta de grupos con sesión privada): «Se borra tu cuenta de Yala. Lo de este teléfono se queda.». Nube y solo-grupos-sin-privada conservan el texto de siempre, que en ellas es cierto. Fila 👥 «Tu nombre pasa a «Usuario eliminado»»; fila ☁️ «Se borra tu cuenta de Yala» (sin «saldrás»); «Usa «Vaciar datos»» con el nombre de la fila en cada idioma, también en `settings.batchLeaveStoppedBody` (misma referencia rota).

**D11 · L19-17: verbos** → Apple `.continue` y Google `.continue` en «Conecta tu cuenta» (las keys de L12-7 ya existen: `auth.googleButton`; el de Apple lo localiza el sistema). El estado vacío ya usa `YalaPrimaryButton` desde L12-2: solo cambia el texto a «Entrar en mi cuenta». Lo demás de L12-7 (línea y título único) es de su sesión.

**D12 · L19-18: los textos que la decisión no da** → mismo molde: actualizar → «No pudimos actualizar este gasto en tus cuentas. Lo intentamos otra vez solos; no tienes que hacer nada.» (se reintenta: `bridgePending`); borrar → «No pudimos quitar este gasto de tus cuentas. Si sigue en Registros, bórralo desde ahí.» (no se reintenta). El título de la alerta no cambia.

**D13 · L19-19: alcance del botón relleno** → `YalaPrimaryButton` en las dos salidas del aviso (Volver a entrar y Actualizar), que es el mismo componente; la frase única solo en `rejoin`.
