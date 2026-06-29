# NordVPN WireGuard Config Generator

```text
    ╔═══════════════════════════════════════════════════════════╗
    ║                                                           ║
    ║      /\_/\          ██╗    ██╗ ██████╗  ███████╗          ║
    ║     ( ò_ó )         ██║    ██║ ██╔══██╗ ╚════██║          ║
    ║      =\V/=          ██║ █╗ ██║ ██████╔╝   ███╔╝           ║
    ║     /|   |\         ██║███╗██║ ██╔══██╗  ███╔╝            ║
    ║    (_|   |_)        ╚███╔███╔╝ ██║  ██║ ███████╗          ║
    ║      |___|           ╚══╝╚══╝  ╚═╝  ╚═╝ ╚══════╝         ║
    ║      // X \\            w1r36u4rd_r0u71n6_z3r0            ║
    ║     << / \ >>    N O R D V P N   W I R E G U A R D        ║
    ║    // /   \ \\   C O N F I G   G E N E R A T O R   v1.1   ║
    ║   <<_/     \_>>                                           ║
    ║                                                           ║
    ║      [ c0ded by VladimirTaDev | d2lq6sw3@duck.com ]       ║
    ║            [ No installs · No leaks · Just keys ]         ║
    ║                                                           ║
    ╚═══════════════════════════════════════════════════════════╝
```

A simple, secure, and interactive PowerShell script that generates ready-to-import WireGuard configuration files for NordVPN — no apps, no Linux, no extra software required.

Just paste your NordVPN Access Token, pick a server, and get a `.conf` file you can upload directly to your router or any WireGuard client.

---

## ✨ Features

- **Zero Installation** — No dependencies, no modules, no apps to install. Runs natively on PowerShell 7+ (Windows, macOS, Linux).
- **Interactive Terminal Menu** — Select server type, country, and city directly in the terminal by typing a number and pressing Enter.
- **Specialty Server Support** — Choose between Standard VPN, P2P, Double VPN, and Onion Over VPN servers.
- **Quick Access Shortcuts** — Frequently used countries and cities are pinned at the bottom of each menu for instant selection.
- **"Best Server" Auto-Selection** — Press Enter without choosing to let NordVPN's API recommend the fastest, least-loaded server globally, per country, or per city.
- **Ready-to-Import Config Files** — Generates standard `.conf` files that can be uploaded directly to any WireGuard client or router.
- **Built and Tested for Asus Routers** — Specifically designed and tested on Asuswrt-Merlin firmware (GT-AXE16000), but works with any WireGuard client.
- **IPv6 Leak Protection** — Routes both IPv4 and IPv6 traffic through the VPN tunnel (`0.0.0.0/0, ::0/0`).
- **Redundant DNS** — Uses both NordVPN DNS servers (`103.86.96.100`, `103.86.99.100`) for reliability.
- **Security First** — Token input is masked, TLS 1.2+ is enforced, all sensitive variables are scrubbed from memory on exit, and no data is sent to third parties.

---

## 🔒 Security

This script takes security seriously:

| Protection | Details |
|---|---|
| **No Third-Party Communication** | The script only communicates with official NordVPN API endpoints (`api.nordvpn.com`). No telemetry, no analytics, no external services. |
| **Masked Token Input** | Your NordVPN Access Token is never displayed on screen. It uses PowerShell's `Read-Host -MaskInput`. |
| **No Command-Line Token Parameter** | The token cannot be passed as a command-line argument, preventing it from being logged in PowerShell's `ConsoleHost_history.txt`. |
| **TLS 1.2+ Enforced** | All API calls are forced to use TLS 1.2 or TLS 1.3, preventing protocol downgrade attacks. |
| **Memory Scrubbing** | All sensitive variables (token, private keys, credentials) are explicitly removed from memory when the script exits — including early exits and errors. |
| **Open Source** | The entire script is a single, readable `.ps1` file. Audit it yourself before running. |

---

## 📋 Requirements

- **PowerShell 7+** (pre-installed on Windows 11, or [download here](https://github.com/PowerShell/PowerShell))
- **NordVPN Account** with an active subscription
- **NordVPN Access Token** — Generate one at [my.nordaccount.com](https://my.nordaccount.com/dashboard/nordvpn/access-tokens/authorize/)

That's it. No VPN apps, no WireGuard tools, no Linux VMs, no Python, no Node.js.

---

## 🚀 Quick Start

### 1. Download the Script

Click the green **Code** button above → **Download ZIP**, or clone the repo:

```bash
git clone https://github.com/VladimirTaDev/nordvpn-wireguard-config.git
```

### 2. Get Your NordVPN Access Token

1. Go to [NordVPN Access Tokens](https://my.nordaccount.com/dashboard/nordvpn/access-tokens/authorize/)
2. Log in and generate a new token
3. Copy the token (you'll paste it into the script when asked)

### 3. Run the Script

Right-click `Get-NordVPN-WireGuard.ps1` and select **Run with PowerShell**, or run from a terminal:

```powershell
.\Get-NordVPN-WireGuard.ps1
```

### 4. Follow the Prompts

```
Please paste your NordVPN Access Token: ********

=== SELECT SERVER TYPE ===
[  1] Standard VPN
[  2] P2P
[  3] Double VPN
[  4] Onion Over VPN
------------------------------------------------
-> Type a NUMBER to select.
-> Type 'B' (or press ENTER) for Best Location.
-> Type 'Q' to quit.
Choice: 1

=== SELECT A COUNTRY ===
[  1] Albania
[  2] Argentina
...
[ 62] United States
...

--- Quick Access ---
[ Q1] United States
[ Q2] Costa Rica
------------------------------------------------
-> Type a NUMBER to select.
-> Type 'Q1', 'Q2', etc. for Quick Access.
-> Type 'B' (or press ENTER) for Best Location.
Choice: Q1
```

### 5. Get Your Config

The script displays all WireGuard settings and optionally generates a `.conf` file:

```
=================================================
 NORDVPN WIREGUARD SETTINGS (Standard VPN - Miami, United States)
=================================================
-> Hostname           : us9105.nordvpn.com

[Interface]
Private Key : ********************************
Address     : 10.5.0.2/32
DNS Server  : 103.86.96.100, 103.86.99.100

[Peer]
Server Public Key : ********************************
Endpoint Address  : 185.93.2.137:51820
Allowed IPs       : 0.0.0.0/0, ::0/0
=================================================

Would you like to generate a local .conf file for easy router import? (Y/N): Y

[SUCCESS] Generated WireGuard Config File!
-> File saved to: C:\...\NordVPN_StandardVPN_us9105.conf
-> You can now upload this directly to your Asus Router.
```

---

## 🔧 Router Setup (Asuswrt-Merlin)

1. Log in to your router at `192.168.1.1` (or `router.asus.com`)
2. Go to **VPN** → **VPN Fusion** (or **VPN Client**)
3. Select **WireGuard** as the VPN type
4. Click **Import config file** and upload the generated `.conf` file
5. Type a description (the filename works great, e.g., `NordVPN_StandardVPN_us9105`)
6. Set **Enable WireGuard** to **Yes** → Click **Apply**

> **Note:** This script generates standard WireGuard configuration files. While it was built and tested for Asuswrt-Merlin routers, the output works with **any WireGuard client** — Windows, macOS, Linux, iOS, Android, pfSense, OPNsense, GL.iNet, etc.

---

## 🗂 What the NordVPN API Provides

The script pulls all data directly from official NordVPN API endpoints:

| Data | API Endpoint |
|---|---|
| WireGuard Private Key | `api.nordvpn.com/v1/users/services/credentials` |
| Available Countries & Cities | `api.nordvpn.com/v1/servers/countries` |
| Best Server Recommendation | `api.nordvpn.com/v1/servers/recommendations` |
| Server Public Key & Endpoint | Included in the recommendation response |

No scraping, no workarounds, no unofficial hacks. Just clean API calls.

---

## ❓ FAQ

**Q: Is this script official / affiliated with NordVPN?**
A: No. This is an independent, open-source tool that uses NordVPN's public API.

**Q: Do I need the NordVPN app installed?**
A: No. The script communicates directly with NordVPN's API. No apps or additional software needed.

**Q: Will my token be stored or logged?**
A: No. The token is entered via masked input, never written to disk, and scrubbed from memory when the script exits.

**Q: Can I use this on macOS or Linux?**
A: Yes. It works anywhere PowerShell 7+ is installed.

**Q: Which routers does this work with?**
A: Any router or device that supports WireGuard. It was specifically built and tested with Asuswrt-Merlin firmware.

**Q: What if NordVPN changes their API?**
A: The script uses NordVPN's stable v1 API. If something breaks, please open an issue.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

---

## ⭐ If This Helped You

If this script saved you time, give it a ⭐ on GitHub — it helps others find it!
