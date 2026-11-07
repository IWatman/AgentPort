# Releasing AgentPort

Releases are built from Git tags by [`.github/workflows/release.yml`](../.github/workflows/release.yml). Pushing a `v*` tag that points to a commit on `main` builds a signed universal APK, writes SHA-256 checksums, and publishes a stable GitHub Release.

## One-time signing setup

1. Create the release keystore outside the repository:

   ```bash
   keytool -genkeypair -v -keystore agentport-release.jks -alias agentport \
     -keyalg RSA -keysize 4096 -validity 10000
   ```

2. Back up `agentport-release.jks` and both passwords offline. GitHub secrets can be overwritten but never read back.

   > **Warning:** Android only installs updates signed with the same key. If the keystore or its passwords are lost, existing installations can never be updated.

3. Base64-encode the keystore:

   ```bash
   # Linux
   base64 -w0 agentport-release.jks > agentport-release.jks.b64

   # macOS
   base64 -i agentport-release.jks | tr -d '\n' > agentport-release.jks.b64

   # Windows PowerShell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("agentport-release.jks")) |
     Set-Content -NoNewline agentport-release.jks.b64
   ```

4. Add these secrets under **Settings → Secrets and variables → Actions**:

   | Secret | Value |
   | --- | --- |
   | `ANDROID_KEYSTORE_BASE64` | Contents of `agentport-release.jks.b64` |
   | `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
   | `ANDROID_KEY_ALIAS` | Key alias, for example `agentport` |
   | `ANDROID_KEY_PASSWORD` | Key password |

The workflow decodes the keystore to `android/app/release-keystore.jks`, writes `android/key.properties`, and deletes both files in an `if: always()` cleanup step. Neither file is committed.

## Cut a release

1. Update `CHANGELOG.md`.
2. Bump `version` in `pubspec.yaml` to the release version:

   ```yaml
   version: 0.1.0+10000
   ```

   The part after `+` is used only for local builds; CI sets the Android version code from the tag.
3. Commit and push `main`.
4. Create and push an annotated tag:

   ```bash
   git switch main
   git pull --ff-only
   git tag -a v0.1.0 -m "AgentPort v0.1.0"
   git push origin v0.1.0
   ```

The tag must match `vMAJOR.MINOR.PATCH` (no prerelease suffix), and its commit must be on `main`. The workflow checks both before building. The base version in `pubspec.yaml` must also match the tag.

To rerun a failed release, use **Actions → Release → Run workflow** and enter the existing tag. The tag must already exist. Never move or reuse a published tag; publish a patch version instead.

## Version code

CI derives the Android `versionCode` from the tag using the formula in `PLAN.md` section 10.2:

```text
major * 1_000_000 + minor * 10_000 + patch * 100
```

| Tag | Version code |
| --- | --- |
| `v0.1.0` | `10000` |
| `v0.1.1` | `10100` |
| `v1.0.0` | `1000000` |

`MINOR` and `PATCH` must be between `0` and `99`. Increasing SemVer therefore always increases the version code, without relying on the GitHub Actions run number. The version name is the tag without the leading `v`.

## Published assets

Each stable release contains:

- `agentport-vX.Y.Z.apk` — signed universal APK.
- `agentport-vX.Y.Z.apk.sha256` — checksum in `sha256sum` format.
- `checksums.txt` — the same checksum, used by the in-app update check (PLAN.md section 10.3).

## Verify a download

Linux:

```bash
sha256sum -c agentport-v0.1.0.apk.sha256
```

macOS:

```bash
shasum -a 256 -c agentport-v0.1.0.apk.sha256
```

Windows PowerShell:

```powershell
(Get-FileHash .\agentport-v0.1.0.apk -Algorithm SHA256).Hash
Get-Content .\agentport-v0.1.0.apk.sha256
```

The two hashes must match. A checksum mismatch means the download is corrupt or has been tampered with; do not install it.

## Local signed builds

Create `android/key.properties` (ignored by Git) with `storeFile` relative to the `android/app` module:

```properties
storeFile=release-keystore.jks
storePassword=your-keystore-password
keyAlias=agentport
keyPassword=your-key-password
```

Place the keystore at `android/app/release-keystore.jks`. When `key.properties` is absent, release builds fall back to debug signing with a Gradle warning; those APKs are for local testing only.
