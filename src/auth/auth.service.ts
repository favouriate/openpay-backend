import {
  ConflictException,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import { argon2id, hash } from 'argon2';
import { PrismaService } from '../database/prisma.service.js';
import { Prisma } from '../generated/prisma/client.js';
import { AccountStatus, AccountType } from '../generated/prisma/enums.js';
import type { RegisterInput } from './schemas/register.schema.js';
import type { RegisterResponse } from './types/register-response.type.js';
import { generateAccountNumber } from './utils/account-number.js';

@Injectable()
export class AuthService {
  constructor(private readonly prisma: PrismaService) {}

  async register(input: RegisterInput): Promise<RegisterResponse> {
    const passwordHash = await hash(input.password, { type: argon2id });
    for (let attempt = 0; attempt < 5; attempt++) {
      const accountNumber = generateAccountNumber();
      try {
        return await this.prisma.$transaction(async (tx) => {
          const user = await tx.user.create({
            data: {
              email: input.email,
              firstName: input.firstName,
              lastName: input.lastName,
              passwordHash,
            },
            select: { id: true, firstName: true, lastName: true, email: true },
          });
          const account = await tx.account.create({
            data: {
              userId: user.id,
              type: AccountType.CUSTOMER,
              status: AccountStatus.ACTIVE,
              accountNumber,
              balance: new Prisma.Decimal(0),
            },
            select: { id: true, balance: true, status: true },
          });
          return {
            data: {
              user: {
                id: user.id,
                firstName: user.firstName,
                lastName: user.lastName,
                email: user.email,
              },
              account: {
                id: account.id,
                accountNumber,
                balance: account.balance.toFixed(2),
                currency: 'NGN' as const,
                status: account.status,
              },
            },
          };
        });
      } catch (error) {
        if (
          !(error instanceof Prisma.PrismaClientKnownRequestError) ||
          error.code !== 'P2002'
        ) {
          throw error;
        }
        // Query only after rollback: a concurrent email registration may have won.
        const existingUser = await this.prisma.user.findUnique({
          where: { email: input.email },
          select: { id: true },
        });
        if (existingUser) {
          throw new ConflictException('Email already registered');
        }
        // The transaction was rolled back; retry with a fresh account candidate.
      }
    }
    throw new ServiceUnavailableException(
      'Registration temporarily unavailable. Please try again.',
    );
  }
}
