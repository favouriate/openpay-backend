import { z } from 'zod';

export const registerSchema = z.strictObject({
  firstName: z.string().trim().min(1).max(100),
  lastName: z.string().trim().min(1).max(100),
  email: z.string().trim().toLowerCase().pipe(z.email()),
  password: z.string().min(15).max(128),
});

export type RegisterInput = z.infer<typeof registerSchema>;
