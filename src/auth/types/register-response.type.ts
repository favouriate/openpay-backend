import type { AccountStatus } from '../../generated/prisma/enums.js';

export type RegisterResponse = {
  data: {
    user: { id: string; firstName: string; lastName: string; email: string };
    account: {
      id: string;
      accountNumber: string;
      balance: string;
      currency: 'NGN';
      status: AccountStatus;
    };
  };
};
