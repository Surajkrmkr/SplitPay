ALTER TABLE "expenses"
ADD COLUMN "category_key" TEXT DEFAULT 'other',
ADD COLUMN "category_label" TEXT,
ADD COLUMN "custom_category_id" TEXT,
ADD COLUMN "app_icon" TEXT,
ADD COLUMN "recurrence" "TxRecurrenceType" DEFAULT 'NONE';
