-- AlterTable
ALTER TABLE "user_categories" ADD COLUMN "suggested_apps" TEXT[] DEFAULT ARRAY[]::TEXT[];
