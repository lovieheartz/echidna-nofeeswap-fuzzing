// Copyright 2025, NoFeeSwap LLC - All rights reserved.
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "../contracts/utilities/Price.sol";
import "../contracts/utilities/X15.sol";
import "../contracts/utilities/X59.sol";
import "../contracts/utilities/X216.sol";

/// @title Echidna test contract for Price.sol storePrice function
/// @notice This contract tests the storePrice function with randomized inputs
/// @dev Uses assertion mode for property-based testing
contract EchidnaPriceTest {
    using PriceLibrary for uint256;

    // Memory guard values (must be literal for assembly)
    bytes32 constant GUARD_1 = 0xDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF;
    bytes32 constant GUARD_2 = 0xBADC0FFEEBADC0FFEEBADC0FFEEBADC0FFEEBADC0FFEEBADC0FFEEBADC0FFEEE;
    bytes32 constant GUARD_3 = 0x1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF;

    /// @notice Test storePrice function with three parameters (logPrice, sqrtPrice, sqrtInversePrice)
    /// @dev This mirrors the Python test: test_storePrice1 (lines 31-41)
    /// @param logPriceRaw Random log price value (will be cast to int256)
    /// @param sqrtPriceRaw Random sqrt price value (will be cast to int256)
    /// @param sqrtInversePriceRaw Random sqrt inverse price value (will be cast to int256)
    function echidna_test_storePrice_basic(
        int256 logPriceRaw,
        int256 sqrtPriceRaw,
        int256 sqrtInversePriceRaw
    ) public returns (bool) {
        // Constrain to positive values and valid ranges
        if (logPriceRaw <= 0) logPriceRaw = 1;
        if (logPriceRaw >= 2**64) logPriceRaw = logPriceRaw % (2**64);

        // X216 uses full int256 range but should be positive
        if (sqrtPriceRaw < 0) sqrtPriceRaw = -sqrtPriceRaw;
        if (sqrtInversePriceRaw < 0) sqrtInversePriceRaw = -sqrtInversePriceRaw;

        X59 logPrice = X59.wrap(logPriceRaw);
        X216 sqrtPrice = X216.wrap(sqrtPriceRaw);
        X216 sqrtInversePrice = X216.wrap(sqrtInversePriceRaw);

        // Setup memory with guards
        uint256 pricePointer;
        bytes32 guardBefore1;
        bytes32 guardBefore2;
        bytes32 guardAfter1;
        bytes32 guardAfter2;

        assembly {
            let freePtr := mload(0x40)

            // Place guard values BEFORE
            mstore(freePtr, GUARD_1)
            guardBefore1 := mload(freePtr)
            mstore(add(freePtr, 32), GUARD_2)
            guardBefore2 := mload(add(freePtr, 32))

            // pricePointer needs to be >= 32
            pricePointer := add(freePtr, 64)

            // Place guard values AFTER (price uses 62 bytes)
            mstore(add(pricePointer, 62), GUARD_3)
            guardAfter1 := mload(add(pricePointer, 62))
            mstore(add(pricePointer, 94), GUARD_1)
            guardAfter2 := mload(add(pricePointer, 94))

            mstore(0x40, add(pricePointer, 126))
        }

        // Store the price
        pricePointer.storePrice(logPrice, sqrtPrice, sqrtInversePrice);

        // Read back
        X59 logResult = pricePointer.log();
        X216 sqrtResult = pricePointer.sqrt(false);
        X216 sqrtInverseResult = pricePointer.sqrt(true);

        // Verify values match
        bool valuesMatch = (
            X59.unwrap(logResult) == X59.unwrap(logPrice) &&
            X216.unwrap(sqrtResult) == X216.unwrap(sqrtPrice) &&
            X216.unwrap(sqrtInverseResult) == X216.unwrap(sqrtInversePrice)
        );

        // Check memory guards
        bytes32 checkBefore1;
        bytes32 checkBefore2;
        bytes32 checkAfter1;
        bytes32 checkAfter2;

        assembly {
            checkBefore1 := mload(sub(pricePointer, 64))
            checkBefore2 := mload(sub(pricePointer, 32))
            checkAfter1 := mload(add(pricePointer, 62))
            checkAfter2 := mload(add(pricePointer, 94))
        }

        bool memoryIntact = (
            guardBefore1 == checkBefore1 &&
            guardBefore2 == checkBefore2 &&
            guardAfter1 == checkAfter1 &&
            guardAfter2 == checkAfter2
        );

        return valuesMatch && memoryIntact;
    }

    /// @notice Test storePrice with height parameter
    function echidna_test_storePrice_with_height(
        int256 heightPriceRaw,
        int256 logPriceRaw,
        int256 sqrtPriceRaw,
        int256 sqrtInversePriceRaw
    ) public returns (bool) {
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
        bytes32 guardBefore1;
        bytes32 guardBefore2;
        bytes32 guardAfter1;
        bytes32 guardAfter2;

        assembly {
            let freePtr := mload(0x40)

            mstore(freePtr, GUARD_1)
            guardBefore1 := mload(freePtr)
            mstore(add(freePtr, 32), GUARD_2)
            guardBefore2 := mload(add(freePtr, 32))

            // Price with height requires pointer >= 34
            pricePointer := add(freePtr, 66)

            mstore(add(pricePointer, 62), GUARD_3)
            guardAfter1 := mload(add(pricePointer, 62))
            mstore(add(pricePointer, 94), GUARD_1)
            guardAfter2 := mload(add(pricePointer, 94))

            mstore(0x40, add(pricePointer, 126))
        }

        pricePointer.storePrice(heightPrice, logPrice, sqrtPrice, sqrtInversePrice);

        X15 heightResult = pricePointer.height();
        X59 logResult = pricePointer.log();
        X216 sqrtResult = pricePointer.sqrt(false);
        X216 sqrtInverseResult = pricePointer.sqrt(true);

        bool valuesMatch = (
            X15.unwrap(heightResult) == X15.unwrap(heightPrice) &&
            X59.unwrap(logResult) == X59.unwrap(logPrice) &&
            X216.unwrap(sqrtResult) == X216.unwrap(sqrtPrice) &&
            X216.unwrap(sqrtInverseResult) == X216.unwrap(sqrtInversePrice)
        );

        bytes32 checkBefore1;
        bytes32 checkBefore2;
        bytes32 checkAfter1;
        bytes32 checkAfter2;

        assembly {
            checkBefore1 := mload(sub(pricePointer, 66))
            checkBefore2 := mload(sub(pricePointer, 34))
            checkAfter1 := mload(add(pricePointer, 62))
            checkAfter2 := mload(add(pricePointer, 94))
        }

        bool memoryIntact = (
            guardBefore1 == checkBefore1 &&
            guardBefore2 == checkBefore2 &&
            guardAfter1 == checkAfter1 &&
            guardAfter2 == checkAfter2
        );

        return valuesMatch && memoryIntact;
    }

    /// @notice Test memory safety at random pointer locations (Requirement #7)
    /// @dev This tests storing at a random memory location and verifying surrounding memory
    function echidna_test_storePrice_random_pointer(
        uint256 pointerOffset,
        int256 logPriceRaw,
        int256 sqrtPriceRaw,
        int256 sqrtInversePriceRaw
    ) public returns (bool) {
        // Constrain inputs
        if (logPriceRaw <= 0) logPriceRaw = 1;
        if (logPriceRaw >= 2**64) logPriceRaw = logPriceRaw % (2**64);

        if (sqrtPriceRaw < 0) sqrtPriceRaw = -sqrtPriceRaw;
        if (sqrtInversePriceRaw < 0) sqrtInversePriceRaw = -sqrtInversePriceRaw;

        // Constrain pointer offset to reasonable range (32 to 512 bytes)
        pointerOffset = 32 + (pointerOffset % 480);

        X59 logPrice = X59.wrap(logPriceRaw);
        X216 sqrtPrice = X216.wrap(sqrtPriceRaw);
        X216 sqrtInversePrice = X216.wrap(sqrtInversePriceRaw);

        uint256 pricePointer;
        bytes32[8] memory guardsBefore;
        bytes32[8] memory guardsAfter;

        assembly {
            let freePtr := mload(0x40)

            // Store pattern in 8 slots before
            let guard := GUARD_1
            for { let i := 0 } lt(i, 8) { i := add(i, 1) } {
                // Alternate guards
                if eq(mod(i, 2), 1) { guard := GUARD_2 }
                if eq(mod(i, 2), 0) { guard := GUARD_1 }
                mstore(add(freePtr, mul(i, 32)), guard)
            }

            pricePointer := add(freePtr, pointerOffset)

            // Store pattern in 8 slots after
            for { let i := 0 } lt(i, 8) { i := add(i, 1) } {
                if eq(mod(i, 2), 1) { guard := GUARD_3 }
                if eq(mod(i, 2), 0) { guard := GUARD_2 }
                mstore(add(add(pricePointer, 62), mul(i, 32)), guard)
            }

            mstore(0x40, add(add(pricePointer, 62), 256))
        }

        // Read guards before
        assembly {
            let freePtr := sub(pricePointer, pointerOffset)
            for { let i := 0 } lt(i, 8) { i := add(i, 1) } {
                mstore(add(guardsBefore, mul(i, 32)), mload(add(freePtr, mul(i, 32))))
            }

            for { let i := 0 } lt(i, 8) { i := add(i, 1) } {
                mstore(add(guardsAfter, mul(i, 32)), mload(add(add(pricePointer, 62), mul(i, 32))))
            }
        }

        // Store the price
        pricePointer.storePrice(logPrice, sqrtPrice, sqrtInversePrice);

        // Read back and verify
        X59 logResult = pricePointer.log();
        X216 sqrtResult = pricePointer.sqrt(false);
        X216 sqrtInverseResult = pricePointer.sqrt(true);

        bool valuesMatch = (
            X59.unwrap(logResult) == X59.unwrap(logPrice) &&
            X216.unwrap(sqrtResult) == X216.unwrap(sqrtPrice) &&
            X216.unwrap(sqrtInverseResult) == X216.unwrap(sqrtInversePrice)
        );

        // Verify guards weren't corrupted
        bool memoryIntact = true;
        assembly {
            let freePtr := sub(pricePointer, pointerOffset)

            for { let i := 0 } lt(i, 8) { i := add(i, 1) } {
                let expected := mload(add(guardsBefore, mul(i, 32)))
                let actual := mload(add(freePtr, mul(i, 32)))
                if iszero(eq(expected, actual)) {
                    memoryIntact := 0
                }
            }

            for { let i := 0 } lt(i, 8) { i := add(i, 1) } {
                let expected := mload(add(guardsAfter, mul(i, 32)))
                let actual := mload(add(add(pricePointer, 62), mul(i, 32)))
                if iszero(eq(expected, actual)) {
                    memoryIntact := 0
                }
            }
        }

        return valuesMatch && memoryIntact;
    }

    /// @notice Test copyPrice function
    function echidna_test_copyPrice(
        int256 logPriceRaw,
        int256 sqrtPriceRaw,
        int256 sqrtInversePriceRaw
    ) public returns (bool) {
        // Constrain inputs
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
            mstore(0x40, add(freePtr, 192))
        }

        // Store in first location
        pricePointer1.storePrice(logPrice, sqrtPrice, sqrtInversePrice);

        // Copy to second location
        pricePointer0.copyPrice(pricePointer1);

        // Read from copied location
        X59 logResult = pricePointer0.log();
        X216 sqrtResult = pricePointer0.sqrt(false);
        X216 sqrtInverseResult = pricePointer0.sqrt(true);

        // Verify copy was correct
        return (
            X59.unwrap(logResult) == X59.unwrap(logPrice) &&
            X216.unwrap(sqrtResult) == X216.unwrap(sqrtPrice) &&
            X216.unwrap(sqrtInverseResult) == X216.unwrap(sqrtInversePrice)
        );
    }
}