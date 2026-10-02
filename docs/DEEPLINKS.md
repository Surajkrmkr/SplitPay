# Group invite links

Group invites use `https://splitpay-c7905.web.app/invite/<CODE>`. Firebase
Hosting supplies this HTTPS domain, so a custom domain is not required. An
installed app opens the invite directly; the invite screen previews the group
and lets an authenticated user join. If the app is missing, the landing page
shows the code and sends iOS users to the App Store and Android users to Google
Play. After installation, open the invite link again or enter its displayed
code. Store installation does not preserve the original invite automatically;
deferred deep links require a separate provider/service.

## One-time production setup

1. In Firebase project `splitpay-c7905`, enable Firebase Hosting and deploy the
   included site:

   ```sh
   firebase deploy --only hosting
   ```

   Confirm that `https://splitpay-c7905.web.app/invite/TEST` serves the landing
   page, and that both
   `https://splitpay-c7905.web.app/.well-known/apple-app-site-association` and
   `https://splitpay-c7905.web.app/.well-known/assetlinks.json` return JSON
   directly (not an HTML rewrite).

2. Before deploying, replace the placeholder in
   `hosting/public/.well-known/assetlinks.json` with the SHA-256 fingerprint of
   the **Play App Signing** certificate from Play Console > Setup > App
   integrity. Use the colon-separated SHA-256 value. If distributing Android
   builds outside Play, include each release signing certificate fingerprint
   as an additional entry. Deploy Hosting again after editing it.

3. Enable the Associated Domains capability for
   `com.splitpay.expensetracker` in the Apple Developer account, regenerate the
   provisioning profiles used for release, and build a new iOS app with
   `ios/Runner/Runner.entitlements`. Its association file is configured for
   team `NJK933T45N` and bundle ID `com.splitpay.expensetracker`.

4. Ensure the SplitPay listing is published in the relevant stores. The iOS
   fallback uses the direct listing URL
   `https://apps.apple.com/us/app/splitpay-bills-expenses/id6787626074`.

The public Android certificate fingerprint and Apple team/bundle identifiers
are association metadata, not signing credentials. Never commit signing keys
or passwords.

## Validation

- Android: install a release-signed build whose certificate is listed in
  `assetlinks.json`, then open a link such as
  `https://splitpay-c7905.web.app/invite/ABC12345`. Android App Links
  verification will fail until the actual Play signing fingerprint is
  published.
- iOS: install a build signed with a profile that has Associated Domains
  enabled, then open the same URL from Messages or Notes. iOS caches the
  association response, so allow time for Apple's CDN to refresh after deploy.
- Confirm a signed-in user can preview and join. For a signed-out user, the
  app preserves the invite across sign-in and returns to it afterward.
