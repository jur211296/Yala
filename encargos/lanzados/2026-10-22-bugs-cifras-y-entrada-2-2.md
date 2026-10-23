Encargo Yala 2.2 · Bugs de cifras y de entrada (cola final, punto 4). Busca en el tablero (`tablero listar --proyecto yala --version 2.2 --estado "lista para lanzar"`) las cards de cada punto y resuélvelas juntas:
- La calculadora da 0 con montos ≥1.000.
- El saldo del Panel no cuadra con «¿Cuánto tienes hoy?».
- «vs mes pasado» cuenta un día de más.
- «Vengo por un grupo» pide el consentimiento otra vez.
- Entrar con Google después de Apple.
- «Ya tengo cuenta» ve los tips.
- Importar archivo: Grupos en PEN y falta «Importación completada».
- El micrófono del chat usa el permiso del chat.
- El segundo botón del educativo de Grupos.
Paso 0: la Mini tiene 22 GB libres (umbral 32). Corre `limpiar-mac` antes de compilar. Confirma que la rama nace de origin/2.2; si no, haz git fetch y pásate a origin/2.2 antes de tocar nada. El PR va contra 2.2.
Reglas: no esperes el CI de ningún PR; haz fetch y rebase sobre origin/2.2 solo justo antes de abrir el PR. Solo simulador, nunca los iPhone/iPad reales de Jürgen. No toques en ~/Yala los .ckdb de CloudKit, Yala.xcscheme ni encargos/pendientes/. No toques tmux salud--, sat-lab-- ni clinicas-dentales-bi--. Si hay diseño de UI sin decidir, deja propuestas y que decida Jürgen. Capturas de antes y después, tests en verde, textos en los 16 idiomas, mueve las cards (lo que necesite un dispositivo real va a in qa a jurgen con su tanda) y el digest en español neutro.
Al terminar: /cerrar-total

## Paso 0

- Base: worktree sobre `origin/2.2` (5fb3a3f88). Disco: 21 GB tras `limpiar-mac` (no liberó nada; DerivedData vive en ExtDev).
- Cards: calculadora `…calculadora-del-saldo-4jj0`, saldo `…panel-y-la-hoja-c-owf3`, vs mes pasado `…heros-de-tendenc-fzxa`,
  Vengo por un grupo `…vengo-por-un-grup-ewvm`, Google `…entrar-con-google-en-un-iphone-qu-qqo7`, tips `…ya-tengo-una-cuenta-vuel-ds09`,
  importar `…importar-archivo-deja-elegir-la-cuenta-i-xoh2` + `…al-terminar-de-importar-un-archivo-no-sa-trc6`,
  micrófono `…microfono-del-chat-manda-el-audio-a-l-0xhm`, educativo `…ultimo-paso-del-educativo-de-grup-ldqu`.
- **Google después de Apple: ya lo resuelve el PR #595** (en cola de auto-merge, card en `in qa` con su guion). No se repite.
- Decisiones de Jürgen hoy (AskUserQuestion): tips → «si llega con datos»; saldo → «saldo = lo que hay» (arriba, curva de
  saldo y hoja: mismas cuentas —filtro de cuentas + interruptor de Grupos— y todos sus movimientos; los chips no mueven un saldo).
- Ya decididas en las cards: micrófono → A (pide además el permiso de voz y foto); educativo → B («Ahora no», reusa `action.notNow`).
- Asumido: «vs mes pasado» se arregla en el helper (`-1 s` condicional) y se retira la corrección local de Yala IA, que quedaría doble.
- Asumido: «Vengo por un grupo» espera a la lectura del consentimiento de la cuenta antes de decidir la puerta; y si la cuenta ya
  tiene grupos con su nombre, el alta se completa con ese nombre en vez de abrir el formulario del primer grupo.
- Asumido: importar → el resultado sale en el `onDismiss` de la hoja (sin retardo fijo) y los dos selectores excluyen cuentas de sistema.
