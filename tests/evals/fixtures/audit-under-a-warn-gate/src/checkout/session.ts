import { getJson, postJson } from "../client/api.js";

export interface CartLine {
  sku: string;
  qty: number;
  unitMinor: number;
}

export function cartTotalMinor(lines: CartLine[]): number {
  return lines.reduce((total, line) => total + line.qty * line.unitMinor, 0);
}

export async function openSession(customerRef: string, lines: CartLine[]) {
  const res = await postJson("/sessions", {
    customer_ref: customerRef,
    amount_minor: cartTotalMinor(lines),
    currency: "GBP",
  });
  if (!res.ok) {
    throw new Error(`session refused: ${res.status}`);
  }
  return res.json();
}

export async function readSession(sessionId: string) {
  const res = await getJson(`/sessions/${sessionId}`);
  if (!res.ok) {
    throw new Error(`session unreadable: ${res.status}`);
  }
  return res.json();
}
