# TestFlight Deployment via Git Push

## How It Works

Every push to `master` branch automatically:
1. ✅ Builds the iOS app
2. ✅ Signs it with your App Store certificates (via Match)
3. ✅ Uploads to TestFlight

## To Deploy

```bash
git add .
git commit -m "Your commit message"
git push origin master
```

That's it! GitHub Actions handles the rest.

## Monitor Deployment

Watch the progress at:
https://github.com/tenex-chat/ios-client/actions

## Current Configuration

- **Trigger**: Push to `master` branch
- **Workflow**: `.github/workflows/release.yml`
- **Fastlane Lane**: `release_testflight`
- **Code Signing**: Match (certificates in `ios-certificates` repo)
- **Build Number**: Auto-incremented using GitHub run number
- **Version**: 1.0.0 (update in `Fastfile` line 37 if needed)

## Required GitHub Secrets

All secrets are configured in the repository settings:

- ✅ `APP_STORE_CONNECT_API_KEY_KEY_ID`
- ✅ `APP_STORE_CONNECT_API_KEY_ISSUER_ID`
- ✅ `APP_STORE_CONNECT_API_KEY_CONTENT`
- ✅ `MATCH_PASSWORD`
- ✅ `MATCH_DEPLOY_KEY`

## Deploy Key Setup

The public SSH key for accessing the certificates repository:

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICkDgnh6cuHQG0qwWeM/W7I4zNuY7fjDfAAKVV5CXHjf github-actions-match-deploy
```

**Add this to:** https://github.com/tenex-chat/ios-certificates/settings/keys

Or to your GitHub account: https://github.com/settings/keys

## Manual Deployment (Local)

If you want to deploy manually without git push:

```bash
fastlane release_testflight
```

(Requires all environment variables to be set locally)

## Troubleshooting

**Build fails with certificate errors:**
- Check that MATCH_DEPLOY_KEY public key is added to ios-certificates repo
- Verify MATCH_PASSWORD is correct

**Build fails with API key errors:**
- Check that all APP_STORE_CONNECT_API_KEY_* secrets are set correctly
- Verify the API key hasn't expired in App Store Connect

**Build succeeds but upload fails:**
- Check that the API key has the "App Manager" role in App Store Connect
- Verify network connectivity in GitHub Actions

## Updating Version Number

Edit `fastlane/Fastfile` line 37:

```ruby
xcargs: "CURRENT_PROJECT_VERSION=#{ENV["GITHUB_RUN_NUMBER"]} MARKETING_VERSION=1.0.0"
```

Change `MARKETING_VERSION=1.0.0` to your desired version (e.g., `1.1.0`).
