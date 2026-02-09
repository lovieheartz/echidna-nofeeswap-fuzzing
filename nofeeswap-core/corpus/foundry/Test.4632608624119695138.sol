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
        Target.test_copyPrice(710541933390077436031390572, 105484015043921953759548202741724541922481558153212027489085330997, 0);
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
