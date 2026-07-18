# FamilyCare Android release

This repository builds Android APKs through GitHub Actions. Do not commit a
keystore, `android/key.properties`, passwords, or Google credentials.

## 1. Create the Android upload key

Run this once on a trusted machine:

```powershell
keytool -genkeypair -v `
  -keystore upload-keystore.jks `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias upload
```

Back up the keystore and its passwords in a secure location. Losing the key can
prevent future updates from being installed over an existing app.

For a local release build, copy `android/key.properties.example` to
`android/key.properties`, put the keystore at
`android/app/upload-keystore.jks`, and replace all placeholder values.

## 2. Configure GitHub Secrets

Open the GitHub repository:

`Settings -> Secrets and variables -> Actions`

Add these repository secrets:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded contents of `upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Key alias, normally `upload` |
| `ANDROID_KEY_PASSWORD` | Key password |

Encode the keystore on Windows:

```powershell
[Convert]::ToBase64String(
  [IO.File]::ReadAllBytes("upload-keystore.jks")
) | Set-Clipboard
```

## 3. Build a release

The `Android Release` workflow runs in either of these ways:

- Push a semantic version tag such as `v1.0.1`.
- Open `Actions -> Android Release -> Run workflow`.

The workflow:

1. Runs analysis and tests.
2. Recreates the signing files from GitHub Secrets.
3. Builds a signed release APK.
4. Generates a SHA-256 checksum.
5. Stores both as GitHub artifacts.
6. Creates a GitHub Release when triggered by a `v*` tag.

## 4. Optional Google Drive upload and QR code

Create a Google Cloud service account, enable the Google Drive API, and share a
Google Drive destination folder with the service-account email.

Add:

| Type | Name | Value |
| --- | --- | --- |
| Secret | `GDRIVE_SERVICE_ACCOUNT_JSON` | Complete service-account JSON |
| Secret | `GDRIVE_FOLDER_ID` | ID from the shared Drive folder URL |
| Variable | `GDRIVE_UPLOAD_ON_TAG` | Set to `true` for automatic tag uploads |

Alternatively, select `upload_to_drive` when manually running the workflow.
After upload, the workflow makes the APK link readable by anyone with the link
and generates:

- `FamilyCare-Android-QR.png`
- `FamilyCare-Android-download-url.txt`

Do not place production credentials in the repository.

## 5. iOS limitation

An APK works only on Android. iPhone distribution requires a separately signed
IPA, an Apple Developer account, and normally TestFlight. A download QR page can
route Android users to the APK and iOS users to TestFlight or a web/PWA build.
