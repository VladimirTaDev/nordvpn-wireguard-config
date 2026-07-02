#Requires -Version 5.1
Set-StrictMode -Version Latest
# ==============================================================================
# Script: Get-NordVPN-WireGuard-v1.2.ps1
# Version: 1.2
# Author: https://github.com/VladimirTaDev | d2lq6sw3@duck.com
# Description: Generates WireGuard configuration files for NordVPN via API.
# ==============================================================================

# [C1] Force TLS 1.2+ with best-effort TLS 1.3 (compatible with PS 5.1)
$proto = [Net.SecurityProtocolType]::Tls12
if ([enum]::IsDefined([Net.SecurityProtocolType], 'Tls13')) {
    $proto = $proto -bor [Net.SecurityProtocolType]::Tls13
}
[Net.ServicePointManager]::SecurityProtocol = $proto

# [S3] Centralized cleanup function (replaces unreliable trap block)
# Note: Plaintext secrets in managed memory cannot be reliably zeroed due to .NET string immutability.
# Cleanup is best-effort.
function Invoke-Cleanup {
    Remove-Variable -Scope Script -Name Token, secureToken, credentials, encodedCredentials, headers, privKeyResponse, privateKey, confContent -ErrorAction SilentlyContinue
    [System.GC]::Collect()
}

# Helper to ensure cleanup and consistent exit behavior
function Stop-Script {
    Invoke-Cleanup
    Read-Host "Press Enter to exit..."
    exit
}

# ------------------------------------------------------------------------------
# Function: Interactive terminal menu with numbered list and Quick Access
# Note: Expects $Items to be a collection of objects exposing .name and .id properties
# [I3] Added -DefaultLabel parameter for context-aware default hint
# ------------------------------------------------------------------------------
function Get-TerminalSelection {
    param(
        [string]$Title,
        [array]$Items,
        [array]$QuickAccessNames,
        [string]$DefaultLabel = "Best Location"
    )

    while ($true) {
        Write-Host "`n=== $Title ===" -ForegroundColor Cyan

        # Display numbered list
        $maxItems = $Items.Count
        for ($i = 0; $i -lt $maxItems; $i++) {
            Write-Host ("[{0,3}] {1}" -f ($i + 1), $Items[$i].name)
        }

        # Build and display Quick Access shortcuts (if provided)
        $qaItems = @()
        if ($QuickAccessNames) {
            foreach ($name in $QuickAccessNames) {
                # [I2] Use exact match instead of regex -match
                $found = $Items | Where-Object { $_.name -ieq $name }
                if ($found) {
                    $qaItems += $found[0]
                }
            }
            if ($qaItems.Count -gt 0) {
                Write-Host "`n--- Quick Access ---" -ForegroundColor Yellow
                for ($q = 0; $q -lt $qaItems.Count; $q++) {
                    Write-Host ("[{0,3}] {1}" -f ("Q" + ($q + 1)), $qaItems[$q].name) -ForegroundColor Yellow
                }
            }
        }

        # Display input instructions
        Write-Host "------------------------------------------------"
        Write-Host "-> Type a NUMBER to select."
        if ($qaItems.Count -gt 0) {
            Write-Host "-> Type 'Q1', 'Q2', etc. for Quick Access."
        }
        # [I3] Context-aware default label
        Write-Host "-> Type 'B' (or press ENTER) for $DefaultLabel."
        Write-Host "-> Type 'Q' to quit."

        $inputStr = (Read-Host "Choice").Trim()

        # Quit
        if ($inputStr -ieq 'q') {
            return $null
        }

        # Best/Default (or empty input)
        if ($inputStr -ieq 'b' -or $inputStr -eq '') {
            return "BEST"
        }

        # Quick Access selection (e.g., Q1, Q2)
        if ($inputStr -match "^(?i)q(\d+)$") {
            $qaIndex = [int]$matches[1] - 1
            if ($qaIndex -ge 0 -and $qaIndex -lt $qaItems.Count) {
                return $qaItems[$qaIndex]
            } else {
                # [I2] Specific error message for invalid Quick Access
                Write-Host "`nInvalid Quick Access selection." -ForegroundColor Red
                continue
            }
        }

        # Numeric selection
        if ([int]::TryParse($inputStr, [ref]$null)) {
            $index = [int]$inputStr - 1
            if ($index -ge 0 -and $index -lt $Items.Count) {
                return $Items[$index]
            } else {
                Write-Host "`nInvalid number." -ForegroundColor Red
            }
        } else {
            Write-Host "`nInvalid input. Please type a number." -ForegroundColor Red
        }
    }
}

# ------------------------------------------------------------------------------
# Banner (v1.2)
# ------------------------------------------------------------------------------
Write-Host ''
Write-Host '    ╔═══════════════════════════════════════════════════════════╗' -ForegroundColor DarkCyan
Write-Host '    ║                                                           ║' -ForegroundColor DarkCyan
Write-Host '    ║      /\_/\          ██╗    ██╗ ██████╗  ███████╗          ║' -ForegroundColor DarkCyan
Write-Host '    ║     ( ò_ó )         ██║    ██║ ██╔══██╗ ╚════██║          ║' -ForegroundColor DarkCyan
Write-Host '    ║      =\V/=          ██║ █╗ ██║ ██████╔╝   ███╔╝           ║' -ForegroundColor DarkCyan
Write-Host '    ║     /|   |\         ██║███╗██║ ██╔══██╗  ███╔╝            ║' -ForegroundColor DarkCyan
Write-Host '    ║    (_|   |_)        ╚███╔███╔╝ ██║  ██║ ███████╗          ║' -ForegroundColor DarkCyan
Write-Host '    ║      |___|           ╚══╝╚══╝  ╚═╝  ╚═╝ ╚══════╝         ║' -ForegroundColor DarkCyan
Write-Host '    ║      // X \\            w1r36u4rd_r0u71n6_z3r0            ║' -ForegroundColor DarkCyan
Write-Host '    ║     << / \ >>    N O R D V P N   W I R E G U A R D        ║' -ForegroundColor DarkCyan
Write-Host '    ║    // /   \ \\   C O N F I G   G E N E R A T O R   v1.2   ║' -ForegroundColor DarkCyan
Write-Host '    ║   <<_/     \_>>                                           ║' -ForegroundColor DarkCyan
Write-Host '    ║                                                           ║' -ForegroundColor DarkCyan
Write-Host '    ║      [ c0ded by VladimirTaDev | d2lq6sw3@duck.com ]       ║' -ForegroundColor DarkCyan
Write-Host '    ║            [ No installs · No leaks · Just keys ]         ║' -ForegroundColor DarkCyan
Write-Host '    ║                                                           ║' -ForegroundColor DarkCyan
Write-Host '    ╚═══════════════════════════════════════════════════════════╝' -ForegroundColor DarkCyan
Write-Host ''

# ------------------------------------------------------------------------------
# Authentication
# [C1] PS 5.1 compatible token input (fallback from -MaskInput to -AsSecureString)
# ------------------------------------------------------------------------------
if ((Get-Command Read-Host).Parameters.ContainsKey('MaskInput')) {
    $Token = Read-Host "Please paste your NordVPN Access Token" -MaskInput
} else {
    $secureToken = Read-Host "Please paste your NordVPN Access Token" -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
    try {
        $Token = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}
$Token = $Token.Trim()

if ([string]::IsNullOrWhiteSpace($Token)) {
    Write-Host "No token provided. Exiting." -ForegroundColor Red
    Stop-Script
}

$credentials = "token:$Token"
$encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($credentials))
$headers = @{ "Authorization" = "Basic $encodedCredentials" }

# Best effort cleanup of local plaintext Token variable
$Token = $null

Write-Host "`nAuthenticating and fetching list of available countries..." -ForegroundColor Cyan
try {
    # [M4] Added -TimeoutSec 30 to prevent indefinite hangs
    $privKeyResponse = Invoke-RestMethod -Uri "https://api.nordvpn.com/v1/users/services/credentials" -Headers $headers -TimeoutSec 30
    $privateKey = $privKeyResponse.nordlynx_private_key

    # [S4] Validate private key from API response
    if ([string]::IsNullOrWhiteSpace($privateKey)) {
        Write-Host "No NordLynx private key found on this account. Enable NordLynx/WireGuard in your NordVPN account first." -ForegroundColor Red
        Stop-Script
    }

    # [M4] Added -TimeoutSec 30
    $countries = Invoke-RestMethod -Uri "https://api.nordvpn.com/v1/servers/countries" -TimeoutSec 30
    $countries = $countries | Sort-Object name
} catch {
    Write-Host "Failed to connect. Make sure your token is correct and active.`nError: $($_.Exception.Message)" -ForegroundColor Red
    Stop-Script
}

# ------------------------------------------------------------------------------
# Server Type Selection
# [I3] Uses -DefaultLabel "Standard VPN" for accurate prompt
# ------------------------------------------------------------------------------
$groups = @(
    @{ name = "Standard VPN"; id = "legacy_standard" }
    @{ name = "P2P"; id = "legacy_p2p" }
    @{ name = "Double VPN"; id = "legacy_double_vpn" }
    @{ name = "Onion Over VPN"; id = "legacy_onion_over_vpn" }
)

$selectedGroup = Get-TerminalSelection -Title "SELECT SERVER TYPE" -Items $groups -DefaultLabel "Standard VPN"

if ($null -eq $selectedGroup) {
    Write-Host "Exiting." -ForegroundColor Yellow
    Stop-Script
}

# Default to Standard VPN when user presses Enter
if ($selectedGroup -eq "BEST") {
    $selectedGroup = $groups[0]
}

# ------------------------------------------------------------------------------
# Country and City Selection
# ------------------------------------------------------------------------------
$selectedCountry = Get-TerminalSelection -Title "SELECT A COUNTRY" -Items $countries -QuickAccessNames @("United States", "Costa Rica")

if ($null -eq $selectedCountry) {
    Write-Host "Exiting." -ForegroundColor Yellow
    Stop-Script
}

$countryId = $null
$cityId = $null

if ($selectedCountry -eq "BEST") {
    $locationName = "Best Global Location"
} else {
    $countryId = $selectedCountry.id
    $locationName = $selectedCountry.name

    # [C3] Wrap .Count in @() for PS 5.1 null safety
    if ($selectedCountry.cities -and @($selectedCountry.cities).Count -gt 1) {
        $sortedCities = $selectedCountry.cities | Sort-Object name
        
        # Context-aware Quick Access for Cities
        $cityQa = @()
        if ($selectedCountry.name -eq "United States") {
            $cityQa = @("Miami", "New York")
        }

        $selectedCity = Get-TerminalSelection -Title "SELECT A CITY IN $($selectedCountry.name)" -Items $sortedCities -QuickAccessNames $cityQa

        if ($null -eq $selectedCity) {
            Write-Host "Exiting." -ForegroundColor Yellow
            Stop-Script
        }

        if ($selectedCity -eq "BEST") {
            $locationName = "Best Server in $($selectedCountry.name)"
        } else {
            $cityId = $selectedCity.id
            $locationName = "$($selectedCity.name), $($selectedCountry.name)"
        }
    } elseif ($selectedCountry.cities -and @($selectedCountry.cities).Count -eq 1) {
        $cityId = $selectedCountry.cities[0].id
        $locationName = "$($selectedCountry.cities[0].name), $($selectedCountry.name)"
    }
}

# ------------------------------------------------------------------------------
# Fetch Best Server and Display WireGuard Configuration
# ------------------------------------------------------------------------------
Write-Host "`nFetching Best Server Details for $locationName..." -ForegroundColor Cyan
try {
    # Build the API URL with filters
    $apiUrl = "https://api.nordvpn.com/v1/servers/recommendations?filters[servers_technologies][identifier]=wireguard_udp&filters[servers_groups][identifier]=$($selectedGroup.id)&limit=1"

    if ($null -ne $cityId) {
        $apiUrl += "&filters[city_id]=$cityId"
    } elseif ($null -ne $countryId) {
        $apiUrl += "&filters[country_id]=$countryId"
    }

    # [M4] Added -TimeoutSec 30
    $serverResponse = Invoke-RestMethod -Uri $apiUrl -TimeoutSec 30

    # [C3] Null-safe server response check
    if (-not $serverResponse) {
        Write-Host "No WireGuard servers found for $locationName." -ForegroundColor Red
        Stop-Script
    }

    # Extract server details
    $server = @($serverResponse)[0]
    $endpoint = $server.station
    $wgTech = $server.technologies | Where-Object { $_.identifier -eq "wireguard_udp" }
    $publicKey = ($wgTech.metadata | Where-Object { $_.name -eq "public_key" }).value

    # [S4] Validate public key and endpoint from API response
    if ([string]::IsNullOrWhiteSpace($publicKey) -or [string]::IsNullOrWhiteSpace($endpoint)) {
        Write-Host "Server response missing public key or endpoint. Try another location." -ForegroundColor Red
        Stop-Script
    }

    # Display the configuration
    Write-Host "`n================================================="
    Write-Host " NORDVPN WIREGUARD SETTINGS ($($selectedGroup.name) - $locationName)"
    Write-Host "================================================="
    Write-Host "-> Hostname           : $($server.hostname)"
    Write-Host "`n[Interface]" -ForegroundColor Yellow
    Write-Host "Private Key : $privateKey"
    Write-Host "Address     : 10.5.0.2/32"
    Write-Host "DNS Server  : 103.86.96.100, 103.86.99.100"
    Write-Host "`n[Peer]" -ForegroundColor Yellow
    Write-Host "Server Public Key : $publicKey"
    Write-Host "Endpoint Address  : $endpoint`:51820"
    Write-Host "Allowed IPs       : 0.0.0.0/0, ::/0"
    # [I1] Show PersistentKeepalive in terminal to match .conf file
    Write-Host "Keepalive         : 25"
    Write-Host "================================================="
    # [S1] Warn user about on-screen private key
    Write-Host "-> Note: Your private key is displayed above. Clear your terminal after copying." -ForegroundColor Yellow

    # ------------------------------------------------------------------------------
    # Config File Generation (Optional)
    # ------------------------------------------------------------------------------
    Write-Host ""
    $generateFile = Read-Host "Would you like to generate a local .conf file for easy router import? (Y/N)"

    if ($generateFile -match "^(?i)y") {
        # [C4] Sanitize hostname for safe filename
        $cleanName = $server.hostname -replace '\.nordvpn\.com$', ''
        $cleanName = [string]::Join('_', $cleanName.Split([System.IO.Path]::GetInvalidFileNameChars()))
        $safeGroupName = $selectedGroup.name -replace ' ', ''
        $configName = "NordVPN_${safeGroupName}_$cleanName"
        $fileName = "$configName.conf"

        $confContent = @"
[Interface]
PrivateKey = $privateKey
Address = 10.5.0.2/32
DNS = 103.86.96.100, 103.86.99.100

[Peer]
PublicKey = $publicKey
Endpoint = $endpoint`:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
"@

        # Save to the directory the script resides in, fallback to current directory
        $saveDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
        $filePath = Join-Path -Path $saveDir -ChildPath $fileName

        # [C5] Don't silently overwrite existing .conf files
        if (Test-Path $filePath) {
            $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $filePath = Join-Path -Path $saveDir -ChildPath "${configName}_${timestamp}.conf"
        }

        # [C2] Separate try/catch for file write operations
        try {
            # Create an empty file first so we can apply permissions before writing keys
            New-Item -Path $filePath -ItemType File -Force | Out-Null
            
            # [S1] Restrict file permissions to current user only
            try {
                if ($PSVersionTable.PSVersion.Major -lt 6 -or $IsWindows) {
                    $acl = New-Object System.Security.AccessControl.FileSecurity
                    $acl.SetAccessRuleProtection($true, $false)
                    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
                        [System.Security.Principal.WindowsIdentity]::GetCurrent().Name, 'FullControl', 'Allow')))
                    Set-Acl -Path $filePath -AclObject $acl
                } else {
                    # macOS/Linux fallback
                    chmod 600 $filePath
                }
            } catch {
                Write-Host "-> Note: Could not restrict file permissions." -ForegroundColor Yellow
            }

            # Write content after securing the file
            Set-Content -Path $filePath -Value $confContent -Encoding utf8 -ErrorAction Stop

            Write-Host "`n[SUCCESS] Generated WireGuard Config File!" -ForegroundColor Green
            Write-Host "-> File saved to: $filePath" -ForegroundColor Yellow
            Write-Host "-> This file contains your PRIVATE KEY. Keep it secret; delete it after import." -ForegroundColor Yellow
            Write-Host "-> You can now upload this directly to your Asus Router." -ForegroundColor Yellow
        } catch {
            Write-Host "Failed to write config file: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "Failed to fetch server details: $($_.Exception.Message)" -ForegroundColor Red
    Stop-Script
}

# ------------------------------------------------------------------------------
# Cleanup
# [S3] Using centralized Invoke-Cleanup function
# ------------------------------------------------------------------------------
Write-Host "`nAll done! You can copy the values above." -ForegroundColor Green
Stop-Script
