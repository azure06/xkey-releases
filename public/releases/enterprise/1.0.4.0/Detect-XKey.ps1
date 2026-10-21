#requires -Version 5.1
# Intune custom detection scripts run independently of the extracted package.
# Build replaces this token with the shared four-part release version.
$minimumVersion = '1.0.4.0'
$expectedProductCode = '{AA96C57B-FC92-FF1B-9011-AFCBC427B53E}'
$ErrorActionPreference = 'Stop'
try {
    # Standalone function bodies are inserted here by the release build.
    function Read-XKeyRegistry {
    param([string]$Path, [ValidateSet('Registry32','Registry64')][string]$View = 'Registry64', [switch]$CurrentUser)
    $hive = if ($CurrentUser) { [Microsoft.Win32.RegistryHive]::CurrentUser } else { [Microsoft.Win32.RegistryHive]::LocalMachine }
    $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($hive, [Microsoft.Win32.RegistryView]::$View)
    try {
        $key = $base.OpenSubKey($Path)
        if (!$key) { return $null }
        try { $values = @{}; foreach ($name in $key.GetValueNames()) { $values[$name] = $key.GetValue($name) }; return $values }
        finally { $key.Dispose() }
    } finally { $base.Dispose() }
}
function Test-XKeyInstalledState {
    param($State, [version]$MinimumVersion, [string]$ExpectedProductCode)
    if (!$State -or !$State.Version -or !$State.DllVersion -or !$State.FilesPresent) { return $false }
    try {
        $distribution=if($State -is [Collections.IDictionary]){$State['Distribution']}elseif($State.PSObject.Properties['Distribution']){$State.Distribution}else{$null}
        if($distribution -and $distribution -ne 'Intune'){return $false}
        if(!$distribution -and [version]$State.Version -gt [version]'1.0.3.0'){return $false}
        if ([version]$State.Version -lt $MinimumVersion -or [version]$State.DllVersion -ne [version]$State.Version) { return $false }
        if ($ExpectedProductCode -and [version]$State.Version -eq $MinimumVersion -and $State.ProductCode -ne $ExpectedProductCode) { return $false }
        $expected = ([uri]$State.ManifestPath).AbsoluteUri
        foreach ($manifest in @($State.Manifest32, $State.Manifest64)) {
            if (!$manifest -or !$manifest.EndsWith('|vstolocal', [StringComparison]::OrdinalIgnoreCase)) { return $false }
            if (([uri]($manifest -replace '\|vstolocal$', '')).AbsoluteUri -ne $expected) { return $false }
        }
        return $true
    } catch { return $false }
}
function Test-XKeyInstalledPayload {
    param([string]$Folder,[string]$Version)
    try {
        [xml]$manifest = Get-Content -LiteralPath (Join-Path $Folder 'XKey.dll.manifest') -Raw
        [xml]$deployment = Get-Content -LiteralPath (Join-Path $Folder 'XKey.vsto') -Raw
        if ($manifest.assembly.assemblyIdentity.version -ne $Version -or $deployment.assembly.assemblyIdentity.version -ne $Version) { return $false }
        $boundary = [IO.Path]::GetFullPath($Folder).TrimEnd('\') + '\'
        foreach ($doc in @($manifest,$deployment)) {
            foreach ($node in $doc.SelectNodes('//*[local-name()="dependentAssembly" and @codebase] | //*[local-name()="file" and @name]')) {
                $relative = if ($node.HasAttribute('codebase')) { $node.GetAttribute('codebase') } else { $node.GetAttribute('name') }
                $path = [IO.Path]::GetFullPath((Join-Path $Folder $relative))
                if (!$path.StartsWith($boundary,[StringComparison]::OrdinalIgnoreCase) -or !(Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
                if ($node.HasAttribute('size') -and [long]$node.GetAttribute('size') -ne (Get-Item -LiteralPath $path).Length) { return $false }
            }
        }
        return $true
    } catch { return $false }
}
function Get-XKeyInstalledState {
    $metadata = Read-XKeyRegistry 'Software\Infiniti\XKey'
    if (!$metadata) { return $null }
    $folder = [string]$metadata['InstallFolder']
    if (!$folder -or ![IO.Path]::IsPathRooted($folder)) { return $null }
    $dll = Join-Path $folder 'XKey.dll'
    $manifest = Join-Path $folder 'XKey.vsto'
    $reg32 = Read-XKeyRegistry 'Software\Microsoft\Office\PowerPoint\Addins\XKey' Registry32
    $reg64 = Read-XKeyRegistry 'Software\Microsoft\Office\PowerPoint\Addins\XKey' Registry64
    return [pscustomobject]@{
        Version = $metadata['Version']; ProductCode = $metadata['ProductCode']; Folder = $folder
        Distribution = if($metadata['Distribution']){$metadata['Distribution']}elseif([version]$metadata['Version'] -le [version]'1.0.3.0'){'Intune'}else{'Unknown'}
        DllVersion = if (Test-Path -LiteralPath $dll) { [Diagnostics.FileVersionInfo]::GetVersionInfo($dll).FileVersion } else { $null }
        FilesPresent = (Test-XKeyInstalledPayload $folder ([string]$metadata['Version']))
        ManifestPath = $manifest
        Manifest32 = if ($reg32) { $reg32['Manifest'] } else { $null }
        Manifest64 = if ($reg64) { $reg64['Manifest'] } else { $null }
    }
}
    if (Test-XKeyInstalledState (Get-XKeyInstalledState) ([version]$minimumVersion) $expectedProductCode) {
        Write-Output "XKey $minimumVersion or newer is installed."
        exit 0
    }
} catch { [Console]::Error.WriteLine($_.Exception.Message) }
exit 1


# SIG # Begin signature block
# MIImpwYJKoZIhvcNAQcCoIImmDCCJpQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCqTB8dcZtve70i
# nGruzN5fCJgUOS9nylPhIIZ+m+XcvaCCIDcwggWNMIIEdaADAgECAhAOmxiO+dAt
# 5+/bUOIIQBhaMA0GCSqGSIb3DQEBDAUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNV
# BAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0yMjA4MDEwMDAwMDBa
# Fw0zMTExMDkyMzU5NTlaMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2Vy
# dCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lD
# ZXJ0IFRydXN0ZWQgUm9vdCBHNDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoC
# ggIBAL/mkHNo3rvkXUo8MCIwaTPswqclLskhPfKK2FnC4SmnPVirdprNrnsbhA3E
# MB/zG6Q4FutWxpdtHauyefLKEdLkX9YFPFIPUh/GnhWlfr6fqVcWWVVyr2iTcMKy
# unWZanMylNEQRBAu34LzB4TmdDttceItDBvuINXJIB1jKS3O7F5OyJP4IWGbNOsF
# xl7sWxq868nPzaw0QF+xembud8hIqGZXV59UWI4MK7dPpzDZVu7Ke13jrclPXuU1
# 5zHL2pNe3I6PgNq2kZhAkHnDeMe2scS1ahg4AxCN2NQ3pC4FfYj1gj4QkXCrVYJB
# MtfbBHMqbpEBfCFM1LyuGwN1XXhm2ToxRJozQL8I11pJpMLmqaBn3aQnvKFPObUR
# WBf3JFxGj2T3wWmIdph2PVldQnaHiZdpekjw4KISG2aadMreSx7nDmOu5tTvkpI6
# nj3cAORFJYm2mkQZK37AlLTSYW3rM9nF30sEAMx9HJXDj/chsrIRt7t/8tWMcCxB
# YKqxYxhElRp2Yn72gLD76GSmM9GJB+G9t+ZDpBi4pncB4Q+UDCEdslQpJYls5Q5S
# UUd0viastkF13nqsX40/ybzTQRESW+UQUOsxxcpyFiIJ33xMdT9j7CFfxCBRa2+x
# q4aLT8LWRV+dIPyhHsXAj6KxfgommfXkaS+YHS312amyHeUbAgMBAAGjggE6MIIB
# NjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTs1+OC0nFdZEzfLmc/57qYrhwP
# TzAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzAOBgNVHQ8BAf8EBAMC
# AYYweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdp
# Y2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNv
# bS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwRQYDVR0fBD4wPDA6oDigNoY0
# aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENB
# LmNybDARBgNVHSAECjAIMAYGBFUdIAAwDQYJKoZIhvcNAQEMBQADggEBAHCgv0Nc
# Vec4X6CjdBs9thbX979XB72arKGHLOyFXqkauyL4hxppVCLtpIh3bb0aFPQTSnov
# Lbc47/T/gLn4offyct4kvFIDyE7QKt76LVbP+fT3rDB6mouyXtTP0UNEm0Mh65Zy
# oUi0mcudT6cGAxN3J0TU53/oWajwvy8LpunyNDzs9wPHh6jSTEAZNUZqaVSwuKFW
# juyk1T3osdz9HNj0d1pcVIxv76FQPfx2CWiEn2/K2yCNNWAcAgPLILCsWKAOQGPF
# mCLBsln1VWvPJ6tsds5vIy30fnFqI2si/xK4VC0nftg62fC2h5b9W9FcrBjDTZ9z
# twGpn1eqXijiuZQwggY8MIIEJKADAgECAhBRnrYY0Q9wIE4XHu30AtQFMA0GCSqG
# SIb3DQEBCwUAMFYxCzAJBgNVBAYTAlBMMSEwHwYDVQQKExhBc3NlY28gRGF0YSBT
# eXN0ZW1zIFMuQS4xJDAiBgNVBAMTG0NlcnR1bSBDb2RlIFNpZ25pbmcgMjAyMSBD
# QTAeFw0yNDA5MTcxMzUwMzZaFw0yNzA5MTcxMzUwMzVaMGIxCzAJBgNVBAYTAkpQ
# MREwDwYDVQQIDAhLYW5hZ2F3YTEQMA4GA1UEBwwHSXNlaGFyYTEWMBQGA1UECgwN
# R2FicmllbGUgU2F0bzEWMBQGA1UEAwwNR2FicmllbGUgU2F0bzCCAaIwDQYJKoZI
# hvcNAQEBBQADggGPADCCAYoCggGBAJ4/t6Xl4v8S5qvSZxbzBo6R0vqig55fZRZv
# rPJ2Yw1Ll1/SSohdkH+HfiF8ejO4Ehlfyn+wIPR5ugIgLUXpma3h2+bagqo4IlLs
# 2zPPCs0NwpvGhSTCUgK4ktr3hvHtzp5RI+aX+dKoR+o5d9x81iFKq3/sVWqDeZz5
# WDyhw91Jzk4B6lcqhndDAdjQ7ZEnAXZ420Uvf+dhn2P9TBMHsB6zkjI0bSwMBysK
# 8/nKIzpkbN2ncZZV5w7vem1Pd2r4H+Yv8ZhZ/za9Urjj5BGDEuz9uBrz4ge+3uN/
# UgzBfMyg8JGjD2tEadliSycbAtlxPacBMfIMZsf2HaC56hPAVAopaTiI9bGST95P
# B6Ro94y16L2+nNwAHc91wdTMkAg+v24NXifW0xNmgooWIxIFQNR3ZSvhQG6rFx/N
# a1Yjy23CUW2dD7EmnkhR9rujT4zrvxUkwgi6WQ+lAI07wJzRUv9p7exfhgCVrtmo
# WTYXjrwryzUbfL/ya3C62xAiG6IUBQIDAQABo4IBeDCCAXQwDAYDVR0TAQH/BAIw
# ADA9BgNVHR8ENjA0MDKgMKAuhixodHRwOi8vY2NzY2EyMDIxLmNybC5jZXJ0dW0u
# cGwvY2NzY2EyMDIxLmNybDBzBggrBgEFBQcBAQRnMGUwLAYIKwYBBQUHMAGGIGh0
# dHA6Ly9jY3NjYTIwMjEub2NzcC1jZXJ0dW0uY29tMDUGCCsGAQUFBzAChilodHRw
# Oi8vcmVwb3NpdG9yeS5jZXJ0dW0ucGwvY2NzY2EyMDIxLmNlcjAfBgNVHSMEGDAW
# gBTddF1MANt7n6B0yrFu9zzAMsBwzTAdBgNVHQ4EFgQU73XEFzjdQjYgpo8fC4qh
# sdNisGEwSwYDVR0gBEQwQjAIBgZngQwBBAEwNgYLKoRoAYb2dwIFAQQwJzAlBggr
# BgEFBQcCARYZaHR0cHM6Ly93d3cuY2VydHVtLnBsL0NQUzATBgNVHSUEDDAKBggr
# BgEFBQcDAzAOBgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcNAQELBQADggIBAGSuv0SN
# uGJdNtfkld8PDNVmjcIlKMRJGt0cayCrvqdUuCZVbvDokk3Y8BVh6mBukGrQL8km
# 5xfTn0C8F6A2Up3D7ZmGeJhumDqxO8KUInALDDWb9eJ1RAQ5tbpoNuygi4PNSQVE
# NHKs8UpmBiH6LKwCBi7z4y7AZnWvmtJv+RQxHG5/6uKPsrIEI7r9Nq3OTk3MQ1DP
# mcgr4UzpJOgsARBlv4ks5kNBeIpmJsYRZ/dB/4bRusVqXUHOsluCfy9HvFyBDuKX
# qA3OwpCOcsARmhaaklo/8ifurdt/cI5QZT+dIkcNhsN9INfDABPt9iJq9ez+Mwu7
# hkp2QD9eZbNLsYFsB01lMMACtiZI1yR4rMdQWI3PHllfIs24rAWtykStOxgKj8DX
# HlvmBSZlfDQE+N0VO5MT0Au43r/oYv6ucSInBoDtOXR4VlA4uHPb+7/WvQPEVKnd
# vlRLLl/49QFcu7Ho0uzeftk403jUiPw3ZJ8fAbb5+PLY6mVIdkc0egfjcoZ89NCC
# +mnCHmIX6bfm5tu/UefJiYHH0J8TmI7SPs7oTbDFgu7Q7qXSCjaJg+4SBjm3yhhx
# SFThghzYHdbmxIrLgNMaUL17PAboXgIuJY68KZYQixD+lnCGl3CXrEGhJ8C6D3Db
# sSFui33T2licZhgevjVgLJkPV6kIyA4/V7j2MIIGtDCCBJygAwIBAgIQDcesVwX/
# IZkuQEMiDDpJhjANBgkqhkiG9w0BAQsFADBiMQswCQYDVQQGEwJVUzEVMBMGA1UE
# ChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYD
# VQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwHhcNMjUwNTA3MDAwMDAwWhcN
# MzgwMTE0MjM1OTU5WjBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQs
# IEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5n
# IFJTQTQwOTYgU0hBMjU2IDIwMjUgQ0ExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
# MIICCgKCAgEAtHgx0wqYQXK+PEbAHKx126NGaHS0URedTa2NDZS1mZaDLFTtQ2oR
# jzUXMmxCqvkbsDpz4aH+qbxeLho8I6jY3xL1IusLopuW2qftJYJaDNs1+JH7Z+Qd
# SKWM06qchUP+AbdJgMQB3h2DZ0Mal5kYp77jYMVQXSZH++0trj6Ao+xh/AS7sQRu
# QL37QXbDhAktVJMQbzIBHYJBYgzWIjk8eDrYhXDEpKk7RdoX0M980EpLtlrNyHw0
# Xm+nt5pnYJU3Gmq6bNMI1I7Gb5IBZK4ivbVCiZv7PNBYqHEpNVWC2ZQ8BbfnFRQV
# ESYOszFI2Wv82wnJRfN20VRS3hpLgIR4hjzL0hpoYGk81coWJ+KdPvMvaB0WkE/2
# qHxJ0ucS638ZxqU14lDnki7CcoKCz6eum5A19WZQHkqUJfdkDjHkccpL6uoG8pbF
# 0LJAQQZxst7VvwDDjAmSFTUms+wV/FbWBqi7fTJnjq3hj0XbQcd8hjj/q8d6ylgx
# CZSKi17yVp2NL+cnT6Toy+rN+nM8M7LnLqCrO2JP3oW//1sfuZDKiDEb1AQ8es9X
# r/u6bDTnYCTKIsDq1BtmXUqEG1NqzJKS4kOmxkYp2WyODi7vQTCBZtVFJfVZ3j7O
# gWmnhFr4yUozZtqgPrHRVHhGNKlYzyjlroPxul+bgIspzOwbtmsgY1MCAwEAAaOC
# AV0wggFZMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0OBBYEFO9vU0rp5AZ8esri
# kFb2L9RJ7MtOMB8GA1UdIwQYMBaAFOzX44LScV1kTN8uZz/nupiuHA9PMA4GA1Ud
# DwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcDCDB3BggrBgEFBQcBAQRrMGkw
# JAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBBBggrBgEFBQcw
# AoY1aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJv
# b3RHNC5jcnQwQwYDVR0fBDwwOjA4oDagNIYyaHR0cDovL2NybDMuZGlnaWNlcnQu
# Y29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcmwwIAYDVR0gBBkwFzAIBgZngQwB
# BAIwCwYJYIZIAYb9bAcBMA0GCSqGSIb3DQEBCwUAA4ICAQAXzvsWgBz+Bz0RdnEw
# vb4LyLU0pn/N0IfFiBowf0/Dm1wGc/Do7oVMY2mhXZXjDNJQa8j00DNqhCT3t+s8
# G0iP5kvN2n7Jd2E4/iEIUBO41P5F448rSYJ59Ib61eoalhnd6ywFLerycvZTAz40
# y8S4F3/a+Z1jEMK/DMm/axFSgoR8n6c3nuZB9BfBwAQYK9FHaoq2e26MHvVY9gCD
# A/JYsq7pGdogP8HRtrYfctSLANEBfHU16r3J05qX3kId+ZOczgj5kjatVB+NdADV
# ZKON/gnZruMvNYY2o1f4MXRJDMdTSlOLh0HCn2cQLwQCqjFbqrXuvTPSegOOzr4E
# Wj7PtspIHBldNE2K9i697cvaiIo2p61Ed2p8xMJb82Yosn0z4y25xUbI7GIN/TpV
# fHIqQ6Ku/qjTY6hc3hsXMrS+U0yy+GWqAXam4ToWd2UQ1KYT70kZjE4YtL8Pbzg0
# c1ugMZyZZd/BdHLiRu7hAWE6bTEm4XYRkA6Tl4KSFLFk43esaUeqGkH/wyW4N7Oi
# gizwJWeukcyIPbAvjSabnf7+Pu0VrFgoiovRDiyx3zEdmcif/sYQsfch28bZeUz2
# rtY/9TCA6TD8dC3JE3rYkrhLULy7Dc90G6e8BlqmyIjlgp2+VqsS9/wQD7yFylIz
# 0scmbKvFoW2jNrbM1pD2T7m3XDCCBrkwggShoAMCAQICEQCZo4AKJlU7ZavcboSm
# s+o5MA0GCSqGSIb3DQEBDAUAMIGAMQswCQYDVQQGEwJQTDEiMCAGA1UEChMZVW5p
# emV0byBUZWNobm9sb2dpZXMgUy5BLjEnMCUGA1UECxMeQ2VydHVtIENlcnRpZmlj
# YXRpb24gQXV0aG9yaXR5MSQwIgYDVQQDExtDZXJ0dW0gVHJ1c3RlZCBOZXR3b3Jr
# IENBIDIwHhcNMjEwNTE5MDUzMjE4WhcNMzYwNTE4MDUzMjE4WjBWMQswCQYDVQQG
# EwJQTDEhMB8GA1UEChMYQXNzZWNvIERhdGEgU3lzdGVtcyBTLkEuMSQwIgYDVQQD
# ExtDZXJ0dW0gQ29kZSBTaWduaW5nIDIwMjEgQ0EwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQCdI88EMCM7wUYs5zNzPmNdenW6vlxNur3rLfi+5OZ+U3iZ
# IB+AspO+CC/bj+taJUbMbFP1gQBJUzDUCPx7BNLgid1TyztVLn52NKgxxu8gpyTr
# 6EjWyGzKU/gnIu+bHAse1LCitX3CaOE13rbuHbtrxF2tPU8f253QgX6eO8yTbGps
# 1Mg+yda3DcTsOYOhSYNCJiL+5wnjZ9weoGRtvFgMHtJg6i671OPXIciiHO4Lwo2p
# 9xh/tnj+JmCQEn5QU0NxzrOiRna4kjFaA9ZcwSaG7WAxeC/xoZSxF1oK1UPZtKVt
# +yrsGKqWONoK6f5EmBOAVEK2y4ATDSkb34UD7JA32f+Rm0wsr5ajzftDhA5mBipV
# ZDjHpwzv8bTKzCDUSUuUmPo1govD0RwFcTtMXcfJtm1i+P2UNXadPyYVKRxKQATH
# N3imsfBiNRdN5kiVVeqP55piqgxOkyt+HkwIA4gbmSc3hD8ke66t9MjlcNg73rZZ
# lrLHsAIV/nJ0mmgSjBI/TthoGJDydekOQ2tQD2Dup/+sKQptalDlui59SerVSJg8
# gAeV7N/ia4mrGoiez+SqV3olVfxyLFt3o/OQOnBmjhKUANoKLYlKmUpKEFI0PfoT
# 8Q1W/y6s9LTI6ekbi0igEbFUIBE8KDUGfIwnisEkBw5KcBZ3XwnHmfznwlKo8QID
# AQABo4IBVTCCAVEwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU3XRdTADbe5+g
# dMqxbvc8wDLAcM0wHwYDVR0jBBgwFoAUtqFUOQLDoD+Oirz61PgcptE6Dv0wDgYD
# VR0PAQH/BAQDAgEGMBMGA1UdJQQMMAoGCCsGAQUFBwMDMDAGA1UdHwQpMCcwJaAj
# oCGGH2h0dHA6Ly9jcmwuY2VydHVtLnBsL2N0bmNhMi5jcmwwbAYIKwYBBQUHAQEE
# YDBeMCgGCCsGAQUFBzABhhxodHRwOi8vc3ViY2Eub2NzcC1jZXJ0dW0uY29tMDIG
# CCsGAQUFBzAChiZodHRwOi8vcmVwb3NpdG9yeS5jZXJ0dW0ucGwvY3RuY2EyLmNl
# cjA5BgNVHSAEMjAwMC4GBFUdIAAwJjAkBggrBgEFBQcCARYYaHR0cDovL3d3dy5j
# ZXJ0dW0ucGwvQ1BTMA0GCSqGSIb3DQEBDAUAA4ICAQB1iFgP5Y9QKJpTnxDsQ/z0
# O23JmoZifZdEOEmQvo/79PQg9nLF/GJe6ZiUBEyDBHMtFRK0mXj3Qv3gL0sYXe+P
# PMfwmreJHvgFGWQ7XwnfMh2YIpBrkvJnjwh8gIlNlUl4KENTK5DLqsYPEtRQCw7R
# 6p4s2EtWyDDr/M58iY2UBEqfUU/ujR9NuPyKk0bEcEi62JGxauFYzZ/yld13fHaZ
# skIoq2XazjaD0pQkcQiIueL0HKiohS6XgZuUtCKA7S6CHttZEsObQJ1j2s0urIDd
# qF7xaXFVaTHKtAuMfwi0jXtF3JJphrJfc+FFILgCbX/uYBPBlbBIP4Ht4xxk2Gmf
# zMn7oxPITpigQFJFWuzTMUUgdRHTxaTSKRJ/6Uh7ki/pFjf9sUASWgxT69QF9Ki4
# JF5nBIujxZ2sOU9e1HSCJwOfK07t5nnzbs1LbHuAIGJsRJiQ6HX/DW1XFOlXY1rc
# 9HufFhWU+7Uk+hFkJsfzqBz3pRO+5aI6u5abI4Qws4YaeJH7H7M8X/YNoaArZbV4
# Ql+jarKsE0+8XvC4DJB+IVcvC9Ydqahi09mjQse4fxfef0L7E3hho2O3bLDM6v60
# rIRUCi2fJT2/IRU5ohgyTch4GuYWefSBsp5NPJh4QRTP9DC3gc5QEKtbrTY0Ka87
# Web7/zScvLmvQBm8JDFpDjCCBu0wggTVoAMCAQICEAhP3DNPfkVO28MPj/mSGDUw
# DQYJKoZIhvcNAQELBQAwaTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0
# LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVTdGFtcGlu
# ZyBSU0E0MDk2IFNIQTI1NiAyMDI1IENBMTAeFw0yNjA4MDUwMDAwMDBaFw0zNzEx
# MDQyMzU5NTlaMGMxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5j
# LjE7MDkGA1UEAxMyRGlnaUNlcnQgU0hBMjU2IFJTQTQwOTYgVGltZXN0YW1wIFJl
# c3BvbmRlciAyMDI2IDEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC2
# e6byyf7NSvjUm0xls/04xjD4fAkOkbnGQi7+Wpx81iYxfzViaxSIctuH3KSl5YEY
# pMuFgGsA31N2D9ATMbfZdw5uaAhuWevQKhDdZIB4NnqcfpfpWQXJiQnDdAElETC+
# bhSEvNLGbA8DtwUpFMQ4yyYQSPqomT92osQAv6hBi47ATZS6JfVWe6XxhF4jJZ3i
# SAuf2Cros1czRSmWRHqMv9AfGZvp8ygYElhudpQjtcPpwoOl6QrZJUyV3iINvN4c
# O05prGV0fkjG426xDr2d3z9lcSIHkdvGPdGUrXdxfVbgOUVcp2/8ISEzwKPW++Wa
# +E2ujI91EZtukGWDJ/xZ27k3oHKEXBRGfRTqjOU+jE3ba/5++JSE/7oNHnjs5mek
# ExYN96LV/mxUbCKJb8pBNY4r3uD7hEmk/M81XhVgwDA7aMzYC3LZBg9WY5BMmbSa
# y5ecmtJuXaB/0nKWmQmVZeqTVDgsmzHP5MQuhAJkiWNuC9MmCg9TZHXbJ2/yLVSo
# v9p16UDTLtT0+aa1vN71fHeu1qMLlLNB3WOB/ADCxr3S/1hxI92Z6jKgEED/btwI
# vbfuXkNNhg8MtDg43c4tMZae9FvqMOt/9PvmAxF9TNIsIFB8G6yb36ZJZGUL8N/p
# L971DyLXcK6HM5PYnH5X+eVtczhCgHCVQCF6XDAlPQIDAQABo4IBlTCCAZEwDAYD
# VR0TAQH/BAIwADAdBgNVHQ4EFgQUFMljijAu1Er7bpTz5uNAfvXszeIwHwYDVR0j
# BBgwFoAU729TSunkBnx6yuKQVvYv1Ensy04wDgYDVR0PAQH/BAQDAgeAMBYGA1Ud
# JQEB/wQMMAoGCCsGAQUFBwMIMIGVBggrBgEFBQcBAQSBiDCBhTAkBggrBgEFBQcw
# AYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMF0GCCsGAQUFBzAChlFodHRwOi8v
# Y2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkRzRUaW1lU3RhbXBp
# bmdSU0E0MDk2U0hBMjU2MjAyNUNBMS5jcnQwXwYDVR0fBFgwVjBUoFKgUIZOaHR0
# cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0VGltZVN0YW1w
# aW5nUlNBNDA5NlNIQTI1NjIwMjVDQTEuY3JsMCAGA1UdIAQZMBcwCAYGZ4EMAQQC
# MAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsFAAOCAgEAjcU6YR6dUgrfmawJgH59
# KECxa9Ji8sEi2g10CBDaMiqsaxWyW5cwlT/6ZF5sFznazqVsoC85U9dqLOYqQwst
# +UQQoNlDHgKRLa3xoc+OReFreFhnTXSG0Vrd2E2CZqUfm+5a+He1MJ/h+tNLuA+0
# Zzhn/Fo+FDYAHWZHx4R79ZsfRFYe9UiXpXBDf6DkUo183Y38NYmR/XfDYf7YZ+oR
# 9t3flbDwK+hgGMs0gNNp1w9Z2CyOyI5or/sSwomAuNQ0hWC9xoU4stD8aWsD7Rkc
# mgVRs6vlIk3zPKQ+ylcheWkMlj+CoVRlFE55pv0ZWCaFt04lwP/rdGHE9qEVQZty
# RE42ox7oNgC/r+Y4bSlZ3dw9K2x1xLtu6PkPKeLBFjzKigwfqm3Hm+k/+lnME8F5
# kPZTgiy2HLEHklpryqs6QHnPXrRNeIzkAMyylnRN8P0wmirS0WkU+ywpEWFZ4QNg
# +9xS43tTuW9x0eXh7NDc1P/sV+zWxHXKH8tFt1ncHdVzqrZaYPyYMLSn2TOXajve
# JW1L3joiQSPsWRGxkbDDW15jERFE4LvjnGu2O9zD1nLJSMdlYZEikl4w2w+q4IN/
# R+TIe0H4ngCI1moJCTbevGH4punIxM1Uoi0nmX3ZK+XbRT01uowE5ViXWHng0Rgs
# mrX/EdYUo80r3TfMlkD0/YMxggXGMIIFwgIBATBqMFYxCzAJBgNVBAYTAlBMMSEw
# HwYDVQQKExhBc3NlY28gRGF0YSBTeXN0ZW1zIFMuQS4xJDAiBgNVBAMTG0NlcnR1
# bSBDb2RlIFNpZ25pbmcgMjAyMSBDQQIQUZ62GNEPcCBOFx7t9ALUBTANBglghkgB
# ZQMEAgEFAKCBhDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJ
# AzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8G
# CSqGSIb3DQEJBDEiBCAFjs0m6iZqmVMrX3YJG0CCHdwQmrZUNF+4hySxABhoETAN
# BgkqhkiG9w0BAQEFAASCAYCJwtnd24+eqg9dxbIfFzrviX3Os8tL4p15UaecbMQ+
# oq5xlmk0VGqd6ZPTqDHj4PdNQjkC4Yg2MmQ9Y78o5rHZdDsKZvejHEzk+k04gM5p
# 6wjW0PWfjOafVd2eTLjtMr/ubxGLGmjkMoA+p6d9fqmjJQf/lckZoWvKwDmMrylu
# QIMf0giWnFlBkXHIEhDsMAans3GCMRXAreVYnuz5XWSLOJOscAyRoti/LMX6Frqq
# 4FJ6ozWN//QbSiNTb5xVQCjK5TLgm2+ls9ojqORMGbBGS3fVMJuVYejAVGocTb/R
# vp+jEBKvt4ea4Ngu4bAE/6jUNM0SaeeVxcktqy9zQKnUdNWsansfHD9WQxmCu61s
# 9k1WylmmCl3nc7KZb9wUC64SOmm2R39YuE3Ylu6kNQ1bEZFKvzOyz+i12JZX3ZJh
# v78b/Rz3Cl/lznCiJiykl3JoDb0Y+1uP/RJohdtYfwov8q0wxcwtOFjY4tAnW87w
# 8WM11WqdMTb9qp+cpmoDA5+hggMmMIIDIgYJKoZIhvcNAQkGMYIDEzCCAw8CAQEw
# fTBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNV
# BAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYgU0hB
# MjU2IDIwMjUgQ0ExAhAIT9wzT35FTtvDD4/5khg1MA0GCWCGSAFlAwQCAQUAoGkw
# GAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjYxMDIx
# MDUxMjQ1WjAvBgkqhkiG9w0BCQQxIgQgQzdFs4FX7vryL+qnoUZEJdnr8SHBjvoN
# PZUIy7CYOAowDQYJKoZIhvcNAQEBBQAEggIAldsfmgYbzsEcP4EgteTTlmpe0D8A
# Z6pnKTYjjauEYVZdGbTr42LACAsfq/qCVWj5kZyoDXozIbKzrOYa96W2ao6epwal
# Kn5mmd+CxBLIMLkLUWv8EGPTm36sQCkh/MdCRV0zPRvu61vq9mUxQpXcykwzOWR4
# plhNjLRCd7sDXeiwwLL2eJbH/ck+eiqaH7az55/P36Jijf41RDIH9SfRH7NZuxzR
# +xTDmEuJm+m+OyiJtdKiBvJhPmlBeFsXm6/JQpximyOZeM0Q36FIClg6vz5uYi3K
# 7XkWdhXUh+IPNvVGfd7OS2HfeLTBFfcVqAeu3QsBqE54/g5KHDA6UAGSPj9Em+SC
# veMOmG3lVm/K2k/k+drLBOF7eqE6s9sOHBBmkWfeXH0q5Hm/6NyDSM4QAaUIfDUE
# 84s4HuOXT97HJzGnVM2idriJhtkWEAJnzKYx1IS3G8ED0CArMBD7C7lMiL1cC3dq
# pVviDsRwgQ/bI+6OEpzfZnPCkYnT62W6lXzY83eizyXhbcWYcWvte1WfnRAKzXvO
# lvvxCwyN9P0QvXUUgFt8BeBeBpY7dKcw1Go9e3gxpEjFUEBLSr73oNu/IOj5A/zn
# pVRq4B81Yovc1Ccpwchnt7QxLTYeTatBRm4A/9y1oZhFSjdI7wck1t55r/cCAdSo
# KCHIAxs10JTO+mc=
# SIG # End signature block
