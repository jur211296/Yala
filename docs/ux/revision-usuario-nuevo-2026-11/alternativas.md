# Alternativas por parte del recorrido

Acompaña a [`README.md`](README.md). Para cada parte del recorrido hay de 3 a 5 alternativas concretas. **Ninguna
está elegida.** Las fricciones (F1…F24) son las del mapa del README, §3.

## Cómo leer las tablas

- **Esfuerzo:** S (días), M (una o dos semanas de una sesión), L (varias sesiones o un encargo propio). Es una
  estimación del tamaño del cambio, no una medida.
- **Riesgo:** qué se puede romper. *Alto* = toca sync, arranque del almacenamiento, cálculos o migraciones.
- **Compatibilidad**, en este orden: **Pr** privado/iCloud · **Nu** nube · **Id** 16 idiomas · **Ac** accesibilidad
  (VoiceOver y texto grande) · **iP** iPad. ✓ = no le afecta o lo resuelve igual; ⚠ = hay trabajo o riesgo
  específico, explicado en la fila.
- **Reabre** = contradice una decisión ya tomada en la auditoría 2.2. Lo dice y por qué podría valer la pena.

Las referencias de `~/Claude/referencias-ui/` se usaron como inspiración de patrones (onboarding crema, métrica con
tendencia, línea de tiempo vertical, del reel de Kargul), no como pantallas a copiar.

---

Las alternativas van por letra según la parte: A bienvenida, B onboarding, C Panel, D Primeros pasos, E cuenta, H presupuesto, G pago, V conversacional. **F** se reserva para las fricciones.

## 1. Bienvenida y entrada (F1, F2, F3)

| Alt. | Qué cambia | A favor | En contra | Esf. | Riesgo | Depende de | Compat. |
|---|---|---|---|---|---|---|---|
| **A1** · Avisar del reinicio desde el selector | «Es mi primera vez» dice antes de tocar que la app se cerrará una vez, y la pantalla de reinicio ofrece un botón que cierra Yala por la persona | Barato; quita la sorpresa; el botón ahorra ir a la pantalla de inicio | Sigue habiendo salida; cerrar la app por programa es frágil y Apple lo desaconseja: hay que validarlo con la revisión de la App Store | S | Bajo-medio (revisión de la App Store si se fuerza el cierre) | Copy en 16 idiomas | Pr ⚠ es su camino · Nu ✓ · Id ⚠ · Ac ✓ · iP ✓ |
| **A2** · Diferir la conexión a iCloud | Empezar en local sin reinicio; conectar con iCloud en el siguiente arranque natural, con un aviso discreto | Elimina F1 en el momento más frágil | Durante la primera sesión los datos no están en iCloud; hay que migrar el almacenamiento con datos dentro. **Reabre L1-4** | L | **Alto**: arranque de SwiftData con CloudKit, migración del store | Review adversarial; `.claude/rules/swiftdata-cloudkit.md` | Pr ⚠ · Nu ✓ · Id ✓ · Ac ✓ · iP ✓ |
| **A3** · Recrear el almacenamiento sin salir | La app cambia en caliente a la configuración con iCloud tras la comprobación | Ni reinicio ni espera | Hipótesis técnica sin comprobar: SwiftData con CloudKit no está pensado para cambiar de contenedor con la app viva. Puede ser inviable | L | **Alto** | Prueba de concepto antes de proponerla en serio | Pr ⚠ · Nu ✓ · Id ✓ · Ac ✓ · iP ✓ |
| **A4** · Reinicio al final | El onboarding se hace antes (en memoria) y el reinicio llega cuando la persona ya vio «Así queda tu Yala» | La persona ya invirtió y entiende para qué es; el reinicio se vive como «guardar» | Lo escrito debe sobrevivir al reinicio; si la persona no vuelve, se pierde. **Reabre L1-4** | M-L | Alto (estado entre arranques) | Guardar el borrador del onboarding | Pr ⚠ · Nu ✓ · Id ✓ · Ac ✓ · iP ✓ |
| **A5** · Juntar presentación y selector | El carrusel queda arriba y las tres opciones abajo, en una pantalla | Una pantalla menos (F2, F3) | La presentación pierde espacio; más texto a la vez para P7 | S | Bajo | El ticket del estilo del onboarding, hoy en QA | Pr ✓ · Nu ✓ · Id ✓ · Ac ⚠ texto grande · iP ✓ |

---

## 2. Onboarding de 7 pasos (F4-F8)

| Alt. | Qué cambia | A favor | En contra | Esf. | Riesgo | Depende de | Compat. |
|---|---|---|---|---|---|---|---|
| **B1** · Tres pasos y lo demás por defecto | Nombre → moneda → saldo (con «0 por ahora, lo ajusto luego» visible). Una cuenta «Mi dinero», categorías estándar y «Llevar el control» por defecto, todo cambiable después | Ataca F2 y F8: la persona llega al Panel en 4 pantallas desde el selector | Pierde la personalización temprana (tipo de cuenta). Si el saldo pasa a opcional, **reabre L1-7** | M | Medio: lo que crea el onboarding alimenta Panel, widgets y nube | `OnboardingStepPlan` y lo que siembra | Pr ✓ · Nu ⚠ el onboarding de la nube comparte pasos · Id ⚠ copy nuevo · Ac ✓ · iP ✓ |
| **B2** · Una sola pantalla | Formulario único: nombre, moneda y saldo, con «Personalizar más» plegado | Lo más corto posible; P3 y P4 contentos | Una pantalla densa es peor para P2 y P7; pierde el tono de acompañamiento | M | Medio | Igual que B1 | Pr ✓ · Nu ⚠ · Id ✓ · Ac ⚠ texto grande · iP ✓ |
| **B3** · Conversacional con IA | Ver §8 | | | | | | |
| **B4** · Conversacional guionizado, sin IA | Las mismas preguntas como conversación: burbujas de Yala, respuestas en botones y «¿Qué es esto?» con una explicación escrita por paso | Cercano para P2; explica sin costo ni red; 100 % predecible | No acorta; P3 y P4 lo viven como más lento. VoiceOver en una conversación pide diseño cuidadoso | M-L | Medio | Diseño en lienzo: Jürgen elige entre 3-4 propuestas | Pr ✓ · Nu ✓ · Id ⚠ mucho copy · Ac ⚠ · iP ✓ |
| **B5** · Plantillas por intención | El paso 2 ofrece 3-4 puntos de partida («Solo anotar», «Controlar mi sueldo», «Vengo de Excel», «Ahorrar para algo»); cada uno preconfigura pasos, Panel, categorías y Primeros pasos | Cada perfil ve menos; es la base del revelado progresivo (§9) | Más combinaciones que probar; la persona puede no reconocerse en ninguna | M | Medio (Panel por defecto distinto por plantilla) | Amplía el paso «purpose» que ya existe | Pr ✓ · Nu ⚠ los ajustes del Panel viajan · Id ⚠ · Ac ✓ · iP ✓ |
| **B6** · Mejorar lo actual sin recortar | «Todo junto» preelegido en el paso 3, una línea de ayuda por tipo de cuenta, y un resumen final que describa el camino elegido (F7) | Barato; no reabre nada | No ataca el largo (F2, F8) | S | Bajo | — | Pr ✓ · Nu ✓ · Id ⚠ copy · Ac ✓ · iP ✓ |

**Categorías dentro del onboarding (F6).** Cualquiera de B1-B6 puede sumar una de estas dos piezas:

- **(a)** Sembrar las 11 categorías igual, pero **enseñar solo las 5-6 de uso diario** en los selectores hasta que la
  persona use otra. No cambia los datos: es la más segura.
- **(b)** En el paso 6, «¿En qué gastas más?» con 6-8 chips, y sembrar solo esas más «Otros». Cambia lo que se
  siembra, y eso afecta a la nube y a los nombres de categoría por idioma.

---

## 3. Primer Panel (F9-F12)

| Alt. | Qué cambia | A favor | En contra | Esf. | Riesgo | Depende de | Compat. |
|---|---|---|---|---|---|---|---|
| **C1** · Panel del día 1 reducido | Hasta el primer registro, el Panel enseña solo el balance, «Nuevo registro» y Primeros pasos; Tendencias, Planificación y Últimos registros aparecen al tener datos | Nada vacío a la vista (F12); un solo camino claro | Quien quiere verlo todo desde el inicio no sabe que existe; hay que decidir cuándo aparece cada sección (§9.1) | M | Medio: `PanelDefaults` y su sincronización entre dispositivos | §9 | Pr ✓ · Nu ⚠ la config del Panel viaja · Id ✓ · Ac ✓ · iP ⚠ dos columnas con poco contenido |
| **C2** · Estados vacíos con acción | Cada widget vacío dice para qué sirve y trae su botón: «Ponle un límite a tus gastos · Crear presupuesto», «¿Pagas algo cada mes? · Agregar pago»; Tendencias dice cuándo tendrá sentido | Ataca F11 de frente; barato; no esconde nada | Más botones en el Panel, que ya tiene «Nuevo registro» | S | Bajo | Copy en 16 idiomas | Pr ✓ · Nu ✓ · Id ⚠ · Ac ✓ · iP ✓ |
| **C3** · Gráficas de ejemplo | Las gráficas vacías dibujan un ejemplo atenuado con la etiqueta «Ejemplo» | Enseña para qué sirve cada gráfica | En una app de finanzas, un número que no es tuyo puede leerse como tuyo; va contra el cuidado con las cifras que la app ya tiene (la marca ≈) | S-M | **Medio-alto**: confusión con datos reales | Regla de dominio financiero | Pr ✓ · Nu ✓ · Id ✓ · Ac ⚠ VoiceOver debe decir «ejemplo» · iP ✓ |
| **C4** · Orden de avisos del día 1 | Primeros pasos va primero; la guía «Este es tu resumen» se funde con él o no sale el día 1; la oferta Pro del Panel espera al primer registro | Ataca F9 y F10; coherente con L1-12 | Menos exposición a Pro el día 1 | S | Bajo | `PanelNoticeQueueLogic` | Pr ✓ · Nu ✓ · Id ✓ · Ac ✓ · iP ✓ |
| **C5** · Interruptor «Panel simple» | Un modo del Panel con solo balance, acciones y últimos registros, que la persona activa o desactiva | Da control; útil también a P7 | Otra preferencia que mantener; no resuelve el día 1 si no viene activado | M | Bajo-medio | Configurar Panel ya existe | Pr ✓ · Nu ⚠ · Id ✓ · Ac ✓ · iP ✓ |

---

## 4. Primeros pasos, la guía de 7 (F8, F13-F15)

| Alt. | Qué cambia | A favor | En contra | Esf. | Riesgo | Depende de | Compat. |
|---|---|---|---|---|---|---|---|
| **D1** · Solo lo que construye tus finanzas | 3-4 pasos: primer gasto, presupuesto, pago que se repite, otra cuenta. Voz y foto pasan a una sugerencia tras el tercer registro; Ajustes y Pro salen de la lista | Ataca F13: cada paso deja algo útil | Menos descubrimiento de funciones Pro; **reabre en parte L5-1**, que fijó el orden de los 7 | S | Bajo | Copy | Pr ✓ · Nu ✓ · Id ⚠ · Ac ✓ · iP ✓ |
| **D2** · Guía por intención | Los pasos salen de lo elegido en el onboarding: «Solo anotar» → 2 pasos; «Llevar el control» → 4 | P3 no ve presupuestos que no quiere | Necesita B5, o al menos el paso 2 actual; más casos que probar | S-M | Bajo | Paso «purpose» | Pr ✓ · Nu ✓ · Id ✓ · Ac ✓ · iP ✓ |
| **D3** · Sin lista: la siguiente acción | No hay tarjeta de N pasos. Tras cada logro, una sola sugerencia («Ya anotaste 3 gastos. ¿Le pones un límite al mes?») | Elimina el contador (F8); se siente como ayuda y no como tarea | Pierde la vista de conjunto; P4 no puede ir directo a lo que quiere | M | Bajo-medio | Reglas de cuándo sugerir | Pr ✓ · Nu ✓ · Id ⚠ · Ac ✓ · iP ✓ |
| **D4** · Mantener 7 con otro marco | Sin «0 de 7»: progreso en positivo («2 hechos») y «Ocultar» disponible desde el primer día | Barato; respeta lo decidido en el lote 5 | No reduce el número de pasos | S | Bajo | — | Pr ✓ · Nu ✓ · Id ⚠ · Ac ✓ · iP ✓ |
| **D5** · Guía siempre disponible fuera del Panel | La lista vive en Más (o Ajustes › Primeros pasos) y el Panel solo enseña el paso siguiente | Se puede volver a ella; el Panel se aligera | Una entrada más en Más | S | Bajo | — | Pr ✓ · Nu ✓ · Id ✓ · Ac ✓ · iP ✓ |

---

## 5. Crear una cuenta (F19)

| Alt. | Qué cambia | A favor | En contra | Esf. | Riesgo | Depende de | Compat. |
|---|---|---|---|---|---|---|---|
| **E1** · Tarjeta «Agregar cuenta» visible | En «Tus finanzas», una tarjeta vacía junto a la primera cuenta mientras haya menos de 3 | Visible sin desplazar el carrusel | Reabre en parte L3-9 (la variante con chips) | S | Bajo | — | Pr ✓ · Nu ✓ · Id ✓ · Ac ✓ · iP ✓ |
| **E2** · Botón «+» con menú de crear | El «+» flotante del Panel abre: Registro · Cuenta · Presupuesto · Pago planificado | Un solo sitio para crear todo (F11, F19, F20) | Un toque más para lo más común (registrar); hay que ver qué hace hoy el «+» y si la gente ya lo usa como atajo | M | Medio: cambia un gesto aprendido | Medir el uso actual del «+» | Pr ✓ · Nu ✓ · Id ⚠ · Ac ✓ · iP ⚠ en iPad el «+» vive en otra parte |
| **E3** · Crear cuenta desde el registro | El selector de cuenta del formulario de registro trae «Nueva cuenta» | Aparece justo cuando hace falta (P6 al registrar en dólares) | Interrumpe el registro con otro formulario | S-M | Bajo-medio | — | Pr ✓ · Nu ✓ · Id ✓ · Ac ✓ · iP ✓ |
| **E4** · Importar crea las cuentas | Desde la bienvenida o el Panel vacío, importar un estado de cuenta o un Excel crea la cuenta con sus movimientos | Responde a P1 y a la card de backlog «Bienvenida: proponer importar el último estado de cuenta» | Revisar un import lleva tiempo; mete trabajo en el día 1 | M-L | Medio (el import ya existe; la puerta es lo nuevo) | Import de PDF, CSV y Excel | Pr ✓ · Nu ✓ · Id ⚠ formatos por país · Ac ⚠ revisión larga · iP ✓ |

---

## 6. Crear un presupuesto (F16, F17, F24)

| Alt. | Qué cambia | A favor | En contra | Esf. | Riesgo | Depende de | Compat. |
|---|---|---|---|---|---|---|---|
| **H1** · Presupuesto rápido | «¿Cuánto quieres gastar este mes?» con un solo campo: crea un presupuesto mensual de todos los gastos, visible en el Panel | El primer presupuesto en segundos; «Todos mis gastos» ya existe | Uno solo, sin categorías; lo demás queda para editar después | S | Bajo | Lo decidido en L9-2 ya lo permite | Pr ✓ · Nu ✓ · Id ⚠ · Ac ✓ · iP ✓ |
| **H2** · Selector corto | Al elegir categorías: sin «Ingresos», primero las 5-6 más usadas (o las padres sin desplegar) y «Ver todas» | Ataca F24 sin tocar datos; quitar «Ingresos» de un límite de gasto corrige un sinsentido | Con cero registros no hay «más usadas»: el primer día enseña las padres | S | Bajo | `BudgetEditorViewModel` | Pr ✓ · Nu ✓ · Id ✓ · Ac ✓ mejora con texto grande · iP ✓ |
| **H3** · Sugerir presupuestos con datos | Tras 2-4 semanas de registros: «Gastas unos S/ X en Alimentación. ¿Le pones un límite?» | Usa datos reales; nada que configurar | No ayuda el día 1; el cálculo debe aguantar fechas y monedas | M | **Medio-alto**: cálculo financiero | Review adversarial del cálculo | Pr ✓ · Nu ✓ · Id ✓ · Ac ✓ · iP ✓ |
| **H4** · Opciones avanzadas plegadas | Nombre, importe y «¿Qué gastos cuenta?» a la vista; período, widget, alertas y filtros en «Más opciones»; «Mostrar en el widget» encendido para el primer presupuesto (F17) | Formulario corto para el primero; no quita nada | Quien usa filtros los encuentra un toque más abajo | S | Bajo | — | Pr ✓ · Nu ✓ · Id ✓ · Ac ✓ · iP ✓ |
| **H5** · Presupuesto por necesidad | «Esencial / Prioritaria / Opcional»: las subcategorías ya traen ese dato sembrado; un presupuesto por tipo de gasto en vez de por categoría | Tres opciones en vez de 62; enseña a pensar el gasto | Concepto nuevo para P2; hay que explicar qué cae en cada una | M | Medio | El campo de necesidad ya sembrado | Pr ✓ · Nu ✓ · Id ⚠ · Ac ✓ · iP ✓ |

---

## 7. Crear un pago planificado (F18)

| Alt. | Qué cambia | A favor | En contra | Esf. | Riesgo | Depende de | Compat. |
|---|---|---|---|---|---|---|---|
| **G1** · Plantillas | Alquiler, Luz, Agua, Celular, Internet, Streaming: categoría e ícono puestos; solo pide importe y día | Responde «¿qué es un pago planificado?» con ejemplos | Plantillas por país e idioma | S-M | Bajo | Copy y categorías por idioma | Pr ✓ · Nu ✓ · Id ⚠ · Ac ✓ · iP ✓ |
| **G2** · Formulario mínimo | Nombre, importe y día del mes; tipo, cuenta, frecuencia y fecha de inicio en «Más opciones», con valores por defecto | Una sola pantalla | Quien paga cada 2 meses lo busca más abajo | S | Bajo | L10-4 ya reordenó el formulario | Pr ✓ · Nu ✓ · Id ✓ · Ac ✓ · iP ✓ |
| **G3** · Detectar repetidos | Tras dos meses con el mismo gasto: «¿Netflix se repite cada mes? Te aviso antes» | Nada que configurar | No ayuda el día 1; falsos positivos | M | Medio | Heurística sobre registros | Pr ✓ · Nu ✓ · Id ✓ · Ac ✓ · iP ✓ |
| **G4** · «¿Se repite?» al registrar | Hacer visible el paso a pago planificado que ya existe en el formulario de registro | Aparece en el momento justo | El formulario de registro ya es largo | S | Bajo | Ya existe en el código | Pr ✓ · Nu ✓ · Id ✓ · Ac ✓ · iP ✓ |

---

## 8. Onboarding conversacional: ¿IA, guion o mezcla?

Candidata del encargo: un onboarding que pregunte nombre, qué quiere gestionar y saldo, y que deje preguntar o pedir
explicaciones. Aquí se compara con alternativas deterministas y mixtas.

**Hechos de partida** [Cód, `origin/2.3`]:

- Yala IA es **Pro** (`FeatureGateService.swift:31-33`). En el servidor, el plan gratis **no tiene chat**; solo un
  cupo de prueba de foto y voz (`gateway/src/policy.ts:38-44`).
- El chat necesita **red, el servidor propio y App Attest** (`ChatAssistantService.swift:106`,
  `ProxyClientFactory.swift:78`). Contesta con OpenAI `gpt-6-luna` a través del gateway.
- Ya hay IA **en el dispositivo**: «Anotar con Siri» usa Foundation Models para quien no es Pro
  (`Yala/App/Intents/SiriOnDeviceEntry.swift`). Es el único precedente sin servidor.
- Yala IA tiene su propia presentación con el consentimiento al final (`YalaAIOnboardingView.swift`). Un onboarding
  con IA en servidor mandaría nombre y saldo **antes** de ese consentimiento.
- Costo medido de llamadas cortas en el banco de modelos de octubre (`docs/ai-model-bench-2026-10.md`): clasificar
  un mensaje del chat, 0,073 USD por 1 000 llamadas; sugerencias del chat, 0,189 USD por 1 000. **No hay medida de
  una conversación de onboarding.** Para estimarla en serio: llamadas por alta × costo por llamada, medido con el
  mismo banco sobre un guion real. Se pagaría por **cada** alta, también por las que nunca se activan.

| Opción | Qué es | Costo de IA | Sin conexión | Privacidad | Accesibilidad | Idiomas | Riesgo propio |
|---|---|---|---|---|---|---|---|
| **V1** · IA en servidor | El chat actual conduce el alta | Por alta, para todas las instalaciones. Hoy el plan gratis no tiene chat: habría que abrir un cupo nuevo | **No funciona**; además necesita App Attest, que puede fallar en el primer arranque | Nombre y saldo salen del teléfono antes del consentimiento de IA. Choca con «Tus datos, en tu iCloud» del camino privado y con la exigencia de Apple de pedir permiso antes de compartir datos personales con una IA de terceros | Un chat es lineal: va bien con VoiceOver si se diseña; escribir texto libre cuesta más a algunas personas | Los 16, con la calidad del modelo en cada uno | Puede entender mal un importe: el saldo tendría que confirmarse siempre en un campo explícito |
| **V2** · IA en el dispositivo | Foundation Models interpreta las respuestas y explica términos | Cero por llamada | Funciona | Nada sale del teléfono | Igual que V1 | Limitado a los idiomas y aparatos con Apple Intelligence | Solo en iPhone compatibles: el resto necesita igual la ruta determinista. Dos caminos que mantener |
| **V3** · Guion determinista con cara de chat (B4) | Burbujas, respuestas en botones y explicaciones escritas por paso | Cero | Funciona | Nada sale | Controlable: cada burbuja es texto normal | Los 16, con los textos de siempre | Más copy; no responde preguntas libres |
| **V4** · Mixto | V3 para todos, más «Pregúntale a Yala» en cada paso: usa V2 si hay Apple Intelligence, o V1 si es Pro y aceptó la IA | Solo cuando se usa | El guion funciona siempre | La IA solo con consentimiento explícito en ese momento | La de V3; la IA es un extra | Los 16 en el guion | Más piezas; la respuesta de la IA tiene que ceñirse al paso |
| **V5** · Formulario actual mejorado (B1, B6) | Pantallas con campos, sin conversación | Cero | Funciona | Nada sale | La más conocida hoy | Los 16 | No responde dudas; depende de que el texto de ayuda baste |

**Lectura.** V1 no sirve como camino principal: no funciona sin conexión, obliga a abrir el chat al plan gratis y
manda datos antes del consentimiento. Si se quiere el tono conversacional, **V3 da la forma sin ese riesgo**, y V4
suma la IA donde aporta (explicar «cuenta corriente» o «saldo» a P2) sin depender de ella. V2 sirve solo como
mejora en aparatos compatibles. Que la conversación ayude a P2 y estorbe a P3 y P4 es una hipótesis: la prueba de
pasillo (README §7.2) puede confirmarla o tumbarla.

---

## 9. Revelado progresivo, Panel sin los siete pasos y guías contextuales

### 9.1 Revelado progresivo: qué y cuándo

Umbrales propuestos para discutir. No están medidos:

| Qué | Hoy | Aparece cuando… (propuesta) |
|---|---|---|
| Tendencias en el Panel | Desde el día 1, con un punto | Hay registros en 3 días distintos |
| Planificación en el Panel | Desde el día 1, vacía | Hay un presupuesto o un pago; antes, solo si trae su estado vacío con acción (C2) |
| Estadísticas (pestaña) | Siempre | Siempre en la barra, con un estado vacío que diga cuándo tendrá datos |
| Voz y Foto en la fila de acciones | Con candado el día 1 | Igual para Pro; para el plan gratis, tras el 3.er registro y con la prueba que ya existe |
| Salud, Distribución, Herramientas | Ocultas por defecto | Sin cambios |

**Riesgo principal:** que alguien no encuentre algo que sabe que existe (por una reseña, un video). Mitigación: todo
lo oculto sigue en Configurar Panel y en Buscar.

### 9.2 Un Panel útil sin completar los siete pasos

La condición es que el Panel **no dependa** de la guía para tener sentido. Con C2 y C4, el día 1 enseña el balance
del mes con «Tienes S/ X en tus cuentas» (ya existe, L3-1), «Nuevo registro», y cada sección vacía diciendo qué hace,
con su botón. Primeros pasos pasa a ser un atajo, no la puerta. Si se suma C1, lo vacío ni se ve.

### 9.3 Guías contextuales

Hoy conviven cinco mecanismos: banner GUÍA por pantalla, Primeros pasos, guía sombreada de Ajustes, «¡Listo!» en los
3 primeros registros y la cola de avisos del Panel. Tres alternativas:

- **Presupuesto de interrupciones:** como mucho una guía o aviso por sesión durante los primeros 7 días; el resto
  espera. Barato si se centraliza en la cola de avisos que ya existe.
- **Un solo sistema:** fundir el banner GUÍA de cada pantalla con el estado vacío de esa pantalla (si hay datos, no
  hace falta guía). Menos piezas, pero cambia muchas pantallas.
- **Ayuda a demanda:** quitar los banners y dejar el «?» que ya tienen los widgets como única explicación. Lo más
  limpio; deja a P2 sin empujón.

### 9.4 Flujos simplificados para crear

Resumen de las tablas 5-7: un «+» con menú de crear (E2), presupuesto rápido de un campo (H1) con selector corto (H2)
y opciones plegadas (H4), y pago planificado mínimo (G2) con plantillas (G1). Todas son deterministas, no tocan sync
y se pueden hacer por separado.
