---
id: 2026-11-19-icloud-privado-eliminar-mi-cuenta
status: qa
priority: high
area: account, cloud-sync
created: 2026-11-19
updated: 2026-11-19
card: tablero-icloud-privado-no-tiene-eliminar-mi-cuen-s591
source: Jürgen, 19-nov 21:45
qa-status: needs-testing
qa-date: 2026-11-19
qa-notes: simulador sin iCloud — falta comprobar en un iPhone con iCloud que la zona de Yala queda vacía (guion abajo)
---

# iCloud privado no tiene «Eliminar mi cuenta»: vaciar datos, cerrar sesión y dejar iCloud limpio

Jürgen (19-nov): la cuenta de iCloud privado debe tener «Eliminar mi cuenta», igual que las otras: vacía los datos,
cierra sesión y deja iCloud limpio.

## Qué se hizo

- **Dónde:** Ajustes, tarjeta del final, debajo de «Cerrar sesión» y separada por la línea de siempre. Solo sin cuenta de
  Yala (iCloud privado); con cuenta sigue dentro de «Tu cuenta de Yala».
- **Textos y confirmación:** los de «Eliminar mi cuenta» de siempre — hoja «¿Eliminar tu cuenta de Yala?» con
  «Exportar antes», «Continuar» y la alerta «Esto es definitivo». Sin copy nuevo: la fila del iCloud usa la frase de
  «Vaciar datos» («Se borran de iCloud, así que desaparecen de los otros dispositivos que guardan ahí tus datos
  personales»).
- **Qué hace** (reutiliza el borrado de la cuenta de grupos con iCloud privado): primero borra la zona de Yala del
  iCloud del usuario; si eso falla, no toca el teléfono y se puede reintentar. Después borra las filas de este teléfono,
  avisa a sus otros dispositivos del mismo iCloud y arma el borrado del arranque: al reabrir, Welcome y almacén vacío.
  Sin servidor: no hay cuenta de Yala que borrar.
- Con grupos guardados en el teléfono (una sesión de grupos que caducó), la hoja dice «Este dispositivo olvidará tus
  grupos (siguen en tu cuenta)».
- **Dos frenos, los del «Cerrar sesión» de esta celda** (los pidió el revisor con checklist): con una migración entre
  iCloud y la nube a medias, o con cambios de grupos sin subir de esa sesión caducada, no se borra nada —ni iCloud— y el
  aviso «No pudimos eliminar tu cuenta» dice lo que toca (terminar la migración, o volver a entrar para subirlos).
- No deja cambios pendientes: no pasa por la espera de subida del cierre.

## Pruebas

- `YalaTests/EliminarCuentaICloud` (cuatro suites: lógica, servicio, freno de grupos y migración sobre un almacén de
  verdad, y cableado de Ajustes): operación y fila solo en iCloud privado sin cuenta; hoja con los mismos
  título, botón e identificadores; orden iCloud → teléfono sin servidor; fallo del iCloud sin tocar el teléfono;
  reintento; nada sin sesión privada.
- Simulador (sin iCloud): crear cuenta → Ajustes → «Eliminar mi cuenta» → «Cuenta eliminada» → reabrir → Welcome con 0
  categorías, 0 movimientos y 0 cuentas en el almacén.

## Guion de QA en el iPhone (con iCloud, Yala Dev → CloudKit de desarrollo)

1. En el iPhone 14, borra Yala Dev si está y vuelve a instalarla desde Xcode (scheme `Yala Dev`).
2. Entra con «Entrar con iCloud privado». Si te ofrece restaurar datos de antes, elige empezar de cero.
3. Crea una cuenta y apunta un gasto. Espera un minuto con la app abierta para que suba a iCloud.
4. Ajustes → baja hasta el final → «Eliminar mi cuenta» → «Continuar» → «Eliminar mi cuenta».
5. Debe salir «Cuenta eliminada · Vuelve a abrir Yala». Cierra Yala del todo y ábrela: debe salir el Welcome.
6. Toca «Entrar con iCloud privado» con el mismo Apple ID. **Hecho cuando** no ofrece restaurar nada y entra de cero
   (sin la cuenta ni el gasto del paso 3).
7. Antes de cerrar sesión, comprueba que «Cerrar sesión» de esa cuenta nueva no enseña «Cambios por subir».
