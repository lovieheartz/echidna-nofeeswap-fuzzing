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
        Target.test_storePrice_basic(0, 105464670460996261499136337619533038111319136960991783822031453961, 2012923249615);
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
