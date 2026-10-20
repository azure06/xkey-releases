# XKey enterprise deployment

Status: local signed-package validation passed. Windows VM acceptance and a real Intune pilot are required before claiming verified compatibility.

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

The direct MSI also supports `msiexec /i XKey-1.0.3-x64.msi /qn /norestart /L*v install.log`. The wrapper adds version-aware skip, strict prerequisite checks, signature/checksum verification and post-install detection.

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
