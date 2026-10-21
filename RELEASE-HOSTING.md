# XKey desktop release hosting

The existing resources site serves public desktop downloads. No update API,
database or customer credentials are needed. Signed Standalone preview packages include the independent updater. Keep
stable/latest promotion separate from preview endpoint publication.

| Repository location | Public endpoint | Purpose |
| --- | --- | --- |
| `public/releases/enterprise/1.0.3.0/` | `/releases/enterprise/1.0.3.0/...` | IT-managed MSI, Intune scripts and upload container |
| `public/releases/standalone/1.0.3.0/` | `/releases/standalone/1.0.3.0/...` | Immutable signed Standalone MSI and release evidence |
| `public/updates/standalone/preview.json` | `/updates/standalone/preview.json` | Mutable preview update manifest |
| `public/updates/standalone/stable.json` | `/updates/standalone/stable.json` | Mutable stable update manifest |

The canonical origin is `https://resources.infiniticlips.com`. Serve files
directly over HTTPS without authentication, HTML fallback or redirects. The
updater only accepts MSI URLs on the feed's origin, using the exact path
`/releases/standalone/<four-field-version>/XKey-<three-field-version>-Standalone-x64.msi`.
The JSON feed is at most 64 KiB and the installer at most 512 MiB.

The site configuration disables caching for the two mutable feeds and allows
long-lived caching for immutable Standalone artifacts. Never replace an existing
version's published MSI, even if only its signature or documentation changed.
Signed files under `public/releases` must remain byte-identical; `.gitattributes`
already disables text conversion there.

## Deliberate promotion

1. Build and validate signed packages from the intended application source.
2. Stage the versioned packages and review their hashes and release metadata.
   Keep existing ClickOnce installation URLs and promote preview first.
3. Complete VM acceptance and endpoint smoke checks. An Intune pilot is a
   separate gate; the Intune MSI contains no self-updater.
4. Only when standalone updating has passed acceptance, copy the validated
   build's `standalone/update-manifest.json` to the selected feed path. The
   build does not publish or promote the feed automatically.
5. After publication, GET the feed with HTTP 200 and JSON content, then download
   its MSI and verify its exact size, SHA256, timestamped publisher signature and
   Standalone MSI identity. Check Cache-Control headers from the canonical host.

Keep preview and stable independent. Roll back a feed pointer to withdraw an
offer without modifying the immutable MSI. Installed clients never downgrade
merely because the feed points to an older version.

Stage in the desktop release tooling deliberately places the signed versioned
packages and promotes only the preview feed. Builds alone never publish a feed.
GitHub prereleases carry the same signed packages for manual downloads; the
updater downloads from this site to avoid GitHub asset redirects.

## Local hosting check

Restore with `pnpm@8.15.9 install --frozen-lockfile --ignore-scripts`, then run
the site's build. Use the documented pnpm lockfile: the separate npm lockfile
currently resolves a different, incompatible Nextra major. Keep lockfile and
website framework migration separate from preparing desktop release files.

From the XKey checkout, run `tests/Test-ReleaseHosting.ps1` with
`-ResourcesRepoPath` pointing here and `-ReleaseDirectory` pointing to the
validated candidate. The test starts a loopback production server, temporarily
places the candidate feed and MSI only at absent paths, checks HTTP status,
content type, caching and downloaded hash/size, and removes its temporary files.
It refuses to overwrite any existing public artifact. A passing local test still
requires canonical-host HTTPS smoke checks after deliberate publication.

## Withdrawn preview replacement

The owner withdrew the GitHub releases and authorized restarting at 1.0.3.0, replacing the existing resources preview. This is an explicit exception to version immutability for this private preview. Existing 1.0.3.0 testers must download the replacement GitHub MSI and install it manually once; equal versions do not trigger an offer. Uninstall withdrawn 1.0.4.0/1.0.5.0 before installing 1.0.3.0. Future public versions must increase normally. Production and Stable remain the fresh-install defaults; Preview is manually configured.
