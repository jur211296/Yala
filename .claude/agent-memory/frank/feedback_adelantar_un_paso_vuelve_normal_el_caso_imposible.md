---
name: adelantar-un-paso-vuelve-normal-el-caso-imposible
description: Mover el consentimiento de Grupos ANTES de la sesión convirtió el «esto no ocurre en la práctica» del docblock en el camino de todo el que entra sin cuenta
metadata:
  type: feedback
---

En el lote decidido 2.2 · 13 (L12-4) el paso 3 del educativo pasó a aceptar el consentimiento de Grupos antes de
iniciar sesión. El registrar ya admitía ese caso («sin sesión no se arma; en la práctica no ocurre; si ocurriera,
`adoptLegacyIfNeeded` lo sella»), así que parecía gratis. La review adversarial midió tres huecos que solo eran
inofensivos mientras el caso era raro: el snapshot sin sello sobrevivía a «Empezar desde cero» y se le atribuía a la
persona siguiente, el `path` de diagnóstico llegaba como «adopt-legacy», y las puertas de inicio de sesión que no son
la hoja de Grupos no lo sellaban hasta relanzar.

**Why:** un docblock que dice «este caso no ocurre» describe las defensas que NO se construyeron; reordenar pasos lo
convierte en el caso principal sin tocar una línea de ese fichero.

**How to apply:** al adelantar o fusionar un paso de una cadena (consentimiento, alta, sello), busca en los
escritores y lectores que toca los «en la práctica no ocurre» / «solo legacy» y vuelve a medir cada frontera (relevo
de persona, cierre de sesión, otras puertas) con el caso ya normal. Relacionado: [[mi-arreglo-cumple-una-premisa-que-era-falsa]].
