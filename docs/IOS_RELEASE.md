# iOS release signing

The iOS release workflow uses manual App Store signing for the app and both
embedded extensions. Create an App Store Connect distribution provisioning
profile for each bundle ID, using the same Apple Developer team and distribution
certificate:

- `com.splitpay.expensetracker`
- `com.splitpay.expensetracker.DimeWidgets`
- `com.splitpay.expensetracker.ShareExtension`

Add the following GitHub Actions secrets. Profile name values must exactly
match the profile's Name in the Apple Developer portal; the workflow checks
both the profile name and its team-prefixed bundle ID.

- `IOS_APP_STORE_PROFILE_BASE64` and `IOS_APP_STORE_PROFILE_NAME`
- `IOS_WIDGET_APP_STORE_PROFILE_BASE64` and `IOS_WIDGET_APP_STORE_PROFILE_NAME`
- `IOS_SHARE_EXTENSION_APP_STORE_PROFILE_BASE64` and
  `IOS_SHARE_EXTENSION_APP_STORE_PROFILE_NAME`

Encode each downloaded `.mobileprovision` file for its corresponding
`*_BASE64` secret with:

```sh
base64 -i profile.mobileprovision | tr -d '\n'
```
