-- CreateEnum
CREATE TYPE "UserStatus" AS ENUM ('ACTIVE', 'SUSPENDED', 'CLOSED');

-- CreateEnum
CREATE TYPE "AccountType" AS ENUM ('CUSTOMER', 'SYSTEM_FEE');

-- CreateEnum
CREATE TYPE "AccountStatus" AS ENUM ('ACTIVE', 'FROZEN', 'CLOSED');

-- CreateEnum
CREATE TYPE "TransferType" AS ENUM ('INTERNAL', 'EXTERNAL');

-- CreateEnum
CREATE TYPE "TransferStatus" AS ENUM ('PENDING', 'COMPLETED', 'REVERSED');

-- CreateTable
CREATE TABLE "User" (
    "id" UUID NOT NULL DEFAULT uuidv7(),
    "email" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "firstName" TEXT NOT NULL,
    "lastName" TEXT NOT NULL,
    "status" "UserStatus" NOT NULL DEFAULT 'ACTIVE',
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Account" (
    "id" UUID NOT NULL DEFAULT uuidv7(),
    "userId" UUID,
    "type" "AccountType" NOT NULL DEFAULT 'CUSTOMER',
    "status" "AccountStatus" NOT NULL DEFAULT 'ACTIVE',
    "accountNumber" VARCHAR(10),
    "balance" DECIMAL(19,2) NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "Account_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FinancialInstitution" (
    "id" UUID NOT NULL DEFAULT uuidv7(),
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "isInternal" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "FinancialInstitution_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Transfer" (
    "id" UUID NOT NULL DEFAULT uuidv7(),
    "reference" TEXT NOT NULL,
    "type" "TransferType" NOT NULL,
    "status" "TransferStatus" NOT NULL DEFAULT 'PENDING',
    "senderAccountId" UUID NOT NULL,
    "recipientAccountId" UUID,
    "destinationInstitutionId" UUID,
    "destinationAccountNumber" VARCHAR(10),
    "destinationAccountName" TEXT,
    "amount" DECIMAL(19,2) NOT NULL,
    "feeAmount" DECIMAL(19,2) NOT NULL DEFAULT 0,
    "description" TEXT,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "completedAt" TIMESTAMPTZ(6),
    "reversedAt" TIMESTAMPTZ(6),

    CONSTRAINT "Transfer_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RefreshSession" (
    "familyId" UUID NOT NULL,
    "usedAt" TIMESTAMPTZ(6),
    "replacedById" UUID,
    "id" UUID NOT NULL DEFAULT uuidv7(),
    "userId" UUID NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMPTZ(6) NOT NULL,
    "revokedAt" TIMESTAMPTZ(6),

    CONSTRAINT "RefreshSession_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "IdempotencyRecord" (
    "transferId" UUID NOT NULL,
    "id" UUID NOT NULL DEFAULT uuidv7(),
    "userId" UUID NOT NULL,
    "key" TEXT NOT NULL,
    "requestHash" TEXT NOT NULL,
    "responseStatusCode" INTEGER NOT NULL,
    "responseBody" JSONB NOT NULL,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "IdempotencyRecord_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE UNIQUE INDEX "Account_userId_key" ON "Account"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "Account_accountNumber_key" ON "Account"("accountNumber");

-- CreateIndex
CREATE UNIQUE INDEX "FinancialInstitution_code_key" ON "FinancialInstitution"("code");

-- CreateIndex
CREATE UNIQUE INDEX "Transfer_reference_key" ON "Transfer"("reference");

-- CreateIndex
CREATE INDEX "Transfer_senderAccountId_createdAt_idx" ON "Transfer"("senderAccountId", "createdAt" DESC);

-- CreateIndex
CREATE INDEX "Transfer_recipientAccountId_createdAt_idx" ON "Transfer"("recipientAccountId", "createdAt" DESC);

-- CreateIndex
CREATE INDEX "Transfer_destinationInstitutionId_idx" ON "Transfer"("destinationInstitutionId");

-- CreateIndex
CREATE UNIQUE INDEX "RefreshSession_replacedById_key" ON "RefreshSession"("replacedById");

-- CreateIndex
CREATE UNIQUE INDEX "RefreshSession_tokenHash_key" ON "RefreshSession"("tokenHash");

-- CreateIndex
CREATE INDEX "RefreshSession_familyId_idx" ON "RefreshSession"("familyId");

-- CreateIndex
CREATE INDEX "RefreshSession_userId_idx" ON "RefreshSession"("userId");

-- CreateIndex
CREATE INDEX "RefreshSession_expiresAt_idx" ON "RefreshSession"("expiresAt");

-- CreateIndex
CREATE UNIQUE INDEX "IdempotencyRecord_transferId_key" ON "IdempotencyRecord"("transferId");

-- CreateIndex
CREATE INDEX "IdempotencyRecord_expiresAt_idx" ON "IdempotencyRecord"("expiresAt");

-- CreateIndex
CREATE UNIQUE INDEX "IdempotencyRecord_userId_key_key" ON "IdempotencyRecord"("userId", "key");

-- AddForeignKey
ALTER TABLE "Account" ADD CONSTRAINT "Account_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "Transfer" ADD CONSTRAINT "Transfer_senderAccountId_fkey" FOREIGN KEY ("senderAccountId") REFERENCES "Account"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "Transfer" ADD CONSTRAINT "Transfer_recipientAccountId_fkey" FOREIGN KEY ("recipientAccountId") REFERENCES "Account"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "Transfer" ADD CONSTRAINT "Transfer_destinationInstitutionId_fkey" FOREIGN KEY ("destinationInstitutionId") REFERENCES "FinancialInstitution"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "RefreshSession" ADD CONSTRAINT "RefreshSession_replacedById_fkey" FOREIGN KEY ("replacedById") REFERENCES "RefreshSession"("id") ON DELETE SET NULL ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "RefreshSession" ADD CONSTRAINT "RefreshSession_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "IdempotencyRecord" ADD CONSTRAINT "IdempotencyRecord_transferId_fkey" FOREIGN KEY ("transferId") REFERENCES "Transfer"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "IdempotencyRecord" ADD CONSTRAINT "IdempotencyRecord_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- Custom OpenPay database constraints
-- Account balances, ownership, and customer account-number format.
ALTER TABLE "Account"
    ADD CONSTRAINT "account_balance_nonnegative" CHECK ("balance" >= 0),
    ADD CONSTRAINT "account_owner_type" CHECK (
        ("type" = 'CUSTOMER' AND "userId" IS NOT NULL AND "accountNumber" IS NOT NULL)
        OR ("type" = 'SYSTEM_FEE' AND "userId" IS NULL AND "accountNumber" IS NULL)
    ),
    ADD CONSTRAINT "customer_account_number_format" CHECK (
        "type" <> 'CUSTOMER'
        OR ("accountNumber" IS NOT NULL AND "accountNumber" ~ '^[0-9]{10}$')
    );

-- Transfer amounts, destinations, and lifecycle timestamps.
-- Explicit null checks prevent SQL UNKNOWN from admitting incomplete destinations.
ALTER TABLE "Transfer"
    ADD CONSTRAINT "transfer_amount_positive" CHECK ("amount" > 0),
    ADD CONSTRAINT "transfer_fee_nonnegative" CHECK ("feeAmount" >= 0),
    ADD CONSTRAINT "transfer_no_internal_self_transfer" CHECK (
        "type" <> 'INTERNAL'
        OR ("recipientAccountId" IS NOT NULL AND "senderAccountId" <> "recipientAccountId")
    ),
    ADD CONSTRAINT "transfer_destination_shape" CHECK (
        (
            "type" = 'INTERNAL'
            AND "recipientAccountId" IS NOT NULL
            AND "destinationInstitutionId" IS NULL
            AND "destinationAccountNumber" IS NULL
            AND "destinationAccountName" IS NULL
        )
        OR (
            "type" = 'EXTERNAL'
            AND "recipientAccountId" IS NULL
            AND "destinationInstitutionId" IS NOT NULL
            AND "destinationAccountNumber" IS NOT NULL
            AND "destinationAccountNumber" ~ '^[0-9]{10}$'
            AND "destinationAccountName" IS NOT NULL
        )
    ),
    ADD CONSTRAINT "transfer_internal_fee_zero" CHECK (
        "type" <> 'INTERNAL' OR "feeAmount" = 0
    ),
    ADD CONSTRAINT "transfer_completed_timestamp" CHECK (
        "status" <> 'COMPLETED' OR "completedAt" IS NOT NULL
    ),
    ADD CONSTRAINT "transfer_reversed_timestamp" CHECK (
        "status" <> 'REVERSED' OR "reversedAt" IS NOT NULL
    );

-- Refresh sessions and idempotency records must expire after creation.
ALTER TABLE "RefreshSession"
    ADD CONSTRAINT "refresh_session_expiry" CHECK ("expiresAt" > "createdAt");

ALTER TABLE "IdempotencyRecord"
    ADD CONSTRAINT "idempotency_expiry" CHECK ("expiresAt" > "createdAt");

-- Custom OpenPay partial unique indexes: at most one row for each system role.
CREATE UNIQUE INDEX "Account_single_system_fee_key"
    ON "Account"("type") WHERE "type" = 'SYSTEM_FEE';

CREATE UNIQUE INDEX "FinancialInstitution_single_internal_key"
    ON "FinancialInstitution"("isInternal") WHERE "isInternal" = true;
