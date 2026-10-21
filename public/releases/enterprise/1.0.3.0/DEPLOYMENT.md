# XKey enterprise deployment

Status: 1.0.3.0 is a preview release. Local package, signature, dependency, updater logic and protected-cache tests do not replace Windows VM lifecycle acceptance or a real Intune pilot.

## Distribution ownership

Use the MSI explicitly named `Intune` with the enterprise scripts and `.intunewin` upload. It contains no updater and remains controlled by IT. The alternative `Standalone` MSI includes automatic update checking and an administrator-approved installer. Both use the same application folder and upgrade family and cannot coexist.

Default installation blocks distribution changes. After removing the previous management assignment, an administrator may supply `ALLOWDISTRIBUTIONSWITCH=1` for a deliberate migration. Standard Intune wrappers never supply it. Intune detection rejects Standalone and its uninstall wrapper does not remove an explicitly Standalone installation. Legacy 1.0.3.0 and earlier MSI installations are treated as IT-managed. Remove obsolete Intune assignments before moving to Standalone, otherwise Intune will keep attempting remediation.

Standalone checks its selected Stable or Preview feed in a separate helper on PowerPoint startup, at most every six hours per user. It offers the update, downloads/verifies it, waits for all PowerPoint windows to close and requests administrator approval. Selecting Postpone, cancelling UAC, losing connectivity or reopening PowerPoint leaves the existing application installed. Retry manually with the installed `Updater\XKey.Updater.exe --update`, or allow the next periodic startup check. It never forces PowerPoint closed or requests a reboot automatically.

Standalone MSI logs and result codes are under `%ProgramData%\Infiniti\XKey\Updates\<job>\install.log` and `result.txt`. Elevated errors are separate `error-*.log` files in that protected Updates directory. User-side errors are under `%LOCALAPPDATA%\Infiniti\XKey\Updates\updater.log`. Results 0/3010/1618 mean success/reboot-required/busy; 1223 means user cancellation. The initial helper exits after handing off; the protected worker records the actual MSI result. These caches preserve diagnostics; an administrator can review and clean old completed job directories. User settings remain separate and preserved.

The updater refuses administrator caches or installed updater files writable by ordinary users, unexpected reparse paths and altered/incorrectly signed packages. If an existing company directory has unsafe ACLs, have IT repair its permissions; the updater does not take ownership or silently broaden permissions.

See [runtime configuration](../docs/runtime-configuration.md) for the manual developer-only backend configuration, administrator-controlled update channel and preservation of the 1.0.4.0 Preview channel. Fresh installations default to Stable. Intune remains IT-managed.

## Supported baseline

Windows 11 x64 and Microsoft 365 desktop PowerPoint, either 32-bit or 64-bit. Native ARM64 and Windows x86 are not supported. The package installs for all users into `C:\Program Files\Infiniti XKey for PowerPoint`; settings remain under each user's `%APPDATA%\XKey` and `HKCU\Software\XKey`.

Install prerequisites machine-wide: .NET Framework 4.8+, Microsoft VSTO Runtime, desktop PowerPoint, and WebView2 Evergreen Runtime 154.0.4258.31+. Distribute these as separate Intune dependencies. XKey's MSI does not download prerequisites. Permit WebView2 servicing through the company's Microsoft Edge Update policies.

## Import into Intune

Import the generated `.intunewin` as a Windows app (Win32). Configure install behavior **System**, Windows x64 requirements, and the desired enrolled device groups. The contents are versioned and do not fetch a changing latest installer.

Install command:

```text
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy AllSigned -File .\Install-XKey.ps1
```

Uninstall command:

```text
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy AllSigned -File .\Uninstall-XKey.ps1
```

Upload the generated `Detect-XKey.ps1` as a **custom detection script**, run in 64-bit PowerShell, with signature checking enabled. It is standalone: it does not depend on the package cache being retained. Do not upload the source template, which contains build tokens.

Return codes: 0 success; 3010 soft reboot; 1618 retry. Other codes indicate failure. A retry caused by PowerPoint being open never closes presentations. Intune retries are finite; IT must reschedule after the user closes PowerPoint. Logs: `%ProgramData%\Infiniti\XKey\Logs`. Never use `Win32_Product` for inventory or detection.

The direct MSI also supports `msiexec /i XKey-1.0.3-Intune-x64.msi /qn /norestart /L*v install.log`. The wrapper adds version-aware skip, strict prerequisite checks, signature/checksum verification and post-install detection.

The owner authorized replacing the withdrawn 1.0.3.0 preview with the current application, updater fixes and manual runtime configuration. Package revision 2 changes the MSI ProductCodes. Existing equal-version testers must manually install the replacement. Uninstall withdrawn higher versions before installing 1.0.3.0. Replace or reimport Intune content and use the new generated detection script; publishing downloads does not update existing Intune content. This preview exception is not a verified production upgrade path.

## Testing without an existing Intune subscription

The MSI can be installed independently of Intune. First test it on a disposable Windows VM with the supported PowerPoint version and prerequisites. Test silent installation, first launch as a standard user, repair, upgrade, removal and settings preservation. A manual administrator install does not establish that installation as SYSTEM, detection, retry handling or Intune supersedence works.

The `.intunewin` is an upload container holding the MSI and supporting files; it is not a local installer. IT uploads it, configures the commands and detection script, and assigns it to enrolled devices. Intune executes the commands and reports results. See [Microsoft's packaging documentation](https://learn.microsoft.com/en-us/intune/app-management/deployment/create-win32-package).

Microsoft offers a [30-day Intune trial](https://learn.microsoft.com/en-us/intune/fundamentals/free-trial-sign-up). Use a separate test tenant and disposable supported Windows device or VM, assign a trial license and enroll it, then pilot the package there. The current signup instructions require phone verification, MFA and a payment method for verification. The Intune trial does not itself supply a desktop PowerPoint license. If no tenant test is possible, document that limitation and arrange a controlled customer IT pilot before broad deployment.

## Existing ClickOnce users

Run `Migrate-XKeyClickOnce.ps1` **as each affected Windows user**, separately from the SYSTEM MSI. Its default is report-only. After verifying the report, use `-Remove` with PowerPoint closed. Standard preview/latest manifest URLs are recognized. An unknown source requires IT to verify it and supply `-ExpectedManifestUri` exactly matching the registered source. Local `|vstolocal` registrations are not automatically removed.

Use user-context management to collect migration results before assigning the machine MSI. One user success does not cover other profiles on a shared computer. Failures or remaining registrations require investigation; do not clear the ClickOnce cache, delete arbitrary profiles or force-enable disabled Office add-ins. Settings are preserved. Never run the user migration as SYSTEM.

## Updates, removal and trust

Publishers supply a newly versioned signed MSI and `.intunewin`. Customer IT pilots, approves, uploads and targets the update. Configure supersedence with **Uninstall previous version = No**; the new MSI performs the transactional major upgrade. Use required assignments for mandatory rollout. Publishing a file on the website does not change existing Intune packages.

Uninstall preserves user data. Downgrades are blocked; remediation normally uses a forward release or a deliberate IT uninstall/reinstall. Machine MSI and ClickOnce must not manage the same user installation concurrently.

Manifests, scripts and MSI are signed. IT may need to approve the publisher for its PowerShell policy. Do not add the signing certificate to Trusted Root. Program Files VSTO installation uses Microsoft's documented MSI trust model; validate first launch under your enterprise policies.

## Acceptance checklist

On separate Windows 11 x64 VMs with x86/x64 Office: silent SYSTEM install, standard-user first launch, modern/classic panes, WebView2, SQLite, sign-in, saved settings, and a second Windows account. Exercise old MSI 1.0.2.5 to 1.0.3, a subsequent test upgrade, repair, repeat install, rollback on failed upgrade, downgrade rejection and uninstall. Exercise missing prerequisites and PowerPoint open without data loss. Test ClickOnce 1.0.2.7 to 1.0.3.0 at its original URL and user migration from both preview/latest.

A real Intune tenant must then demonstrate install, independent detection, supersedence, retry/failure reporting and uninstall. No such pilot has been completed by the build script.
