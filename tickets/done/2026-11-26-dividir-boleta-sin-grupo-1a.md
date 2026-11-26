---
id: 2026-11-26-dividir-boleta-sin-grupo-1a
status: done
priority: high
area: groups
created: 2026-11-26
updated: 2026-11-26
---
# Dividir una boleta sin crear grupo (maqueta 1A con los ajustes de Jürgen)

Decisión de Jürgen (26-nov, 10:15 Lima) sobre `docs/propuestas/dividir-boleta-sin-grupo/`: opción A con la imagen 1
(«Me deben») y cuatro ajustes: elegir quién pagó, imagen «Solo resumen» o «Con detalle», más de un diseño con colores y
logo de Yala, y «Listo» arriba a la derecha. Va en 2.3. Card del tablero: «Dividir pago grupal escaneando un recibo».

## Qué cambia para quien usa la app

- Un botón largo «Dividir una boleta» bajo Cámara, Fotos y Archivo de la hoja de foto, y bajo la fila de acciones de
  Grupos.
- Foto de la boleta → «¿Entre quiénes?» (Yo siempre, los demás escritos al vuelo, sin grupo ni cuenta de Yala) →
  «Por igual» o «Por líneas» con la frase opcional de quién comió qué → Repartir (una sola lectura con IA, del cupo
  diario de recibos de Grupos) → revisión (quién comió cada línea, propina/servicio/impuestos sin incluir hasta que se
  elige) → resultado.
- Resultado: «¿Quién pagó?» con todas las personas (por defecto Yo). Si pagué yo, «Te deben X»; si pagó Carla, «Le debes
  a Carla mi parte». Imagen «Solo resumen» o «Con detalle» en tres diseños (Clara, Yala, Boleta) con logo y colores de
  Yala, para WhatsApp, Instagram o el menú de compartir. «Listo» arriba a la derecha.
- La imagen va a otras personas, así que habla de quien la manda con su nombre y en tercera persona: «A Jürgen le
  deben», «Carla le debe a Jürgen», «La parte de Jürgen»; nunca «Yo» ni «Me deben» (Jürgen, 26-nov, a mitad de la
  sesión). El nombre sale del perfil; si no hay, la hoja lo pide una vez antes de compartir y lo guarda en el perfil.
  Dentro de la app se sigue hablando a la persona («Tu parte», «Te deben»).
- En Yala completo: «Registrar mi parte» (borrador de la Bandeja con su editor en la misma hoja) o «o mándala a la
  Bandeja». En «solo grupos», solo ver y compartir.
- Si la IA no puede (sin conexión, sin cupo, boleta ilegible), «Apuntarlo a mano» pide el total y lo reparte por igual.

## Paso 0 — decisiones

Las diez del encargo (`encargos/lanzados/2026-11-26-dividir-boleta-sin-grupo-1a.md`, «Paso 0»): una lectura al tocar
«Repartir» con la frase incluida; personas de valor sin `SplitMember` y `GroupCaptureModel` intacto; «por igual» ignora
asignados; quién pagó en el resultado; mi parte como borrador de la Bandeja; dos tipos y tres diseños de imagen; «Listo»
arriba a la derecha; total a mano si la IA no puede; dos entradas.

## Fuera

- «Recientes» de la maqueta: guardar nombres de terceros pide clave nueva en disco y su borrado en «Vaciar datos».
- «Guardar como grupo» (4b): en «solo grupos» solo se ve y se comparte.
- Opción C (cuenta del día, quién ya pagó, enlace): 2.4.

## Hecha cuando

- En Yala completo y en «solo grupos», boleta de 7 líneas con 4 personas al vuelo: reparto por igual y por líneas al
  céntimo, «Quién pagó» elegible, «Solo resumen» y «Con detalle» en cada diseño, compartir abre el menú del sistema,
  «Listo» cierra; en Yala completo, mi parte queda como gasto o en la Bandeja.
- Ningún grupo ni miembro nuevo guardado.

## Device-QA (iPhone 14)

No frena el merge: se corre cuando Jürgen pueda. El ticket queda en `done` porque el encargo lo pedía así; el guion
vive aquí.

1. Panel › Foto › «Dividir una boleta» › Cámara: foto de una boleta real; escribir 3 nombres; «Por líneas» con una frase
   («yo el lomo, Ana el ají, la chicha entre todos»); Repartir. Esperado: las líneas llegan asignadas según la frase.
2. En el resultado, cambiar «¿Quién pagó?» a otra persona: la cifra grande pasa a «Le debes a …» con tu parte.
3. «Compartir imagen» › WhatsApp e Instagram (Historias): la imagen llega nítida, con el logo y los montos correctos.
4. «Registrar mi parte» › elegir cuenta y categoría › aprobar: aparece en Registros con tu parte.
5. Grupos (en «solo grupos»): «Dividir una boleta» no ofrece registrar; «Listo» vuelve a Grupos sin grupo nuevo.
