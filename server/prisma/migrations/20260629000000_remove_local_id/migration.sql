-- DropIndex
DROP INDEX "transactions_user_id_local_id_key";

-- DropIndex
DROP INDEX "user_categories_user_id_local_id_key";

-- AlterTable
ALTER TABLE "transactions" DROP COLUMN "local_id";

-- AlterTable
ALTER TABLE "user_categories" DROP COLUMN "local_id";
