# Sync de los ajustes del flujo de caja · 2.1 (dos cards en una sesión)

Cards (Yala, 2.1, frank), muévelas a in progress al empezar y a done al cerrar:
- «Dos teléfonos con el mismo ajuste de un mes acaban con dos»
- «Un ajuste del flujo de caja que llega a un teléfono con versión vieja no se ve al actualizarlo»
Búscalas con `tablero listar --proyecto yala --version 2.1 --buscar "ajuste"` y lee su contexto y su «hecha cuando».

## Qué hacer
- Reproduce los dos casos con tests (unitarios o de sync), arregla la causa raíz y deja los tests en verde. Prefiere lo más robusto: deduplicar el ajuste del mes por su clave natural (cuenta + mes) al fusionar, y que un registro desconocido para una versión vieja se conserve y se aplique al actualizar, sin perder datos.
- Si el arreglo toca el esquema de iCloud (un campo o tipo de registro nuevo), PARA y deja la propuesta en la card en espera decisión para Jürgen: no despliegues nada a Producción.
- Prueba según /barrido-qa (sin escenarios de dos dispositivos en el simulador; los de dos aparatos reales quedan como QA de Jürgen en la card).

## Reglas
- Base origin/2.1. Sin esperar el CI de nadie; `git fetch && git rebase origin/2.1` solo justo antes de abrir tu PR contra 2.1.
- 1 simulador a la vez; apágalo y borra tu DerivedData al terminar. La Mini va justa de disco: mira `df -h /` antes de compilar.
- En `~/Yala` (árbol principal) no toques los `.ckdb` sin commitear, `Yala.xcscheme` ni `encargos/pendientes/`. No toques tmux `salud--*`, `sat-lab--*`, `clinicas-dentales-bi--*`.
- Todo ticket nuevo lleva su card.
- Cierra con /cerrar-total.

## Paso 0 (Frank, 2026-10-17, autocontestado)

- **Regla del superviviente:** con dos o más ajustes del mismo mes en la misma línea, se queda el de menor `id`
  (uuidString), mire la relación nueva o la de legado. Es la clave natural (línea + mes) que pide el encargo. Es la
  misma regla en todos los caminos y en todos los teléfonos: el orden de llegada no cambia el resultado y ningún
  teléfono borra el que el otro conserva. No hay fecha en el modelo, así que «el más reciente» exigiría un campo
  nuevo de iCloud, y eso está fuera de este encargo.
- **Dónde se funde:** en la pasada de arranque que ya existía (`CashFlowOverrideLineMigration`). Los cuatro lectores
  eligen el mismo superviviente aunque la limpieza aún no haya corrido. No se añade al observador de cambios remotos:
  guardar mientras el import de CloudKit está en curso es el crash conocido del arranque (`BootSaveGateLogic`).
- **Ajuste huérfano de una versión vieja:** no se borra nunca (sin línea no hay clave natural). Medido en el binario
  de Core Data de esta Mac: el espejo guarda los hashes del modelo del cliente y tiene un «zone fetch after client
  migration». Apunta a que al actualizar re-baja la zona y le pone la línea. Sin medir en un aparato: queda para el
  QA de dos iPhone de Jürgen. Cuando la línea llega, si choca con otro ajuste del mismo mes, lo resuelve la regla de
  arriba.
- **Esquema de iCloud:** no cambia. No hay nada que parar.
- **Cards:** a done al cerrar, como pide el encargo. Los pasos de dos iPhone van a la card ly22, que ya es de Jürgen
  y está en qa.
