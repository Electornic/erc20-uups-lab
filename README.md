# erc20-uups-lab

A learning project for upgradeable ERC20 tokens using the **UUPS proxy pattern**, built with Foundry and OpenZeppelin. Walks through the full lifecycle: deploy V1, upgrade to V2 in place, add governance and access-control features without losing state.

[![Solidity](https://img.shields.io/badge/Solidity-0.8.24-363636?logo=solidity&logoColor=white)](https://soliditylang.org)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C?logo=foundryvirtualtabletop&logoColor=black)](https://getfoundry.sh)
[![OpenZeppelin](https://img.shields.io/badge/OpenZeppelin-5.6.1-4E5EE4?logo=openzeppelin&logoColor=white)](https://docs.openzeppelin.com/contracts/5.x/)
[![Pattern](https://img.shields.io/badge/Pattern-UUPS-blueviolet)](https://eips.ethereum.org/EIPS/eip-1822)
[![Network](https://img.shields.io/badge/Network-Sepolia-CE412B)](https://sepolia.etherscan.io)
[![Tests](https://img.shields.io/badge/tests-26%2F26%20passing-brightgreen)](#testing)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

---

## What's inside

| Version | Features |
|---|---|
| **V1** | ERC20 + Permit (EIP-2612) + Ownable + UUPS + owner-only mint |
| **V2** | V1 + Burnable + Pausable + Votes (EIP-5805) + AccessControl + 21M supply cap |

V2 was deployed by **upgrading the V1 proxy in place** — same contract address, new logic, all balances preserved.

## Live deployment (Sepolia)

| Contract | Address |
|---|---|
| **Proxy** (use this) | [`0x7923abd8112036b2786A65844c70251aC8f4DFa5`](https://sepolia.etherscan.io/address/0x7923abd8112036b2786A65844c70251aC8f4DFa5) |
| V1 Implementation | [`0xb145eF2d47f8262af95E033D5C2Bfd8356829970`](https://sepolia.etherscan.io/address/0xb145eF2d47f8262af95E033D5C2Bfd8356829970) |
| V2 Implementation (current) | [`0xa64d4078c21132Aea1c7e678B336B9a4e30367f7`](https://sepolia.etherscan.io/address/0xa64d4078c21132Aea1c7e678B336B9a4e30367f7) |

Token: **Lab Token (LAB)**, 18 decimals, max supply 21,000,000.

## Project layout

```
src/
  LabTokenV1.sol          ERC20 + Permit + Ownable + UUPS + Mintable
  LabTokenV2.sol          + Burnable + Pausable + Votes + AccessControl + cap
test/
  LabTokenV1.t.sol        7 tests for V1
  Upgrade.t.sol           19 tests for V1 -> V2 upgrade and V2 features
script/
  Deploy.s.sol            Initial UUPS proxy deployment
  Upgrade.s.sol           In-place upgrade V1 -> V2
foundry.toml              Solc 0.8.24, optimizer 200, ffi enabled, remappings
.env.example              Required env vars (RPC, PK, Etherscan)
```

## Architecture

### UUPS proxy pattern

```
                    ┌──────────────────┐
   user ─── tx ───► │   ERC1967Proxy   │ ◄── stores all state
                    │   (0x7923abd8…)  │     (balances, roles, votes)
                    └────────┬─────────┘
                             │ delegatecall
                             ▼
                    ┌──────────────────┐
                    │ LabTokenV2 impl  │ ◄── logic only, no state
                    │   (0xa64d40…)    │
                    └──────────────────┘
```

Upgrades replace the implementation address inside the proxy. The proxy address never changes, so users, balances, and integrations stay intact.

### Two upgrade gotchas worth noting

**Storage compatibility.** V2 keeps `OwnableUpgradeable` in its inheritance chain even though new logic uses `AccessControl`. Removing it would orphan the `erc7201:openzeppelin.storage.Ownable` namespace and the OZ Upgrades plugin blocks the upgrade.

**Votes bootstrap.** V1 didn't track `ERC20Votes` checkpoints. After upgrade, burning would have underflowed `_totalCheckpoints`. `initializeV2` calls `_transferVotingUnits(address(0), address(0xdEaD), totalSupply())` once to seed the checkpoint with V1's existing supply.

## Access roles (V2)

| Role | Can do |
|---|---|
| `DEFAULT_ADMIN_ROLE` | Grant / revoke any role |
| `MINTER_ROLE` | Call `mint()` (subject to 21M cap) |
| `PAUSER_ROLE` | Call `pause()` / `unpause()` |
| `UPGRADER_ROLE` | Authorize the next implementation upgrade |

All four were granted to the deployer at upgrade time. They can be redistributed to a multisig or timelock via `grantRole` / `revokeRole`.

## Quick start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js 20+ (the OZ Foundry Upgrades plugin runs safety checks via `npx`)
- A funded Sepolia test wallet
- Etherscan API key (optional, for source verification)

### Install

```bash
git clone <this-repo>
cd erc20-uups-lab
forge install                # pulls submodules
cp .env.example .env         # then fill in values
```

### Build & test

```bash
forge clean && forge build
forge test
```

The OZ Upgrades plugin requires a full compilation, so `forge clean` is needed before the first `forge test` of a session.

### Deploy V1 to Sepolia

```bash
source .env
forge script script/Deploy.s.sol:Deploy \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify
```

### Upgrade to V2

```bash
source .env
PROXY_ADDRESS=0xYourProxyAddress \
forge script script/Upgrade.s.sol:Upgrade \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify
```

## Testing

26 tests cover the full surface:

| Suite | What it checks |
|---|---|
| `LabTokenV1.t.sol` | Metadata, initial mint, owner-only mint, transfer, upgrade auth, impl lock |
| `Upgrade.t.sol` — state preservation | totalSupply / balances / metadata persist across upgrade |
| `Upgrade.t.sol` — AccessControl | Role-gated mint, role granting, non-minter rejected |
| `Upgrade.t.sol` — Cap | Mint up to 21M succeeds, exceeding reverts |
| `Upgrade.t.sol` — Burnable | `burn` and `burnFrom` after approve |
| `Upgrade.t.sol` — Pausable | Pause blocks transfer / mint, unpause restores, role-gated |
| `Upgrade.t.sol` — Votes | Zero votes pre-delegate, self-delegate, delegate to other, transfer moves votes |
| `Upgrade.t.sol` — Upgrade auth | Non-upgrader rejected, reinitialize prevented |

```bash
forge test -vv
```

## Stack notes

- **OpenZeppelin Contracts 5.6.1** — uses ERC-7201 namespaced storage, no `__gap` arrays needed
- **OZ Foundry Upgrades 0.4.0** — runs `@openzeppelin/upgrades-core` via `npx` to validate storage-layout compatibility before upgrades; requires `ffi = true` in `foundry.toml`
- **Solidity 0.8.24** — Cancun EVM target

## License

MIT
