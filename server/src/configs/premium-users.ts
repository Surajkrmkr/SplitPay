/**
 * Hardcoded allowlist of ad-free users, keyed by email.
 *
 * This is a stopgap ahead of a real premium subscription system — there's no
 * DB column or purchase flow yet, just a manually curated list (internal
 * testers, VIPs, etc.) who never see ads or ad placeholders. Once premium
 * subscriptions ship, replace `isAdFreeEmail` with a lookup against the
 * user's subscription status instead of this list.
 *
 * Emails are matched case-insensitively.
 */
const AD_FREE_EMAILS = new Set<string>(
  (['surajkarmakar2000@gmail.com'] as string[]).map((email) => email.toLowerCase())
);

export function isAdFreeEmail(email: string): boolean {
  return AD_FREE_EMAILS.has(email.trim().toLowerCase());
}
