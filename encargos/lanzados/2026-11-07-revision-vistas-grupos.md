# Revisión por vistas 2.3 · Grupos en el uso diario: gastos, saldos, partir y liquidar
card: tablero-revision-por-vistas-2-3-grupos-en-el-uso-s6v8
toca: docs/ux/revision-vistas-2.3/37-grupos/
esfuerzo: xhigh

Rama base: origin/2.3 en jur211296/Yala. Un solo PR de documentación a 2.3 y un solo cierre: termina con `/cerrar-total`. Cierre autónomo (cierra-sola). Commits y PR sin firma de IA. NO cambies código de la app, tests, gateway, auth, producción, marketing/, colas ni sesiones: es revisión y prototipo de UX, sin cambios funcionales ni merge de funcionalidad. Sin publicación pública, hosting nuevo ni compras. Da siempre una descripción corta en español a cada comando Bash. Jürgen duerme: no esperes respuesta; dudas no vitales anótalas con alternativas para mañana en el cierre; nada de seguridad o producto crítico sin él. Justo antes del PR: `git fetch` y un solo rebase sobre origin/2.3.

Simuladores: puedes y debes usarlos para capturas actuales con datos ficticios. En la Mini, tope 1; en la Max, tope 2 (puedes abrir un segundo aunque otra sesión de otro proyecto use uno) o el iPhone 14 por DeviceMCP. Build `xcodebuild -jobs 2` sin sim encendido, luego bootear, capturar, apagar y borrar solo lo que encendiste (simuladores, DerivedData propio, temporales). No toques recursos de otras sesiones.

## Vistas y estados a revisar (lista cerrada)
GroupsContainerView, GroupCardView, GroupDetailView, GroupRecordsView, GroupBalancesView, GroupStatsView, GroupMembersView, GroupSettingsView, GroupsGlobalSettingsView, GroupFormView, GroupExpenseComposerView, GroupExpenseFormView, GroupExpenseSuccessView, GroupSplitSelectorView, GroupTwoPersonSplitView, GroupReceiptSplitView, MemberPickerView, SettlementFormView, GroupOpeningBalanceFormView.
Caso guía: Viaje de 4 personas: apuntar, partir desigual, ver quién debe a quién, liquidar. Excluye invitación, consentimiento y entrada a Grupos (alta).

## Método (igual en todas las revisiones por vistas)
1. Lee el estado actual en origin/2.3 de cada vista listada (lectura focalizada, sin auditoría general) y la revisión del PR 837 (`docs/ux/revision-usuario-nuevo-2026-11/`): reutiliza sus fricciones si aplican a esta zona, sin duplicar la guía visual del usuario nuevo. Lee el mapa de cobertura `/Users/jur/Claude/flota/cobertura-vistas-yala-2.3.md` y revisa SOLO tu zona.
2. Capturas actuales en simulador (iPhone; iPad y texto grande donde aplique) de cada vista y estado: vacío, con datos, cargando, error, sin permisos/sin conexión, según la vista.
3. Revisión adversarial con los siete perfiles SIMULADOS del PR 837 como lentes (no entrevistas): ¿se entiende?, ¿es clara?, terminología, jerarquía, encontrabilidad, carga cognitiva, cantidad de pasos, errores, accesibilidad (VoiceOver, texto grande), iPad.
4. Eficiencia técnica: recomputaciones, cargas, scroll y rendimiento. Separa medido (con cómo se midió) de hipótesis. Ninguna cifra inventada, ningún refactor.
5. Para cada problema prioritario: 3-5 alternativas con MAQUETAS DE PANTALLA de iPhone con el estilo de Yala, distinguibles, con el mismo caso y datos ficticios rotulados; secuencias de 2-4 pantallas si es conducta. Nada de tablas o texto disfrazados de maqueta. Recomendación justificada con tradeoffs; decide Jürgen.
6. Entrega en `docs/ux/revision-vistas-2.3/<tu-subdir>/`: HTML ligero portable (imágenes livianas, sin un único archivo gigante) + PDF VISUAL de respaldo + `ficha.md` corta (vistas cubiertas, problemas, recomendación, decisiones para Jürgen). NO edites ningún índice común.
7. Verifica visualmente el HTML a tamaño teléfono y escritorio en un navegador (Playwright o Chrome) y corrige legibilidad, imágenes y controles.
8. Cierre: rutas absolutas de HTML/PDF, capturas del artefacto probado, link del PR, «Saltado o asumido sin preguntar» y decisiones pendientes. Card a `in qa`.

## Cómo se sabe que está bien
Cada vista listada tiene capturas actuales, problemas priorizados y, para los prioritarios, 3-5 maquetas comparables; HTML+PDF verificados en teléfono y escritorio; un PR de documentación en 2.3; card en in qa; `/cerrar-total`.
FIN

## Instrucción temporal de Jürgen — 7-nov-2026 hasta 11:00, hora de Lima
Jürgen estará ausente hasta las 11:00 y autoriza trabajar autónomamente dentro del alcance. Resolver dudas menores reversibles con la opción recomendada y registrarla. Esto NO autoriza elegir rediseños materiales, ampliar alcance, acceder a datos reales, producción, envíos, compras ni acciones irreversibles. Para decisión fuera de autoridad: preservar íntegramente todo el trabajo (rama/commits y estado de reanudación), usar mecanismo existente seguro de pausa/reanudación y liberar máquina para siguiente sin esperar bloqueando. No dar incompleto por terminado. Mantener máximo una Yala/marketing por máquina. Sin rutinas/polling/wakes nuevos. Esta excepción temporal caduca automáticamente a las 11:00 Lima del 7-nov; después rige playbook habitual.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, Jürgen ausente): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Sobre qué rama se revisa y se entrega?** → `origin/2.3` (la rama del encargo se recolocó sobre ella al
arrancar: nacía de `2.2`). Un solo PR de documentación a `2.3`.
Por qué: el encargo lo pide y las zonas hermanas (30-35) ya están en `2.3`. Alternativa descartada: `2.2` directo
(la regla de «solo docs va directo» de CLAUDE.md), porque el encargo pide PR.

**D2 · El caso guía es un viaje de 4 personas y la semilla de pruebas trae 3 (Tú, Ana, Beto). ¿Cómo se capturan 4?**
→ Parche LOCAL de la semilla `DevSeedGroups.create` que suma a «Carla» (solo bajo `-uitest`), aplicado para compilar
las capturas y **revertido antes del commit**; el parche queda como documento en `37-grupos/fuente/` y el PR no toca
`Yala/`. Por qué: añadir un miembro de verdad exige invitación y servidor (fuera del encargo) y
`GroupService.addMember` no tiene llamadores; con 3 personas no se ve el «partir desigual» que pide el caso.
Alternativa descartada: capturar con 3 y maquetar con 4 (las capturas no serían del caso).

**D3 · ¿Cómo se conduce el simulador?** → Simuladores propios creados para la sesión (iPhone 17 Pro y iPad Pro 13),
borrados al terminar; conducción con Device MCP/axe y, donde un toque sintético no abre (la tarjeta de grupo), un
XCUITest conductor temporal que no se commitea. Por qué: memoria medida (la tarjeta de grupo no abre con toques
sintéticos). Alternativa descartada: usar los simuladores compartidos (no se pueden borrar al terminar).

**D4 · Formato de la entrega** → El mismo de las zonas hermanas: `index.html` + «Hoy, vista a vista» + «Perfiles y
eficiencia» + una página por problema prioritario, `estilo.css`, capturas JPEG livianas, generador en `fuente/`
(reusa `ui.py` de las maquetas), PDF visual impreso desde una página «todo», y `ficha.md`. Carpeta `37-grupos/`.
No se edita el índice común. Por qué: consistencia con el índice y lo que Jürgen ya leyó.

**D5 · Lentes** → Los siete perfiles simulados del PR 837 (P1-P7), adaptados al uso diario de un grupo. Lo ya
decidido en la auditoría 2.2 (lote 13: L13-1 Saldos, L13-2 pago por confirmar, L13-3 «¡Gasto agregado!») se mide
contra lo que hay en `2.3`; una alternativa que lo cambie lleva la marca «Reabre L13-x».

**D6 · ¿Cuántos problemas con maquetas?** → Los prioritarios (alta y media-alta), 4 alternativas cada uno (rango
3-5), con el caso «Viaje a Cusco, 4 personas» y datos ficticios rotulados. El resto, en la tabla de problemas.

**D7 · Publicación** → Nada de Artifact ni hosting: HTML y PDF en el repo; el PDF y la ficha se envían a Jürgen por
`SendUserFile` al cerrar. Por qué: el encargo prohíbe publicación y hosting nuevos.
