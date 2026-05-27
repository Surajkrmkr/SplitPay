-- CreateEnum
CREATE TYPE "PersonalTxType" AS ENUM ('INCOME', 'EXPENSE', 'TRANSFER');

-- CreateEnum
CREATE TYPE "TxRecurrenceType" AS ENUM ('NONE', 'DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY');

-- CreateTable
CREATE TABLE "transactions" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "local_id" TEXT NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "transaction_type" "PersonalTxType" NOT NULL,
    "category_key" TEXT NOT NULL,
    "custom_category_id" TEXT,
    "app_icon" TEXT,
    "note" TEXT,
    "date" TIMESTAMP(3) NOT NULL,
    "recurrence" "TxRecurrenceType" NOT NULL DEFAULT 'NONE',
    "group_id" TEXT,
    "device_id" TEXT,
    "deleted_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "transactions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_categories" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "local_id" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "color_value" INTEGER NOT NULL,
    "icon_code_point" INTEGER NOT NULL,
    "deleted_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "user_categories_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "transactions_user_id_idx" ON "transactions"("user_id");

-- CreateIndex
CREATE INDEX "transactions_user_id_deleted_at_idx" ON "transactions"("user_id", "deleted_at");

-- CreateIndex
CREATE INDEX "transactions_user_id_date_idx" ON "transactions"("user_id", "date");

-- CreateIndex
CREATE INDEX "transactions_user_id_transaction_type_idx" ON "transactions"("user_id", "transaction_type");

-- CreateIndex
CREATE UNIQUE INDEX "transactions_user_id_local_id_key" ON "transactions"("user_id", "local_id");

-- CreateIndex
CREATE INDEX "user_categories_user_id_idx" ON "user_categories"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "user_categories_user_id_local_id_key" ON "user_categories"("user_id", "local_id");

-- AddForeignKey
ALTER TABLE "transactions" ADD CONSTRAINT "transactions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_categories" ADD CONSTRAINT "user_categories_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
