// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
// import "../contracts/Patina.sol";

/// THE PATINA - test suite skeleton
///
/// House rule: the underflow class is the family bug. Every test that
/// touches time arithmetic gets written BEFORE the function it tests.
///
/// Tests to implement, in order:
///
/// 1. ORIGIN
///    - mint sets lastPolished == mintedAt == block.timestamp
///    - supply cap at 999 holds, mint 1000 reverts
///    - payment forwards to artist wallet inside mint, contract balance stays 0
///
/// 2. OXIDATION MATH (the dangerous file)
///    - oxidation at t=0 is 0
///    - oxidation is monotonic: never decreases as time advances
///    - polish in the SAME BLOCK as mint (the v1 Shallows bug, elapsed == 0)
///    - polish arrests exactly 30 days, second-boundary check at 30d-1s and 30d+1s
///    - polish never reduces existing patina depth
///    - fuzz: random timestamps, assert no underflow, no overflow, monotonicity
///
/// 3. RENDER
///    - tokenURI returns valid base64 SVG for token 0, 500, 998
///    - render is a view call: identical input state gives identical output
///    - render gas stays under RPC limits at maximum patina depth
///
/// 4. IMMUTABILITY
///    - no owner(), no admin functions exist (check ABI surface)
///    - polish by non-owner reverts
///
contract PatinaTest is Test {
    function setUp() public {
        // deploy here once Patina.sol exists
    }

    function test_placeholder() public pure {
        assertTrue(true);
    }
}
