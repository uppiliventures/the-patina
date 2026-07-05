// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// ─────────────────────────────────────────────────────────────────────
///  OXIDATION MATH — the clock inside the image.
///
///  This library is the whole mechanic. Everything else in The Patina
///  is plumbing around these functions. It is deliberately small enough
///  to read in one sitting, because that is a spec requirement.
///
///  DESIGN DECISIONS (locked, answering the adversarial pre-commitments):
///   1. uint256 + Solidity 0.8 checked math. Overflow impossible in any
///      human timescale; depth is capped regardless.
///   2. block.timestamp nudging by validators moves depth by ~seconds
///      against a day-granular mechanic. Accepted, documented, undefended.
///   3. Re-polish EXTENDS: the 30-day arrest always restarts from now.
///      No stacking. No banked protection.
///   4. Failed polish reverts atomically. No partial state.
///   5. Transfer carries everything. Patina and arrest window persist.
///      Transfer is not a polish. The crease travels with the card.
///   6. Depth saturates at MAX_DEPTH (10 years of neglect). Monotonic
///      to the cap, flat after. No wrap. No reset. Ever.
///   7. No function accepts a caller-supplied timestamp. Views read
///      block.timestamp themselves.
///
///  THE FAMILY BUG:
///   v1 of The Shallows shipped an underflow when touch happened in the
///   same block as mint (elapsed == 0). The guard here is explicit and
///   tested before the subtraction it protects. See pendingDepth().
/// ─────────────────────────────────────────────────────────────────────
library OxidationMath {
    /// One depth unit accrues per full day of UNPROTECTED time.
    uint256 internal constant DAY = 86400;

    /// A polish arrests oxidation for exactly this long.
    uint256 internal constant PROTECTION = 30 days;

    /// Depth saturates at ten years of unprotected neglect.
    /// 3650 is also a friendly number for the renderer to map.
    uint256 internal constant MAX_DEPTH = 3650;

    /// Per-token oxidation state. Two slots. That is all history needs.
    struct Surface {
        uint64 lastPolished;   // timestamp of most recent polish (or mint)
        uint32 settledDepth;   // patina crystallised into storage at each polish
        uint32 polishCount;    // legibility of devotion; no mechanical effect
    }

    /// ── PENDING DEPTH ────────────────────────────────────────────────
    /// Patina accrued since the last polish, computed live, never stored.
    /// This is the function with the clock inside it.
    ///
    /// Timeline since lastPolished:
    ///   [0 ................ 30 days] : arrested. pending = 0.
    ///   (30 days ........ forever]  : 1 unit per full day beyond arrest.
    ///
    /// THE GUARD: `elapsed <= PROTECTION` is checked BEFORE the
    /// subtraction `elapsed - PROTECTION`. Same-block polish gives
    /// elapsed == 0, returns 0, no underflow, no revert. The v1 bug
    /// dies here, in daylight, with a comment on its grave.
    function pendingDepth(uint64 lastPolished, uint256 nowTs)
        internal
        pure
        returns (uint256)
    {
        // Clock skew or same-block weirdness: never let "now" precede
        // the last polish. Clamp, don't revert. A view must not brick.
        if (nowTs <= lastPolished) return 0;

        uint256 elapsed = nowTs - lastPolished;

        // The guard. The family bug's grave.
        if (elapsed <= PROTECTION) return 0;

        return (elapsed - PROTECTION) / DAY;
    }

    /// ── TOTAL DEPTH ──────────────────────────────────────────────────
    /// What the renderer reads: history plus the living clock, capped.
    /// Monotonic between polishes. Saturates at MAX_DEPTH.
    function totalDepth(Surface memory s, uint256 nowTs)
        internal
        pure
        returns (uint256)
    {
        uint256 depth = uint256(s.settledDepth) + pendingDepth(s.lastPolished, nowTs);
        return depth > MAX_DEPTH ? MAX_DEPTH : depth;
    }

    /// ── POLISH ───────────────────────────────────────────────────────
    /// Crystallise the pending patina into storage, THEN restart the
    /// arrest window. Order matters: settle first, protect second.
    /// This is why patina never reverses — every polish writes the
    /// neglect that preceded it permanently into state before it
    /// grants any protection.
    function applyPolish(Surface storage s, uint256 nowTs) internal {
        uint256 pending = pendingDepth(s.lastPolished, nowTs);

        if (pending > 0) {
            uint256 settled = uint256(s.settledDepth) + pending;
            if (settled > MAX_DEPTH) settled = MAX_DEPTH;
            s.settledDepth = uint32(settled);
        }

        s.lastPolished = uint64(nowTs);
        s.polishCount += 1;
    }

    /// ── MINT ─────────────────────────────────────────────────────────
    /// A surface is born gleaming and protected. Its first 30 days are
    /// a grace window: mint counts as the zeroth polish.
    function initialize(Surface storage s, uint256 nowTs) internal {
        s.lastPolished = uint64(nowTs);
        s.settledDepth = 0;
        s.polishCount = 0;
    }
}
