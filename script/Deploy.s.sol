// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
// import "../contracts/Patina.sol";

/// Deploy script. Run from the fresh wallet only.
/// That address has zero prior transactions. Its entire history is this artwork.
///
/// Testnet:  forge script script/Deploy.s.sol --rpc-url zora_sepolia --broadcast
/// Mainnet:  not until two weeks of open review have passed. No exceptions.
contract Deploy is Script {
    function run() external {
        // vm.startBroadcast();
        // new Patina(ARTIST_WALLET);
        // vm.stopBroadcast();
    }
}
