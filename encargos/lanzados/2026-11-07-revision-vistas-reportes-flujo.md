# Revisión por vistas 2.3 · Reportes y Flujo de caja/proyectado (después de la mejora de flujo de caja)
card: tablero-revision-por-vistas-2-3-reportes-y-flujo-vcz4
toca: docs/ux/revision-vistas-2.3/36-reportes-flujo/
esfuerzo: high

Rama base: origin/2.3 en jur211296/Yala. Un solo PR de documentación a 2.3 y un solo cierre: termina con `/cerrar-total`. Cierre autónomo (cierra-sola). Commits y PR sin firma de IA. NO cambies código de la app, tests, gateway, auth, producción, marketing/, colas ni sesiones: es revisión y prototipo de UX, sin cambios funcionales ni merge de funcionalidad. Sin publicación pública, hosting nuevo ni compras. Da siempre una descripción corta en español a cada comando Bash. Jürgen duerme: no esperes respuesta; dudas no vitales anótalas con alternativas para mañana en el cierre; nada de seguridad o producto crítico sin él. Justo antes del PR: `git fetch` y un solo rebase sobre origin/2.3.

Simuladores: puedes y debes usarlos para capturas actuales con datos ficticios. En la Mini, tope 1; en la Max, tope 2 (puedes abrir un segundo aunque otra sesión de otro proyecto use uno) o el iPhone 14 por DeviceMCP. Build `xcodebuild -jobs 2` sin sim encendido, luego bootear, capturar, apagar y borrar solo lo que encendiste (simuladores, DerivedData propio, temporales). No toques recursos de otras sesiones.

## Vistas y estados a revisar (lista cerrada)
FinancialReportView, NetFlowSummaryView, PivotRowView, CashFlowSetupView, CashFlowTableView, CashFlowMonthDetailView y «Ver proyectado» en Tendencias/Panel/widgets.
Caso guía: Revisa el estado DESPUÉS del PR de «Mejorar el flujo de caja» si ya está mergeado; si no, revisa 2.3 y rotula qué puede cambiar. Saber si llego a fin de mes, leer un mes, entender lo aproximado/proyectado.

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

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Base: estado antes o después de «Mejorar el flujo de caja»?** → Después: el PR de la mejora ya está mergeado en `origin/2.3` (7-nov 05:05). La rama se recreó desde `origin/2.3` porque había nacido de 2.2.
Por qué: el encargo pide el estado posterior si existe. Alternativa descartada: revisar 2.2 y rotular, innecesario.

**D2 · Subcarpeta** → `docs/ux/revision-vistas-2.3/36-reportes-flujo/`, sin tocar el `README.md` índice.
Por qué: número de zona del mapa de cobertura y de la línea «36» del índice. Alternativa: otro nombre, rompería el patrón.

**D3 · Formato del entregable** → el mismo de las zonas hermanas (Estadísticas): generador Python en `fuente/` que reutiliza las primitivas de maqueta (`ui.py`), páginas HTML ligeras con capturas JPEG enlazadas, PDF de respaldo y `ficha.md`.
Por qué: coherencia entre zonas y estilo de Yala ya validado. Alternativa: HTML único, el encargo lo descarta.

**D4 · Cómo se sacan las capturas** → un XCUITest conductor TEMPORAL (`YalaUITests/ZZRevisionReportesCapturasUITests.swift`) sobre un build de `origin/2.3` sin tocar; no se commitea y se borra al final. Simulador propio de la sesión (iPhone 17 Pro, iOS 27.2) creado y borrado por mí; iPad propio igual. Widgets con el arnés `qa/widget-render` y una foto exportada de mi simulador.
Por qué: el encargo prohíbe cambiar tests; un fichero que nunca entra en el diff no es un cambio. Alternativa: conducir con axe a mano, más lento y frágil (memoria).

**D5 · Datos** → semillas de prueba (`realista`, `minimal`, vacío, Free con `pro: false`, `-panelAmountsHidden`, `-uitest-expenses-only`), período «Este mes» con `-defaultPeriod thisMonth`. Nada de datos reales.

**D6 · Estados que no se pueden ver en simulador** (sin conexión, error) → se documentan desde el código con fichero y línea, rotulados como tales.

**D7 · Cuántos problemas con alternativas** → los prioritarios (alta y media-alta), 3-5 alternativas maquetadas cada uno; los de severidad baja, solo descritos con su recomendación.
Por qué: el criterio del encargo pide maquetas «para cada problema prioritario».

**D8 · VoiceOver** → medido en el árbol de accesibilidad (sin encender VoiceOver), como en Estadísticas.
