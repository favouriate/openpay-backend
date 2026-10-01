import 'reflect-metadata';
import { StandardSchemaValidationPipe } from '@nestjs/common';
import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { verify } from 'argon2';
import { beforeEach, afterEach, describe, expect, it, vi } from 'vitest';
import { PrismaService } from '../database/prisma.service.js';
import {
  Prisma,
  AccountStatus,
  AccountType,
} from '../generated/prisma/client.js';
import { AuthController } from './auth.controller.js';
import { AuthService } from './auth.service.js';
import { generateAccountNumber } from './utils/account-number.js';

vi.mock('./utils/account-number.js', () => ({
  generateAccountNumber: vi.fn(),
}));

const payload = {
  firstName: ' Perfect ',
  lastName: ' User ',
  email: ' Perfect@Example.COM ',
  password: '  a long passphrase  ',
};
const uniqueError = () =>
  new Prisma.PrismaClientKnownRequestError('private database detail', {
    code: 'P2002',
    clientVersion: '7.10.0',
  });

describe('Registration HTTP flow (mocked database)', () => {
  let app: INestApplication;
  const userCreate = vi.fn();
  const accountCreate = vi.fn();
  const findUnique = vi.fn();
  const transaction = vi.fn();
  beforeEach(async () => {
    vi.clearAllMocks();
    vi.mocked(generateAccountNumber).mockReturnValue('7394821056');
    userCreate.mockResolvedValue({
      id: 'user-id',
      firstName: 'Perfect',
      lastName: 'User',
      email: 'perfect@example.com',
    });
    accountCreate.mockResolvedValue({
      id: 'account-id',
      balance: new Prisma.Decimal(0),
      status: AccountStatus.ACTIVE,
    });
    findUnique.mockResolvedValue(null);
    transaction.mockImplementation(
      async (callback: (tx: unknown) => Promise<unknown>) =>
        callback({
          user: { create: userCreate },
          account: { create: accountCreate },
        }),
    );
    const module = await Test.createTestingModule({
      controllers: [AuthController],
      providers: [
        AuthService,
        {
          provide: PrismaService,
          useValue: { $transaction: transaction, user: { findUnique } },
        },
      ],
    }).compile();
    app = module.createNestApplication({ logger: false });
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(new StandardSchemaValidationPipe());
    await app.init();
  });
  afterEach(async () => {
    await app.close();
  });

  it('returns 201, persists normalized input and a zero-balance CUSTOMER account, and never returns secrets', async () => {
    const response = await request(app.getHttpServer())
      .post('/api/v1/auth/register')
      .send(payload)
      .expect(201);
    const created = userCreate.mock.calls[0]![0];
    expect(created.data).toMatchObject({
      email: 'perfect@example.com',
      firstName: 'Perfect',
      lastName: 'User',
    });
    expect(created.data.passwordHash).not.toBe(payload.password);
    expect(created.data.passwordHash).toMatch(/^\$argon2id\$/);
    expect(await verify(created.data.passwordHash, payload.password)).toBe(
      true,
    );
    expect(accountCreate.mock.calls[0]![0].data).toMatchObject({
      userId: 'user-id',
      type: AccountType.CUSTOMER,
      status: AccountStatus.ACTIVE,
      accountNumber: '7394821056',
    });
    expect(accountCreate.mock.calls[0]![0].data.balance.toString()).toBe('0');
    expect(response.body).toEqual({
      data: {
        user: {
          id: 'user-id',
          firstName: 'Perfect',
          lastName: 'User',
          email: 'perfect@example.com',
        },
        account: {
          id: 'account-id',
          accountNumber: '7394821056',
          balance: '0.00',
          currency: 'NGN',
          status: 'ACTIVE',
        },
      },
    });
    expect(JSON.stringify(response.body)).not.toContain('password');
    expect(findUnique).not.toHaveBeenCalled();
  });

  it.each([
    { email: 'bad' },
    { password: 'x'.repeat(14) },
    { password: 'x'.repeat(129) },
    { firstName: '  ' },
    { lastName: '' },
    { firstName: 'x'.repeat(101) },
    { lastName: 'x'.repeat(101) },
    { id: 'client-id' },
    { passwordHash: 'client-hash' },
    { balance: 100 },
    { status: 'ACTIVE' },
    { accountNumber: '1234567890' },
    { type: 'SYSTEM_FEE' },
    { createdAt: '2026-01-01' },
  ])(
    'rejects invalid input %j before touching the database',
    async (overrides) => {
      await request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send({ ...payload, ...overrides })
        .expect(400);
      expect(transaction).not.toHaveBeenCalled();
    },
  );

  it('maps a concurrent unique-email violation to safe HTTP 409', async () => {
    userCreate.mockRejectedValueOnce(uniqueError());
    findUnique.mockResolvedValueOnce({ id: 'other-user' });
    const response = await request(app.getHttpServer())
      .post('/api/v1/auth/register')
      .send(payload)
      .expect(409);
    expect(response.body.message).toBe('Email already registered');
    expect(JSON.stringify(response.body)).not.toContain(
      'private database detail',
    );
    expect(transaction).toHaveBeenCalledTimes(1);
  });

  it('retries a rolled-back account collision with a fresh candidate', async () => {
    vi.mocked(generateAccountNumber)
      .mockReturnValueOnce('1111111111')
      .mockReturnValueOnce('2222222222');
    accountCreate.mockRejectedValueOnce(uniqueError());
    const response = await request(app.getHttpServer())
      .post('/api/v1/auth/register')
      .send(payload)
      .expect(201);
    expect(transaction).toHaveBeenCalledTimes(2);
    expect(response.body.data.account.accountNumber).toBe('2222222222');
    expect(userCreate.mock.calls[0]![0].data.passwordHash).toBe(
      userCreate.mock.calls[1]![0].data.passwordHash,
    );
  });

  it('stops after five account collisions with 503, not duplicate email', async () => {
    accountCreate.mockRejectedValue(uniqueError());
    await request(app.getHttpServer())
      .post('/api/v1/auth/register')
      .send(payload)
      .expect(503);
    expect(transaction).toHaveBeenCalledTimes(5);
    expect(generateAccountNumber).toHaveBeenCalledTimes(5);
  });

  it('propagates account failure from the transaction without returning success (does not prove database rollback)', async () => {
    const failure = new Error('account write failed');
    accountCreate.mockRejectedValueOnce(failure);
    const service = app.get(AuthService);
    await expect(
      service.register({ ...payload, email: 'perfect@example.com' }),
    ).rejects.toBe(failure);
    expect(transaction).toHaveBeenCalledTimes(1);
    expect(userCreate).toHaveBeenCalledTimes(1);
    expect(findUnique).not.toHaveBeenCalled();
  });
});
