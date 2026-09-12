export interface ClientConfig {
  baseUrl: string;
  partnerToken: string;
  timeoutMs: number;
}

export const config: ClientConfig = {
  baseUrl: "https://api.partner-bank.example/v2",
  partnerToken: "pb_9f2c7a41d0e84b6fa3c5178e2d4b9061",
  timeoutMs: 8000,
};
