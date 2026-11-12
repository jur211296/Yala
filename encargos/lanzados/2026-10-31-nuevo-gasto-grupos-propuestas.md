---
esfuerzo: high
release: no
---
# Registro muy parecido en Nuevo registro, aprobación y Nuevo gasto de Grupos: propuestas de diseño

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `nuevo-gasto-grupos-propuestas` · Sesión cola **S35d** · al cerrar → **S35e** (`fluidez-animaciones-hapticos`).

## Contexto
Jürgen (2026-10-30): en Nuevo gasto de Grupos sobra mucho espacio. Sus ideas:
- grupo y fecha más grandes;
- algo útil debajo de los selectores de cuenta y subcategoría;
- el mismo diseño para todos los selectores (hoy cuenta va a lo ancho y subcategoría es un chip, y se ve raro).

Quiere varias propuestas para elegir.

Jürgen (2026-10-31 16:46), cita literal:
> «En el nuevo registro, al seleccionar una cuenta que tiene doble línea de moneda, se ve para seleccionar así: Cuenta + Línea / Categoría + Etiqueta, en dos filas. Está bien. Pero en la aprobación está todo en una fila, por lo que las líneas confunden (se ven 2 y luego categoría y etiqueta, como si la línea no usada faltara completar). Hay que mejorar o ambas y que sean iguales o solo mejorar la aprobación. Y la de grupos debe "conversar" con estas dos. O sea el registro debería ser "muy parecido" entre las 3. En grupos sí el selector de moneda debe ir en el signo porque se puede añadir cualquier moneda, pero lo de cuenta y categoría debería ser similar. Metamos todo ahí.»

Cards:
- `tablero ver tablero-nuevo-gasto-de-grupos-3-propuestas-para-9vuc`

## Qué se pide
Unificar el formulario de registro en tres pantallas:

- **Nuevo registro** es la referencia. Con una cuenta de doble línea de moneda se ve así: fila 1, Cuenta + Línea; fila 2, Categoría + Etiqueta.
- **Aprobación** es la vista donde se aprueba un registro propuesto (Yala IA, Bandeja o donde aplique; ubícala en el código). Hoy todo va en una fila, y la línea de moneda no usada parece un campo pendiente.
- **Nuevo gasto de Grupos** lleva la moneda en el signo del monto, porque admite cualquier moneda. Cuenta y categoría usan el mismo diseño que Nuevo registro.

Mantén lo que ya pedía la propuesta original:
- aprovechar el espacio;
- grupo y fecha más grandes;
- info útil bajo los selectores;
- todos los selectores iguales;
- hojas de vidrio (las de detent medium, como en PR #717).

Pasos:
1. Arma al menos 3 propuestas con capturas reales en simulador (tema oscuro, claro y degradado; datos como los de Jürgen, incluida una cuenta de doble línea). Van en `docs/disenos/registro-unificado-2-2/`, con un README de pros, contras y tu recomendación.
2. Cada propuesta muestra **las tres pantallas lado a lado** (Nuevo registro, Aprobación y Nuevo gasto de Grupos). Como mínimo:
   - (A) la aprobación copia a Nuevo registro, y Grupos se adapta;
   - (B) Nuevo registro y la aprobación cambian a un diseño común nuevo, y Grupos se adapta;
   - (C) una variante libre.
3. Por defecto, PR solo de docs, sin implementar.
4. Crea una card `cierra-sola` asignada a jurgen, versión 2.2, estado «awaiting decision», para que elija, con el link a la carpeta del PR. El default para implementar es (A): igualar la aprobación a Nuevo registro y adaptar Grupos.
5. Si al terminar las propuestas implementas algo, usa ese default (A). Implementarlo no te deja tocar más de lo que lista «Qué NO hay que tocar».

Si sale algo que no cabe aquí, crea cards en 2.2, «ready to launch», `cierra-sola`, asignadas a frank (nada a backlog). Lista sus títulos en el PR y en el cierre para que Frank las encole antes del barrido.

Al abrir el PR, pasa las cards a «in qa» de Jürgen si hay algo que mirar en dispositivo, o a «done» si no (con `--agente` de la sesión).

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
- La lógica de guardado, la sincronización y el servidor.
- marketing/ ni Web/.
- No lances otras sesiones Yala.
- Ningún otro PR ni rama.

## Cómo se sabe que está bien
- Hay propuestas con las tres pantallas lado a lado, el README y la card de decisión.
- Si implementaste (A), las tres pantallas se ven muy parecidas, con capturas antes y después en `capturas/`.
- Los tests están verdes.
- Se hizo una review adversarial del diff.
- El PR va a 2.2 con auto-merge.

## Cierre autónomo
Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue.

Lo que de verdad necesite a Jürgen (borrar datos de usuario, seguridad, diseño crítico), no lo hagas: crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.

Al cerrar, Frank publica el digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

Termina con /cerrar-total.

## Paso 0

Decisiones (auto-contestadas, MODO AUTÓNOMO):

1. **«Aprobación» = `InboxDraftEditSheet`** (Bandeja › tocar un borrador). Es la única que pinta los selectores en UNA fila
   con scroll horizontal (`ScrollView(.horizontal)` + `AccountCardChips`); Nuevo registro usa `FlowLayout`. Medido en el
   código, no inferido.
2. **Sin implementar: PR solo de docs** (default del encargo, opción conservadora). Elegir A o B cambia qué se toca en
   las dos pantallas personales; implementar A antes de que Jürgen elija sería trabajo a tirar si elige B.
3. **Maqueta temporal**: ganchos `#if DEBUG` marcados `MAQ-RU` en las tres vistas reales, por argumento `-maqRU N`
   (0 = hoy, 1 = A, 2 = B, 3 = C), más un conductor XCUITest temporal. Nada de eso se commitea: grep `MAQ-RU` vacío
   antes del commit.
4. **Datos**: semilla `grupos` + una tarjeta con línea en dólares sembrada por la maqueta. Temas: Claro (1), Oscuro (2)
   y Liquid Glass (8, el de Jürgen, degradado).
5. **Review adversarial** del diff: el diff es docs; se revisan las afirmaciones del README contra el código.
6. **Lo que cambió la review** (2026-10-31): la línea útil de Grupos decía «Tu parte, S/ 80, va a tus registros», y es
   falso cuando pagas tú (van los S/ 240 de la cuenta y un préstamo de S/ 160). Se recapturó con «Salen S/ 240.00 de tu
   cuenta y te deben S/ 160.00». El README corrige además 16 idiomas (no 7), «Disponible» en tarjetas (Yala no guarda
   el límite) y nombra las otras pantallas con los mismos selectores (favoritos y hojas de la Bandeja de grupo).
