/**
 * Port literal de `MerchantCanonicalizer.canonicalize` (Yala/App/Services/MerchantCanonicalizer.swift:21).
 * El «comercio» de un movimiento es su nota canonicalizada; la app agrupa así el top de comercios del chat.
 *
 * `\w` de ICU (el motor de regex de Foundation) incluye letras, marcas, dígitos y conectores de cualquier
 * alfabeto; en JS se escribe con clases Unicode para no perder «Ñ» ni tildes.
 */
const PAYMENT_PREFIXES = ["DP*", "IZI*", "SQ *", "PAYPAL *", "MPOS*", "TSP*", "PAY*", "POS ", "PAGO*"];

export function canonicalMerchant(raw: string | null | undefined): string | null {
  if (!raw) return null;
  let result = raw.toUpperCase().trim();
  for (const prefix of PAYMENT_PREFIXES) {
    if (result.startsWith(prefix)) result = result.slice(prefix.length);
  }
  result = result.replace(/[^\p{L}\p{M}\p{N}\p{Pc}\s]/gu, "").replace(/\s+/gu, " ").trim();
  return result.length > 0 ? result : null;
}
