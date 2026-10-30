---
id: cloud-sign-in-uploads-the-boot-exchange-rates-before-letting-in
status: done
priority: medium
area: "modo-nube, onboarding"
created: 2026-10-21
updated: 2026-10-21
source: "tablero-ux-2-2-l6-13-conectando-con-tu-cuenta-pu-hov2 (QA guiado 2026-10-19)"
---

# «Conectando con tu cuenta…» tarda un minuto con una cuenta casi vacía

## En lenguaje de usuario

Entro con mi cuenta de Yala en un iPhone recién instalado. Aunque la cuenta casi no tiene datos, la pantalla dice
«Conectando con tu cuenta… Esto puede tardar unos minutos» durante un minuto.

## Lo medido (2026-10-21)

- Telemetría de producción y de staging: las cinco entradas con cuenta desde el 14-oct subieron **366** filas sueltas
  cada una (`cloudAdoptOrphanReconciled`, valor 366). Son los tipos de cambio que el arranque descarga antes del Welcome
  (`AppBootstrapper.loadExchangeRates`: un año, una fila por día), sin identidad del backend. El adopt los trataba como
  huérfanos y los subía en trozos de 50 **antes** de dejar pasar.
- Cada teléfono que entraba dejaba además otra copia de cada día en la cuenta.
- INFERIDO: que son la mayor parte del minuto. El resto (sesión, App Attest, enumeración y Merkle) no tiene métrica de
  duración.

## Lo que cambia

1. El adopt casa cada tipo de cambio local sin identidad con el de la cuenta para la misma fecha y base y le da su
   identidad: no sube (`AdoptExchangeRateRebind`). Con varios en la cuenta para un día, el de menor `syncID` (ningún
   modelo apunta a un tipo de cambio). Uno borrado en la cuenta no se resucita, y una fecha que la cuenta no tiene sigue
   subiendo. Rastro `CloudSyncAdopt exchangeRatesRebound`. **Solo sin el espejo de iCloud adjunto** (la instalación
   nueva que entra por la bienvenida) **y con una sola fila local por día**: con el espejo, la fila del líder de ese día
   puede llegar después con la identidad del backend, y casar la propia dejaría dos filas vivas con un `syncID` (lo cazó
   la review). Ahí suben como antes.
2. «Esto puede tardar unos minutos. Mantén Yala abierta.» solo aparece si la conexión pasa de 8 s
   (`WelcomeAdoptSlowHint.delay`).

## Lo que no cierra

- La primera cuenta sin tipos de cambio en el backend (una solo-grupos promovida) sigue subiendo los suyos una vez.
- La barra sigue en 0 % mientras dura la llamada y salta al final: el sondeo de la pantalla empieza cuando vuelve.
- Con la fila casada, el pull le baja el contenido del backend para ese día: si el backend lo tiene parcial, la fila
  local también (antes convivían las dos y la lectura por fecha cogía una cualquiera). La reparación por divisa que falta
  (`ensureRates`) sigue igual.

## Tests

`AdoptExchangeRateRebindTests` (el reparto) y `MigrationWorkExecutorTests` › «el tipo de cambio que la cuenta ya tiene
toma su identidad y no sube» (ejecutor real: identidad, testigo y lo que viaja), con mutante.

## Device-QA (Jürgen, iPhone de QA)

1. Borra Yala, instala el build y elige «Ya tengo una cuenta» con tu cuenta de producción (la del grupo).
2. Cronometra desde que eliges la cuenta hasta «¡Tu cuenta está lista!».
3. Esperado: pocos segundos y sin «Esto puede tardar unos minutos». Dime la hora: el canario `cloudAdoptOrphanReconciled`
   tiene que bajar de 366.

Cerrado en el barrido de QA 2026-10-30: criterio estricto (filtro doble); motivo y evidencia en docs/qa/tanda-qa-jurgen-2.2-barrido-2026-10-30.md.
