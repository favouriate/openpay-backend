import { expect, it, vi } from 'vitest';
import { randomInt } from 'node:crypto';
import { generateAccountNumber } from './account-number.js';
vi.mock('node:crypto', () => ({ randomInt: vi.fn() }));

it.each([1_000_000_000, 9_999_999_999])(
  'generates ten non-leading-zero digits at boundary %s',
  (candidate) => {
    vi.mocked(randomInt).mockReturnValue(candidate as never);
    expect(generateAccountNumber()).toBe(String(candidate));
    expect(generateAccountNumber()).toMatch(/^[1-9][0-9]{9}$/);
    expect(randomInt).toHaveBeenCalledWith(1_000_000_000, 10_000_000_000);
  },
);
