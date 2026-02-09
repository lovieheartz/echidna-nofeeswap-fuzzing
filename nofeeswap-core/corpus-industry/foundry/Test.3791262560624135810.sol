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
        Target.test_property_random_pointer_memory_safety(0, 1, 0, 105321728752546928095990813588036654167103873528271871525968153947);
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
