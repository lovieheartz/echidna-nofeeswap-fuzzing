// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

contract FoundryTest is Test {
    address constant USER1 = address(0x10000);

    // TODO: Replace with your actual contract instance
    PriceTestSimple Target;

  function setUp() public {
      // TODO: Initialize your contract here
      Target = new PriceTestSimple();
  }

  function test_replay() public {
        _setUpActor(USER1);
        Target.test_storePrice_with_height(12169234928638245609, 15313876002, 0, 105542517096618251161171651396631026605784647284159929786491751871);
  }

  function _setUpActor(address actor) internal {
      vm.startPrank(actor);
      // Add any additional actor setup here if needed
  }

  function _delay(uint256 timeInSeconds, uint256 numBlocks) internal {
      vm.warp(block.timestamp + timeInSeconds);
      vm.roll(block.number + numBlocks);
  }
}
