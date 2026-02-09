// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

contract FoundryTest is Test {
    address constant USER1 = address(0x10000);

    // TODO: Replace with your actual contract instance
    PriceTestIndustryGrade Target;

  function setUp() public {
      // TODO: Initialize your contract here
      Target = new PriceTestIndustryGrade();
  }

  function test_replay() public {
        _setUpActor(USER1);
        Target.test_property_store_retrieve_correctness(1, 106042693688286888749844332309173760875888815757289183140478978951, 0);
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
