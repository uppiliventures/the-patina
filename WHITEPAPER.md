# THE PATINA

**A Ciridium Labs experiment. 999 objects. Rust never reverses.**

---

## What this is

The Patina is a collection of 999 procedural metal surfaces that live entirely on-chain. There is no image file. No IPFS. No server. Each object is rendered at read time by the contract itself, computed from three inputs: its seed, the current block timestamp, and the last time its owner polished it.

The surfaces oxidise continuously. A polish, one small transaction, arrests oxidation for 30 days. It never removes existing patina. Rust is history, and history does not undo. Every object is a permanent, visible record of its whole life: the gleaming years and the neglected years, in layers.

Kill every website on earth. The Patina still renders, still oxidising, from the contract.

## The technical question

*Can an image age on-chain without anyone paying for it to change?*

Storage is static and mutation costs gas, so the question sounds absurd. But the image was never a file. It is a pure function with a clock inside it, evaluated free at read time, forever. If the artwork changes every block and nobody renders it, did it change? Owners will argue about this. That argument is part of the work.

## What ownership means here

Digital ownership stripped out the one thing that made physical ownership feel real: time leaving marks. A hockey card creased. It faded. It got thumbed at recess. The Patina gives digital objects that crease back. Your surface silently tells the truth about your attention. Some owners will polish daily and hold a gleaming plate. Some will never touch theirs and cultivate deep, deliberate rust. Both are legitimate. Neither can be faked, bought back, or reset.

## What this is not

- No roadmap. No Discord. No utility promises.
- No admin keys. No owner functions. No upgrades. The contract is immutable from block one.
- No reclaim mechanics. Neglect cannot be purchased away.
- No manufactured rarity. Whatever accidents survive review become the founding record, as is tradition.

## Specification

| | |
|---|---|
| Supply | 999 total. 100 hand-placed with collectors and writers, 899 at flat mint. |
| Price | 0.015 ETH flat. No auction, no tiers. |
| Chain | Zora (EVM). Rendering is a contract view function. |
| Base | OpenZeppelin ERC721. Novel surface is ~150 lines: oxidation math and SVG renderer. |
| Funds | The contract holds no balance. Mint payments forward directly at mint time. |
| Royalties | 5% secondary. Nothing else, ever. |
| Deployer | A fresh address with zero prior transactions. Its entire history is this artwork. |

## Honesty about risk

v1 ships without a paid audit. Instead: OpenZeppelin foundations, static analysis, and a minimum of two weeks on public testnet with the code open and a standing invitation to break it. Audited by everyone, paid by no one. This is not as safe as a commissioned audit and we say so plainly. It is proportionate to a small immutable contract that holds no funds. A retroactive professional audit will be commissioned from mint proceeds and published to holders at day 90.

## The daily report

Each day, one short oxidation report is written by the artist in flat prose: notable oxidations, polish streaks, surfaces crossing thresholds. No hype, no emojis, no calls to action. The report is part of the artwork and cannot be delegated.

## Success

Not mint count. At day 90, we measure deliberate holding: the share of supply showing an intentional pattern, either an unbroken polish streak or a verifiably untouched surface in an otherwise active wallet. Target: 40%. A v2 exists only as opt-in migration and only if the numbers earn it.

---

*The Patina. Legal owner: Unrealised Ltd. Imprint: Ciridium Labs.*
*Polish arrests. Nothing reverses.*
