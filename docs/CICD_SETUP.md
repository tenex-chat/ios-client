# CI/CD Setup & Credentials

To enable automatic release to TestFlight on merge to `master`, you need to configure the following secrets in your GitHub repository settings.

## Required Secrets

Go to **Settings** > **Secrets and variables** > **Actions** and add the following secrets:

1.  **`APP_STORE_CONNECT_API_KEY_KEY_ID`**
    *   The Key ID of your App Store Connect API Key.
2.  **`APP_STORE_CONNECT_API_KEY_ISSUER_ID`**
    *   The Issuer ID of your App Store Connect API Key.
3.  **`APP_STORE_CONNECT_API_KEY_CONTENT`**
    *   The content of the `.p8` private key file. Open the `.p8` file in a text editor and copy the entire content.

## How to generate an App Store Connect API Key

1.  Log in to [App Store Connect](https://appstoreconnect.apple.com/).
2.  Go to **Users and Access**.
3.  Select the **Integrations** tab.
4.  Click the **+** button to generate a new key.
5.  Give it a name (e.g., "GitHub Actions CI") and assign the role **App Manager** (or Admin).
6.  Download the `.p8` file (you can only download it once!).
7.  Note the **Key ID** and **Issuer ID**.

## Code Signing

The current setup uses `build_app` (gym) which can handle signing if you have set up **automatic signing** in Xcode and the build machine has access to the necessary certificates and profiles.

For a robust CI environment, it is highly recommended to use [fastlane match](https://docs.fastlane.tools/actions/match/) to manage code signing identities.

If you decide to use `match`:
1.  Run `fastlane match init` locally to create a private repository for your certificates.
2.  Run `fastlane match appstore` to generate/fetch certificates.
3.  Add `MATCH_PASSWORD` (the password you used to encrypt the repo) to GitHub Secrets.
4.  Update the `Fastfile` to include `match(type: "appstore")` before building.
5.  Ensure the GitHub Action has access to the certificates repository (via SSH key or token).

## Current Fastlane Configuration

The `Fastfile` is configured to:
1.  Setup CI context.
2.  Increment the build number using the GitHub Run Number.
3.  Build the app using the `TENEX` scheme.
4.  Upload the build to TestFlight.

**Note:** The `Appfile` in `fastlane/Appfile` is configured with the correct Team ID. The `apple_id` and `itc_team_id` are not required when using App Store Connect API Key authentication (as configured in the workflow).
