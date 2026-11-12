# Pagos planificados: Deshacer + borradores idénticos en Bandeja

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Esfuerzo: high.
Slug: `pagos-planificados-deshacer` · Sesión cola **S25** · al cerrar → **S26**.

## Encargo
Cumple **íntegramente** estos briefs per-card, en este orden o en el que el código exija (mismo dominio: pagos planificados):

1. `~/Claude/tmp-frank/pagos-planificados-pending-deletion-deshacer-x1ei.md`
2. `~/Claude/tmp-frank/pagos-planificados-borradores-identicos-bandeja-tzpw.md`

Léelos y ejecútalos (contexto, qué se pide, qué NO tocar, cómo se sabe que está bien). Este wrapper solo fija el hueco en la cola automática S0–S29.

## Qué NO tocar
Lo que digan los briefs. Además: no lanzar otras sesiones Yala; no tocar marketing/ ni Web/.

## Cómo se sabe que está bien
El criterio de cada brief + PR(s) a 2.2 cuando aplique (puede ser un solo PR si el dominio es el mismo).

## Pie pipeline
- Base: `origin/2.2`. Una sesión Yala a la vez. Rebase único antes del PR.
- Pipeline serial Yala: (1) limpiar sims muertos, DerivedData y cachés XcodeBuildMCP de worktrees cerrados; (2) build `xcodebuild -jobs 2` sin sim booteado; (3) bootear 1 sim; (4) tests; (5) apagar y limpiar.
- Al cerrar: Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.
- marketing/ y Web/ = Lola. No relances otras sesiones Yala.

## Paso 0 — decisiones (resueltas en autónomo, bypass, 03:00 Lima)

**Deshacer (x1ei)**
1. **Molde**: `ScheduledPaymentPendingDeletion` copia el de `RecordPendingDeletion` (un plazo compartido, tope de 30 s por lote, `commitDelay = undoWindow + 400 ms`, `undoAll` en el aviso, `refreshAfterUndo` con la foto de los widgets, `visible(_:)`). Sin generalizar las dos clases en una: los registros tienen la pareja de las transferencias y los pagos no; un genérico tocaría `RecordPendingDeletion`, que el brief pide no reabrir.
2. **Aviso de varios**: «Eliminaste N pagos» (clave nueva `scheduled.pendingDeletion.deletedMany`, 17 idiomas, mismo patrón que «Eliminaste N registros»).
3. **Dónde no cuenta lo pendiente**: Planificación (ya), Panel (pagos del mes, salud financiera, flujo de caja del widget), widgets, Estadísticas (compromisos de Insights y Sankey de Distribución), Informe y flujo de caja (tabla, configuración y «añadir línea»). El chat de IA y los avisos programados no: el plazo es de 5 s.
4. **Tests**: suite propia en fichero nuevo (lógica + scan de cableado) y XCUITest de dos borrados seguidos con `-uitest-undo-notice-seconds 30`; el botón «Eliminar pago» gana id `scheduled_editor_delete`.

**Borradores idénticos (tzpw)**
5. **Causa**: un vencimiento lo materializa CADA dispositivo (`processDuePayments` solo ve sus borradores; el del otro llega después por iCloud o la nube), y descartar uno rechaza a propósito todos los pendientes de la misma ocurrencia (`dismissScheduledOccurrence`, 1dafda29c). En un solo dispositivo no se reproducen: las guardas de pendiente lo impiden (se fija con test).
6. **Un solo borrador**: barrido idempotente en `processDuePayments` que funde los pendientes IDÉNTICOS de la misma ocurrencia (mismo pago, origen, día, importe, nota, cuenta, subcategoría, etiquetas, evidencia). Superviviente = menor `createdAt`, la misma regla en todos los dispositivos (regla «Fundir duplicados que llegan de dos dispositivos»); empate a menos de 1 ms o cualquier diferencia de contenido ⇒ no se funde. Los perdedores se BORRAN (no se archivan: Archivados no se llena de copias). No corre con la Bandeja abierta ni con una hoja presentada (review adversarial).
7. **Descartar quita solo ese**: si otro pendiente retiene la misma ocurrencia, descartar no salta la ocurrencia ni toca al hermano; la ocurrencia se salta al descartar el último. El barrido de ocurrencias descartadas (borrador que llega de otro dispositivo después del salto) se queda como está.
8. **Fuera**: aprobar uno de dos duplicados no toca al otro, y una edición en el otro dispositivo de la copia que sobra se pierde si la fusión llega antes (residuales en el ticket).
9. **Review adversarial (2 lentes)**: añadidos el fetch del pago antes del borrado diferido (molde de registros), el tope del lote ≥ dos avisos (el XCUITest de 30 s), la espera con hoja presentada y el estado en memoria en el descarte en lote.
