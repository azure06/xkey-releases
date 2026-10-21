# Next release: updater acceptance plan

Proposed next version: **1.0.6.0** (MSI **1.0.6**). Include the desired feature commits before freezing the release. Do not rebuild or replace published 1.0.5.0 assets.

## 1. Prepare a reproducible baseline

- Use a disposable Windows 11 x64 VM with desktop PowerPoint and machine-wide prerequisites. Test 32-bit and 64-bit Office separately when validating both configurations.
- Manually install the published **1.0.5.0 Standalone MSI**. This is the GitHub-only cutover baseline; earlier versions cannot use the removed feed.
- Verify XKey loads, sign in with a test account and save a recognisable setting.
- Set the machine update channel to Preview using the installed helper's `--configure-channel preview`. Leave the application backend at Production unless backend testing is specifically intended.
- Take a VM checkpoint with PowerPoint closed and **before any update check**. A checkpoint captures the installed version, registry, settings and timer state so the same test can be repeated without downgrading a live machine.

A machine already on 1.0.6.0 will not offer 1.0.6.0 again. Restore the baseline checkpoint for repeat testing. Do not reset version numbers or overwrite a published release to simulate an upgrade.

## 2. Freeze and validate the candidate

- Finish feature changes in the private application repository and commit them to `preview`.
- Advance the shared release setting to 1.0.6.0 / 1.0.6. Build from one clean source commit using the established signed Build command.
- Run Validate and the release audit. Check matching application payloads, signatures, hashes, MSI identities, dependency checks and existing regressions. Keep detailed machine logs private.
- Review release notes and the consolidated public validation report. Record untested Office and Intune lifecycle checks accurately.
- Use Publish to upload and verify all assets in a draft, then publish **1.0.6.0 as a prerelease** in `azure06/xkey-releases`. The workflow requires a clean pushed public checkout; coordinate documentation commits before publication.
- Verify discovery, downloads and package trust anonymously with the existing older-version probe. This step does not install the app.

Build/Validate/Publish run from the private repository's `XKeyInstaller/build.ps1`; use its current BUILD.md for exact signing and audit arguments. Do not deploy ClickOnce as part of this test.

## 3. Exercise the real Standalone update

From the baseline VM:

1. Run `Updater\XKey.Updater.exe --status` and `--check` from the installed application directory. Confirm Preview and an offer for 1.0.6.0.
2. Test automatic discovery on the baseline's first eligible PowerPoint startup. Merely restarting within six hours of a previous check does not force another check. Use `--update` for an immediate manual attempt.
3. Accept the update, keep its window open, then close every PowerPoint window. Confirm the administrator prompt appears and approve it.
4. Wait for installation to complete. Inspect the protected job's `install.log` and `result.txt`; distinguish a helper handoff from a completed MSI installation.
5. Reopen PowerPoint. Confirm version 1.0.6.0, updater presence, sign-in, saved settings, panes, WebView2 and the new features.
6. Check again: the installed version must not offer itself or an older version.

Use the runtime configuration guide for complete CLI paths. Keep a short test record with baseline/candidate versions, Office bitness, results and sanitized diagnostic excerpts.

## 4. Repeat from the checkpoint for alternate outcomes

- **Postpone:** the attempt stops and 1.0.5.0 remains usable. A later manual attempt should work.
- **Cancel administrator approval:** the old installation remains usable; retry succeeds.
- **PowerPoint still open:** the updater waits without closing presentations. Cancelling leaves the old installation usable.
- **Offline or failed download:** no partial package is installed; the old app remains usable.
- **Stable channel:** the prerelease is not offered. If no full Stable release exists, report no published Stable update. Do not promote solely to run this negative test.

VM installation acceptance should also cover repair, uninstall, settings preservation, a second Windows account and controlled failed-upgrade rollback. Intune needs its own SYSTEM/detection/supersedence tests and a real tenant pilot; Standalone success does not cover those.

## 5. Decide whether to promote

When feature and updater checks pass, clear prerelease and mark the release Latest in GitHub. Stable clients then discover the **same signed assets** without a rebuild. Verify Stable discovery and downloads anonymously after promotion.

If a published candidate has a bug, keep it out of Stable and issue a new version with the fix. Withdrawing an offer does not downgrade machines that already installed it. Preserve the baseline checkpoint for diagnosis.
