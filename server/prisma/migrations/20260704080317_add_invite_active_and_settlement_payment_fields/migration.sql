-- AlterTable
ALTER TABLE "group_invites" ADD COLUMN     "active" BOOLEAN NOT NULL DEFAULT true;

-- AlterTable
ALTER TABLE "settlements" ADD COLUMN     "payment_method" TEXT,
ADD COLUMN     "transaction_id" TEXT;
