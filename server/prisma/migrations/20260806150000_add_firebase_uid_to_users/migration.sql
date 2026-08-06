-- AlterTable: add firebase_uid column to users
ALTER TABLE "users" ADD COLUMN "firebase_uid" TEXT;

-- CreateIndex: unique constraint on firebase_uid
CREATE UNIQUE INDEX "users_firebase_uid_key" ON "users"("firebase_uid");
