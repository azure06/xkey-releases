# XKey installation and deployment

Guides and downloads for **XKey for Microsoft PowerPoint**.

[English documentation](https://resources.infiniticlips.com) · [日本語ドキュメント](https://resources.infiniticlips.com/ja) · [Downloads](https://github.com/azure06/xkey-releases/releases)

## Choose an installation option

| Option | Intended use | How updates work |
| --- | --- | --- |
| **Standalone MSI** | Individuals who can approve administrator prompts | Bundled updater checks for newer versions and asks before installing |
| **Intune package** | Organisations where IT manages software | IT deploys and approves updates through Intune; no self-updater |
| **ClickOnce** | Existing ClickOnce installations | Uses its original ClickOnce installation and update channel |

Standalone and Intune cannot coexist. Coordinate a change of installation type with your administrator. Avoid installing an MSI alongside an existing ClickOnce installation.

- [Installation and removal](https://resources.infiniticlips.com/installation)
- [Updates](https://resources.infiniticlips.com/updates)
- [Corporate deployment with Intune](https://resources.infiniticlips.com/enterprise)

## Download files

| File | Purpose |
| --- | --- |
| `XKey-<version>-Standalone-x64.msi` | Installs XKey and its bundled updater |
| `XKey-<version>-Intune-x64.msi` | Installs the IT-managed distribution |
| `XKey-<version>-Intune-x64.intunewin` | Intune Win32 app upload container; not a local installer |
| `XKey-<app-version>-Intune.zip` | Intune MSI, signed management scripts and supporting files |
| `DEPLOYMENT.md` | Package-specific IT instructions |
| `runtime-configuration.md` | Administrator and developer configuration |
| `release-manifest.json`, `SHA256SUMS.txt` | Package identities and checksums |
| `validation-report.json` | Automated check results and acceptance limitations |

Choose the distribution you need from [GitHub Releases](https://github.com/azure06/xkey-releases/releases). Read the instructions supplied with that package. Prereleases are intended for testing.

## Maintaining this documentation

The website hosts English and Japanese guides and preserves existing ClickOnce files. GitHub Releases hosts Standalone and Intune downloads. Application source and packaging are maintained in a separate private repository.

Use pnpm 8.15.9, as recorded in package.json, with the checked-in pnpm lockfile:

```sh
pnpm install --frozen-lockfile
pnpm dev
pnpm build
```

Open http://localhost:3000 during development. Update both languages together. Do not generate a second npm lockfile or edit signed ClickOnce files by hand. Maintainer procedures are in [RELEASE-HOSTING.md](RELEASE-HOSTING.md); the [updater test plan](NEXT-RELEASE-TEST.md) is separate from user documentation.

## License

See [LICENSE](LICENSE) for repository content. Application packages carry their own applicable terms.
