// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {Patina} from "../contracts/Patina.sol";
import {OxidationMath} from "../contracts/OxidationMath.sol";

/// ─────────────────────────────────────────────────────────────────────
///  THE PATINA — test suite.
///
///  Every trap staked in review is sprung here on purpose, so the only
///  bugs left for mainnet are the ones nobody imagined. House rules:
///   - The family bug (same-block polish underflow) gets its own test
///     and it runs first alphabetically, because respect.
///   - Precision-neglect is PINNED as a feature. If a future edit makes
///     30d23h polishing accrue depth, a named test breaks loudly.
///   - Kimi's mint-interleaving invariant is fuzzed, not just traced.
/// ─────────────────────────────────────────────────────────────────────

/// A wallet that refuses money. Exists to prove the documented
/// assumption: if the artist address can't receive ETH, mint bricks.
contract RejectsEth {
    receive() external payable { revert("no thank you"); }
}

contract PatinaTest is Test {
    Patina patina;
    address artist;
    address alice;
    address bob;

    uint256 constant PRICE = 0.015 ether;
    uint256 constant DAY = 86400;
    uint256 constant PROTECTION = 30 days;

    function setUp() public {
        artist = makeAddr("artist");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        patina = new Patina(artist);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }

    function _mintAs(address who) internal returns (uint256 id) {
        vm.prank(who);
        id = patina.mint{value: PRICE}();
    }

    // ═════════════════════════════════════════════════════════════════
    //  1. THE FAMILY BUG
    // ═════════════════════════════════════════════════════════════════

    /// v1 of The Shallows underflowed when touch happened in the same
    /// block as mint. This is the grave-dance: mint and polish at the
    /// exact same timestamp. Must not revert. Depth must be zero.
    function test_familyBug_sameBlockPolish_doesNotRevert() public {
        uint256 id = _mintAs(alice);
        vm.prank(alice);
        patina.polish(id); // same block, elapsed == 0
        assertEq(patina.depthOf(id), 0, "same-block polish must leave depth 0");
    }

    /// And the double grave-dance: polish twice in the same block.
    function test_familyBug_doubleSameBlockPolish() public {
        uint256 id = _mintAs(alice);
        vm.startPrank(alice);
        patina.polish(id);
        patina.polish(id);
        vm.stopPrank();
        assertEq(patina.depthOf(id), 0);
    }

    // ═════════════════════════════════════════════════════════════════
    //  2. OXIDATION BOUNDARIES (second-precision on the 30-day line)
    // ═════════════════════════════════════════════════════════════════

    function test_depthZeroAtMint() public {
        uint256 id = _mintAs(alice);
        assertEq(patina.depthOf(id), 0);
    }

    function test_depthZeroInsideProtection() public {
        uint256 id = _mintAs(alice);
        vm.warp(block.timestamp + PROTECTION - 1);
        assertEq(patina.depthOf(id), 0, "one second inside the window");
    }

    function test_depthZeroAtExactProtectionBoundary() public {
        uint256 id = _mintAs(alice);
        vm.warp(block.timestamp + PROTECTION);
        assertEq(patina.depthOf(id), 0, "exactly 30 days: still arrested (<= guard)");
    }

    function test_depthZeroOneSecondPastBoundary() public {
        uint256 id = _mintAs(alice);
        vm.warp(block.timestamp + PROTECTION + 1);
        assertEq(patina.depthOf(id), 0, "one second of neglect < one day: floors to 0");
    }

    function test_firstDepthUnitAtThirtyOneDays() public {
        uint256 id = _mintAs(alice);
        vm.warp(block.timestamp + PROTECTION + DAY);
        assertEq(patina.depthOf(id), 1, "first full unprotected day = first unit");
    }

    function test_depthSaturatesAtMax() public {
        uint256 id = _mintAs(alice);
        vm.warp(block.timestamp + PROTECTION + 20_000 * DAY); // ~54 years of neglect
        assertEq(patina.depthOf(id), 3650, "depth must saturate, never wrap");
    }

    // ═════════════════════════════════════════════════════════════════
    //  3. POLISH SEMANTICS (settle-then-protect, nothing reverses)
    // ═════════════════════════════════════════════════════════════════

    /// The most consequential ordering in the project: polish must
    /// crystallise pending depth BEFORE restarting the window. If the
    /// order ever swaps, this test fails because depth silently drops.
    function test_polishSettlesBeforeProtecting() public {
        uint256 id = _mintAs(alice);
        vm.warp(block.timestamp + PROTECTION + 10 * DAY); // 10 units pending
        assertEq(patina.depthOf(id), 10);

        vm.prank(alice);
        patina.polish(id);

        assertEq(patina.depthOf(id), 10, "polish must not erase history");
        (, uint32 settled,,, bool arrested) = patina.surfaceOf(id);
        assertEq(settled, 10, "pending must crystallise into storage");
        assertTrue(arrested, "and the window must restart");
    }

    function test_patinaNeverReverses_acrossManyPolishes() public {
        uint256 id = _mintAs(alice);
        uint256 lastDepth = 0;
        for (uint256 i = 0; i < 12; i++) {
            vm.warp(block.timestamp + PROTECTION + (i % 4) * DAY);
            vm.prank(alice);
            patina.polish(id);
            uint256 d = patina.depthOf(id);
            assertGe(d, lastDepth, "depth must be monotonic across polishes");
            lastDepth = d;
        }
    }

    /// Re-polish inside the window EXTENDS, never stacks.
    function test_repolishExtendsWindow() public {
        uint256 id = _mintAs(alice);
        vm.warp(block.timestamp + 15 days);
        vm.prank(alice);
        patina.polish(id); // window restarts from here

        // 29 days later: still arrested (would NOT be, if windows stacked
        // weirdly or if the original mint-window governed).
        vm.warp(block.timestamp + 29 days);
        (,,,, bool arrested) = patina.surfaceOf(id);
        assertTrue(arrested);

        // 31 days after the re-polish: window lapsed.
        vm.warp(block.timestamp + 2 days);
        (,,,, bool arrestedNow) = patina.surfaceOf(id);
        assertFalse(arrestedNow);
    }

    // ═════════════════════════════════════════════════════════════════
    //  4. PRECISION-NEGLECT (pinned feature — adversarial review)
    // ═════════════════════════════════════════════════════════════════

    /// The stopwatch owner: polishes every 30 days and 23 hours,
    /// forever, and accrues nothing. This is a PLAY STYLE. If this
    /// test ever fails, someone changed the day-granularity mechanic
    /// and must answer for it in public.
    function test_precisionNeglect_isAFeature() public {
        uint256 id = _mintAs(alice);
        for (uint256 i = 0; i < 100; i++) {
            vm.warp(block.timestamp + PROTECTION + 23 hours);
            vm.prank(alice);
            patina.polish(id);
        }
        assertEq(patina.depthOf(id), 0, "devotion-by-stopwatch accrues nothing, by design");
    }

    // ═════════════════════════════════════════════════════════════════
    //  5. TRANSFER (the crease travels with the card)
    // ═════════════════════════════════════════════════════════════════

    function test_transferCarriesPatinaAndWindow() public {
        uint256 id = _mintAs(alice);
        vm.warp(block.timestamp + PROTECTION + 50 * DAY);
        uint256 before = patina.depthOf(id);

        vm.prank(alice);
        patina.transferFrom(alice, bob, id);

        assertEq(patina.depthOf(id), before, "transfer must not touch oxidation state");
        (,,uint32 count,,) = patina.surfaceOf(id);
        assertEq(count, 0, "transfer is not a polish");
    }

    // ═════════════════════════════════════════════════════════════════
    //  6. ACCESS (no admin keys; owner-only polish)
    // ═════════════════════════════════════════════════════════════════

    function test_polishByNonOwnerReverts() public {
        uint256 id = _mintAs(alice);
        vm.prank(bob);
        vm.expectRevert(Patina.NotYourSurface.selector);
        patina.polish(id);
    }

    function test_curatedMintByNonArtistReverts() public {
        vm.prank(alice);
        vm.expectRevert(Patina.OnlyArtist.selector);
        patina.curatedMint(alice);
    }

    function test_curatedReserveExhausts() public {
        vm.startPrank(artist);
        for (uint256 i = 0; i < 100; i++) patina.curatedMint(alice);
        vm.expectRevert(Patina.ReserveExhausted.selector);
        patina.curatedMint(alice);
        vm.stopPrank();
    }

    // ═════════════════════════════════════════════════════════════════
    //  7. MONEY (push-payment: the contract never holds a balance)
    // ═════════════════════════════════════════════════════════════════

    function test_mintForwardsPaymentImmediately() public {
        uint256 artistBefore = artist.balance;
        _mintAs(alice);
        assertEq(artist.balance, artistBefore + PRICE, "payment must land in artist wallet");
        assertEq(address(patina).balance, 0, "contract balance must be zero, always");
    }

    function test_wrongPaymentReverts() public {
        vm.prank(alice);
        vm.expectRevert(Patina.WrongPayment.selector);
        patina.mint{value: PRICE - 1}();

        vm.prank(alice);
        vm.expectRevert(Patina.WrongPayment.selector);
        patina.mint{value: PRICE + 1}();
    }

    /// The documented assumption, proven rather than assumed: an artist
    /// address that rejects ETH bricks the public mint. Fresh-EOA spec
    /// exists precisely because of this test.
    function test_documentedAssumption_rejectingArtistBricksMint() public {
        Patina broken = new Patina(address(new RejectsEth()));
        vm.prank(alice);
        vm.expectRevert(Patina.PaymentFailed.selector);
        broken.mint{value: PRICE}();
    }

    // ═════════════════════════════════════════════════════════════════
    //  8. SUPPLY (Kimi's interleaving invariant, traced AND fuzzed)
    // ═════════════════════════════════════════════════════════════════

    function test_publicSupplyCapsAt899() public {
        for (uint256 i = 0; i < 899; i++) _mintAs(alice);
        vm.prank(alice);
        vm.expectRevert(Patina.SoldOut.selector);
        patina.mint{value: PRICE}();
        // and the curated reserve must still be fully intact:
        vm.prank(artist);
        patina.curatedMint(bob); // must succeed
    }

    /// Random interleavings of public and curated mints. At every step:
    /// public <= 899, curated <= 100, total <= 999. The three bounds
    /// hold regardless of order. (Adversarial review, executable form.)
    function testFuzz_mintInterleaving(uint256 seed) public {
        uint256 publicCount;
        uint256 curatedCount;
        for (uint256 i = 0; i < 150; i++) {
            bool goCurated = (uint256(keccak256(abi.encode(seed, i))) % 5) == 0;
            if (goCurated && curatedCount < 100) {
                vm.prank(artist);
                patina.curatedMint(bob);
                curatedCount++;
            } else if (publicCount < 899) {
                _mintAs(alice);
                publicCount++;
            }
            assertLe(patina.totalMinted() - patina.curatedMinted(), 899);
            assertLe(patina.curatedMinted(), 100);
            assertLe(patina.totalMinted(), 999);
        }
    }

    // ═════════════════════════════════════════════════════════════════
    //  9. MONOTONICITY FUZZ (depth never decreases, no op reverts)
    // ═════════════════════════════════════════════════════════════════

    function testFuzz_depthMonotonicUnderRandomTime(uint256 seed) public {
        uint256 id = _mintAs(alice);
        uint256 lastDepth = 0;
        for (uint256 i = 0; i < 30; i++) {
            uint256 h = uint256(keccak256(abi.encode(seed, i)));
            vm.warp(block.timestamp + (h % (90 * DAY)) + 1);
            if (h % 3 == 0) {
                vm.prank(alice);
                patina.polish(id);
            }
            uint256 d = patina.depthOf(id);
            assertGe(d, lastDepth, "depth must never decrease, under any sequence");
            assertLe(d, 3650, "and never exceed saturation");
            lastDepth = d;
        }
    }

    // ═════════════════════════════════════════════════════════════════
    //  10. RENDER (the image exists, at both ends of its life)
    // ═════════════════════════════════════════════════════════════════

    function test_tokenURI_rendersGleamingAndSaturated() public {
        uint256 id = _mintAs(alice);
        string memory freshUri = patina.tokenURI(id);
        assertGt(bytes(freshUri).length, 100, "gleaming surface must render");

        vm.warp(block.timestamp + PROTECTION + 4000 * DAY);
        string memory rustedUri = patina.tokenURI(id);
        assertGt(bytes(rustedUri).length, 100, "saturated surface must render");
        assertTrue(
            keccak256(bytes(freshUri)) != keccak256(bytes(rustedUri)),
            "the image must age: fresh and rusted cannot be identical"
        );
    }

    function test_renderIsDeterministic() public {
        uint256 id = _mintAs(alice);
        vm.warp(block.timestamp + PROTECTION + 100 * DAY);
        string memory a = patina.tokenURI(id);
        string memory b = patina.tokenURI(id);
        assertEq(a, b, "same state, same block: identical image");
    }

    function test_seedsDifferPerToken() public {
        uint256 a = _mintAs(alice);
        uint256 b = _mintAs(alice);
        assertTrue(patina.seedOf(a) != patina.seedOf(b), "every surface rusts its own way");
    }
}
