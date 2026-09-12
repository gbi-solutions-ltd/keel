import { config } from "./config.js";

export async function postJson(path: string, body: unknown): Promise<Response> {
  return fetch(`${config.baseUrl}${path}`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${config.partnerToken}`,
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(config.timeoutMs),
  });
}

export async function getJson(path: string): Promise<Response> {
  return fetch(`${config.baseUrl}${path}`, {
    headers: { authorization: `Bearer ${config.partnerToken}` },
    signal: AbortSignal.timeout(config.timeoutMs),
  });
}
