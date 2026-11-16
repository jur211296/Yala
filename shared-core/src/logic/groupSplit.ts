/**
 * Reparto igual de un gasto de grupo, como la app (`GroupSplitCalculator.equalSplit`,
 * `Yala/App/Logic/Calculators/GroupSplitCalculator.swift`). Lo usa Yala web al añadir un gasto (lote 3).
 *
 * La regla, línea a línea: la parte base es `floor(total * 100 / n) / 100`; los céntimos que sobran van de uno en uno a
 * los primeros participantes (en el orden de la lista), así que las partes suman el total exacto. Con un solo
 * participante, el total redondeado. Sin total positivo o sin participantes, `null`.
 *
 * Paridad: `mcp/test/groups-parity.test.ts` contra el golden que escribe la app (`WebGroupsParityGoldenTests`).
 */
import { round2 } from "./groupBalances";

export function equalSplit(total: number, participants: readonly string[]): { member: string; amount: number }[] | null {
  if (!(total > 0) || participants.length === 0) return null;
  if (participants.length === 1) return [{ member: participants[0]!, amount: round2(total) }];
  const count = participants.length;
  const base = Math.floor((total * 100) / count) / 100;
  let remainder = round2(total - base * count);
  return participants.map((member) => {
    let amount = base;
    if (remainder >= 0.005) {
      amount += 0.01;
      remainder -= 0.01;
    }
    return { member, amount: round2(amount) };
  });
}
