# Bienvenida y Primeros pasos · Yala 2.3 — especificación oficial

*9 de noviembre de 2026. Artifact (privado, versión oficial): https://claude.ai/artifact/AcwrfYm96uy8k6Ga2EXnU6*

Prototipo navegable con 8 pestañas; cada card dice en qué pestaña y con qué atajo se ve. El artifact incluye esta misma especificación y un bloque JSON (`#yala-spec`).

## Cómo usar esta especificación

- Esta versión es la OFICIAL. Lo que no está aquí no se construye; lo que está aquí no se cambia sin una decisión nueva de Jürgen.
- Cada card se implementa tal como se ve en su pestaña del artifact y con los textos exactos de su ficha. Si el artifact y la ficha no coinciden, manda la ficha y se avisa.
- «Existe hoy» = ya está en la app 2.2/2.3 (se reutiliza). «Nuevo» = hay que construirlo. «Dependencia» = necesita una decisión, backend o App Store Connect antes.
- Los datos de ejemplo del prototipo (Ana, «Mi dinero», S/ 1,500, los registros del tutorial, el recibo) son solo para mostrar: la app usa los de la persona.
- Textos: español neutro, con «tú», según docs/planning/BRAND-VOICE.md. Los textos marcados «de la app» se copian de Localizable.strings, no se reescriben.
- Solo modo oscuro en la bienvenida (fondo F2). El resto sigue el tema de la app.
- Accesibilidad en todas: Reducir movimiento deja solo fundidos y las páginas que avanzan solas se quedan quietas; VoiceOver no avanza solo; texto grande no corta.

## Índice de cards

| ID | Card | Dónde se ve | Estado |
|---|---|---|---|
| Y23-01 | Bienvenida con vitrina y accesos | 1 · Mis finanzas | Nuevo (rediseño de la bienvenida) |
| Y23-02 | Acceso con Google o Apple: el servidor decide | 1 · Mis finanzas (mando «Qué pasa con ese correo») | Nuevo (verificar siempre) |
| Y23-03 | Entrar con iCloud privado | 1 · Mis finanzas (botón iCloud) | Existe con ajustes |
| Y23-04 | Conversación de tres preguntas | 1 · Mis finanzas | Nuevo |
| Y23-05 | Llegada y mazo de «Primeros pasos» (7 pasos) | 3 · Primera cuenta (Llegada) y todas las de Primeros pasos | Nuevo |
| Y23-06 | Entrada por Grupos (quien llega por un grupo) | 2 · Viene por grupos | Existe con ajustes |
| Y23-07 | Paso 1 · Crear la primera cuenta | 3 · Primera cuenta | Nuevo (preguntas en vez del formulario; mismos datos) |
| Y23-08 | Paso 2 · Aprender a registrar: página y formulario con guía de foco | 4 · Nuevo registro | Nuevo (guía); el formulario existe |
| Y23-09 | Paso 2 · Voz, foto y Yala IA con prueba de cortesía | 4 · Nuevo registro | Existe (voz y foto) · Nuevo (IA) |
| Y23-10 | Paso 2 · Cierre: borrar registros de prueba, Panel lleno y Bandeja | 4 · Nuevo registro (Panel final) | Nuevo |
| Y23-11 | Paso 3 · Primer presupuesto | 5 · Primer presupuesto | Nuevo (preguntas en vez del formulario; mismos datos) |
| Y23-12 | Paso 4 · Primer pago planificado | 6 · Pagos planificados | Nuevo (preguntas); el modelo existe |
| Y23-13 | Paso 5 · Grupos (su onboarding, con este estilo) | 7 · Grupos (paso 5) | Existe con ajustes |
| Y23-14 | Paso 6 · Mira a dónde va tu dinero | 8 · Pasos 6 y 7 | Nuevo (guía) |
| Y23-16 | Paso 7 · Anota sin abrir Yala (cinco mini tutoriales) | 8 · Pasos 6 y 7 | Existe (widget, Apple Pay, compartir, Siri) · Nuevo (correo) |
| Y23-18 | Final · Primeros pasos completos y prueba de Pro de 30 días | 8 · Pasos 6 y 7 (final) | Existe con ajustes |
| Y23-15 | Pestañas por defecto y «dónde vive cada cosa» | Todas (barra de abajo) · 4 · Nuevo registro (Días después) | Nuevo (cambio de valores por defecto) |
| Y23-17 | Permisos dentro del tutorial | 3, 4, 5 y 6 | Nuevo (momentos) |
| Y23-19 | Correo automático (feature nueva) | 8 · Pasos 6 y 7 (mini tutorial 4) | Nuevo · requiere decisión |

## A · Bienvenida y alta

### Y23-01 · Bienvenida con vitrina y accesos

**Estado:** Nuevo (rediseño de la bienvenida) · **Dónde:** pestaña 1 · Mis finanzas · atajo `#fin`

**Qué ve la persona**

- Vitrina que rota sola con seis funciones reales de Yala (foto y voz con rótulo PRO), con pausa al tocar y deslizar entre funciones. Grupos va DENTRO de la vitrina («Dividir gastos con amigos»).
- Debajo, tres accesos: «Entrar con Google», «Entrar con Apple» (mismo tamaño que Google, estilos oficiales) y la tarjeta «Entrar con mi iCloud privado» con su línea dentro.
- Fondo F2: base oscura con el índigo como brillo detrás de la vitrina. Solo modo oscuro.

**Textos exactos:** «Entrar con Google» · «Entrar con Apple» · «Entrar con mi iCloud privado»

**Ya existe en la app**

- Las seis funciones y sus textos.
- Inicio de sesión con Google y Apple.

**Hay que construir**

- Vitrina, fondo F2 y un único botón por proveedor que crea o entra según exista la cuenta (sin «Empezar» ni «Ya tengo una cuenta»).

**Fuera de alcance**

- Modo claro de la bienvenida.
- Mascota: hay un espacio reservado (círculo punteado) para sumarla después.

**Está bien cuando**

- La vitrina rota sola, se pausa al tocar y respeta Reducir movimiento.
- Los tres accesos llevan a su caso (Y23-02 / Y23-03).


### Y23-02 · Acceso con Google o Apple: el servidor decide

**Estado:** Nuevo (verificar siempre) · **Dónde:** pestaña 1 · Mis finanzas (mando «Qué pasa con ese correo») · atajo `#fin`

**Qué ve la persona**

- Tras la hoja del sistema, «Verificando tu cuenta…».
- Correo sin cuenta: «Vamos a crear tu cuenta» con el aviso de la nube en la misma hoja → «Creando tu cuenta…» → conversación (Y23-04).
- Correo con cuenta: «¿Cargamos tus datos y entramos?» → «Conectando con tu cuenta…» con porcentaje (a los 8 s: «Esto puede tardar unos minutos. Mantén Yala abierta.») → llegada con sus datos.
- Casos especiales con los textos de hoy: misma cuenta con el otro proveedor; en este iPhone hay una cuenta del otro proveedor (entrar con él o crear otra); otro dispositivo preparando la cuenta («Continuar a la app»); datos de otra cuenta en el dispositivo; sin conexión («Reintentar»); cuenta no disponible («Escribir a soporte»).

**Textos exactos:** «Verificando tu cuenta…» · «Vamos a crear tu cuenta» · «¿Cargamos tus datos y entramos?» · «Creando tu cuenta…» · «Conectando con tu cuenta…»

**Ya existe en la app**

- Los textos de los casos especiales y la fase «Verificando tu cuenta…».

**Hay que construir**

- Verificar SIEMPRE al entrar (hoy solo con «Ya tengo una cuenta»), para que un botón sirva para crear y para entrar.
- Consentimiento de la nube dentro de la hoja «Vamos a crear tu cuenta».

**Dependencias y decisiones**

- Saber con qué proveedor se creó la cuenta en un iPhone nuevo (lo tendría que contestar el servidor).
- Validar que el aviso dentro de la hoja sigue siendo un consentimiento explícito.

**Fuera de alcance**

- —

**Está bien cuando**

- Cada caso del mando muestra su pantalla y su texto.


### Y23-03 · Entrar con iCloud privado

**Estado:** Existe con ajustes · **Dónde:** pestaña 1 · Mis finanzas (botón iCloud) · atajo `#fin-icloud`

**Qué ve la persona**

- Revisa iCloud. Sin datos: reabre Yala y sigue a la conversación. Con datos: «Traer mis datos», reabre y restaura.
- Con iCloud privado no hay Grupos en la bienvenida (Grupos exige cuenta de Yala; ver Y23-12).

**Textos exactos:** «Traer mis datos»

**Ya existe en la app**

- El flujo de iCloud privado.

**Hay que construir**

- Encaje visual con la bienvenida nueva.

**Dependencias y decisiones**

- Quitar el reinicio de iCloud privado es un cambio técnico aparte.

**Fuera de alcance**

- —

**Está bien cuando**

- Con y sin datos llegan a su destino.


### Y23-04 · Conversación de tres preguntas

**Estado:** Nuevo · **Dónde:** pestaña 1 · Mis finanzas · atajo `#fin-s_nombre`

**Qué ve la persona**

- Yala pregunta en chat y la tarjeta «Tu Yala» se llena arriba: 1) nombre («Sí, llámame Ana» propone el de Google/Apple; con iCloud se escribe), 2) moneda, 3) qué llevar: «Gastos e ingresos» o «Solo gastos» (con «¿Cuál es la diferencia?» que se explica en dos frases y desaparece).
- Las categorías van siempre por defecto: se quita «Prefiero crearlas yo» del alta. Ya no se pregunta dónde está tu dinero, cuánto tienes ni las categorías.

**Textos exactos:** «Gastos e ingresos» · «Solo gastos» · «¿Cuál es la diferencia?»

**Ya existe en la app**

- Los dos modos («Llevar el control» y «Solo anotar») con otro texto.

**Hay que construir**

- Proponer el nombre que trae Google o Apple.

**Fuera de alcance**

- —

**Está bien cuando**

- Termina en la llegada (Y23-05) con nombre, moneda y modo guardados.


### Y23-05 · Llegada y mazo de «Primeros pasos» (7 pasos)

**Estado:** Nuevo · **Dónde:** pestaña 3 · Primera cuenta (Llegada) y todas las de Primeros pasos · atajo `#cta`

**Qué ve la persona**

- Llegada tranquila: «Hola, Ana.», el cero en su moneda y una sola acción.
- La acción es el MAZO de Primeros pasos: adelante el paso actual («Primeros pasos · N de 7» + el paso, en morado) y asomando detrás los dos siguientes («Después: …», «Luego: …»). «Ver los 7 pasos» abre la lista con los hechos marcados.
- Los 7 pasos, en orden: 1 Crea tu primera cuenta · 2 Aprender a registrar · 3 Crea tu primer presupuesto · 4 Anota tus pagos fijos · 5 Divide gastos con tu grupo · 6 Mira a dónde va tu dinero · 7 Yala en tu pantalla de inicio.
- En el Panel, cuando ya están las acciones (Nuevo registro, Voz, Foto, Yala IA), el mazo va DEBAJO de ellas.
- Con «Solo gastos»: «Anotar el primer gasto» y Yala crea sola «Gastos Soles», como hoy.

**Textos exactos:** «Primeros pasos · 1 de 7» · «Ver los 7 pasos» · «Seguir donde iba»

**Ya existe en la app**

- «Primeros pasos» existe como lista de 7 (SetupChecklistManager); se reemplaza su forma.

**Hay que construir**

- Mazo apilado y los 7 pasos guiados de este orden.

**Fuera de alcance**

- Guía, «Primeros pasos · 0 de 7» y oferta Pro en la llegada.

**Está bien cuando**

- El mazo avanza al completar u omitir cada paso y desaparece al terminar el 7 (Y23-16).


### Y23-06 · Entrada por Grupos (quien llega por un grupo)

**Estado:** Existe con ajustes · **Dónde:** pestaña 2 · Viene por grupos · atajo `#grp`

**Qué ve la persona**

- Tres caminos: crear un grupo / tengo un enlace / solo crear mi cuenta (Grupos vacío). Con enlace de invitación, el orden de hoy: tarjeta del grupo, tu nombre y «Unirme al grupo», y después la cuenta.

**Textos exactos:** «Unirme al grupo»

**Ya existe en la app**

- Pantallas de Grupos de la app.

**Hay que construir**

- Encaje con la bienvenida nueva.

**Fuera de alcance**

- Splitwise y Tricount salen del alta.

**Está bien cuando**

- Los tres caminos y la invitación llegan a su destino.


## B · Primeros pasos

### Y23-07 · Paso 1 · Crear la primera cuenta

**Estado:** Nuevo (preguntas en vez del formulario; mismos datos) · **Dónde:** pestaña 3 · Primera cuenta · atajo `#cta-s_cuenta.intro`

**Qué ve la persona**

- Página corta «qué son las cuentas» (E2): 3 partes que avanzan cada 3,4 s (¿Qué es una cuenta? · Así se ven tus cuentas · ¿Por qué tenerlas al día?), con «Crear mi primera cuenta» siempre visible.
- Preguntas con la tarjeta de la cuenta llenándose arriba: tipo (Efectivo, Cuenta corriente, Ahorros, Tarjeta de crédito, Todo junto) → moneda → nombre → saldo por moneda → (tarjeta) cierre, pago y recordatorio → ¡Lista! (con «Crear otra cuenta»).
- MONEDA: un selector con la moneda del país ya puesta y al lado «+ Añadir moneda» (hasta 4). Tocar un selector cambia la moneda; × quita las añadidas. Botón «Continuar». Texto: «¿Tienes también en dólares u otra moneda? Añádela.» (tarjeta: «¿También pagas en dólares u otra moneda? Añádela.»).
- NOMBRE: cuenta corriente, ahorros y tarjeta → la persona lo escribe (ejemplo en el campo: «Cuenta sueldo», «Ahorro viaje», «Visa del trabajo»). Efectivo y Todo junto → «¿La llamamos «Efectivo» / «Mi dinero»?». El nombre no lleva la moneda. Sin lista de bancos.
- SALDO por cada moneda: «¿Cuánto tienes hoy en soles?» → «¿Y en dólares?»; en tarjeta «¿Cuánto debes hoy…?». Salidas: escribirlo, «No sé, ayúdame a sacarlo», «Empiezo en 0» / «No debo nada». El signo va en un botón + / − junto al campo (fuera de tarjeta).
- AYUDA del saldo con palabras simples: tarjeta → «Tu límite» y «Lo que te queda» con una barra de lo usado; las demás → sumar dónde tienes dinero.
- TARJETA: «¿Qué día cierra tu tarjeta?» (explica para qué: cuánto vas a pagar y en qué mes cae cada compra) y «¿Hasta qué día puedes pagarla?» (para recordarte y evitar intereses): se escribe el día (1–31) o «No lo sé» / «Prefiero no decirlo». Recordatorio «¿Cuándo te recordamos pagarla?»: el mismo día, 1, 3 o 5 días antes, o «No me lo recuerdes»; sin día de cierre solo el mismo día y sin monto. Sin día de pago se salta el recordatorio.
- Si elige recordatorio y no hay permiso: aviso de iOS de notificaciones (Y23-17).
- Panel final: la cuenta (o varias en carrusel, una tarjeta por cuenta; las otras monedas van dentro de su tarjeta) y el mazo en el paso 2: «Aprender a registrar».

**Textos exactos:** «Crear mi primera cuenta» · «¿Tienes también en dólares u otra moneda? Añádela.» · «+ Añadir moneda» · «Continuar» · «No sé, ayúdame a sacarlo» · «Empiezo en 0» · «No debo nada» · «Tu límite» · «Lo que te queda» · «¿Qué día cierra tu tarjeta?» · «¿Hasta qué día puedes pagarla?» · «No lo sé» · «Prefiero no decirlo» · «¿Cuándo te recordamos pagarla?» · «No me lo recuerdes» · «Crear otra cuenta»

**Ya existe en la app**

- Los campos del formulario de cuenta, la calculadora de saldo y las «líneas en otra divisa» (parentAccountID) de cualquier cuenta.
- Opciones de recordatorio 0/1/3/5 (CreditCardStatementLogic).

**Hay que construir**

- Crear preguntando; moneda con líneas ANTES de guardar (hoy se ofrece después); textos simples del saldo y la ayuda; día escrito con «No lo sé»/«Prefiero no decirlo».

**Dependencias y decisiones**

- Tope de 4 monedas por cuenta: decisión de producto (la app hoy no fija tope).

**Fuera de alcance**

- Número de cuenta, «Excluir de las estadísticas»: quedan en Editar cuenta.
- Página E1 y E3 (descartadas).

**Está bien cuando**

- Una tarjeta en soles y dólares queda como principal + línea en USD con su saldo.
- El recordatorio guarda 0/1/3/5 días y pide el permiso solo si se eligió.


### Y23-08 · Paso 2 · Aprender a registrar: página y formulario con guía de foco

**Estado:** Nuevo (guía); el formulario existe · **Dónde:** pestaña 4 · Nuevo registro · atajo `#reg`

**Qué ve la persona**

- Arranca en la MISMA pantalla con que termina crear cuenta; el mazo dice «Aprender a registrar» (2 de 7).
- Página «Cuatro maneras de anotar» (4 partes, 3,4 s): A mano · Con la voz · Con una foto · Con Yala IA (las tres últimas con PRO y «Aquí la pruebas gratis una vez»). «Empezar a mano» / «Omitir este paso».
- A mano: el formulario de HOY tal cual (NewTransactionView) con la guía de foco de la app (CoachMarkOverlay): oscurece todo menos lo que toca, en 5 pasos: 1 «Empieza por el monto» · 2 «¿En qué fue?» (abre la hoja real de categorías) · 3 «Tu cuenta ya está puesta» (es la única) · 4 «Un nombre, si quieres» (Escribir / Saltar) · 5 «Guárdalo». «Omitir guía» en cada uno. Al guardar, «¡Listo!» de los primeros registros.

**Textos exactos:** «Aprender a registrar» · «Cuatro maneras de anotar» · «Empieza por el monto» · «¿En qué fue?» · «Tu cuenta ya está puesta» · «Un nombre, si quieres» · «Guárdalo» · «Omitir guía»

**Ya existe en la app**

- El formulario, la hoja de categorías y la pantalla «¡Listo!».
- La guía de foco (hoy se usa en el tour Pro).

**Hay que construir**

- Usar la guía de foco en el formulario y la página de las cuatro maneras.

**Fuera de alcance**

- Rediseñar el formulario (las variantes R1, R2 y R3 se descartaron).

**Está bien cuando**

- Cada paso de la guía avanza al hacer la acción; «Omitir guía» deja el formulario normal.


### Y23-09 · Paso 2 · Voz, foto y Yala IA con prueba de cortesía

**Estado:** Existe (voz y foto) · Nuevo (IA) · **Dónde:** pestaña 4 · Nuevo registro · atajo `#reg-s_reg.voz`

**Qué ve la persona**

- Entre una manera y otra, una pantalla con las cuatro (hecha / omitida / la que sigue), lo ya anotado y «Probar …» / «Omitir».
- Voz (VoiceRecordingView de hoy): primero el aviso de IA de Yala y el aviso de iOS del micrófono; «Escuchando…» con su ejemplo, transcripción en vivo, «Transcribiendo… / Entendiendo tu registro… / Preparando tu registro…», «Esto entendí» y «Guardar». Si niega el micrófono, se explica Ajustes y se sigue.
- Foto (ImageSelectionView): aviso de iOS de la cámara; Cámara / Fotos / Archivo y «Usar el recibo de ejemplo» (la imagen de ejemplo de la app); «Leyendo tu foto…», «Esto leí», «Guardar».
- Yala IA (ChatSheetView): guía de foco en «Apunta un gasto»; se escribe «Pagué 45 de luz» y responde con la tarjeta de borrador (Descartar / Detalles / Guardar).
- Franja arriba: «Prueba de cortesía: …, una vez gratis» con «Omitir».

**Textos exactos:** «Prueba de cortesía: la voz, una vez gratis» · «Yala lo apunta por ti» · «Esto entendí» · «Esto leí» · «Usar el recibo de ejemplo»

**Ya existe en la app**

- Prueba de cortesía de voz y foto en «Primeros pasos» (FeatureGateService.enableSetupTrial) con imágenes de ejemplo.
- Las tres pantallas y el aviso de IA.

**Hay que construir**

- Prueba de cortesía de Yala IA (hoy el chat es solo Pro).

**Fuera de alcance**

- —

**Está bien cuando**

- Con cuenta Free, cada una funciona una vez dentro del tutorial y el registro se guarda de verdad; después vuelve el candado.


### Y23-10 · Paso 2 · Cierre: borrar registros de prueba, Panel lleno y Bandeja

**Estado:** Nuevo · **Dónde:** pestaña 4 · Nuevo registro (Panel final) · atajo `#reg-s_reg.fin`

**Qué ve la persona**

- Al terminar sube una hoja a media altura: «¿Borramos los de prueba?» con los 1–4 registros del tutorial, todos marcados; se desmarcan los que se conservan. «Borrar N registros» (rojo) / «Conservarlos todos». Aviso «Borramos N registros de prueba».
- Al cerrarla, el Panel se LLENA: vuelven las acciones originales (Nuevo registro, Voz, Foto, Yala IA con su candado Free) y desde aquí la app funciona normal. Barra de arriba de hoy: Bandeja a la izquierda; filtros, Configurar Panel y perfil a la derecha.
- Debajo de la cuenta, SOLO el widget «Últimos registros». La pestaña Más lleva un punto de «algo nuevo».
- Guía de foco sobre la Bandeja: «Lo que Yala anota solo — Aquí llegan los registros que se preparan sin ti —tus pagos planificados, Apple Pay o lo que dejes sin guardar de voz o foto— para que los revises y los apruebes.» «Entendido».
- Mazo en el paso 3 («Crea tu primer presupuesto»).

**Textos exactos:** «¿Borramos los de prueba?» · «Borrar N registros» · «Conservarlos todos» · «Lo que Yala anota solo»

**Ya existe en la app**

- «¿Era de prueba?» del primer registro (se amplía a los del tutorial).

**Hay que construir**

- La hoja con selección y el Panel que se llena al terminar.

**Fuera de alcance**

- Widgets de gráficas en el Panel recién creado (ver Y23-15).

**Está bien cuando**

- Borrar devuelve el saldo y quita los registros; conservar los deja en Últimos registros.


### Y23-11 · Paso 3 · Primer presupuesto

**Estado:** Nuevo (preguntas en vez del formulario; mismos datos) · **Dónde:** pestaña 5 · Primer presupuesto · atajo `#pre`

**Qué ve la persona**

- Página corta (3 partes): «Un tope para lo que gastas» (tarjeta con título «Tu tope de este mes»), «Tú eliges qué cuenta» (chips que se marcan solos, con borde y ✓), «Yala te avisa a tiempo» (aviso de ejemplo + tarjeta «Si te pasas, lo ves en rojo»).
- Preguntas con la tarjeta del presupuesto (BudgetRowView) llenándose: ¿Qué gastos cuenta? (Todos mis gastos / Solo algunas categorías) → ¿Cuáles? (TODAS las categorías de gasto en rejilla de 3 tarjetas iguales con su icono; las que tienen gasto dicen «Llevas S/ X») → ¿Algo que no quieras contar? (subcategorías de lo elegido, en círculos de 4 columnas, TODAS marcadas; se quita lo que no entra) → ¿Cada cuánto se renueva? (Mensual, Semanal, Anual, Una sola vez con fechas) → ¿Cuánto como máximo? → nombre sugerido → ¿Te avisamos cuando vayas llegando al tope? (75 % y 100 % / solo 100 % / No) → ¿Lo ponemos en tu Panel? → ¡Listo!
- Si elige aviso y no hay permiso: aviso de iOS de notificaciones (Y23-17).
- Al terminar: guía «Tus presupuestos viven en Más» sobre la pestaña Más; al tocarla, la pantalla Más con foco en Presupuestos («Aquí están tus presupuestos»). Panel con el widget «Presupuestos» (si dijo sí) y mazo en el paso 4.

**Textos exactos:** «Un tope para lo que gastas» · «Tú eliges qué cuenta» · «Yala te avisa a tiempo» · «¿Qué gastos cuenta?» · «¿Cuáles?» · «¿Algo que no quieras contar?» · «¿Cada cuánto se renueva?» · «¿Te avisamos cuando vayas llegando al tope?» · «¿Lo ponemos en tu Panel?» · «Tus presupuestos viven en Más» · «Aquí están tus presupuestos»

**Ya existe en la app**

- Campos de Budget/BudgetEditorView, umbrales de alerta y «Mostrar en el widget».
- Categorías y subcategorías del seed (CategorySeed.swift).

**Hay que construir**

- Crear preguntando; mostrar lo gastado por categoría al elegir; 75 % y 100 % propuestos por defecto.

**Fuera de alcance**

- Cuentas, etiquetas, necesidad, gastos de grupo, 50 %/90 % y personalizar: quedan en Editar presupuesto.
- Sugerir el monto (la app no lo hace; no se inventa).

**Está bien cuando**

- El presupuesto guarda las subcategorías marcadas (subcategoryIDs) y el período elegido.


### Y23-12 · Paso 4 · Primer pago planificado

**Estado:** Nuevo (preguntas); el modelo existe · **Dónde:** pestaña 6 · Pagos planificados · atajo `#pag`

**Qué ve la persona**

- Página corta (3 partes): «Lo que pagas cada mes» · «Llega a tu Bandeja» (siempre como borrador para aprobar) · «Te avisamos antes» (texto real «Mañana toca pagar … 💰»).
- Pantalla 1: ¿Qué pagas cada cierto tiempo? Seis SUBCATEGORÍAS con nombre corto: Renta (Alquiler o hipoteca), Servicios (Servicios del hogar), Comunicación (Telefonía y comunicaciones), Suscripción de utilidad, Suscripción de ocio, Fitness (Fitness y actividad física). «Otra subcategoría» abre una hoja con todas las de gasto agrupadas (círculos de 4 columnas, buscador); la elegida queda como tarjeta con «Cambiar». En la misma pantalla «Es una suscripción» (encendido en las dos de suscripción). «Continuar». Sin marcas (nada de Netflix).
- Pantalla 2: nombre y monto juntos. Nombre precargado con el tipo («Servicio») que se borra o cambia, con ejemplos para tocar (Luz, Agua, Gas…), monto y «Cambia cada vez» (monto estimado; encendido en Servicios).
- Pantalla 3: ¿Cuándo toca pagar? frecuencia (Cada mes / Cada semana / Cada año / Una vez) y el día.
- Pantalla 4: ¿Te avisamos antes de que toque pagar? (3 días antes por defecto, 1 día antes, el mismo día, No). Aquí se piden/reintentan las notificaciones (Y23-17).
- Pantalla 5: ¿Lo ponemos en tu Panel? → ¡Listo! («El 1 de diciembre llegará a tu Bandeja para que lo apruebes») con «Anotar otro pago».
- Al terminar: guía «Tus pagos planificados viven en Más» → pantalla Más con foco en Pagos planificados. Widget «Pagos planificados» en el Panel solo si dijo sí. Mazo en el paso 5.

**Textos exactos:** «¿Qué pagas cada cierto tiempo?» · «Otra subcategoría» · «Es una suscripción» · «Cambia cada vez» · «¿Cuándo toca pagar?» · «¿Te avisamos antes de que toque pagar?» · «¿Lo ponemos en tu Panel?» · «Tus pagos planificados viven en Más»

**Ya existe en la app**

- ScheduledPayment, el resumen «… cada mes, el día 1. Primer pago: …», la Bandeja como destino y la hoja «¿Te avisamos antes de cada pago?».

**Hay que construir**

- Elegir por subcategoría al empezar; nombre precargado; preguntar si va al Panel.

**Fuera de alcance**

- «Cada N», 2/5/7/14/30 días y gasto compartido: en el editor.

**Está bien cuando**

- El pago se guarda con su subcategoría, monto (estimado o no), frecuencia, día y aviso.


### Y23-13 · Paso 5 · Grupos (su onboarding, con este estilo)

**Estado:** Existe con ajustes · **Dónde:** pestaña 7 · Grupos (paso 5) · atajo `#gru`

**Qué ve la persona**

- Si ya vio el onboarding de Grupos (hasShownGroupsOnboarding), el paso se da por hecho: el mazo pasa al 6 y un aviso lo dice.
- Si no: sus tres pantallas de hoy como página corta: «Comparte gastos sin perderles el rastro» (animación: llega «Sofía agregó S/ 50 al grupo Amigos» y el saldo pasa a «Debes S/ 25») · «Tres pasos, cero hojas de cálculo» (tres tarjetas + la nota del registro en la cuenta personal) · «Grupos en la nube» (consentimiento de 4 puntos; no avanza solo: «Aceptar y continuar» / «Ahora no»).
- Con iCloud privado, tras aceptar: «Conecta tu cuenta» (Apple o Google).
- ¿Qué quieres hacer? (Crear mi primer grupo / Tengo un enlace / Ahora no) → «Tu nombre en el grupo» → nombre e icono del grupo (sugerencias Casa, Viaje a Cusco, Amigos, Pareja) → «“…” está listo» con «Invitar por WhatsApp u otra app» / «Más tarde». Con enlace: pegar → «¿Es este grupo?» → «Unirme al grupo».
- Al terminar: guía sobre la pestaña Grupos «Tus grupos, a un toque». El grupo aparece en la tarjeta «Grupos» del carrusel de cuentas. Mazo en el paso 6.

**Textos exactos:** «Comparte gastos sin perderles el rastro» · «Tres pasos, cero hojas de cálculo» · «Grupos en la nube» · «Aceptar y continuar» · «Conecta tu cuenta» · «Invitar por WhatsApp u otra app» · «Tus grupos, a un toque»

**Ya existe en la app**

- GroupsOnboardingView, GroupFormView, GroupCreatedInviteSheet y la tarjeta Grupos del carrusel.

**Hay que construir**

- Verlo como página del tutorial.

**Dependencias y decisiones**

- Al completarlo aquí, marcar hasShownGroupsOnboarding para que Grupos no lo repita.

**Fuera de alcance**

- —

**Está bien cuando**

- Con el flag en sí, el paso se salta; en no, crea o se une y queda marcado.


### Y23-14 · Paso 6 · Mira a dónde va tu dinero

**Estado:** Nuevo (guía) · **Dónde:** pestaña 8 · Pasos 6 y 7 · atajo `#fin7`

**Qué ve la persona**

- Al tocar el paso: guía «Tus gráficas viven en Más» sobre la pestaña Más; al tocarla, la pantalla Más con foco en Estadísticas (Resumen, Tendencias, Distribución): «En Estadísticas ves lo más importante del mes, cómo cambia tu dinero y en qué se va. Más abajo, en Reportes, el flujo de caja y cómo vas contra el mes pasado.»
- Quien no lo toque la recibe sola «días después» (Y23-15).

**Textos exactos:** «Tus gráficas viven en Más» · «Todas tus gráficas»

**Ya existe en la app**

- La pantalla Más (MoreView) con sus secciones y subtítulos.

**Hay que construir**

- La guía.

**Fuera de alcance**

- —

**Está bien cuando**

- Tras la guía, el mazo pasa al paso 7.


### Y23-16 · Paso 7 · Anota sin abrir Yala (cinco mini tutoriales)

**Estado:** Existe (widget, Apple Pay, compartir, Siri) · Nuevo (correo) · **Dónde:** pestaña 8 · Pasos 6 y 7 · atajo `#fin7-s_fin7.s7`

**Qué ve la persona**

- Página corta de 5 partes y un mini tutorial por manera, todas omitibles, con pantalla entre una y otra:
- 1 Widget: «Añade el widget» en 4 pasos (mantén presionado → Editar → Añadir widget → busca Yala, «Nuevo registro» → Añadir widget). La app no puede ponerlo ni saber si se puso.
- 2 Apple Pay: la guía de Tutoriales (Abre Atajos › Automatización › + › Wallet › «Registrar pago de Apple Pay» › Cantidad y Comercio; «Mostrar al ejecutar» apagado). «Cada pago llega como borrador: nada se registra sin que lo apruebes.» Gratis.
- 3 Compartir una foto (Pro): hoja de compartir de iOS con Yala; 3 pasos. Fotos, capturas o PDF.
- 4 Tu correo (NUEVO): «Tu dirección de Yala» con «Copiar», crear un filtro de reenvío de los correos del banco, llegan a la Bandeja como borrador. «Pronto: conectar Gmail y Outlook directamente, sin filtros.»
- 5 Siri: «¿Qué le digo a Siri?» con las frases de «Siri y Atajos»: Anota un gasto en Yala (PRO), Nuevo registro en Yala, Registra con voz en Yala (PRO), Registra con foto o archivo en Yala (PRO), Cuánto gasté en Yala, Mi saldo en Yala.

**Textos exactos:** «Anota sin abrir Yala» · «Añade el widget» · «Registrar con Apple Pay» · «Compártele una foto a Yala» · «Tu correo, en automático» · «¿Qué le digo a Siri?»

**Ya existe en la app**

- Widgets, ApplePayAutomationGuideView, extensión YalaShare, SiriShortcutsView y sus frases.

**Hay que construir**

- Guía de compartir (hoy no existe).

**Dependencias y decisiones**

- Correo: no existe; es el plan de 2.3 (docs/ROADMAP.md: dirección propia de reenvío, gateway que lee con IA, Pro con cupo de prueba, exige cuenta en la nube). Su card de implementación va aparte (Y23-19).

**Fuera de alcance**

- —

**Está bien cuando**

- Cada mini tutorial se puede omitir; al terminar se completa Primeros pasos (Y23-18).


### Y23-18 · Final · Primeros pasos completos y prueba de Pro de 30 días

**Estado:** Existe con ajustes · **Dónde:** pestaña 8 · Pasos 6 y 7 (final) · atajo `#fin7-s_fin7.end`

**Qué ve la persona**

- El mazo desaparece: tarjeta «¡Primeros pasos completos!» con chispas.
- A los 1,6 s sube la oferta: «Prueba Yala Pro 30 días gratis», los 6 beneficios de la app, planes Anual (preseleccionado, «El más elegido») y Mensual, línea de tiempo «Hoy: tienes todo Pro. No pagas nada · Día 28: te avisamos antes de cobrar · Día 30: empieza tu plan. Cancela antes en Ajustes y no pagas nada».
- «Empezar mis 30 días gratis» → hoja de pago de la App Store → «¡Listo! Tienes Pro — Tus 30 días gratis van hasta el … El … te avisamos, antes de cualquier cobro.» → Voz, Foto y Yala IA pierden el candado. «Seguir con la versión gratis»: sin regalo; se vuelve a ofrecer en momentos de valor (Voz con candado, límite de presupuestos).

**Textos exactos:** «¡Primeros pasos completos!» · «Prueba Yala Pro 30 días gratis» · «El más elegido» · «Empezar mis 30 días gratis» · «Seguir con la versión gratis»

**Ya existe en la app**

- La oferta en ese momento (TrialOfferMomentLogic, ProTrialOfferSheet), la prueba de 30 días de la App Store y los textos de beneficios (uxpro.feature.*).

**Hay que construir**

- Plan anual preseleccionado, línea de tiempo y aviso local el día 28.

**Dependencias y decisiones**

- NORMA DE APPLE (3.1.2): la prueba de una suscripción solo la inicia la persona en la hoja de pago; NO se activa sola. Decisión de Jürgen: esta oferta (C) a 30 días.
- Precios reales (en el prototipo son marcadores).

**Fuera de alcance**

- Activar la prueba automáticamente.
- Regalar 30 días por la app (opción A, descartada).

**Está bien cuando**

- Sin confirmar en la hoja de pago no hay Pro; con confirmación, Pro activo y aviso programado el día 28.


## C · Transversal

### Y23-15 · Pestañas por defecto y «dónde vive cada cosa»

**Estado:** Nuevo (cambio de valores por defecto) · **Dónde:** pestaña Todas (barra de abajo) · 4 · Nuevo registro (Días después) · atajo `#reg-s_reg.later`

**Qué ve la persona**

- Pestañas por defecto: Panel · Grupos · Registros, más «Más» y Buscar. Presupuestos, Pagos planificados y Estadísticas viven en Más.
- Guías de foco al terminar cada paso: presupuestos y pagos → Más (dos toques); grupos → pestaña Grupos; gráficas → Más.
- «Días después»: UNA vez, cuando hay registros en 2 o más días distintos: guía en «Configurar Panel» (icono de cuadritos: «Arma tu Panel») y luego en Más → Estadísticas. No va en el tutorial de primer uso.

**Textos exactos:** «Arma tu Panel» · «Tus gráficas viven en Más»

**Ya existe en la app**

- Pestañas configurables (TabBarConfiguration), MoreView, botón Configurar Panel.

**Hay que construir**

- Cambiar los valores por defecto (hoy Panel, Estadísticas, Planificación) SOLO para instalaciones nuevas.
- Disparador de «días después».

**Fuera de alcance**

- Mover las pestañas de quien ya las configuró.

**Está bien cuando**

- Instalación nueva ve Panel · Grupos · Registros · Más · Buscar.


### Y23-17 · Permisos dentro del tutorial

**Estado:** Nuevo (momentos) · **Dónde:** pestaña 3, 4, 5 y 6 · atajo `#reg-s_reg.voz`

**Qué ve la persona**

- IA: aviso de Yala «Yala lo apunta por ti» al empezar voz o foto, una vez.
- Micrófono: aviso de iOS en «voz», tras el de IA. Cámara: aviso de iOS en «foto». Fotos/carrete NO se pide (la app usa el selector del sistema, que no lo necesita).
- Notificaciones: SOLO cuando la persona dice «sí, recuérdame»: en la tarjeta de crédito (paso 1) y en el aviso del presupuesto (paso 3). Si ya se dio, no se repite.
- Reintento en pagos planificados (paso 4): si iOS nunca preguntó → hoja de la app «¿Te avisamos antes de cada pago?» y luego el aviso de iOS; si se negó → alerta de la app «Activa las notificaciones» con «Ir a Configuración». El aviso de iOS sale UNA vez por app: «No me lo recuerdes» no lo gasta; «No permitir» sí.
- Textos de iOS: los de InfoPlist.strings (es-419).

**Textos exactos:** «Yala lo apunta por ti» · «¿Te avisamos antes de cada pago?» · «Activa las notificaciones» · «Ir a Configuración»

**Ya existe en la app**

- Textos de permisos, NotificationPrimerSheet y la alerta de Ajustes.

**Hay que construir**

- Pedir en estos momentos del tutorial.

**Fuera de alcance**

- Pedir permiso de fotos.

**Está bien cuando**

- Nunca se pide un permiso sin que la persona haya elegido usar esa función.


### Y23-19 · Correo automático (feature nueva)

**Estado:** Nuevo · requiere decisión · **Dónde:** pestaña 8 · Pasos 6 y 7 (mini tutorial 4) · atajo `#fin7-s_fin7.mail`

**Qué ve la persona**

- Lo que muestra el tutorial: dirección propia de Yala para reenviar correos del banco, filtro de reenvío y llegada a la Bandeja como borrador; «Pronto: Gmail y Outlook».

**Textos exactos:** «Tu dirección de Yala» · «Copiar»

**Ya existe en la app**

- —

**Hay que construir**

- Todo: dirección por persona, gateway que lee el correo con IA, borrador a la Bandeja.

**Dependencias y decisiones**

- Plan de 2.3 en docs/ROADMAP.md (cuenta en la nube, Pro con cupo de prueba, verificación de Google para «Conectar Gmail»). Hasta que exista, el mini tutorial 4 no se muestra.

**Fuera de alcance**

- —

**Está bien cuando**

- Sin la feature lista, el paso 7 muestra 4 maneras.

