// Copyright 2025, NoFeeSwap LLC - All rights reserved.
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "../contracts/utilities/Price.sol";
import "../contracts/utilities/X15.sol";
import "../contracts/utilities/X59.sol";
import "../contracts/utilities/X216.sol";

/// @title Sanity check test with DELIBERATE ERRORS
/// @notice This contract intentionally contains bugs to verify that Echidna catches them
/// @dev DO NOT use this test for actual verification - it's meant to FAIL
contract PriceTestSanityCheck {
    using PriceLibrary for uint256;

    // Constants for valid ranges
    uint256 constant MAX_X216 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

    /// @notice SANITY CHECK 1: Test with a WRONG assertion (should fail quickly)
    /// @dev This introduces a deliberate error where we accept ANY value for logPrice = 0x1234
    /// Echidna should find this bug immediately
    function echidna_test_wrong_assertion(
        uint64 logPrice,
        uint256 sqrtPrice,
        uint256 sqrtInversePrice
    ) public returns (bool) {
        if (logPrice == 0) logPrice = 1;
        if (sqrtPrice >= MAX_X216) sqrtPrice = sqrtPrice % MAX_X216;
        if (sqrtInversePrice >= MAX_X216) sqrtInversePrice = sqrtInversePrice % MAX_X216;

        X59 logPriceWrapped = X59.wrap(logPrice);
        X216 sqrtPriceWrapped = X216.wrap(sqrtPrice);
        X216 sqrtInversePriceWrapped = X216.wrap(sqrtInversePrice);

        uint256 pricePointer;
        assembly {
            pricePointer := add(mload(0x40), 64)
            mstore(0x40, add(pricePointer, 128))
        }

        pricePointer.storePrice(logPriceWrapped, sqrtPriceWrapped, sqrtInversePriceWrapped);

        X59 logResult = pricePointer.log();
        X216 sqrtResult = pricePointer.sqrt(false);
        X216 sqrtInverseResult = pricePointer.sqrt(true);

        // DELIBERATE BUG: Accept any value if logPrice is 0x1234
        // Echidna should find a case where this fails
        bool logMatches = X59.unwrap(logResult) == X59.unwrap(logPriceWrapped) || logPrice == 0x1234ABCD;
        bool sqrtMatches = X216.unwrap(sqrtResult) == X216.unwrap(sqrtPriceWrapped);
        bool sqrtInverseMatches = X216.unwrap(sqrtInverseResult) == X216.unwrap(sqrtInversePriceWrapped);

        return logMatches && sqrtMatches && sqrtInverseMatches;
    }

    /// @notice SANITY CHECK 2: Test that deliberately corrupts memory
    /// @dev This writes garbage to memory after storing, which should fail the guard check
    function echidna_test_memory_corruption(
        uint64 logPrice,
        uint256 sqrtPrice,
        uint256 sqrtInversePrice
    ) public returns (bool) {
        if (logPrice == 0) logPrice = 1;
        if (sqrtPrice >= MAX_X216) sqrtPrice = sqrtPrice % MAX_X216;
        if (sqrtInversePrice >= MAX_X216) sqrtInversePrice = sqrtInversePrice % MAX_X216;

        X59 logPriceWrapped = X59.wrap(logPrice);
        X216 sqrtPriceWrapped = X216.wrap(sqrtPrice);
        X216 sqrtInversePriceWrapped = X216.wrap(sqrtInversePrice);

        bytes32 constant GUARD_PATTERN = 0xDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF;

        uint256 pricePointer;
        bytes32 guardAfter;

        assembly {
            let freePtr := mload(0x40)
            pricePointer := add(freePtr, 64)

            // Place guard after the price data
            mstore(add(pricePointer, 62), GUARD_PATTERN)
            guardAfter := mload(add(pricePointer, 62))

            mstore(0x40, add(pricePointer, 128))
        }

        // Store the price
        pricePointer.storePrice(logPriceWrapped, sqrtPriceWrapped, sqrtInversePriceWrapped);

        // DELIBERATE BUG: Corrupt memory after storing
        // This simulates a bug where the function writes beyond its bounds
        assembly {
            // Corrupt the guard by writing past the 62-byte boundary
            mstore(add(pricePointer, 70), 0xBADBADBADBADBAD)
        }

        // Check if guard was preserved (it won't be due to our deliberate corruption)
        bytes32 checkGuardAfter;
        assembly {
            checkGuardAfter := mload(add(pricePointer, 62))
        }

        // This should fail because we corrupted memory
        return guardAfter == checkGuardAfter;
    }

    /// @notice SANITY CHECK 3: Test with off-by-one error
    /// @dev This introduces a subtle bug in the value comparison
    function echidna_test_offbyone_error(
        uint64 logPrice,
        uint256 sqrtPrice,
        uint256 sqrtInversePrice
    ) public returns (bool) {
        if (logPrice == 0) logPrice = 1;
        if (sqrtPrice >= MAX_X216) sqrtPrice = sqrtPrice % MAX_X216;
        if (sqrtInversePrice >= MAX_X216) sqrtInversePrice = sqrtInversePrice % MAX_X216;

        X59 logPriceWrapped = X59.wrap(logPrice);
        X216 sqrtPriceWrapped = X216.wrap(sqrtPrice);
        X216 sqrtInversePriceWrapped = X216.wrap(sqrtInversePrice);

        uint256 pricePointer;
        assembly {
            pricePointer := add(mload(0x40), 64)
            mstore(0x40, add(pricePointer, 128))
        }

        pricePointer.storePrice(logPriceWrapped, sqrtPriceWrapped, sqrtInversePriceWrapped);

        X59 logResult = pricePointer.log();
        X216 sqrtResult = pricePointer.sqrt(false);
        X216 sqrtInverseResult = pricePointer.sqrt(true);

        // DELIBERATE BUG: Allow off-by-one error in sqrtResult
        // This is a subtle bug that Echidna should catch
        bool logMatches = X59.unwrap(logResult) == X59.unwrap(logPriceWrapped);
        bool sqrtMatches = (
            X216.unwrap(sqrtResult) == X216.unwrap(sqrtPriceWrapped) ||
            X216.unwrap(sqrtResult) == X216.unwrap(sqrtPriceWrapped) + 1  // BUG: Accept off-by-one
        );
        bool sqrtInverseMatches = X216.unwrap(sqrtInverseResult) == X216.unwrap(sqrtInversePriceWrapped);

        return logMatches && sqrtMatches && sqrtInverseMatches;
    }
}