# Al archivar una cuenta, excluirla sola de estadísticas y avisar del toggle

## Contexto
Ticket: archived-accounts-still-count-in-the-panel-total.
Hoy al archivar una cuenta sigue contando en totales del panel / estadísticas. Jürgen (2026-10-03): al archivar, la cuenta debe excluirse sola de las estadísticas, y se avisa que el usuario puede no excluirla a mano en los ajustes de esa cuenta. Lo que decide si suma o se muestra es el toggle de excluir, no el hecho de estar archivada.
Sesión anterior more-tab-missing-profile-button cerró con PR #343 en cola a 2.1.

## Que se pide
1. Al archivar una cuenta: marcarla excluida de estadísticas automáticamente (mismo efecto que el toggle «excluir»).
2. Mostrar un aviso claro de que quedó excluida y que puede volver a incluirla a mano en los ajustes de esa cuenta (no forzar el archivo como criterio de suma).
3. Confirmar que el toggle de excluir sigue siendo lo que decide si suma/se muestra; archivar solo dispara la exclusión automática + aviso.
4. Si el cambio se ve: capturas/antes.png y capturas/despues.png en el worktree y listar rutas en el cierre.
5. PR a 2.1; al terminar /cerrar-total autónomo.

## Que NO hay que tocar
No rediseñar el panel entero. No tocar trends-insight. No cambiar el significado del toggle de excluir más allá de auto-activar al archivar. No CloudAgent.

## Como se sabe que esta bien
Archivar una cuenta → deja de sumar en totales/estadísticas; aparece aviso de exclusión + que puede revertir en ajustes; toggle sigue mandando; tests verdes; PR en cola; /cerrar-total.

## Paso 0

Medido: el toggle «Excluir de las estadísticas» ya es lo que decide la suma en Panel
(`LiveBalanceCalculator`), Estadísticas, widgets y contexto del chat. Archivar sólo hace falta que lo encienda.

| Decisión | Elegido | Por qué |
|---|---|---|
| Dónde se auto-excluye | Los dos sitios que archivan: el toggle del formulario de cuenta y el downgrade de plan | Es el mismo objeto que nombra la decisión («al archivar»); el downgrade archiva en lote |
| Cuándo en el formulario | Al encender «Archivar», en vivo: el usuario ve saltar el toggle de excluir | Que vea qué cambió antes de guardar |
| Si ya estaba excluida | No se toca y no hay aviso | No cambió nada que avisar |
| Des-archivar | No re-incluye. Excepción: si se apaga «Archivar» en la misma edición, se deshace la auto-exclusión | El toggle no cambia de significado; deshacer el propio gesto no es criterio nuevo |
| Aviso | Texto bajo el toggle (avisar sin confirmar), y una línea en el downgrade | Cambia qué se ve, no destruye datos: no hay que pedir permiso |
| Conteo «en N cuentas» del Panel | Pasa a contar por el toggle de excluir, no por archivada | La decisión: el toggle decide si suma o se muestra; si no, re-incluir una archivada la suma sin contarla |
| Cuentas YA archivadas antes de este cambio | No se tocan (sin backfill) — **asumido**, queda para Jürgen | Mover datos existentes en silencio es suyo |
| Carrusel | Sin cambios: sigue sin mostrar archivadas | Archivar = esconder de listas; no es criterio de suma |

### Revisado tras la review adversarial (2026-10-03)

- **Downgrade: ya no auto-excluye.** Excluir oculta también los movimientos en Registros, y al volver a
  Pro nada los re-incluye: es un flag persistente sobre cuentas que el usuario no eligió archivar. Queda
  para Jürgen.
- **El aviso dice que los movimientos se ocultan en Registros**, porque excluir lo hace.
- **Conteo: las cuentas sistema de Grupos que archiva la app no cuentan** (si no, «en N cuentas» subía con
  una cuenta invisible de saldo 0).
- **Re-incluir a mano retira la marca de «excluida por archivar»**: desarchivar ya no pisa un «excluir»
  que el usuario volvió a encender él.
