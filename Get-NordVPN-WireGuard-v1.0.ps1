# ==============================================================================
# Script: Get-NordVPN-WireGuard-v1.0.ps1
# Version: 1.0
# Author: https://github.com/VladimirTaDev | d2lq6sw3@duck.com
# Description: Generates WireGuard configuration files for NordVPN via API.
# ==============================================================================

# Force TLS 1.2+ to prevent protocol downgrade attacks
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

# Ensure sensitive variables are scrubbed on ALL exit paths (including early exits)
trap {
    Remove-Variable -Name Token, credentials, encodedCredentials, headers, privKeyResponse, privateKey, confContent -ErrorAction SilentlyContinue
    [System.GC]::Collect()
}

# ------------------------------------------------------------------------------
# Function: Interactive terminal menu with numbered list and Quick Access
# ------------------------------------------------------------------------------
function Get-TerminalSelection {
    param(
        [string]$Title,
        [array]$Items,
        [array]$QuickAccessNames
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
                $found = $Items | Where-Object { $_.name -match $name }
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
        Write-Host "-> Type 'B' (or press ENTER) for Best Location."
        Write-Host "-> Type 'Q' to quit."

        $inputStr = (Read-Host "Choice").Trim()

        # Quit
        if ($inputStr -ieq 'q') {
            return $null
        }

        # Best Location (or empty input)
        if ($inputStr -ieq 'b' -or $inputStr -eq '') {
            return "BEST"
        }

        # Quick Access selection (e.g., Q1, Q2)
        if ($inputStr -match "^(?i)q(\d+)$") {
            $qaIndex = [int]$matches[1] - 1
            if ($qaIndex -ge 0 -and $qaIndex -lt $qaItems.Count) {
                return $qaItems[$qaIndex]
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
# Banner
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
Write-Host '    ║    // /   \ \\   C O N F I G   G E N E R A T O R   v1.0   ║' -ForegroundColor DarkCyan
Write-Host '    ║   <<_/     \_>>                                           ║' -ForegroundColor DarkCyan
Write-Host '    ║                                                           ║' -ForegroundColor DarkCyan
Write-Host '    ║      [ c0ded by VladimirTaDev | d2lq6sw3@duck.com ]       ║' -ForegroundColor DarkCyan
Write-Host '    ║            [ No installs · No leaks · Just keys ]         ║' -ForegroundColor DarkCyan
Write-Host '    ║                                                           ║' -ForegroundColor DarkCyan
Write-Host '    ╚═══════════════════════════════════════════════════════════╝' -ForegroundColor DarkCyan
Write-Host ''

# ------------------------------------------------------------------------------
# Authentication
# ------------------------------------------------------------------------------
$Token = Read-Host "Please paste your NordVPN Access Token" -MaskInput
$Token = $Token.Trim()

if ([string]::IsNullOrWhiteSpace($Token)) {
    Write-Host "No token provided. Exiting." -ForegroundColor Red
    Read-Host "Press Enter to exit..."
    exit
}

$credentials = "token:$Token"
$encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($credentials))
$headers = @{ "Authorization" = "Basic $encodedCredentials" }

Write-Host "`nAuthenticating and fetching list of available countries..." -ForegroundColor Cyan
try {
    $privKeyResponse = Invoke-RestMethod -Uri "https://api.nordvpn.com/v1/users/services/credentials" -Headers $headers
    $privateKey = $privKeyResponse.nordlynx_private_key

    $countries = Invoke-RestMethod -Uri "https://api.nordvpn.com/v1/servers/countries"
    $countries = $countries | Sort-Object name
} catch {
    Write-Host "Failed to connect. Make sure your token is correct and active." -ForegroundColor Red
    Read-Host "Press Enter to exit..."
    exit
}

# ------------------------------------------------------------------------------
# Server Type Selection
# ------------------------------------------------------------------------------
$groups = @(
    @{ name = "Standard VPN"; id = "legacy_standard" }
    @{ name = "P2P"; id = "legacy_p2p" }
    @{ name = "Double VPN"; id = "legacy_double_vpn" }
    @{ name = "Onion Over VPN"; id = "legacy_onion_over_vpn" }
)

$selectedGroup = Get-TerminalSelection -Title "SELECT SERVER TYPE" -Items $groups

if ($null -eq $selectedGroup) {
    Write-Host "Exiting." -ForegroundColor Yellow
    exit
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
    exit
}

$countryId = $null
$cityId = $null

if ($selectedCountry -eq "BEST") {
    $locationName = "Best Global Location"
} else {
    $countryId = $selectedCountry.id
    $locationName = $selectedCountry.name

    # Show city menu only if the country has multiple cities
    if ($selectedCountry.cities.Count -gt 1) {
        $sortedCities = $selectedCountry.cities | Sort-Object name
        $selectedCity = Get-TerminalSelection -Title "SELECT A CITY IN $($selectedCountry.name)" -Items $sortedCities -QuickAccessNames @("Miami", "New York")

        if ($null -eq $selectedCity) {
            Write-Host "Exiting." -ForegroundColor Yellow
            exit
        }

        if ($selectedCity -eq "BEST") {
            $locationName = "Best Server in $($selectedCountry.name)"
        } else {
            $cityId = $selectedCity.id
            $locationName = "$($selectedCity.name), $($selectedCountry.name)"
        }
    } elseif ($selectedCountry.cities.Count -eq 1) {
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

    $serverResponse = Invoke-RestMethod -Uri $apiUrl

    if ($serverResponse.Count -eq 0) {
        Write-Host "No WireGuard servers found for $locationName." -ForegroundColor Red
        Read-Host "Press Enter to exit..."
        exit
    }

    # Extract server details
    $server = $serverResponse[0]
    $endpoint = $server.station
    $wgTech = $server.technologies | Where-Object { $_.identifier -eq "wireguard_udp" }
    $publicKey = ($wgTech.metadata | Where-Object { $_.name -eq "public_key" }).value

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
    Write-Host "Allowed IPs       : 0.0.0.0/0, ::0/0"
    Write-Host "================================================="

    # ------------------------------------------------------------------------------
    # Config File Generation (Optional)
    # ------------------------------------------------------------------------------
    Write-Host ""
    $generateFile = Read-Host "Would you like to generate a local .conf file for easy router import? (Y/N)"

    if ($generateFile -match "^(?i)y") {
        $cleanName = $server.hostname -replace '\.nordvpn\.com$', ''
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
AllowedIPs = 0.0.0.0/0, ::0/0
PersistentKeepalive = 25
"@

        # Save to the directory the script resides in, fallback to current directory
        $saveDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
        $filePath = Join-Path -Path $saveDir -ChildPath $fileName

        Set-Content -Path $filePath -Value $confContent -Encoding Ascii

        Write-Host "`n[SUCCESS] Generated WireGuard Config File!" -ForegroundColor Green
        Write-Host "-> File saved to: $filePath" -ForegroundColor Yellow
        Write-Host "-> You can now upload this directly to your Asus Router." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Failed to fetch server details." -ForegroundColor Red
}

# ------------------------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------------------------
Write-Host "`nAll done! You can copy the values above." -ForegroundColor Green
Read-Host "Press Enter to exit..."

# Scrub all sensitive variables from memory before the session ends
Remove-Variable -Name Token, credentials, encodedCredentials, headers, privKeyResponse, privateKey, confContent -ErrorAction SilentlyContinue
[System.GC]::Collect()
