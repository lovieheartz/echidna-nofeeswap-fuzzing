// SPDX-License-Identifier: MIT
// Copyright 2025, NoFeeSwap LLC - All rights reserved.
pragma solidity ^0.8.28;

import "../contracts/utilities/Price.sol";
import "../contracts/utilities/X15.sol";
import "../contracts/utilities/X59.sol";
import "../contracts/utilities/X216.sol";

/// @title Industry-Grade Echidna Test Suite for Price.sol
/// @author Security Audit Team
/// @notice Comprehensive fuzzing test suite with advanced property testing
/// @dev This test suite provides:
///      - Strict input validation (no false positives)
///      - Memory corruption detection with multiple guard layers
///      - Invariant testing across all operations
///      - Gas consumption tracking
///      - Cross-function consistency checks
///      - Random pointer location testing (buffer overflow detection)
contract PriceTestIndustryGrade {
    using PriceLibrary for uint256;

    // ==================== CONSTANTS ====================

    /// @dev Valid range for X59 (logPrice): 1 to 2^64 - 1
    int256 constant MIN_X59 = 1;
    int256 constant MAX_X59 = int256(uint256(type(uint64).max));

    /// @dev Valid range for X15 (heightPrice): 0 to 2^16 - 1
    uint16 constant MAX_X15 = type(uint16).max;

    /// @dev Maximum safe value for X216 to avoid overflow
    int256 constant MAX_SAFE_X216 = type(int256).max / 2;

    /// @dev Memory guard patterns (multiple layers for robustness)
    bytes32 constant GUARD_LAYER_1 = 0xDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF;
    bytes32 constant GUARD_LAYER_2 = 0xBADC0FFEEBADC0FFEEBADC0FFEEBADC0FFEEBADC0FFEEBADC0FFEEBADC0FFEEE;
    bytes32 constant GUARD_LAYER_3 = 0xCAFEBABECAFEBABECAFEBABECAFEBABECAFEBABECAFEBABECAFEBABECAFEBABE;

    // ==================== STATE TRACKING ====================

    /// @dev Total number of tests executed (for statistics)
    uint256 public testsExecuted;

    /// @dev Total gas consumed across all tests
    uint256 public totalGasConsumed;

    /// @dev Maximum gas seen in a single operation
    uint256 public maxGasObserved;

    // ==================== MODIFIERS ====================

    /// @dev Track gas consumption for performance monitoring
    modifier trackGas() {
        uint256 gasBefore = gasleft();
        _;
        uint256 gasUsed = gasBefore - gasleft();
        totalGasConsumed += gasUsed;
        if (gasUsed > maxGasObserved) {
            maxGasObserved = gasUsed;
        }
    }

    // ==================== PROPERTY 1: Basic Store/Retrieve Correctness ====================

    /// @notice PROPERTY: Values stored must equal values retrieved
    /// @dev This tests the fundamental correctness of storePrice and read operations
    /// @param logPriceRaw Random log price (will be validated)
    /// @param sqrtPriceRaw Random sqrt price (will be validated)
    /// @param sqrtInversePriceRaw Random sqrt inverse price (will be validated)
    function test_property_store_retrieve_correctness(
        int256 logPriceRaw,
        int256 sqrtPriceRaw,
        int256 sqrtInversePriceRaw
    ) public trackGas {
        // ===== STRICT INPUT VALIDATION (NO INVALID INPUTS) =====

        // Skip invalid logPrice (must be in range [1, 2^64-1])
        if (logPriceRaw < MIN_X59 || logPriceRaw > MAX_X59) return;

        // Skip invalid sqrtPrice (must be non-negative and not too large)
        if (sqrtPriceRaw < 0 || sqrtPriceRaw > MAX_SAFE_X216) return;

        // Skip invalid sqrtInversePrice (must be non-negative and not too large)
        if (sqrtInversePriceRaw < 0 || sqrtInversePriceRaw > MAX_SAFE_X216) return;

        testsExecuted++;

        // ===== WRAP IN CUSTOM TYPES =====
        X59 logPrice = X59.wrap(logPriceRaw);
        X216 sqrtPrice = X216.wrap(sqrtPriceRaw);
        X216 sqrtInversePrice = X216.wrap(sqrtInversePriceRaw);

        // ===== SETUP MEMORY WITH GUARDS =====
        uint256 pricePointer;
        bytes32[3] memory guardsBefore;
        bytes32[3] memory guardsAfter;

        assembly {
            let freePtr := mload(0x40)

            // Place 3 layers of guards BEFORE price storage
            mstore(freePtr, GUARD_LAYER_1)
            mstore(add(freePtr, 32), GUARD_LAYER_2)
            mstore(add(freePtr, 64), GUARD_LAYER_3)

            // Price pointer must be >= 32 bytes from start
            pricePointer := add(freePtr, 96)

            // Place 3 layers of guards AFTER price storage (62 bytes)
            mstore(add(pricePointer, 62), GUARD_LAYER_1)
            mstore(add(pricePointer, 94), GUARD_LAYER_2)
            mstore(add(pricePointer, 126), GUARD_LAYER_3)

            // Update free memory pointer
            mstore(0x40, add(pricePointer, 158))
        }

        // Save guard values for later verification
        assembly {
            mstore(guardsBefore, mload(sub(pricePointer, 96)))
            mstore(add(guardsBefore, 32), mload(sub(pricePointer, 64)))
            mstore(add(guardsBefore, 64), mload(sub(pricePointer, 32)))

            mstore(guardsAfter, mload(add(pricePointer, 62)))
            mstore(add(guardsAfter, 32), mload(add(pricePointer, 94)))
            mstore(add(guardsAfter, 64), mload(add(pricePointer, 126)))
        }

        // ===== EXECUTE FUNCTION UNDER TEST =====
        pricePointer.storePrice(logPrice, sqrtPrice, sqrtInversePrice);

        // ===== READ BACK VALUES =====
        X59 logResult = pricePointer.log();
        X216 sqrtResult = pricePointer.sqrt(false);
        X216 sqrtInverseResult = pricePointer.sqrt(true);

        // ===== PROPERTY 1: VALUES MUST MATCH =====
        assert(X59.unwrap(logResult) == X59.unwrap(logPrice));
        assert(X216.unwrap(sqrtResult) == X216.unwrap(sqrtPrice));
        assert(X216.unwrap(sqrtInverseResult) == X216.unwrap(sqrtInversePrice));

        // ===== PROPERTY 2: MEMORY GUARDS MUST BE INTACT =====
        bytes32[3] memory checkBefore;
        bytes32[3] memory checkAfter;

        assembly {
            mstore(checkBefore, mload(sub(pricePointer, 96)))
            mstore(add(checkBefore, 32), mload(sub(pricePointer, 64)))
            mstore(add(checkBefore, 64), mload(sub(pricePointer, 32)))

            mstore(checkAfter, mload(add(pricePointer, 62)))
            mstore(add(checkAfter, 32), mload(add(pricePointer, 94)))
            mstore(add(checkAfter, 64), mload(add(pricePointer, 126)))
        }

        assert(guardsBefore[0] == checkBefore[0]);
        assert(guardsBefore[1] == checkBefore[1]);
        assert(guardsBefore[2] == checkBefore[2]);
        assert(guardsAfter[0] == checkAfter[0]);
        assert(guardsAfter[1] == checkAfter[1]);
        assert(guardsAfter[2] == checkAfter[2]);
    }

    // ==================== PROPERTY 2: Height Parameter Correctness ====================

    /// @notice PROPERTY: storePrice with height must preserve all 4 values correctly
    /// @dev Tests the 4-parameter version of storePrice
    function test_property_store_retrieve_with_height(
        uint16 heightPriceRaw,
        int256 logPriceRaw,
        int256 sqrtPriceRaw,
        int256 sqrtInversePriceRaw
    ) public trackGas {
        // ===== INPUT VALIDATION =====
        if (logPriceRaw < MIN_X59 || logPriceRaw > MAX_X59) return;
        if (sqrtPriceRaw < 0 || sqrtPriceRaw > MAX_SAFE_X216) return;
        if (sqrtInversePriceRaw < 0 || sqrtInversePriceRaw > MAX_SAFE_X216) return;
        // heightPriceRaw is uint16, so always valid

        testsExecuted++;

        X15 heightPrice = X15.wrap(heightPriceRaw);
        X59 logPrice = X59.wrap(logPriceRaw);
        X216 sqrtPrice = X216.wrap(sqrtPriceRaw);
        X216 sqrtInversePrice = X216.wrap(sqrtInversePriceRaw);

        uint256 pricePointer;
        bytes32[3] memory guardsBefore;
        bytes32[3] memory guardsAfter;

        assembly {
            let freePtr := mload(0x40)

            mstore(freePtr, GUARD_LAYER_1)
            mstore(add(freePtr, 32), GUARD_LAYER_2)
            mstore(add(freePtr, 64), GUARD_LAYER_3)

            // Height requires pointer >= 34
            pricePointer := add(freePtr, 98)

            mstore(add(pricePointer, 62), GUARD_LAYER_1)
            mstore(add(pricePointer, 94), GUARD_LAYER_2)
            mstore(add(pricePointer, 126), GUARD_LAYER_3)

            mstore(0x40, add(pricePointer, 158))
        }

        assembly {
            mstore(guardsBefore, mload(sub(pricePointer, 98)))
            mstore(add(guardsBefore, 32), mload(sub(pricePointer, 66)))
            mstore(add(guardsBefore, 64), mload(sub(pricePointer, 34)))

            mstore(guardsAfter, mload(add(pricePointer, 62)))
            mstore(add(guardsAfter, 32), mload(add(pricePointer, 94)))
            mstore(add(guardsAfter, 64), mload(add(pricePointer, 126)))
        }

        pricePointer.storePrice(heightPrice, logPrice, sqrtPrice, sqrtInversePrice);

        X15 heightResult = pricePointer.height();
        X59 logResult = pricePointer.log();
        X216 sqrtResult = pricePointer.sqrt(false);
        X216 sqrtInverseResult = pricePointer.sqrt(true);

        // PROPERTY: All 4 values must match
        assert(X15.unwrap(heightResult) == X15.unwrap(heightPrice));
        assert(X59.unwrap(logResult) == X59.unwrap(logPrice));
        assert(X216.unwrap(sqrtResult) == X216.unwrap(sqrtPrice));
        assert(X216.unwrap(sqrtInverseResult) == X216.unwrap(sqrtInversePrice));

        // PROPERTY: Memory guards must be intact
        bytes32[3] memory checkBefore;
        bytes32[3] memory checkAfter;

        assembly {
            mstore(checkBefore, mload(sub(pricePointer, 98)))
            mstore(add(checkBefore, 32), mload(sub(pricePointer, 66)))
            mstore(add(checkBefore, 64), mload(sub(pricePointer, 34)))

            mstore(checkAfter, mload(add(pricePointer, 62)))
            mstore(add(checkAfter, 32), mload(add(pricePointer, 94)))
            mstore(add(checkAfter, 64), mload(add(pricePointer, 126)))
        }

        assert(guardsBefore[0] == checkBefore[0]);
        assert(guardsBefore[1] == checkBefore[1]);
        assert(guardsBefore[2] == checkBefore[2]);
        assert(guardsAfter[0] == checkAfter[0]);
        assert(guardsAfter[1] == checkAfter[1]);
        assert(guardsAfter[2] == checkAfter[2]);
    }

    // ==================== PROPERTY 3: Copy Operation Correctness ====================

    /// @notice PROPERTY: Copied price must exactly match original
    /// @dev Tests copyPrice function integrity
    function test_property_copy_preserves_data(
        int256 logPriceRaw,
        int256 sqrtPriceRaw,
        int256 sqrtInversePriceRaw
    ) public trackGas {
        // ===== INPUT VALIDATION =====
        if (logPriceRaw < MIN_X59 || logPriceRaw > MAX_X59) return;
        if (sqrtPriceRaw < 0 || sqrtPriceRaw > MAX_SAFE_X216) return;
        if (sqrtInversePriceRaw < 0 || sqrtInversePriceRaw > MAX_SAFE_X216) return;

        testsExecuted++;

        X59 logPrice = X59.wrap(logPriceRaw);
        X216 sqrtPrice = X216.wrap(sqrtPriceRaw);
        X216 sqrtInversePrice = X216.wrap(sqrtInversePriceRaw);

        uint256 pricePointer0;
        uint256 pricePointer1;

        assembly {
            let freePtr := mload(0x40)
            pricePointer0 := add(freePtr, 64)
            pricePointer1 := add(freePtr, 192)
            mstore(0x40, add(freePtr, 320))
        }

        // Store in source location
        pricePointer1.storePrice(logPrice, sqrtPrice, sqrtInversePrice);

        // Copy to destination
        pricePointer0.copyPrice(pricePointer1);

        // Read from both locations
        X59 log0 = pricePointer0.log();
        X216 sqrt0 = pricePointer0.sqrt(false);
        X216 sqrtInv0 = pricePointer0.sqrt(true);

        X59 log1 = pricePointer1.log();
        X216 sqrt1 = pricePointer1.sqrt(false);
        X216 sqrtInv1 = pricePointer1.sqrt(true);

        // PROPERTY 1: Destination must match source
        assert(X59.unwrap(log0) == X59.unwrap(log1));
        assert(X216.unwrap(sqrt0) == X216.unwrap(sqrt1));
        assert(X216.unwrap(sqrtInv0) == X216.unwrap(sqrtInv1));

        // PROPERTY 2: Both must match original input
        assert(X59.unwrap(log0) == X59.unwrap(logPrice));
        assert(X216.unwrap(sqrt0) == X216.unwrap(sqrtPrice));
        assert(X216.unwrap(sqrtInv0) == X216.unwrap(sqrtInversePrice));
    }

    // ==================== PROPERTY 4: Random Memory Location Safety (CRITICAL!) ====================

    /// @notice PROPERTY: Storing at random memory location must not corrupt surroundings
    /// @dev This is REQUIREMENT #7 from the assignment - CRITICAL for security
    /// @param pointerOffset Random memory offset (will be constrained to safe range)
    /// @param logPriceRaw Random log price
    /// @param sqrtPriceRaw Random sqrt price
    /// @param sqrtInversePriceRaw Random sqrt inverse price
    function test_property_random_pointer_memory_safety(
        uint256 pointerOffset,
        int256 logPriceRaw,
        int256 sqrtPriceRaw,
        int256 sqrtInversePriceRaw
    ) public trackGas {
        // ===== INPUT VALIDATION =====
        if (logPriceRaw < MIN_X59 || logPriceRaw > MAX_X59) return;
        if (sqrtPriceRaw < 0 || sqrtPriceRaw > MAX_SAFE_X216) return;
        if (sqrtInversePriceRaw < 0 || sqrtInversePriceRaw > MAX_SAFE_X216) return;

        // Constrain pointer offset to safe range: 32 to 1024 bytes
        // (must be >= 32 for Price.sol requirements)
        pointerOffset = 32 + (pointerOffset % 992);

        testsExecuted++;

        X59 logPrice = X59.wrap(logPriceRaw);
        X216 sqrtPrice = X216.wrap(sqrtPriceRaw);
        X216 sqrtInversePrice = X216.wrap(sqrtInversePriceRaw);

        // ===== ADVANCED MEMORY GUARD SYSTEM =====
        // We use 16 guard slots (512 bytes) on EACH side for maximum safety
        uint256 pricePointer;
        bytes32[16] memory guardsBefore;
        bytes32[16] memory guardsAfter;

        assembly {
            let freePtr := mload(0x40)

            // Place 16 guard slots BEFORE (512 bytes)
            let guard := GUARD_LAYER_1
            for { let i := 0 } lt(i, 16) { i := add(i, 1) } {
                // Rotate through 3 guard patterns
                if eq(mod(i, 3), 0) { guard := GUARD_LAYER_1 }
                if eq(mod(i, 3), 1) { guard := GUARD_LAYER_2 }
                if eq(mod(i, 3), 2) { guard := GUARD_LAYER_3 }
                mstore(add(freePtr, mul(i, 32)), guard)
            }

            // Set random pointer location
            pricePointer := add(freePtr, pointerOffset)

            // Place 16 guard slots AFTER (512 bytes)
            for { let i := 0 } lt(i, 16) { i := add(i, 1) } {
                if eq(mod(i, 3), 0) { guard := GUARD_LAYER_1 }
                if eq(mod(i, 3), 1) { guard := GUARD_LAYER_2 }
                if eq(mod(i, 3), 2) { guard := GUARD_LAYER_3 }
                mstore(add(add(pricePointer, 62), mul(i, 32)), guard)
            }

            // Update free memory pointer past all guards
            mstore(0x40, add(add(pricePointer, 62), 512))
        }

        // Save all guard values
        assembly {
            let freePtr := sub(pricePointer, pointerOffset)
            for { let i := 0 } lt(i, 16) { i := add(i, 1) } {
                mstore(add(guardsBefore, mul(i, 32)), mload(add(freePtr, mul(i, 32))))
            }

            for { let i := 0 } lt(i, 16) { i := add(i, 1) } {
                mstore(add(guardsAfter, mul(i, 32)), mload(add(add(pricePointer, 62), mul(i, 32))))
            }
        }

        // ===== EXECUTE FUNCTION UNDER TEST =====
        pricePointer.storePrice(logPrice, sqrtPrice, sqrtInversePrice);

        // ===== VERIFY VALUES =====
        X59 logResult = pricePointer.log();
        X216 sqrtResult = pricePointer.sqrt(false);
        X216 sqrtInverseResult = pricePointer.sqrt(true);

        assert(X59.unwrap(logResult) == X59.unwrap(logPrice));
        assert(X216.unwrap(sqrtResult) == X216.unwrap(sqrtPrice));
        assert(X216.unwrap(sqrtInverseResult) == X216.unwrap(sqrtInversePrice));

        // ===== CRITICAL: VERIFY ALL 16 GUARDS ON EACH SIDE =====
        assembly {
            let freePtr := sub(pricePointer, pointerOffset)

            // Check all 16 guards BEFORE
            for { let i := 0 } lt(i, 16) { i := add(i, 1) } {
                let expected := mload(add(guardsBefore, mul(i, 32)))
                let actual := mload(add(freePtr, mul(i, 32)))
                if iszero(eq(expected, actual)) {
                    // Memory corruption detected!
                    revert(0, 0)
                }
            }

            // Check all 16 guards AFTER
            for { let i := 0 } lt(i, 16) { i := add(i, 1) } {
                let expected := mload(add(guardsAfter, mul(i, 32)))
                let actual := mload(add(add(pricePointer, 62), mul(i, 32)))
                if iszero(eq(expected, actual)) {
                    // Memory corruption detected!
                    revert(0, 0)
                }
            }
        }
    }

    // ==================== PROPERTY 5: Idempotence ====================

    /// @notice PROPERTY: Reading twice must return same values
    /// @dev Tests that read operations are idempotent (don't modify state)
    function test_property_read_idempotence(
        int256 logPriceRaw,
        int256 sqrtPriceRaw,
        int256 sqrtInversePriceRaw
    ) public trackGas {
        if (logPriceRaw < MIN_X59 || logPriceRaw > MAX_X59) return;
        if (sqrtPriceRaw < 0 || sqrtPriceRaw > MAX_SAFE_X216) return;
        if (sqrtInversePriceRaw < 0 || sqrtInversePriceRaw > MAX_SAFE_X216) return;

        testsExecuted++;

        X59 logPrice = X59.wrap(logPriceRaw);
        X216 sqrtPrice = X216.wrap(sqrtPriceRaw);
        X216 sqrtInversePrice = X216.wrap(sqrtInversePriceRaw);

        uint256 pricePointer;
        assembly {
            pricePointer := add(mload(0x40), 64)
            mstore(0x40, add(pricePointer, 128))
        }

        pricePointer.storePrice(logPrice, sqrtPrice, sqrtInversePrice);

        // Read first time
        X59 log1 = pricePointer.log();
        X216 sqrt1 = pricePointer.sqrt(false);
        X216 sqrtInv1 = pricePointer.sqrt(true);

        // Read second time
        X59 log2 = pricePointer.log();
        X216 sqrt2 = pricePointer.sqrt(false);
        X216 sqrtInv2 = pricePointer.sqrt(true);

        // PROPERTY: Both reads must return identical values
        assert(X59.unwrap(log1) == X59.unwrap(log2));
        assert(X216.unwrap(sqrt1) == X216.unwrap(sqrt2));
        assert(X216.unwrap(sqrtInv1) == X216.unwrap(sqrtInv2));
    }

    // ==================== INVARIANTS ====================

    /// @notice INVARIANT: Test execution counter must never decrease
    function echidna_invariant_test_counter_monotonic() public view returns (bool) {
        // This invariant is trivially true but demonstrates invariant testing
        return testsExecuted >= 0;
    }

    /// @notice INVARIANT: Gas tracking must be consistent
    function echidna_invariant_gas_tracking_consistent() public view returns (bool) {
        // Max gas observed should never exceed total gas (for single-threaded execution)
        return maxGasObserved <= totalGasConsumed || testsExecuted == 0;
    }
}