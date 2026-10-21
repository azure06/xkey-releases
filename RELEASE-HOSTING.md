# XKey releases and legacy ClickOnce hosting

This public repository is azure06/xkey-releases. Application source stays private in azure06/XKey. Download Standalone and Intune packages from [GitHub Releases](https://github.com/azure06/xkey-releases/releases).

## GitHub releases

Every release carries the signed Standalone MSI, Intune MSI/ZIP/.intunewin, release-manifest.json, SHA256SUMS.txt, validation-report.json and deployment/runtime configuration guides. Standalone discovers releases and downloads assets directly from GitHub. No MSI packages or updater JSON feeds are served by this website.

Stable follows the GitHub Latest published full release. Preview follows the highest published valid application version, including prereleases and full releases. Promote a tested prerelease by clearing prerelease and marking it Latest in GitHub's GUI. Reuse the same assets; never overwrite published versioned packages. Rollback means withdrawing an offer or issuing a forward fix, not forcing installed clients to downgrade.

XKey 1.0.5.0 is the GitHub-only cutover. Existing test installations on older versions require one manual MSI installation. The previous website-hosted Standalone/enterprise directories and feeds are removed with normal Git commits; history is preserved. No fallback or transition feed remains.

## ClickOnce and documentation

Existing public/releases/preview and public/releases/latest content and the resources.infiniticlips.com ClickOnce URLs remain unchanged. The Next.js site continues serving documentation and legacy ClickOnce. Publishing/promoting a GitHub release does not deploy or promote ClickOnce.

The private application repository supplies Build, Validate, Publish and StageClickOnce commands. StageClickOnce copies only ClickOnce after validation; it does not commit, push or publish GitHub assets. Local checkout folders may retain the old xkey-resources-next name even though origin points to xkey-releases.

Use the existing frozen pnpm lockfile for site builds. Keep framework upgrades separate. Verify ClickOnce hashes and live URLs when deploying site cleanup.
## Next release acceptance

Use the [next-release test plan](NEXT-RELEASE-TEST.md) to test a 1.0.5.0 Standalone baseline against the next prerelease, including startup discovery, installer handoff and cancellation. Published assets must never be replaced to repeat a test.
