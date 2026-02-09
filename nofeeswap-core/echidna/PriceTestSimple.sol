// Copyright 2025, NoFeeSwap LLC - All rights reserved.
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "../contracts/utilities/Price.sol";
import "../contracts/utilities/X15.sol";
import "../contracts/utilities/X59.sol";
import "../contracts/utilities/X216.sol";

/// @title Simple Echidna test for Price.sol (Property mode)
/// @notice This tests the storePrice function with randomized inputs
/// @dev Uses property mode for fuzzing
contract PriceTestSimple {
    using PriceLibrary for uint256;

    // Test counter
    uint256 public testCount;

    /// @notice Test storePrice function - Echidna will call this with random inputs
    /// @param logPriceRaw Random log price value
    /// @param sqrtPriceRaw Random sqrt price value
    /// @param sqrtInversePriceRaw Random sqrt inverse price value
    function test_storePrice_basic(
        int256 logPriceRaw,
        int256 sqrtPriceRaw,
        int256 sqrtInversePriceRaw
    ) public {
        testCount++;

        // Constrain to valid ranges
        if (logPriceRaw <= 0) logPriceRaw = 1;
        if (logPriceRaw >= 2**64) logPriceRaw = logPriceRaw % (2**64);
        if (sqrtPriceRaw < 0) sqrtPriceRaw = -sqrtPriceRaw;
        if (sqrtInversePriceRaw < 0) sqrtInversePriceRaw = -sqrtInversePriceRaw;

        X59 logPrice = X59.wrap(logPriceRaw);
        X216 sqrtPrice = X216.wrap(sqrtPriceRaw);
        X216 sqrtInversePrice = X216.wrap(sqrtInversePriceRaw);

        // Setup memory
        uint256 pricePointer;
        assembly {
            pricePointer := add(mload(0x40), 64)
            mstore(0x40, add(pricePointer, 128))
        }

        // Store the price
        pricePointer.storePrice(logPrice, sqrtPrice, sqrtInversePrice);

        // Read back
        X59 logResult = pricePointer.log();
        X216 sqrtResult = pricePointer.sqrt(false);
        X216 sqrtInverseResult = pricePointer.sqrt(true);

        // Assert values match (this is the property we're testing)
        assert(X59.unwrap(logResult) == X59.unwrap(logPrice));
        assert(X216.unwrap(sqrtResult) == X216.unwrap(sqrtPrice));
        assert(X216.unwrap(sqrtInverseResult) == X216.unwrap(sqrtInversePrice));
    }

    /// @notice Test with height parameter
    function test_storePrice_with_height(
        int256 heightPriceRaw,
        int256 logPriceRaw,
        int256 sqrtPriceRaw,
        int256 sqrtInversePriceRaw
    ) public {
        testCount++;

        // Constrain inputs
        if (heightPriceRaw < 0) heightPriceRaw = -heightPriceRaw;
        if (heightPriceRaw >= 2**16) heightPriceRaw = heightPriceRaw % (2**16);
        if (logPriceRaw <= 0) logPriceRaw = 1;
        if (logPriceRaw >= 2**64) logPriceRaw = logPriceRaw % (2**64);
        if (sqrtPriceRaw < 0) sqrtPriceRaw = -sqrtPriceRaw;
        if (sqrtInversePriceRaw < 0) sqrtInversePriceRaw = -sqrtInversePriceRaw;

        X15 heightPrice = X15.wrap(uint16(uint256(heightPriceRaw)));
        X59 logPrice = X59.wrap(logPriceRaw);
        X216 sqrtPrice = X216.wrap(sqrtPriceRaw);
        X216 sqrtInversePrice = X216.wrap(sqrtInversePriceRaw);

        uint256 pricePointer;
        assembly {
            pricePointer := add(mload(0x40), 66)
            mstore(0x40, add(pricePointer, 128))
        }

        pricePointer.storePrice(heightPrice, logPrice, sqrtPrice, sqrtInversePrice);

        X15 heightResult = pricePointer.height();
        X59 logResult = pricePointer.log();
        X216 sqrtResult = pricePointer.sqrt(false);
        X216 sqrtInverseResult = pricePointer.sqrt(true);

        assert(X15.unwrap(heightResult) == X15.unwrap(heightPrice));
        assert(X59.unwrap(logResult) == X59.unwrap(logPrice));
        assert(X216.unwrap(sqrtResult) == X216.unwrap(sqrtPrice));
        assert(X216.unwrap(sqrtInverseResult) == X216.unwrap(sqrtInversePrice));
    }

    /// @notice Test copyPrice function
    function test_copyPrice(
        int256 logPriceRaw,
        int256 sqrtPriceRaw,
        int256 sqrtInversePriceRaw
    ) public {
        testCount++;

        if (logPriceRaw <= 0) logPriceRaw = 1;
        if (logPriceRaw >= 2**64) logPriceRaw = logPriceRaw % (2**64);
        if (sqrtPriceRaw < 0) sqrtPriceRaw = -sqrtPriceRaw;
        if (sqrtInversePriceRaw < 0) sqrtInversePriceRaw = -sqrtInversePriceRaw;

        X59 logPrice = X59.wrap(logPriceRaw);
        X216 sqrtPrice = X216.wrap(sqrtPriceRaw);
        X216 sqrtInversePrice = X216.wrap(sqrtInversePriceRaw);

        uint256 pricePointer0;
        uint256 pricePointer1;

        assembly {
            let freePtr := mload(0x40)
            pricePointer0 := add(freePtr, 64)
            pricePointer1 := add(freePtr, 128)
            mstore(0x40, add(freePtr, 256))
        }

        pricePointer1.storePrice(logPrice, sqrtPrice, sqrtInversePrice);
        pricePointer0.copyPrice(pricePointer1);

        X59 logResult = pricePointer0.log();
        X216 sqrtResult = pricePointer0.sqrt(false);
        X216 sqrtInverseResult = pricePointer0.sqrt(true);

        assert(X59.unwrap(logResult) == X59.unwrap(logPrice));
        assert(X216.unwrap(sqrtResult) == X216.unwrap(sqrtPrice));
        assert(X216.unwrap(sqrtInverseResult) == X216.unwrap(sqrtInversePrice));
    }

    /// @notice Memory corruption test - random pointer location
    function test_storePrice_memory_safety(
        uint256 pointerOffset,
        int256 logPriceRaw,
        int256 sqrtPriceRaw,
        int256 sqrtInversePriceRaw
    ) public {
        testCount++;

        if (logPriceRaw <= 0) logPriceRaw = 1;
        if (logPriceRaw >= 2**64) logPriceRaw = logPriceRaw % (2**64);
        if (sqrtPriceRaw < 0) sqrtPriceRaw = -sqrtPriceRaw;
        if (sqrtInversePriceRaw < 0) sqrtInversePriceRaw = -sqrtInversePriceRaw;

        // Random pointer offset (32 to 512 bytes)
        pointerOffset = 32 + (pointerOffset % 480);

        X59 logPrice = X59.wrap(logPriceRaw);
        X216 sqrtPrice = X216.wrap(sqrtPriceRaw);
        X216 sqrtInversePrice = X216.wrap(sqrtInversePriceRaw);

        uint256 pricePointer;
        bytes32 guardBefore;
        bytes32 guardAfter;

        assembly {
            let freePtr := mload(0x40)

            // Place guard before
            mstore(freePtr, 0xDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF)
            guardBefore := mload(freePtr)

            pricePointer := add(freePtr, pointerOffset)

            // Place guard after
            mstore(add(pricePointer, 62), 0xBADC0FFEEBADC0FFEEBADC0FFEEBADC0FFEEBADC0FFEEBADC0FFEEBADC0FFEEE)
            guardAfter := mload(add(pricePointer, 62))

            mstore(0x40, add(pricePointer, 256))
        }

        // Store price
        pricePointer.storePrice(logPrice, sqrtPrice, sqrtInversePrice);

        // Verify values
        X59 logResult = pricePointer.log();
        X216 sqrtResult = pricePointer.sqrt(false);
        X216 sqrtInverseResult = pricePointer.sqrt(true);

        assert(X59.unwrap(logResult) == X59.unwrap(logPrice));
        assert(X216.unwrap(sqrtResult) == X216.unwrap(sqrtPrice));
        assert(X216.unwrap(sqrtInverseResult) == X216.unwrap(sqrtInversePrice));

        // Check memory guards weren't corrupted
        bytes32 checkBefore;
        bytes32 checkAfter;
        assembly {
            checkBefore := mload(sub(pricePointer, pointerOffset))
            checkAfter := mload(add(pricePointer, 62))
        }

        assert(guardBefore == checkBefore); // Memory before should be intact
        assert(guardAfter == checkAfter);   // Memory after should be intact
    }
}