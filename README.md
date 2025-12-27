# Sing-Box CI/CD (ref1nd Fork)

> Automated Build Pipeline for modern architectures.

## Architecture

This repository maintains a "Zero-Ops" pipeline to build [reF1nd/sing-box](https://github.com/reF1nd/sing-box).

### Build Matrix

We focus on modern production environments only. Legacy 32-bit and MIPS architectures are excluded.

| Platform    | Arch    | Micro-Arch       | Status |
| :---------- | :------ | :--------------- | :----- |
| **Android** | `arm64` | -                | ✅     |
| **Linux**   | `amd64` | `v1`, `v3`, `v4` | ✅     |
| **Linux**   | `arm64` | -                | ✅     |
| **Windows** | `amd64` | `v3`             | ✅     |
| **Windows** | `arm64` | -                | ✅     |
| **macOS**   | `amd64` | `v3`             | ✅     |
| **macOS**   | `arm64` | -                | ✅     |

### Features (Tags)

Builds include the following feature tags enabled:

- `with_gvisor`
- `with_quic`
- `with_dhcp`
- `with_wireguard`
- `with_utls`
- `with_clash_api`
- `with_tailscale`
- `with_acme`

## Automation

- **Schedule**: Daily check against upstream at 20:00 UTC.
- **Logic**: See `scripts/` directory for build logic.
