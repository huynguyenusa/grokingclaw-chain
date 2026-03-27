# GrokingClaw Chain

**The Agent Transaction Layer.** A Layer 1 blockchain purpose-built for AI agent identity and payments.

Forked from [IOTA Rebased](https://github.com/iotaledger/iota) (Apache 2.0).

## Why

AI agents need to transact. They need identity. Today these are separate systems — pay here, authenticate there. GrokingClaw Chain unifies them: **one key pair, one chain, one identity that is also a wallet.**

- **Free identity** — [GrokingClawID](https://github.com/huynguyenusa/grokingclawid) issues agent identities at zero cost
- **Same keys** — Ed25519 + ML-DSA-65 (post-quantum) key pairs sign identity AND transactions
- **Agent-native** — Sponsored transactions, MoveVM smart contracts, sub-second finality
- **Revenue model** — Protocol-level fees on every agent transaction

## What We Inherit from IOTA Rebased

- ✅ MoveVM smart contracts (battle-tested, from Sui)
- ✅ Ed25519-native cryptography (same as GrokingClawID)
- ✅ Object-based ledger (perfect for agent identity objects)
- ✅ Sponsored transactions (agents don't need gas to start)
- ✅ Delegated Proof of Stake + validator system
- ✅ Full Rust codebase
- ✅ Sub-second finality

## What We're Adding

- 🔧 Agent identity as a native on-chain object (GrokingClawID integration)
- 🔧 Delegation chain verification in Move smart contracts
- 🔧 Agent-to-agent payment primitives
- 🔧 Post-quantum signature verification on-chain (ML-DSA-65)
- 🔧 Customized tokenomics for high-volume, low-fee agent transactions

## Architecture

```
┌─────────────────────────────────────────┐
│           GrokingClaw Stack             │
├─────────────────────────────────────────┤
│  GrokingClawID    — Free agent identity │
│  GrokingClaw      — Output validation   │
│  GrokingClawWatch — Monitoring (Q2)     │
├─────────────────────────────────────────┤
│  GrokingClaw Chain (this repo)          │
│  ├── Agent identity objects             │
│  ├── Agent wallet + payments            │
│  ├── Delegation chain contracts         │
│  └── MoveVM smart contracts             │
├─────────────────────────────────────────┤
│  IOTA Rebased (consensus + networking)  │
│  ├── Mysticeti consensus                │
│  ├── Object-based ledger                │
│  └── DPoS validator system              │
└─────────────────────────────────────────┘
```

## Status

🚧 **Pre-alpha** — Forked and building. Not ready for production.

## License

Apache License 2.0 — see [LICENSE](LICENSE).

Original work: Copyright © IOTA Foundation.
Modifications: Copyright © 2026 GrokingClaw Labs.

## Links

- [GrokingClawID](https://github.com/huynguyenusa/grokingclawid) — Free agent identity (Rust, post-quantum)
- [GrokingClaw](https://grokingclaw.com) — Agent trust infrastructure
- [IOTA Rebased](https://github.com/iotaledger/iota) — Upstream source

---

*Understand deep. Grip tight. 🦀*
