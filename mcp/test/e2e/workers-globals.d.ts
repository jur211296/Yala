// El e2e compila con los tipos de Node y del DOM, no con los de Workers (mezclarlos choca en fetch y Request).
// `src/env.ts` nombra el KV del runtime; al e2e le basta con que el nombre exista.
interface KVNamespace {}
