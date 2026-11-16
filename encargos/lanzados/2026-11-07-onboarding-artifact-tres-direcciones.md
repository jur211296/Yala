Yala
# Onboarding 2.3 desde cero: tres direcciones en un artifact nativo de Claude
toca: prototipos/onboarding-artifact-tres-direcciones
cierre: cierras-tu
modalidad: cierras-tu
esfuerzo: xhigh
ubicacion: Max exclusivamente, lanzamiento manual dirigido tras confirmación
alcance: prototipos aislados; ningún cambio funcional del repositorio

## Contrato y antecedentes
AUTORIZADO para lanzamiento manual por Jürgen 7-nov16:36 Lima («Dale, lancemos claude»). Reutiliza el contexto de `~/Claude/flota/cola-yala/manual-pendiente/01-onboarding-libre-iphone14.md`, conservado como historial. Prevalecen los pedidos de Jürgen del 7-nov16:08 y16:09 Lima: SOLO onboarding, UI sobre UX, propuestas desde cero, artifact nativo de Claude, sesión abierta. Quedan reemplazados HTML/PDF como entregables, autocierre y consultas al bot. La excepción temporal hasta11:00 está vencida.

No lanzar hasta confirmar el brief y la disponibilidad real del artifact nativo. Después, usar únicamente `lanzar-sesion Yala <slug> --maquina max --permission-mode bypassPermissions --effort xhigh --nuevo`, con encargo interactivo **CIERRAS TÚ**. NO `/cerrar-total`, NO autocierre, NO reactivar cola ni rutinas. Máximo una Yala/marketing por máquina; Mini no es alternativa.

## Comprobación de capacidad previa
La revisión anterior dejó la referencia https://code.claude.com/docs/en/artifacts y metadatos de Max como antecedentes. Esta investigación documental NO verifica la disponibilidad real de artifacts nativos en Claude Code, comandos, publicación privada ni habilitación de cuenta. No tratarlos como capacidad confirmada ni prometer que un terminal equivale a Claude.ai.

Antes de producir propuestas, verificar con documentación oficial y herramientas efectivamente disponibles en la sesión de Jürgen la creación y visualización de un artifact nativo privado. No asumir que existe `/artifacts` ni publicación desde CLI. No iniciar login ni cambiar configuración. Si falta capacidad, explicárselo allí a Jürgen y esperar: puede habilitar Artifacts mediante los controles oficiales de su cuenta/organización si corresponde. No sustituir con archivo HTML, PDF, Canvas ni enlace de hosting propio. Un archivo interno de implementación no es el entregable solicitado. El artifact debe tener ubicación real accesible desde esa sesión; permanece privado, sin compartir públicamente.

## Objetivo y límites
Crear una bienvenida y experiencia de crear/acceder a cuenta grata, divertida, fácil y moderna, sin abrumar. Recorrido SOLO desde Welcome hasta primera llegada a Yala. Se puede descartar todo el diseño actual excepto conservar colores de marca de alguna manera. No barrer bugs ni revisar arquitectura, backend, autenticación o toda la app.

Sin mascota actual; prever incorporación futura con elementos sustituibles, sin huecos reservados ni pasos dependientes de ella. Quitar lo innecesario, mejorar lo esencial y añadir recomendaciones como propuestas, nunca decisiones de implementación. Mantener tono adulto y respetuoso; no moralizar gastos ni usar presión comercial.

Leer focalizadamente onboarding actual2.3, decisiones pertinentes de cuenta/datos, PR837 y guíaPR842, como antecedentes y no plantilla a retocar. Consultar `~/Claude/referencias-ui/README.md` sin copiar marcas/pantallas.

## Investigación y tres direcciones
Leer `investigacion.md` de esta misma carpeta: investigación ampliada completada, fuentes primarias Apple/NN-g/Monzo/Copilot/Duolingo y publicaciones individuales X. Distingue declaraciones y opiniones de evidencia: no se observaron vídeos ni se validó UI actual de las apps. No hay un número mágico de pasos. Justificar extensión por información necesaria, dependencias y carga, mostrando qué se elimina/aplaza y cómo se recupera. No inventar métricas de conversión ni entrevistas.

Explorar como hipótesis tres estructuras: A Mesa viva (escena ficticia manipulable, cuenta en hoja contextual); B Portada editorial (entrada directa, tipografía y primera llegada tranquila); C Recorrido cinematográfico bajo control (transformación continua cancelable). A es candidata diferenciada y B control de claridad, no elección aprobada. Crear EXACTAMENTE tres direcciones realmente distintas en composición, narrativa y acciones, no recolores. Cada una tendrá pantallas completas navegables Welcome→crear cuenta o acceder→primera llegada, variantes de Welcome y cuenta, atrás, omitir cuando proceda y teclado/espera/cancelación visuales.

Comparar con mismo caso ficticio: Ana, soles, interés en entender sus gastos. Si se muestra información financiera, rotular datos de ejemplo; no exigir un gasto, presupuesto ni saldo reales. Considerar quien empieza, quien ya tiene cuenta y quien quiere configurar después. Mostrar acceso y permisos con semántica actual; cambios funcionales necesarios se rotulan como dependencias futuras, sin implementarlos. Recomendar una dirección con razones y renuncias; decide Jürgen.

## Principios derivados y referencias
Eliminar carrusel comercial y configuración ornamental obligatorios; mantener acceso existente visible desde Welcome. No convertir divulgación progresiva en un campo por pantalla. Preguntas solo si cambian un resultado inmediato; permisos cuando una función los necesita. No añadir invitado, proveedores, KYC, cuentas bancarias ni paywall a la app. Demo solo ficticia dentro del artifact, identificada como tal y separada del estado vacío real. Preservar decisiones previas sobre aplazar bienvenida sin confundirla con tutorial omitido.
Referencias principales: Apple onboarding y managing-accounts; NN/g mobile-app-onboarding y progressive-disclosure; Copilot Quick Start y Settings. URLs, contradicciones y límites completos en `investigacion.md`.

## Sensación, movimiento y accesibilidad
Diseñar gestos comprensibles, acciones directas, continuidad entre pantallas y animaciones que expliquen estado. Para cada interacción importante: disparador, respuesta visual, sonido y háptica opcionales, alternativa accesible. Sin retrasos decorativos ni gestos como única manera de avanzar.

Probar Reduce Motion, VoiceOver, texto grande, contraste y foco; ofrecer experiencia completa sin sonido/vibración. Respetar silencio y preferencias del sistema sin cambiarlos para forzar demo. No confundir animación visible en web con háptica nativa: marcar límites de navegador y sandbox; adaptar imposibles sin prometer capacidades iOS inexistentes.

## iPhone14 y entrega en esta sesión
Max tiene `device-mcp` instalado; `devicectl` reportó iPhone14 físico conectado. No equivale a confirmar servidor MCP/permisos: verificar herramientas oficiales al comenzar sin pedir reconexión por costumbre. Usar DeviceMCP para escenarios seguros de app actual y prototipo. Separar APP REAL, ARTIFACT/PROTOTIPO e HIPÓTESIS, con evidencia y limitaciones.

No iniciar restauración, borrar datos, reinstalar app con datos, cerrar sesión personal ni completar autenticación real. No modificar redes/auth ni configuración global. Máximo2 simuladores en Max, incluido un segundo si otra sesión usa el primero; limpiar solo recursos propios. Ninguna instalación nativa adicional sin autorización.

Mostrar las tres propuestas en UN artifact nativo navegable con selector de dirección, variantes y repetición de animaciones, revisado en teléfono/escritorio. Evidencia de prueba física dentro del artifact; no afirmar validación de lo solo simulado. Sin PR mergeado, publicación pública ni implementación final.

**Comunicación:** solo UN aviso al bot dueño cuando las propuestas estén listas: «Propuestas listas; artifact: [ubicación real]». Ninguna consulta al bot ni aviso intermedio. Las dudas se plantean directamente a Jürgen en esta misma sesión abierta. No usar automatismos de cierre/consulta que contradigan este pedido. Mantener sesión viva y cola pausada esperando su revisión.

## Adenda vinculante de lanzamiento · 7-nov16:36 Lima
Esta instrucción explícita de Jürgen prevalece sobre el pie genérico que añade el lanzador: CIERRAS-TÚ; NO /cerrar-total, NO autocierre, NO PR/merge/publish público, NO implementación en app real. Permanecer abierta mostrando propuestas. Ninguna consulta al bot: dudas y accesos se preguntan a Jürgen EN ESTA MISMA SESIÓN. No enviar avisos intermedios ni digest Slack.
El parent verificó directamente documentación oficial https://code.claude.com/docs/en/artifacts : la CLI actual soporta artifacts y Max 2.1.319 es compatible. Verifica habilitación efectiva con herramienta nativa /artifacts; si cuenta/política la bloquean, pregunta aquí a Jürgen, sin formatos sustitutos ni negar capacidad por recuerdos anteriores.
Lee COMPLETA la investigación adjunta al final de este mismo encargo; también está en /Users/max-jur/Claude/entregas/onboarding-yala-20261107/investigacion.md.
Da siempre una descripción corta en español y sobre el tema a cada comando Bash. Español neutro latinoamericano.
Aviso final: el mecanismo inspeccionado avisar_grok.py rechaza avisos de artifact para despertar al bot; las rutinas están pausadas. No disfraces propuestas listas como consulta/cierre, ni llames un emisor interno para saltar el filtro. Si hay una herramienta directa oficialmente soportada y autorizada que entregue al bot sin rutinas, úsala UNA sola vez al estar listo con «Propuestas listas; artifact: [ubicación real]». Si no está disponible, deja esa frase y el enlace real visibles en sesión y explica aquí a Jürgen la limitación; NO prometas aviso automático. No crear/reanudar rutinas.
Max e iPhone físico conectados comprobados con devicectl al lanzar; verificar acceso DeviceMCP efectivo desde esta sesión, no confundir con estado de conexión del teléfono en el chat. No instalar nada adicional ni modificar datos/cuentas reales. Prototipos aislados en carpeta de entregas, no tocar código de producto. Cola automática permanece pausada.


---
# INVESTIGACIÓN ADJUNTA COMPLETA

# Investigación ampliada · onboarding Yala 2.3
7 noviembre 2026 · Lima. Investigación documental pública, no prueba de apps ni estudio con usuarios.

## Decisiones recomendadas
- Diseñar una bienvenida con valor comprensible y acceso visible, no una presentación comercial que haya que pasar. Enseñar una acción solo si aclara algo desconocido. Una demo opcional puede mostrar el beneficio sin pedir dinero, permisos o datos reales.
- Separar dos tareas: entender Yala y acceder/crear cuenta. El usuario existente debe saltar la presentación. Conservar proveedores, validaciones y semántica de autenticación actuales: las recomendaciones generales de acceso tardío NO autorizan crear modo invitado ni modificar auth.
- No prefijar pasos. Cada pantalla debe justificar información necesaria, acción útil o una dependencia real. Agrupar elecciones relacionadas; separar decisiones independientes si la densidad lo exige. Contar decisiones, escritura, interrupciones y bloqueos, no solo pantallas.
- Posponer tema visual, preguntas aspiracionales, presupuesto, carga de cuentas y permisos no esenciales. No ocultar acceso, condiciones esenciales o consecuencias bajo «simplicidad». Mostrar cómo recuperar lo aplazado mediante rutas existentes; si no existen, señalar dependencia, no inventarlas.
- Diversión adulta: transformación directa de elementos financieros ficticios, tipografía expresiva y continuidad espacial. No mascota, rachas, culpa por gastar, confeti perpetuo ni una encuesta disfrazada de conversación.
- Movimiento como respuesta, no peaje: una acción provoca un cambio entendible, interrumpible y breve. Gestos con botón equivalente. Háptica discreta y causal; sonido accesorio, nunca indispensable. Silencio del sistema, Reduce Motion, texto grande y VoiceOver forman parte del diseño, no una variante inferior.

## Fuentes verificadas y aplicación
Se leyó contenido textual de las siguientes fuentes; los HIG con página vacía se verificaron mediante su JSON público oficial. No se reprodujeron vídeos ni se observaron medios de X: ninguna valoración aquí equivale a inspección visual o táctil.

1. Apple HIG · Onboarding
https://developer.apple.com/design/human-interface-guidelines/onboarding
Guía primaria: rápido, divertido y opcional; aprendizaje interactivo seguro, tips contextuales y configuración no esencial después. Inspira una acción de prueba opcional; no justifica un minijuego obligatorio. El HIG pide no repetir tutorial omitido: no reinterpretar silenciosamente decisiones Yala previas sobre aplazar bienvenida una vez; distinguir tutorial de bienvenida.

2. Apple HIG · Managing accounts
https://developer.apple.com/design/human-interface-guidelines/managing-accounts
Explicar beneficio de cuenta y demorar acceso cuando sea posible; identificar método disponible. Aplicación: acceso existente claramente separado, copy de utilidad. No importar passkeys, biometría ni invitado nuevos: recomendaciones de plataforma, fuera de alcance funcional.

3. Apple HIG · Privacy
https://developer.apple.com/design/human-interface-guidelines/privacy
Pedir únicamente acceso necesario y en contexto. Una app financiera no necesita por defecto micrófono, contactos o fotos en Welcome. No diseñar falsos diálogos iOS ni botones «Permitir» que solo abran otro diálogo. Diferenciar tutorial omisible de prealerta de permiso: Apple impone reglas específicas a esta última; mejor no añadirla por rutina.

4. Apple HIG · Motion
https://developer.apple.com/design/human-interface-guidelines/motion
Propósito, brevedad, posibilidad de cancelar y alternativas sin movimiento. Inspira continuidad de una tarjeta de Welcome a cuenta/primera llegada. No importar splash obligatorio, parallax constante o esperas teatrales.

5. Apple HIG · Playing haptics
https://developer.apple.com/design/human-interface-guidelines/playing-haptics
Patrones consistentes, cortos, vinculados a eventos discretos y opcionales. Proponer una confirmación o selección, no vibración en cada letra. La sensación nativa solo puede validarse físicamente; un artifact web no prueba háptica iOS.

6. Apple HIG · Playing audio
https://developer.apple.com/design/human-interface-guidelines/playing-audio
Sonidos accesorios respetan silencio y volumen; evitar interferir con audio ajeno. Diseñar primero sin sonido; luego un acento opcional a una acción significativa, sin narración automática.

7. NN/g · Mobile-App Onboarding (2020)
https://www.nngroup.com/articles/mobile-app-onboarding/
Análisis con ejemplos concretos: MindNode enseña un flujo poco familiar haciendo un mapa; Fabulous añade práctica innecesaria a tareas conocidas; NOAA sobrecarga con muchas marcas a la vez. Inspira aprender una sola interacción útil; descartar carrusel de funciones y tutorial que explica controles estándar. No evidencia de conversión Yala ni observación de versiones actuales de esas apps.

8. NN/g · Progressive Disclosure (2006)
https://www.nngroup.com/articles/progressive-disclosure/
Distingue divulgación progresiva (opciones secundarias a demanda) de secuenciación (pasos que todos recorren). No equivale a «un campo por pantalla». Mantener juntas decisiones que hay que comparar; aplazar lo que no influye en la tarea presente. Fuente fundacional, no investigación móvil de 2026.

9. Monzo · Cómo abrir cuenta personal (ayuda oficial vigente consultada)
https://monzo.com/help/opening-an-account/how-to-open-a-Monzo-Personal-Account
Explicita requisitos, motivo regulatorio y secuencia: datos personales → identidad → opciones → tarjeta. Inspira expectativas claras antes de un esfuerzo y lenguaje humano. NO copiar KYC, selfie, teléfono/domicilio ni longitud bancaria: Monzo es banco regulado, Yala no adquiere esos requisitos por parecer fintech. Solo se verificó guía, no UI actual.

10. Copilot Money · Quick Start (27 agosto 2026) + Settings (6 octubre 2026)
https://help.copilot.money/en/articles/11157550-quick-start-guide
https://help.copilot.money/en/articles/11062072-settings-overview
La guía confirma conexión financiera al inicio, elección de suscripción para prueba y presupuesto basado en historial; ajustes confirma demo con datos ficticios y reiniciar onboarding. Inspira mostrar utilidad sin exponer finanzas personales. No importar conexión bancaria ni paywall ni afirmar que hoy la demo está antes de registro: la fuente primaria confirma demo en ajustes, no su ubicación inicial. La demo propuesta para Yala vive SOLO dentro del prototipo.

11. Duolingo · Animation / visemes (2022, equipo de producto)
https://blog.duolingo.com/world-character-visemes/
Describe respuesta a acciones: tocar una palabra dispara voz/animación; avanzar interrumpe el habla; resultado cambia estado. Inspira feedback interrumpible ligado a intención. No copiar personaje, infraestructura Rive, voces o gamificación; no demuestra un onboarding actual ni mejoras de conversión.

12. X · contraste de ideas y testimonios, no prueba causal
https://x.com/imhslva/status/2115735568881521007
Observador declara que probó Duolingo: actuar antes de cuenta, pequeñas animaciones/sonidos y progreso antes de pedir. Inspira «mostrar antes de exigir». Es relato independiente, no captura validada por mí.
https://x.com/tanmays/status/2109697027680751901
Elogia háptica/onboarding de Milepost, pero dice aún no haber usado el producto en viaje. Útil para separar primera impresión de uso sostenido; no permite especificar qué gesto funciona.
https://x.com/Glassappdotdev/status/2115843512319000796
Cuenta de producto anuncia swipe, háptica y onboarding/acceso más suaves. Confirma intención declarada, no calidad ni resultado. No copiar splash animado por ser tendencia.

## Contradicciones resueltas
- «Más corto siempre» frente a onboarding largo de Duolingo: ninguno es regla. NN/g y Apple justifican solo lo necesario; una lección es el propio valor de una app educativa. En Yala una encuesta larga no es una experiencia financiera valiosa por sí misma. Se excluyen números de pasos y supuestas mejoras de retención no comprobadas.
- «Cuenta después» frente a banca con identidad primero: depende de requisitos reales. Yala puede demostrar con ficción en artifact, sin prometer acceso invitado de producción.
- «Añadir motion/háptica a todo» frente a tranquilidad: adoptar semántica y control de Apple, no intensidad de clips promocionales. No se han visto esos vídeos.
- Personalización frente a sobrecarga: preguntar solo algo que cambie un resultado perceptible inmediato; no coleccionar preferencias que no se usan.

## Tres direcciones genuinamente diferentes (hipótesis de diseño)
A · Mesa viva — recomendada para explorar primero.
Welcome como una pequeña escena manipulable: tarjetas ficticias se ordenan al tocar (arrastre opcional con alternativa botón); se entiende un beneficio sin leer una lista. Cuenta aparece en una hoja clara sin perder el contexto; primera llegada retoma ese lenguaje pero distingue inequívocamente datos ficticios de estado real vacío. Sin escribir ni guardar transacciones. Diversión por causa/efecto, no mascota. Renuncia: es la más sensible a límites web/háptica y exige prueba de comprensión.
B · Portada editorial — la alternativa más simple.
Tipografía grande y una composición abstracta con colores Yala; una promesa concreta, empezar y «Ya tengo cuenta» visibles. Acceso directo con proveedores actuales, primera llegada tranquila y una siguiente acción existente. Sin carrusel ni práctica. Movimiento de composición breve y cancelable. Renuncia: menos sorpresa, más claridad; sirve como control para decidir si A añade valor o solo ruido.
C · Recorrido cinematográfico bajo control.
Welcome como una historia visual continua, no mazo de diapositivas: al tocar avanzar, una misma forma pasa de caos ficticio a claridad y luego enmarca cuenta y primera llegada. Saltar y acceder siempre disponibles; teclado no compite con animación. El gesto no es obligatorio y Reduce Motion conserva escenas estáticas legibles. Renuncia: puede convertirse en publicidad; cada transición debe comunicar algo que B no comunique ya, o se elimina.

Las tres preservan colores de marca y ausencia de mascota; cambian estructura, ritmo e interacción, no solo decoración. Todas cubren Welcome → crear/acceder cuenta → primera llegada con el mismo contenido/caso para comparar justamente.

## Criterio de elección y límites
Comparar si se entiende qué hace Yala y dónde acceder, esfuerzo antes de primera llegada, claridad de ejemplo frente a dato real, cancelación y recuperación, y accesibilidad completa. Recomendar A como hipótesis de identidad diferenciada, B como referencia de claridad; elegir definitivamente solo tras ver prototipos. No hay estudios Yala, métricas fabricadas ni validación física en esta investigación. No se tocó Mac, app, cola ni rutinas; no se lanzó Claude.
Artifact nativo de Claude sigue siendo condición, no capacidad comprobada aquí. No sustituir con HTML/PDF/Canvas y no confundir feedback web con capacidades nativas. Mantener sesión abierta CIERRAS-TÚ, único aviso final de propuestas listas; dudas con Jürgen en esa misma sesión.

## Paso 0 — decisiones (tomadas en la sesión, a la vista de Jürgen)

1. **Formato:** artifact nativo de página (privado), no el tipo «Design» de lienzo: el encargo pide un prototipo navegable con selector, variantes, repetición de animaciones y estados de teclado/espera/cancelación, y el lienzo no admite interfaz construida por script. Capacidad comprobada con la herramienta Artifact en esta sesión (quickstart y publicación).
2. **Base de lectura:** `origin/2.3` en solo lectura (el worktree nació de 2.2). Ningún cambio de código de producto.
3. **Semántica de hoy, medida en 2.3:** nube primero y sin recomendar; consentimiento antes de crear cuenta en la nube; Apple y Google como únicos proveedores; restaurar desde iCloud; reabrir Yala con iCloud privado y al restaurar; ningún permiso en el alta. Lo que las propuestas cambian se rotula como dependencia futura.
4. **Bienvenida real en el iPhone 14:** no se muestra. El arranque `-uitest` purga del almacén persistente las marcas de onboarding hecho; reiniciar el estado está prohibido. Evidencia de la app real: Panel actual del iPhone 14 y capturas de simulador del 6-nov (revisión de 2.3), rotuladas.
5. **`~/Claude/referencias-ui/README.md` no existe** en la Max. Se usó la referencia de entrada guardada en `docs/design/referencias/` (memoria «referencia de UI para onboarding»), sin copiar marca ni pantalla.
6. **Decisión previa sobre «aplazar la bienvenida»:** no hay una registrada con ese nombre. Lo más cercano se cita en el artifact (L1-4, L1-12, tutoriales a 2.4).
7. **Accesibilidad en el teléfono físico:** Reducir movimiento, texto grande, contraste y modo claro se simulan en la página; no se cambian ajustes del iPhone.
8. **Aviso al bot:** `avisar_grok.py` rechaza avisos de artifact y `ListAgents` no muestra ninguna sesión a la que mandar. La frase «Propuestas listas; artifact: …» queda visible en la sesión y en el artifact.
9. **Recomendación:** explorar A con las pantallas de cuenta tan claras como en B. Decide Jürgen.
