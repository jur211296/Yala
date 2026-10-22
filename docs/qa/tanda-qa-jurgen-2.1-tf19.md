# Tanda de QA de Jürgen — 2.1 sobre el TestFlight 19

Sale del QA guiado del 19-oct sobre el TestFlight 18 (PR #563): 23 de 27 pasaron, y las ocho cards de 2.1 que salieron
de ahí ya están arregladas en los PR **#564** (`cq2i`, `9ttd`, `ewkw`, `8171`) y **#566** (`axgf`, `ppxk`, `t2q8`,
`n2xn`). Esta tanda las prueba en aparatos de verdad y cierra lo que quedó pendiente (D · E2 y el paso 3 del micrófono).

**Todo lo que se puede, en Yala Dev contra staging** (decisión de Jürgen del 20-oct: no contaminar producción). Al
TestFlight 19, contra producción, solo van las dos pruebas que staging no reproduce:

- **`n2xn`**: actualizar desde la 2.0.4 de la App Store exige el mismo bundle que la App Store.
- **`axgf`**: el atasco era App Attest en `enforce`, que solo tiene producción (staging va en `observe`).

Fuera de la tanda (2.2): `n5zw` (iCloud Drive apagado con la app cerrada) y `ewvm` (consentimiento y nombre otra vez al
re-entrar en Grupos, la mitad que falló de A · C6). Tiempo: unas **2 h 15 min**, casi todo esperas.

## Montaje

- **Yala Dev** compilado desde `origin/2.1` (`ad6781f8a`, con #562, #564, #566 y #569) e instalado por Frank con
  `devicectl`. **TestFlight 19** desde el mismo `2.1`.
- **iPhone de QA** (iCloud `test@yala-app.pe`) = aparato **A**. Yala Dev en privado con 1 movimiento; en Archivos sigue
  `movimientos-qa-1500.csv`.
- **iPad** (iCloud `test@yala-app.pe`) = aparato **B**.
- **Cuentas:** staging y producción están sin cuentas de prueba, así que `jur211296@gmail.com`, `admin@yala-app.pe` y
  `test@yala-app.pe` (Google) cuentan como nuevas en los dos.
- **Enlaces de invitación:** con Yala Dev y Yala instaladas a la vez, un enlace puede abrir la que no toca. En el bloque
  5, el iPad solo tiene Yala Dev.

## Orden

| # | Bloque | Card | App | Aparato | Min |
|---|---|---|---|---|---|
| 1 | La música vuelve tras la voz | `8171` | Yala Dev | A | 5 |
| 2 | «Empezar sin ellos» con 1.500 movimientos en iCloud | `9ttd` | Yala Dev | A | 30 |
| 3 | Grupos sin relanzar y la cuenta de grupos correcta | `ewkw`, `cq2i`, `ppxk` | Yala Dev | A | 30 |
| 4 | D · E2: reintentar «Volver a iCloud» en el segundo aparato | `gk5w` | Yala Dev | A + B | 25 |
| 5 | D · E1 paso 3: unirse por enlace tras reinstalar | `t2q8` | Yala Dev | A + B | 25 |
| 6 | Actualizar desde la 2.0.4: «Mira lo nuevo» al primer arranque | `n2xn` | App Store → TF 19 | A | 15 |
| 7 | «Activar la nube» en producción sin pararse | `axgf`, `ppxk` | TF 19 | A | 20 |

Cada bloque deja el aparato como lo necesita el siguiente.

---

## Parte 1 · Yala Dev contra staging

### 1 · La música vuelve tras la voz — `8171`

1. Pon música en otra app. En Yala Dev › Panel › **Voz**: la música se para.
2. **«Cancelar»**. **Esperado:** la música vuelve sola.
3. Repite diciendo «taxi 12» y **«Listo»**. **Esperado:** la música vuelve al terminar de grabar. Descarta el borrador.

Cierra también `h52f` (IA sesión 2), que solo esperaba esto.

### 2 · «Empezar sin ellos» con un iCloud grande — `9ttd` · bloquea

1. En la sesión privada: Perfil › **«Importar archivo»** › `movimientos-qa-1500.csv`, a una cuenta en soles.
2. Deja Yala abierta un par de minutos para que suban a iCloud. Perfil › **«Cerrar sesión»**. Si sale «Guardando tus
   cambios pendientes…» y un aviso con cifra, **«Esperar»** hasta que cierre sola; nada con «igualmente» ni «borrar».
3. **«Es mi primera vez en Yala»** › **«Tu cuenta en la nube»** › **Google jur211296@gmail.com**. (Si sale «Entra a tu
   cuenta», toca «Crear otra cuenta».) Termina el onboarding y crea un gasto **«TF19 A1»**.
4. Perfil › **«Dónde viven tus datos»** › **«Volver a iCloud»** → «Tu iCloud ya tiene datos de Yala», con unos 1.500.
5. **«Empezar sin ellos»** › **«Borrar y volver a iCloud»**.
6. **Esperado:** el botón dice **«Borrando los datos de antes… N hasta ahora»** y la cifra sube; termina en **un solo
   intento** y la vuelta sigue sola (reabre si lo pide). Al final, en Registros solo está «TF19 A1».
7. Si se corta, apunta la cifra y el texto: no debe decir «Revisa tu conexión» salvo sin red.

### 3 · Grupos sin relanzar y la cuenta de grupos correcta — `ewkw`, `cq2i`, `ppxk` · bloquea

1. En la sesión privada que dejó el bloque 2: Perfil › **«Dónde viven tus datos»** › **«Asociar una cuenta para
   grupos»** › **Google test@yala-app.pe**. Es la cuenta de grupos «vieja» que recordará el iCloud.
2. Borra Yala Dev (la reinstalo yo). **«Vengo por un grupo»** › **«Crear mi primer grupo»** › **Google
   admin@yala-app.pe** › crea **«QA TF19»**. Perfil › **«Cerrar sesión»**.
3. Borra Yala Dev otra vez (la reinstalo yo). **«Ya tengo una cuenta»** › **Google admin@yala-app.pe**.
4. **`ewkw` · esperado:** en **Grupos**, «QA TF19» aparece en unos segundos, **sin cerrar Yala**.
5. Perfil › **«Activar Yala completo»** › **«Tu cuenta en tu iCloud privado»** › **«Traer mis datos»**, reabriendo si lo
   pide.
6. **`cq2i` · esperado:** en «Dónde viven tus datos», Grupos dice **«Tus grupos usan admin@yala-app.pe»** (no
   test@yala-app.pe) y «Activar la nube» **no** sale bloqueado. **No** toques «Desasociar».
7. **«Activar la nube»** › consentimiento (usa la sesión de admin@) y quédate en la pantalla hasta «Tu cuenta en la
   nube». **`ppxk` · esperado:** si sale «Esperando a que iCloud termine de sincronizar…», «Cancelar la activación» está
   **activo** (no lo toques) y la barra **no** vuelve del 75 % al 60 %. Apunta cuánto tardó.

### 4 · D · E2: reintentar «Volver a iCloud» en el segundo aparato — `gk5w`

El iPhone quedó en la nube con admin@, una cuenta **migrada** desde iCloud: la única que puede volver a iCloud desde otro
aparato.

1. iPad: borra la **Yala de TestFlight** (y Yala Dev, si está; la instalo yo nueva). En Yala Dev: **«Ya tengo una
   cuenta»** › **Google admin@yala-app.pe** → Panel con los mismos datos.
2. iPhone: «Dónde viven tus datos» › **«Volver a iCloud»** hasta terminar. Si sale «Tu iCloud ya tiene datos de Yala»,
   **«Sumarlos a mis datos»**.
3. iPad: **«Volver a iCloud»** → sale la espera; **cancélala**.
4. iPad: **reintenta**. **Esperado:** avanza, y **no** sale «tu cuenta no lo permitía».

### 5 · D · E1 paso 3: unirse por enlace tras reinstalar — `t2q8` · bloquea

1. iPhone (Yala Dev): Grupos › crea **«QA unión 19»** › sus ajustes › **«Invitar por enlace»** › al iPad por AirDrop.
2. iPad: borra Yala Dev; la reinstalo yo **sin abrirla**. Abre el enlace › **«Unirme al grupo»** › **Google
   jur211296@gmail.com** (cuenta completa del bloque 2).
3. **Esperado:** **no** sale «Este dispositivo tiene datos de otra cuenta» ni «Antes de unirte, este teléfono queda en
   blanco»; «Conectando con tu grupo…» pasa a **«Esperando aprobación»** sin esperar minutos. En el iPhone llega la
   solicitud.
4. iPad: borra Yala Dev; la reinstalo yo sin abrir. Enlace › «Unirme al grupo» › **Google test@yala-app.pe**. En la hoja
   de Unirme, **cierra Yala del todo** y vuelve a abrir el enlace.
5. **Esperado:** no pide dejar el teléfono en blanco ni se queda minutos en «Conectando…»; acaba en «Esperando
   aprobación».

---

## Parte 2 · TestFlight 19 contra producción

### 6 · Actualizar desde la 2.0.4 — `n2xn` · bloquea

1. iPhone: borra la **Yala de TestFlight**. Instala **Yala desde la App Store** (2.0.4).
2. Ábrela y haz el alta **restaurando desde iCloud** (los datos de prueba del contenedor de producción).
3. Sin volver a abrirla, instala el **TestFlight 19 encima** y ábrelo.
4. **Esperado:** «Mira lo nuevo en Yala» sale en el **primer** arranque. «Continuar».
5. Cierra Yala del todo y ábrela: sale la **oferta de prueba de Pro** (si no eres Pro) y Novedades **no** vuelve.

### 7 · «Activar la nube» en producción sin pararse — `axgf`, `ppxk` · bloquea

1. En la sesión privada del bloque 6: «Dónde viven tus datos» › **«Activar la nube»** › consentimiento › **Google
   jur211296@gmail.com** (en producción es nueva).
2. Quédate en la pantalla. **`axgf` · esperado:** la barra pasa del 55 % y termina **sin cerrar Yala**. Si se para más
   de 2 min, apunta la hora.
3. **`ppxk` · esperado:** si sale «Esperando a que iCloud termine de sincronizar…», «Cancelar la activación» está activo
   y la barra no vuelve del 75 % al 60 %.
4. Limpieza: Perfil › **«Eliminar mi cuenta»** hasta el final. Producción vuelve a quedar sin cuentas de prueba.

---

## Al terminar

- Cada card que pase, a done; `gk5w`, `h52f` y los tickets de `tickets/qa/` que cuelgan de ellas, también.
- El iPad vuelve a tu iCloud personal.
- Staging: Frank borra las cuentas de prueba de la tanda (las `i5-*` se quedan).

---

## Resultado (2026-10-20)

**Pasan:** `8171` (la música vuelve), `9ttd` (1.501 borrados en un intento), `ewkw` (grupo sin relanzar), `cq2i` (Grupos
nombra la cuenta correcta), `gk5w` · E2 (con el montaje bueno: el iPad adopta con «Activar en este dispositivo»),
`n2xn` (Novedades al primer arranque, con la 2.0.4 cerrada) y `axgf` (producción: sin reabrir a mitad). `h52f` se cerró
con `8171`.

**Falla:** `t2q8`. Pasa el enlace directo con cuenta completa; fallan la entrada por «Vengo por un grupo › Tengo una
invitación» con cuenta completa y el relanzamiento a mitad: los dos acaban en «Antes de unirte, este teléfono queda en
blanco». Vuelve a in progress.

**A 2.2 por decisión de Jürgen:** `ppxk` (sin bucle, pero 9,5 min en producción y ~2,5 en staging; prioridad alta, junto
a `igt9` y `27z3`).

**Cards nuevas:** 2.1 → `840m` (rechazar solicitudes en grupos de la nube; decisión A, implementarlo), `blqa` (la revisión
de iCloud se pasa de 25 s; 2.1), `z81w` (la invitación tarda 10-15 s en la bienvenida; 2.1 con «Abriendo tu
invitación…»). 2.2 → `ypit` («reabre Yala» solo al entrar en privado), `y2vg` (Novedades con la 2.0.4 en segundo plano),
`9mc6` (bloqueo por una asociación vieja tras la 2.0.4), `vbf9` (el segundo aparato debería proponer la nube solo).
Notas en `trc6`, `27z3`, `046l` (L12-17).
