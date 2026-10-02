# Store subscriptions

SplitPay uses Apple App Store and Google Play Billing for subscription products.
There is no subscription endpoint, receipt database, or purchase record in the
SplitPay API. The app reads product metadata and purchase/restore events from
the native stores through Flutter's `in_app_purchase` plugin.

## Product IDs

Create matching products in App Store Connect and Google Play Console:

| Product ID | Product | Billing period |
| --- | --- | --- |
| `splitpay_pro_monthly` | SplitPay Pro Monthly | 1 month |
| `splitpay_pro_yearly` | SplitPay Pro Yearly | 1 year |

Product IDs are compiled into
[`subscription_service.dart`](../lib/data/services/subscription_service.dart).
Treat them as permanent identifiers; do not rename IDs after publishing.
The app displays the localized price returned by the active store.
If you already created products using an earlier product ID, create products
with these IDs as well; store product IDs cannot be renamed after publication.

## App Store Connect

1. Confirm the app record uses bundle ID `com.splitpay.expensetracker` and
   complete Paid Apps agreements, tax, and banking setup.
2. Create a subscription group named **SplitPay Pro**.
3. Add two auto-renewable subscriptions with the product IDs above, one month
   and one year duration. Set localized display names, descriptions, prices,
   and required review information.
4. Submit both products with the app version and test using Sandbox Apple IDs
   or TestFlight.

## Google Play Console

1. Confirm the Play app uses package name `com.splitpay.expensetracker` and
   complete the payments profile / merchant setup.
2. Create two subscription products with the IDs above. Add an enabled
   auto-renewing base plan to each: monthly for the monthly ID and yearly for
   the yearly ID. Set regional availability and pricing.
3. Activate the base plans and publish the products with an internal testing
   track. Add licensed testers and test with a Play-installed build.
4. Optional introductory or promotional offers can be added later; the app
   will use the offer returned by the store for the selected product.

## App integration

The Settings screen opens the subscription page, which queries the store,
starts purchases, listens for purchase updates, completes transactions, and
offers restore. Future client-only feature gates can watch
`subscriptionProvider` and use `state.isPremium`.

Entitlement state is derived from successful purchase/restore events and is
re-established from the store when the subscription controller initializes.
The server does not validate receipts or enforce premium features. Therefore,
this client-only entitlement is suitable for client-side features but must not
be used to authorize protected server data or actions. A trusted server-side
entitlement check would be needed for that.

When enabling paid access, also provide working Terms of Use and Privacy Policy
links and verify the applicable storefront disclosure requirements before
submission. StoreKit / Play Billing test purchases should be exercised on
physical devices or the respective store test environments; simulators do not
represent production billing.
