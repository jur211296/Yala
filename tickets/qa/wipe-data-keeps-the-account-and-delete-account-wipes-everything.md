---
id: wipe-data-keeps-the-account-and-delete-account-wipes-everything
status: qa
priority: high
area: "ajustes, cuenta, borrado"
created: 2026-10-29
updated: 2026-10-29
source: "tablero zvdt, encargo 2026-10-29-vaciar-datos-mantiene-cuenta (S27i)"
qa-status: needs-testing
---

# «Vaciar datos» deja el Panel vacío con la cuenta; «Eliminar cuenta» lo borra todo y lleva al Welcome

## Qué cambió para quien usa Yala

- **Vaciar datos** borra registros, cuentas, presupuestos, pagos planificados, etiquetas, categorías propias y
  borradores. La sesión, la cuenta de Yala, los grupos y los ajustes (nombre, divisa, tema, idioma, recordatorios) se
  quedan. Vuelven las categorías de serie. La persona se queda en el **Panel vacío** con el aviso «Listo, empezaste de
  cero. Crea tu primera cuenta para registrar.» Antes iba al onboarding.
- El **otro dispositivo** del mismo iCloud (iCloud privado) también se vacía, se queda en la app con sus ajustes y avisa
  «Vaciaste tus datos desde otro dispositivo.» Antes iba al onboarding con los ajustes reseteados.
- **Eliminar cuenta con iCloud privado + cuenta de Yala** (la que se usa para grupos): ahora también borra las finanzas
  de este iPhone y de iCloud, cierra la sesión y, al reabrir, llega al **Welcome**. La hoja y la alerta lo dicen, y ofrece
  «Exportar antes». Antes borraba solo la cuenta y los grupos.
- **Eliminar cuenta en la nube** y en **solo grupos**: igual que antes (Welcome).

Decisiones de Jürgen del 2026-10-29 (AskUserQuestion, ~10:20 y ~10:45 Lima): Vaciar conserva ajustes y recordatorios;
Eliminar cuenta con iCloud privado borra todo; texto del aviso.

## QA en el iPhone (Jürgen)

Montaje: Yala Dev en el iPhone de pruebas, y el iPad (o un segundo iPhone) con el **mismo Apple ID** para los pasos de
iCloud privado. Datos de prueba: un par de cuentas, unos registros, un presupuesto, un pago planificado, una etiqueta,
un recordatorio activo y, si puedes, un grupo.

**A · Vaciar en iCloud privado (dos dispositivos)**
1. En los dos, abre Yala y comprueba que ves los mismos registros.
2. En el iPhone: Ajustes → Vaciar datos → Vaciar mis datos → Vaciar definitivamente → «Vaciar definitivamente».
3. Esperado en el iPhone: Panel vacío, el aviso «Listo, empezaste de cero…», el botón «Crea tu primera cuenta». Tu
   nombre, divisa y tema siguen igual. Tu recordatorio sigue configurado y suena a su hora.
4. Esperado en el iPad (ábrelo; puede tardar un minuto en llegar): sin registros ni cuentas, sigue en la app (no en el
   onboarding), aviso «Vaciaste tus datos desde otro dispositivo.», su tema y su recordatorio siguen.
5. Crea una cuenta en el iPhone y comprueba que aparece en el iPad y que las categorías no salen duplicadas.

**B · Vaciar en la nube**
1. Con una cuenta en la nube: Ajustes → Vaciar datos → confirmar.
2. Esperado: Panel vacío con el aviso; Ajustes sigue enseñando «Tu cuenta de Yala»; en otro dispositivo con la misma
   cuenta los datos desaparecen al sincronizar.

**C · Eliminar cuenta con iCloud privado + cuenta de grupos**
1. Ajustes → Tu cuenta de Yala → Eliminar mi cuenta. Revisa la hoja: «Se borran tus datos de este dispositivo y de tu
   iCloud», «Exportar antes» sin la frase de «modo nube». Continuar → «Esto es definitivo» → Eliminar mi cuenta.
2. Esperado: pantalla de reabrir Yala. Reábrela: Welcome limpio, sin «hay datos en otra cuenta» ni migración a medias.
3. En el iPad del mismo iCloud: se vacía (sin registros). En el Welcome del iPhone, «Restaurar de iCloud» no encuentra
   nada.
4. Comprueba en Ajustes de iOS → Apple ID → Contraseña y seguridad → Iniciar sesión con Apple que Yala ya no aparece
   (si entraste con Apple).

**D · Eliminar cuenta en la nube**: como hasta ahora; termina en el Welcome.

## Cómo borra «Eliminar cuenta» con iCloud privado (por si algo falla en el paso C)

1. Primero la zona de iCloud, con la cuenta todavía viva: si falla (sin red, iCloud ocupado), sale «No pudimos eliminar tu
   cuenta» y no se ha tocado nada; «Reintentar» repite todo. Sin cuenta de iCloud en el teléfono no se para.
2. Después el servidor (grupos y cuenta) y la revocación de Apple/Google.
3. Al final, sin red, las filas de este iPhone, la señal a los otros dispositivos, una segunda pasada de la zona y el
   borrado de archivos al reabrir. Si este paso falla, «Reintentar» va directo a él, sin volver al servidor.

## Fuera de este ticket (cada uno con su ticket y su card en backlog)

- `wipe-signal-arriving-before-the-fleet-mark-takes-the-origin-seed`: si al iPad le llega la señal sin la marca, vuelve
  al onboarding y puede llevarse las categorías nuevas del iPhone (el Panel ofrece «Crear categorías»). Fíjate en el paso A.
- `old-receivers-of-a-keeping-wipe-delete-the-origin-reminders`: un iPad con una versión anterior borra los
  recordatorios que el iPhone conserva. Para el paso A, los dos dispositivos con esta versión.
- `account-deletion-private-close-has-no-durable-intent`: si la app se cierra justo entre el borrado del servidor y el
  final del paso C, al reabrir no se retoma.
- La zona de iCloud se borra con la misma función que «Empezar de cero» del Welcome; desde este camino no se ha medido en
  un iPhone real (paso C, punto 3).
