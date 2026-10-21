# Criterios para asignar versión en Yala

> Propuesta del 2026-10-19, **vigente desde el 2026-10-21** (Jürgen la aprobó tal cual con el roadmap). Acompaña a
> `docs/ROADMAP.md`.
> Sirve para decidir **sin preguntar** en qué versión entra una card nueva, sea bug, mejora o idea.

## 1. Los tres tipos de versión

| Tipo | Forma | Qué puede llevar | Qué no puede llevar |
|---|---|---|---|
| **Parche** | `x.y.Z` (2.1.1) | Arreglos de bugs y textos que corrigen un bug. Lo que se quedó fuera del build de lanzamiento. Lo que pida App Review. | Funciones nuevas. Cambios de esquema (SwiftData, CloudKit, base de la nube). Copy nuevo que no arregle nada. |
| **Menor** | `x.Y` (2.3) | **Un tema**, que se dice en una frase. Funciones nuevas en las plataformas que ya existen. Su cuota de bugs. **Una** ventana de cambio de esquema, aditiva (campos nuevos y opcionales). | Una plataforma nueva. Un cambio de dónde viven los datos por defecto. Un plan de pago nuevo. |
| **Mayor** | `X.0` (3.0) | Cualquiera de estas cuatro cosas: **(a)** abre una plataforma nueva (web, Android); **(b)** cambia dónde viven los datos por defecto o quién es su dueño (por ejemplo, una cuenta compartida entre dos personas); **(c)** cambia el modelo de cobro (un plan nuevo, cobrar fuera de la App Store); **(d)** rompe compatibilidad (versiones viejas que dejan de sincronizar, o una migración sin vuelta atrás). | — |

Lo que no cumple ninguna de las cuatro condiciones de una mayor **es una menor, por grande que sea**. El tamaño no hace mayor
a una versión: la hace mayor lo que obliga a cambiar fuera del iPhone.

**Sin fechas** (decidido el 2026-10-21): cada versión sale cuando cumple su criterio de salida. Un parche sale cuando
un bug lo exige; no se planifica por adelantado.

## 2. Cómo pesan los bugs según su severidad

La severidad es la **prioridad de la card**, con la escala de `docs/TICKETS.md`. No se inventa otra.

| Severidad (prioridad de la card) | Qué es | A qué versión obliga |
|---|---|---|
| **Muy alta** (o `critical`) | Pérdida o corrupción de datos confirmada en producción; la app no abre o no deja registrar; un cobro de Pro que no se entrega a nadie. | **Parche inmediato.** No espera a ninguna versión. |
| **Alta** | Un flujo principal roto sin salida; una cifra financiera equivocada a la vista; algo que deja atrapada a la persona. | El parche en curso o la menor en curso. **Bloquea la salida de cualquier versión** mientras siga abierta. |
| **Media** | Falla con salida; riesgo de datos en un caso estrecho; una pantalla que dice lo contrario que otra. | La menor en curso si toca su tema; si no, la siguiente. Cada menor cierra **todas** las medias de su tema. |
| **Baja** | Texto confuso, caso raro sin pérdida, pulido. | Se agrupan por tema en la menor que toca esa área. Cada menor tiene una cuota mínima. |
| **Muy baja** | Cosmética, teórica o interna. | Al tocar el área; como tarde, en el endurecimiento antes de la siguiente mayor. |

Tres ajustes, siempre en este orden:

1. **Una cifra financiera equivocada sube un escalón.** En una app de finanzas, el número *es* el producto.
2. **El riesgo de datos sube un escalón** frente al mismo fallo que solo da un texto confuso. Duplicar, perder o no subir
   datos va antes que un aviso mal redactado.
3. **La población baja un escalón** cuando el caso solo puede pasar en teléfonos de QA, en versiones que nadie tiene
   instaladas o en una ventana de milisegundos sin reproducir.

**Meta de bugs de cada versión.** Toda versión declara dos números: cuántos bugs ataca como mínimo y qué severidad queda en
cero al salir. Como regla general, **muy alta y alta en cero siempre**, y la media en cero dentro del tema de la versión.

## 3. Cómo pesan los otros factores

**Paridad con la competencia.** Una función que tienen Pablo, Clever u otra app de la región y Yala no, y que esa app
enseña en su página principal, es candidata a la **primera menor de su tema que tenga hueco**. Se iguala primero lo que la
persona ve el primer día (que los gastos se apunten solos, los gastos hormiga, las metas) y lo que **ya prometemos** en la
ficha de la App Store. Superar al competidor va **después** de igualarlo, salvo que hacerlo mejor cueste lo mismo que
copiarlo.

**Plataforma.** Android y web son **mayores**. Excepción decidida el 2026-10-21: una **beta que solo mira y deja borradores en la Bandeja**
(la web de 2.3, como los conectores de IA) cabe en una menor, porque no escribe en la sincronización ni cobra. La
plataforma completa sigue siendo mayor. Sus dependencias —la nube estable, la cuenta de Yala, una suscripción que
valga en todas las plataformas— son requisitos de entrada, no trabajo de la propia versión. Lo que solo existe en Apple
(widgets, Siri, iPad, Apple Watch, Mac) cabe en una menor.

**Deuda técnica.** Pesa por lo que frena, no por lo que molesta:

- Un test rojo o un CI que frena PRs va a la **versión en curso**: frena todo lo demás.
- La deuda que pone en riesgo datos se trata **como un bug** de su severidad.
- Documentación vieja, comentarios y código muerto se arreglan **al tocar el área**; como tarde, en el endurecimiento
  antes de la siguiente mayor.
- Reserva orientativa: una quinta parte del trabajo de cada menor.

**Esquema de datos.** Cada menor tiene **una sola** ventana de cambio de esquema: un despliegue de CloudKit a producción y
un DDL de la nube. Los cambios de modelo de una versión se juntan en esa ventana. Por eso la tarjeta de crédito con fecha de
corte va con la tarjeta multidivisa en 2.2: tocan el mismo objeto.

**Pro.** Lo que cuesta dinero por cada uso (IA, WhatsApp, correo leído con IA) es Pro con un cupo de prueba, con el patrón
del ADR del 2026-10-07 (5 notas de voz y 5 fotos). Lo que hace que las cifras sean correctas (períodos, saldos,
conversiones) es **gratis**.

## 4. Árbol de decisión para una idea o un bug nuevo

Se recorre de arriba abajo y se para en la primera respuesta:

1. **¿Es un bug?** Se le pone severidad con la tabla de §2, con sus tres ajustes.
   - Muy alta → parche ya.
   - Alta → el parche abierto o la menor en curso.
   - Media → la menor en curso si es de su tema; si no, la siguiente.
   - Baja o muy baja → la menor cuyo tema toca esa área (tabla de §5) o el endurecimiento.
2. **¿Abre una plataforma, cambia dónde viven o de quién son los datos, cambia el cobro o rompe compatibilidad?** → Mayor:
   la que ya abre esa plataforma o ese cambio (§5). Si ninguna lo abre, se propone una mayor nueva y se pregunta.
3. **¿Depende de algo que aún no existe** (la nube endurecida, un buzón de correo por persona, la cuenta en la web)? → No
   antes de la versión que entrega esa dependencia.
4. **¿Encaja en el tema de una menor planificada?** → Esa (§5).
5. **¿Es paridad con un competidor?** → La primera menor de su tema con hueco, aunque haya otra cosa antes.
6. **¿No encaja en nada?** → Backlog sin versión, con la nota «revisar al planificar la próxima menor». No se le pone
   versión por poner.

Y una regla de tamaño: **si no cabe en su menor, se parte.** La primera entrega va en esa versión y el resto en la
siguiente del mismo tema.

## 5. Qué tema tiene cada versión

| Versión | Tema | Le llega |
|---|---|---|
| 2.2 | Se entiende a la primera | UX, copy, coherencia visual, tarjetas (multidivisa y fecha de corte), Siri, Sentry, los bugs del QA guiado de 2.1 |
| 2.3 | Yala apunta sola | Captura automática (correo, atajo del banco y conectores de IA que registran), importar de Splitwise y Tricount, Yala web beta (ver y borradores), suscripciones, gastos hormiga, nube de severidad media |
| 2.4 | Tu mes real | Períodos, cuentas, ahorro, deudas, cuotas, presupuestos, notificaciones, divisas exactas, integridad de datos en la nube, iPad, iPhone Duo y Mac, tutoriales, empezar con datos |
| 2.5 | Yala conversa | Yala IA, WhatsApp, manos libres y reglas, IA en el iPhone, rachas y mascota, endurecimiento final de la nube |
| 3.0 | Yala en la web | Plataforma web, suscripción por cuenta, cobro fuera de la App Store |
| 3.1 | Juntos | Plan dúo: cuentas y presupuestos compartidos |
| 3.2 | Yala en la muñeca | Apple Watch |
| 4.0 | Yala en Android | App de Android nativa |

Cuando una versión sale, su fila se borra de esta tabla y se añade la siguiente. El roadmap se revisa entero al cerrar cada
menor.
