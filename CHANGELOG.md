# Changelog

## v1.1 — 2026-06-29

### 🔴 Critical Fix
- **PowerShell 5.1 Compatibility**: Script now works on both Windows PowerShell 5.1 and PowerShell 7+. TLS 1.3 is applied as best-effort (no crash on older .NET). Token input gracefully falls back from `-MaskInput` (PS 7.1+) to `-AsSecureString` (PS 5.1).

### 🟠 Security Improvements
- **API Response Validation**: Private key, public key, and endpoint are now validated before use. Missing fields produce a clear error message instead of generating a silently broken config.
- **File Permission Hardening**: Generated `.conf` files are now restricted to the current user only (inherited ACLs are stripped on Windows).
- **Private Key Warning**: Users are warned to clear their terminal after the private key is displayed on screen.
- **Reliable Cleanup**: Replaced unreliable `trap` block with a centralized `Invoke-Cleanup` function called at every exit point, ensuring sensitive variables are always scrubbed.

### 🟡 Correctness & Robustness
- **Separated Error Handling**: File write errors now report "Failed to write config file" instead of the misleading "Failed to fetch server details."
- **PS 5.1 Null Safety**: `.Count` calls are now wrapped with null-checks to prevent unexpected behavior on PowerShell 5.1.
- **Filename Sanitization**: Hostnames from the API are now stripped of invalid filename characters before building the output path.
- **No Silent Overwrites**: If a `.conf` file with the same name already exists, a timestamp suffix is appended instead of silently overwriting.

### 🔵 UX Improvements
- **Consistent Terminal/File Output**: `PersistentKeepalive = 25` is now shown in the terminal display to match the generated `.conf` file.
- **Accurate Menu Prompts**: The server type menu now shows "Type 'B' (or press ENTER) for Standard VPN" instead of the misleading "Best Location."
- **Better Quick Access Matching**: Quick Access uses exact name matching instead of regex, preventing accidental partial matches. Invalid Quick Access selections (e.g., Q5 when only Q1–Q2 exist) now show a specific error message.

### ⚪ Minor
- **Request Timeouts**: All API calls now include `-TimeoutSec 30` to prevent the script from hanging indefinitely on a dead endpoint.
- **Improved Error Messages**: Network/API catch blocks now include `$_.Exception.Message` for easier debugging.

---

## v1.0 — 2026-06-26

- Initial release.
- Interactive terminal menu with Quick Access locations.
- NordVPN API authentication and WireGuard key retrieval.
- Server type selection (Standard, P2P, Double VPN, Onion Over VPN).
- Country and city selection with automatic best-server recommendation.
- `.conf` file generation for direct router import.
- TLS 1.2+ enforcement and token masking.
- IPv6 leak prevention via `AllowedIPs = 0.0.0.0/0, ::0/0`.
- Redundant NordVPN DNS servers (103.86.96.100, 103.86.99.100).
