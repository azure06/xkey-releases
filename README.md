# XKey releases

Public downloads and documentation for **XKey for Microsoft PowerPoint**. Application source is maintained separately in a private repository.

[Download releases](https://github.com/azure06/xkey-releases/releases) · [Installation guide](https://resources.infiniticlips.com/installation) · [Report an issue](https://github.com/azure06/xkey-releases/issues)

## Choose a package

| Package | Who it is for | Updates |
| --- | --- | --- |
| **Standalone MSI** | Individuals and manual installations | Bundled updater; installation requires administrator approval |
| **Intune MSI / ZIP / .intunewin** | Company IT and managed devices | IT-managed deployment; no self-updater |
| **ClickOnce** | Existing installations | Legacy, separate update path and hosting |

Standalone and Intune are alternative distributions of the same app and cannot coexist. Use the package matching your installation's management model.

**1.0.5.0 is the GitHub-only cutover.** Older Standalone test installations need one manual installation of the 1.0.5.0 Standalone MSI. Their old website update feed has been removed. Prereleases require explicit tester opt-in; fresh Standalone installs use Stable updates and the Production application backend.

## Release files

| File | Purpose |
| --- | --- |
| `XKey-<version>-Standalone-x64.msi` | Install XKey and its updater |
| `XKey-<version>-Intune-x64.msi` | Machine-wide app installation controlled by IT |
| `XKey-<version>-Intune-x64.intunewin` | Upload container for an Intune Win32 app; not a local installer |
| `XKey-<app-version>-Intune.zip` | Intune MSI, signed management scripts and supporting files |
| `release-manifest.json` | Versions, source commit, package identities and artifact hashes |
| `SHA256SUMS.txt` | Checksums for the published download set |
| `validation-report.json` | Automated validation results and remaining acceptance boundaries |
| `DEPLOYMENT.md` | IT prerequisites, installation, migration and detection instructions |
| `runtime-configuration.md` | Manual backend and update-channel configuration |

Read the guides attached to the release you install. Automated validation does not establish full Office lifecycle or Intune compatibility; those require a Windows/Office test and an Intune pilot.

## How updates work

- **Stable** follows GitHub's Latest published full release.
- **Preview** selects the highest published valid application version, including prereleases.
- Only newer versions are offered. Checks run on PowerPoint startup at most once every six hours per user and channel.
- Accept the offer, leave the updater open and close all PowerPoint windows. Approve the administrator prompt to install. **Postpone cancels the current attempt.**
- Release discovery and Standalone downloads use this public GitHub repository anonymously. No website-hosted MSI or updater feed remains.

Promoting a tested prerelease to a full release and marking it Latest makes the same signed assets available to Stable clients. Published assets are immutable; fixes use a new version. See [release operations](RELEASE-HOSTING.md) and the [next-release test plan](NEXT-RELEASE-TEST.md).

## This repository

GitHub Releases hosts Standalone and Intune downloads. The website at [resources.infiniticlips.com](https://resources.infiniticlips.com) provides documentation and preserves existing ClickOnce URLs. Publishing a GitHub release does not deploy ClickOnce.

For local documentation development, use pnpm 8.15.9 (recorded in package.json) with the checked-in lockfile. pnpm-lock.yaml is the dependency source; do not generate a second npm lockfile:

```sh
pnpm install --frozen-lockfile
pnpm dev
pnpm build
```

Open http://localhost:3000 during development. Keep application packaging and framework upgrades separate from documentation edits. Do not modify signed ClickOnce files by hand.

## License

Repository content is covered by [LICENSE](LICENSE). Installing a published application package remains subject to the terms supplied with that application.
