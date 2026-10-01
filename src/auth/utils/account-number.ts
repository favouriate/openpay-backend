import { randomInt } from 'node:crypto';

export function generateAccountNumber(): string {
  return randomInt(1_000_000_000, 10_000_000_000).toString();
}
