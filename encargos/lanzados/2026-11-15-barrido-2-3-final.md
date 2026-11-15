Yala
# Barrido QA final de 2.3 en el iPhone 14, para dejarle a Jürgen solo lo indispensable
---
toca: docs/qa/barrido-2-3-final/
esfuerzo: high
cierre: cierra-sola
depende: Yala/yala-web-a-produccion
---

## Contexto
Jürgen pidió el 14-nov un barrido QA al final de la cola de 2.3, antes de la primera subida a TestFlight de 2.3. El objetivo es que a él le queden solo las pruebas indispensables, las que de verdad necesitan su ojo o su mano. Todo lo demás lo prueba esta sesión. Ya hubo un barrido hoy (`docs/qa/barrido-iphone-2026-11-14/`); úsalo como base y no repitas lo que ya pasó, salvo que su código haya cambiado después.

## Qué se pide
1. Con `tablero listar` arma la lista de todas las cards de Yala en QA y de lo mergeado en 2.3 desde el barrido anterior. Guárdala en `docs/qa/barrido-2-3-final/lista.md`.
2. Prueba cada una de punta a punta. Usa el simulador para lo que se pueda probar bien ahí (más rápido y con menos carga) y el iPhone 14 por DeviceMCP para lo que no: notificaciones, Siri y atajos, cámara y fotos, iCloud/CloudKit real, widgets, Live Activities, hápticos, rendimiento y teclado real. Lo que se da por probado en el dispositivo se prueba en el iPhone.
3. Con cada card:
   - Si pasa y no depende de un gusto de Jürgen: nota «Probada el <fecha>: pasó» con la evidencia, y a done.
   - Si falla: no la arregles. Va a backlog, prioridad high, con pasos, lo esperado, lo que pasó y la evidencia.
   - Si pasa pero necesita a Jürgen, se queda en QA. Esto aplica solo cuando hay una decisión de diseño o textos, algo que únicamente él puede hacer (su cuenta, su banco, su voz) o una prueba física que no se pudo automatizar ni hacer por DeviceMCP. La nota dice en una línea qué mirar.
4. Sé estricto con «indispensable»: si lo puedes probar tú, lo pruebas tú. Cada cosa que le dejes a Jürgen lleva el motivo de por qué no la pudiste probar.

## Entregable
Un artifact visual de Claude (no Markdown ni PDF), con la fuente en `docs/qa/barrido-2-3-final/`. Debe mostrar cuántas pasaron, cuántas fallaron (con link a su card) y, aparte y bien corta, la lista de pruebas indispensables para Jürgen, con pasos de un minuto cada una. Evidencia en `docs/qa/barrido-2-3-final/evidencia/`.

## Reglas de pruebas
- iPhone 14 («iPhone de JURGEN») por DeviceMCP, visible desde la Mini y la Max. Si está bloqueado, no lo desbloquees: deja checkpoint y cierra. Antes de instalar, con `mirar` revisa que ninguna otra sesión lo esté usando; si lo usa, espera en tramos cortos con aviso.
- Puedes usar un segundo simulador (en la Max el tope es 2, en la Mini 1).
- Pruebas de interfaz automáticas: solo las que tocan el cambio y la suite completa una sola vez al final. Una prueba que falla dos veces por timeout se anota como inestable. Tope de 30 minutos. Ninguna espera de más de 3 minutos sin escribir avance. No compiles en paralelo con otra sesión que esté compilando en la misma máquina si la carga pasa los núcleos.
- Descripción corta, en español, en cada comando Bash.

## Límites y cierre
- No arregles código de la app. No toques Production de CloudKit ni de Supabase.
- Commits y PR sin firma de IA, contra 2.3.
- /cerrar-total al terminar.

## Paso 0 — decisiones (resueltas en autónomo, bypass, nocturno)

1. **Qué entra en la lista.** Las 65 cards de Yala en «in qa» a las 00:55. Las 65 ya las había visto el barrido del
   14-nov; se re-prueba lo que cambió después (13 llegaron a QA tras él y 8 que fallaron volvieron con su arreglo) y lo
   que quedó «sin probar». Lo mergeado desde aquel barrido entra a través de sus cards, no como lista aparte.
2. **Build.** Yala Dev desde `origin/2.3` en `94e1ed469` (Debug-Dev, staging), instalada por cable en el iPhone 14 desde
   la Max. Sin TestFlight: lo que exige producción o Sandbox queda para Jürgen.
3. **Cuenta para «cuenta nueva».** Se elimina la cuenta de staging de `test@yala-app.pe` (datos de prueba) para tener una
   cuenta sin Yala; memoria: «QA físico: datos dev, no preguntes». Nada de Production.
4. **Filtro.** El de la skill `barrido-qa` más el del encargo: accesibilidad/tamaños y casos raros con test → done; a
   Jürgen solo Face ID/Apple, voz y cámara, su banco, su cuenta de Claude, la compra de Sandbox y el QR físico. Los
   vistos buenos de gusto se quedan en QA aparte de las pruebas.
5. **Pruebas de interfaz.** Solo las de las cards (11 suites) y una vez. La suite completa no se corre en local: el tope
   de 30 min se agota con la corrida de las cards (la primera cayó por infraestructura del simulador); vale la nocturna
   completa del 14-nov, verde, y la de esta noche cubre los merges posteriores.
6. **Bugs nuevos.** Cada hallazgo grave, card propia en backlog con pasos, esperado, pasó y evidencia; los menores, en
   una card baja conjunta. No se arregla código.
7. **Entregable.** Artifact HTML generado desde `docs/qa/barrido-2-3-final/fuente/` (resultados.json → index.html y
   lista.md), evidencia en `evidencia/`. PR contra 2.3 en cola de auto-merge.
