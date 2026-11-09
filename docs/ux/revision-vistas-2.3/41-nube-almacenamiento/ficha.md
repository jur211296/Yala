# Revisión por vistas 2.3 · Dónde viven tus datos: nube, iCloud y cierre de sesión (zona 41)

Revisión de comprensión (textos, jerarquía y pasos) de lo que dice Yala sobre dónde están los datos, con el caso de Lucía:
1.537 registros en su iCloud privado y cuenta de Yala por Grupos; activa la nube para usar el iPad del trabajo, vuelve a
iCloud meses después y quita sus datos del iPhone que va a vender. No implementa nada, no mueve datos y no elige: cada
problema prioritario (ocho) trae de tres a cuatro alternativas maquetadas y una recomendación. Decide Jürgen.

- **Abrir:** `index.html` (móvil y Mac; capturas y estilo al lado, en `capturas/` y `estilo.css`).
- **Respaldo:** `revision-nube-almacenamiento.pdf` (68 páginas, ~7 MB).
- **Regenerar:** `cd fuente && python3 capturas.py <carpetas de PNG> && python3 build.py` (con `--todo <ruta>` deja la
  página única para imprimir el PDF; `capturas.py` usa ImageMagick).

## Vistas cubiertas

StorageSettingsView (con la hoja «Antes de activar la nube»), iCloudSyncSettingsView, CloudConsentView,
CloudProgressStepsView, StorageSignInChooserView, StorageMigrationBlockedView, ReturnToFullYalaView, SignOutRelaunchView y
GroupBatchLeaveView. CloudSyncDebugView queda fuera: solo existe en Yala Dev. Capturas del simulador (iPhone 17 Pro e iPad
Pro 13, iOS 27.2, tema oscuro) con semillas y ganchos de prueba que ya trae la app: iCloud con y sin cuenta de Grupos, la
hoja, bloqueos de cuenta, borrado pendiente, subiendo, esperando a iCloud, cancelar, fallo, diario ilegible, en la nube,
pide iniciar sesión, volver (sin y con datos previos, sin iCloud), volviendo, solo grupos y vuelta, salir de grupos,
quitar los datos hasta «Ya casi está», texto grande (AX3) e iPad. Ningún botón que mueve datos se pulsó contra una cuenta
real. El conductor es `fuente/Revision41CapturasUITests.swift.txt` y no va en la app.

Sin captura, leídos del código: la tarjeta de «reabre Yala» tras activar o volver, la espera de otro dispositivo, iCloud
al día o con fallo (el simulador no tiene iCloud) y la nube sin conexión.

## Problemas, por severidad

| | Problema | Recomendada |
|---|---|---|
| 1 · alta | Nueve nombres y seis verbos para dos sitios; «cuenta de Yala» es a la vez la de Grupos y la de los datos sin decirlo | T1: dos nombres fijos, «En tu iCloud» y «En tu cuenta de Yala», con «Pasar a» / «Volver a» |
| 2 · alta | Al activar la nube, «no hay cifrado de extremo a extremo» y «tus fotos de recibos no viajan» quedan plegados en «Ver los detalles», y la bienvenida usa otro consentimiento | H1: los tres puntos a la vista, una línea cada uno, con la cifra de fotos |
| 3 · alta | Volver a iCloud promete «sin perder nada» y «en pausa por si vuelves», pero volver a la nube con esa cuenta no se puede; la elección que borra iCloud va en globos de 9-10 pt | V2: una hoja con fases (qué pasa, qué hacer con lo que ya hay, confirmar) |
| 7 · media-alta | Con iCloud apagado, «Dónde viven tus datos» dice que se sincroniza por iCloud y «Sincronización iCloud» dice que no; dos filas para la misma pregunta | S1: una fila «Tus datos» con el estado real (y S2 ya, por separado) |
| 4 · media-alta | «Desasociar» es el botón más llamativo, encima de la acción; los bloqueos mandan a buscarlo sin enlace | G1: la cuenta en una fila con «Cambiar de cuenta», y el bloqueo ofrece esa salida |
| 5 · media | 43 textos de fallo (hasta 394 caracteres) con un solo botón, «Reintentar», aunque el arreglo esté en Ajustes o en soporte | E1: qué pasó · dónde están tus datos · qué hacer, con su botón |
| 6 · media | La subida no dice cuánto falta («650 de 1537»); «Ya casi está» dice «Sesión cerrada» tras «Quitar mis datos» y no repite que siguen en iCloud | R1: cifras con unidad y plazo; «Ya casi está» que dice lo hecho y dónde quedan |
| 8 · media | Con texto grande, el estado se aprieta en media columna y el pie fijo de la hoja de activar ocupa casi la mitad | X1: estado apilado y botones dentro del desplazamiento |

Eficiencia, medido (Debug, simulador, semilla «realista», una corrida por caso, `ps` desde el Mac): en reposo la app gasta
**6,5 %** de CPU con Ajustes abierto y **8,4 %** con «Dónde viven tus datos» (iCloud); en la nube, **8,0 %** frente a
**8,5 %**. La pantalla suma poco; que la app gaste 6-8 % sin tocar nada es de otra zona y está por medir en Release.
Hipótesis leídas en el código, con cómo medirlas: el bucle de 1 s que relee el diario y un `refreshTick` que nadie lee,
dos recuentos al almacén por pintado (volver y activar), el recuento de pendientes en cada guardado en la nube, y la
muestra de la vuelta que recorre las filas dos veces (ya tiene ticket).

## Lo que ya estaba decidido

La revisión parte de L20-11 (hoja única de activar; solo H2 la reabre), L20-17 (una confirmación al volver), la opción B
del 22-oct (pasos con cifra), L20-18 («Ya casi está» con lo hecho y los gestos), el paso 10 (la cuenta de Grupos en esta
pantalla; solo G4 lo reabre) y L19-15 (solo grupos no ve esta fila). De la revisión del usuario nuevo (PR 837) aplican F1
(salir y volver a abrir) y F21 (sin telemetría en esa pantalla).

## Decisiones para Jürgen

Las marcadas con **(datos)** tocan la seguridad o la pérdida de datos: van también a la tarjeta del tablero «Decidir:
cinco puntos de datos de la revisión de la nube».

1. **(datos)** Problema 7: ¿se corrige ya la frase del estado con iCloud apagado (S2)? Hoy afirma una copia que no existe. ¿Y se juntan las dos filas (S1)?
2. **(datos)** Problema 2: ¿el cifrado y las fotos salen a la vista en la hoja (H1)? ¿Un solo consentimiento para todas las entradas (H2)?
3. **(datos)** Problema 3: ¿se retira «queda en pausa por si vuelves» y se dice que volver a la nube con esa cuenta hoy no se puede (V1/V2), o se prioriza que se pueda (V4)? ¿La vuelta pasa a una hoja con fases (V2)?
4. **(datos)** Problema 4: ¿la cuenta pasa a una fila con «Cambiar de cuenta» y el bloqueo ofrece esa salida (G1)? Acerca un gesto que mueve datos de grupos. ¿Se adelanta G3?
5. **(datos)** Secundario: «Activar sin borrar» cancela un borrado de iCloud que la persona pidió, y se decide en un globo pequeño anclado al botón. ¿Pasa a una hoja que diga qué se queda en iCloud?
6. Problema 1: ¿dos nombres fijos con «Pasar a» / «Volver a» (T1), o el mínimo de T2? ¿La bienvenida cambia a la vez?
7. Problema 5: ¿plantilla de tres partes con el botón que arregla (E1), o solo el segundo botón (E2) por ahora?
8. Problema 6: ¿«Ya casi está» dice lo hecho y dónde quedan los datos en cada caso (R1)? ¿Se mide cuánta gente sale a mitad antes de añadir el aviso (R2)?
9. Problema 8: ¿estado apilado y botones dentro del desplazamiento con texto grande (X1)? Es de accesibilidad y puede ir sin esperar.
