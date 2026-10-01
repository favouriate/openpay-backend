import { z } from 'zod';

export const envSchema = z.object({
  DATABASE_URL: z
    .string()
    .min(1)
    .pipe(z.url())
    .refine(
      (value) => /^postgres(?:ql)?:/i.test(value),
      'DATABASE_URL must be a PostgreSQL URL using postgresql:// or postgres://',
    ),
});

export type Environment = z.infer<typeof envSchema>;
