Yala
# Cerrar sesión sin cambios fantasma y «Eliminar mi cuenta» en iCloud privado
---
toca: Yala/App/Views/SignOut/,Yala/App/Views/Shared/SignOutBlockedCopy.swift,Yala/App/Logic/YalaAccountLogic.swift,Yala/App/Logic/DestructiveScopeLogic.swift,Yala/App/Views/Profile/YalaAccountView.swift,Yala/App/Views/Profile/ProfileView.swift,Yala/App/Views/Shared/DestructiveScopeSheet.swift,YalaTests/CerrarSesionCuentaVacia/,YalaTests/EliminarCuentaICloud/,tickets/backlog/2026-11-19-cerrar-sesion-cuenta-vacia-893-cambios.md,tickets/done/2026-11-19-cerrar-sesion-cuenta-vacia-893-cambios.md,tickets/backlog/2026-11-19-icloud-privado-eliminar-mi-cuenta.md,tickets/done/2026-11-19-icloud-privado-eliminar-mi-cuenta.md
esfuerzo: high
cierre: cierra-sola
depende:
---

Rama base: 2.3. Dos temas que Jürgen vio en la build 2.3 (5) creando una cuenta de cero en iCloud privado. Un solo PR y un solo cierre.

## 1. Cerrar sesión en una cuenta vacía dice «Cambios por subir: 893»
Jürgen, 19-nov 21:32, misma cuenta nueva y sin datos: al cerrar sesión aparece «Quitando tus datos de este dispositivo… Subiendo tus cambios a iCloud… Cambios por subir: 893». Captura en la Mini: `~/Claude/flota/borradores/solo-gastos-y-cerrar-sesion/cerrar-sesion-893-cambios.png` (si corres en la Max, cópiala con `scp`). Vista: `Yala/App/Views/SignOut/SignOutProgressOverlay.swift`.
- Encuentra de dónde salen esos 893 (¿categorías, cuentas o semillas por defecto contadas como cambios pendientes? ¿cola de exportación duplicada? ¿contador que no se vacía tras subir?). Mide en el simulador con una cuenta nueva.
- Arréglalo en la causa: lo que la app crea sola no debe inflar el contador ni retrasar el cierre de sesión si ya está en iCloud o no hace falta subirlo, y el número mostrado debe ser el real. No pierdas datos reales del usuario: si de verdad hay cambios propios sin subir, se siguen subiendo antes de borrar.
- Card: «Cerrar sesión en una cuenta vacía dice “Cambios por subir: 893”». Ticket `tickets/backlog/2026-11-19-cerrar-sesion-cuenta-vacia-893-cambios.md`.

## 2. iCloud privado no tiene «Eliminar mi cuenta»
Jürgen, 19-nov 21:45: la cuenta de iCloud privado debe tener «Eliminar mi cuenta», igual que las otras: vacía los datos, cierra sesión y deja iCloud limpio (borra los registros de Yala en la base privada de CloudKit del usuario, no solo en el teléfono).
- Usa el mismo lugar, textos y confirmación que ya tiene «Eliminar mi cuenta» en Modo Nube (`YalaAccountView`, `DestructiveScopeLogic`, `DestructiveScopeSheet`); revisa también cómo está hoy «Vaciar datos».
- Confirma, en un entorno de desarrollo de CloudKit, que después de eliminar no queda nada en iCloud y que, al volver a entrar con el mismo Apple ID, la app parte de cero y no restaura datos viejos. Tampoco debe dejar cambios pendientes que inflen el contador del punto 1.
- Nada de esquemas ni despliegues en producción de CloudKit; si hiciera falta un cambio de esquema, es decisión vital.
- Card: «iCloud privado no tiene “Eliminar mi cuenta”: vaciar datos, cerrar sesión y dejar iCloud limpio».

## Cómo trabajar
- Tests en `YalaTests/CerrarSesionCuentaVacia/` y `YalaTests/EliminarCuentaICloud/`.
- Corren otras sesiones de Yala sobre `Yala/App/Views/Panel/`, `Yala/App/Tips/`, los `PrimerosPasos*`, `Yala/App/Views/Onboarding/`, `Yala/App/Views/Settings/`, `Yala/App/Views/Planning/` y `Yala/Services/CloudSync/EntityApplyMap.swift`/`EntityEmissionMap.swift`: no los toques. Si el arreglo necesita otro archivo fuera de `toca:`, anótalo en «Decidido sin consultar» y mantenlo mínimo.
- Textos nuevos en su propia tabla, nunca en Localizable.strings. Nunca un botón debajo de otro.
- En la Max puedes usar un segundo simulador además del de otra sesión, o el iPhone 14 por DeviceMCP; en la Mini, uno solo. No uses `-derivedDataPath /tmp/claude-*`.
- Nada en producción (ni CloudKit ni Supabase).
- Commit y PR sin firma de IA, contra 2.3. Deja el auto merge activado y no cierres hasta ver el PR dentro de 2.3. Si hay conflicto o el CI falla por tu PR, arréglalo tú. Si tras unos 45 minutos el CI sigue rojo por algo ajeno, cierra y anota el motivo.
- Lo menor y reversible se decide con la opción recomendada y se anota. Lo vital, según el modo fijado al arrancar: en semi (05:30–20:00) preguntas y esperas con la sesión viva; en nocturno (20:00–05:30) dejas un checkpoint recuperable y una card «Espera decisión» para Jürgen, sin cerrar como completo, sin mergear ni desplegar lo incompleto.
- Entregable del cierre: artifact visual de Claude (capturas antes y después, comparación de los Primeros pasos), nunca Markdown ni PDF.
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 (Frank, 2026-11-19, nocturno, en la Max)

**Medido.** Cuenta nueva en iCloud privado en el simulador, sin tocar nada: el historial del almacén personal ya
tiene **80 objetos** escritos por la app (11 categorías, 62 subcategorías y 7 avisos por defecto). Con un ancla de
subida anterior al alta —la que tiene un iPhone que ya usó iCloud, porque el ancla sobrevive al borrado— el cierre
enseña «Cambios por subir: 80». En un iPhone se suman los tipos de cambio: el arranque baja un año (≈ 366 filas, una
por día) y los vuelve a bajar tras cada borrado. Lo del 893 exacto de Jürgen (≈ el doble) es **inferido**: encaja con
haber borrado una copia anterior y vuelto a crear la nueva; no hay iPhone conectado a la Max para medirlo.

**Decidido (sin consultar, reversible):**
1. **Causa:** el contador del cierre privado (`PersonalExportPendingCounter`) cuenta como «cambio tuyo» todo lo local.
   Arreglo en el contador: no cuentan los tipos de cambio (caché que se vuelve a bajar) ni lo que la app creó sola y
   nadie tocó después (categorías y subcategorías de serie y de sistema, avisos por defecto idénticos a su valor de
   serie). Un borrado siempre cuenta (salvo de tipos de cambio). Lo de la persona sigue esperando su subida.
2. **«Eliminar mi cuenta» en iCloud privado:** en la tarjeta final de Ajustes, debajo de «Cerrar sesión», separado
   por la línea de siempre (una lista de filas, no dos botones apilados). Mismo título, hoja de alcance, alerta
   final y error que el de la nube. Por dentro reutiliza el borrado de la celda D: primero la zona de Yala en el
   iCloud del usuario, luego las filas de este teléfono, la señal a sus otros dispositivos y el Welcome.
3. Hoja de alcance nueva por operación (`deleteAccountICloud` y su variante con grupos guardados en el teléfono),
   con los textos que ya existen: nada de copy nuevo.
4. La comprobación en un CloudKit de desarrollo con iCloud real no se puede hacer en la Max (sin iPhone y el
   simulador sin iCloud): queda como guion de device-QA para Jürgen; no frena el merge.
