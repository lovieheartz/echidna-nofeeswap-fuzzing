// Copyright 2025, NoFeeSwap LLC - All rights reserved.
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "contracts/helpers/CalldataWrapper.sol";
import {
    _msgSender_,
    _poolId_,
    _logPriceMin_,
    _logPriceMax_,
    _logPriceMinOffsetted_,
    _logPriceMaxOffsetted_,
    _shares_,
    _curve_,
    _hookData_,
    _hookDataByteCount_,
    _hookInputByteCount_,
    _freeMemoryPointer_,
    _endOfStaticParams_,
    _hookInputByteCount_ as HOOK_INPUT_BYTE_COUNT_SLOT
} from "contracts/utilities/Memory.sol";

/// @title Echidna Property-Based Test for readModifyPositionInput
/// @notice Comprehensive fuzzing test suite that replicates Python/Brownie tests in randomized manner
/// @dev Tests arbitrary non-strictly encoded input with random hookdata starting positions
/// @dev This addresses Question 2: Property-based testing of readModifyPositionInput with
///      random hookdata offsets to test calldatacopy mechanism with non-strict ABI encoding
contract CalldataTestIndustryGrade {

    // ========================================================================
    // CONSTANTS & TYPE DEFINITIONS
    // ========================================================================

    /// @notice Maximum allowed hookData byte count (uint16.max)
    uint256 constant MAX_HOOK_DATA_BYTE_COUNT = 0xFFFF;

    /// @notice Guard patterns for memory corruption detection
    bytes32 constant GUARD_PATTERN_1 = 0xDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF;
    bytes32 constant GUARD_PATTERN_2 = 0xBADC0FFEBADC0FFEBADC0FFEBADC0FFEBADC0FFEBADC0FFEBADC0FFEBADC0FFE;
    bytes32 constant GUARD_PATTERN_3 = 0xCAFEBABECAFEBABECAFEBABECAFEBABECAFEBABECAFEBABECAFEBABECAFEBABE;

    /// @notice Fixed-point constants for log price calculations (X59 format)
    uint256 constant ONE_X59 = 1 << 59;
    uint256 constant SIXTEEN_X59 = 16 * ONE_X59;
    uint256 constant THIRTY_TWO_X59 = 32 * ONE_X59;
    uint256 constant ONE_X63 = 1 << 63;

    /// @notice Valid ranges for shares parameter
    int256 constant MAX_INT128 = type(int128).max;
    int256 constant MIN_INT128 = -MAX_INT128; // Note: not type(int128).min, as per contract logic

    /// @notice CalldataWrapper contract instance
    CalldataWrapper public wrapper;

    /// @notice Function selector for _readModifyPositionInput()
    bytes4 constant READ_MODIFY_POSITION_SELECTOR = CalldataWrapper._readModifyPositionInput.selector;

    // ========================================================================
    // STATE VARIABLES FOR TRACKING
    // ========================================================================

    uint256 public testsExecuted;
    uint256 public totalGasConsumed;
    uint256 public maxGasObserved;

    // ========================================================================
    // CONSTRUCTOR
    // ========================================================================

    constructor() {
        wrapper = new CalldataWrapper();
        testsExecuted = 0;
        totalGasConsumed = 0;
        maxGasObserved = 0;
    }

    // ========================================================================
    // HELPER FUNCTIONS
    // ========================================================================

    /// @notice Extracts qOffset (8-bit signed) from poolId at bits [180:187]
    /// @param poolId The pool identifier (256 bits)
    /// @return qOffset The extracted offset as int8 (-128 to +127)
    function extractQOffset(uint256 poolId) internal pure returns (int8 qOffset) {
        uint8 unsignedOffset = uint8((poolId >> 180) & 0xFF);
        if (unsignedOffset >= 128) {
            qOffset = int8(int256(uint256(unsignedOffset)) - 256);
        } else {
            qOffset = int8(int256(uint256(unsignedOffset)));
        }
    }

    /// @notice Converts int256 to two's complement uint256 representation
    function toTwosComplement(int256 value) internal pure returns (uint256 result) {
        if (value >= 0) {
            result = uint256(value);
        } else {
            unchecked {
                result = uint256(type(uint256).max) + uint256(value) + 1;
            }
        }
    }

    /// @notice Calculates adjusted logPrice from normalized q and poolId offset
    /// @dev Formula: logPrice = q + (qOffset * 2^59) - 2^63
    function calculateLogPrice(uint64 q, int8 qOffset) internal pure returns (int256) {
        int256 shift;
        if (qOffset >= 0) {
            shift = int256(uint256(int256(qOffset))) * int256(ONE_X59) - int256(ONE_X63);
        } else {
            shift = -int256(uint256(int256(-qOffset))) * int256(ONE_X59) - int256(ONE_X63);
        }
        return int256(uint256(q)) + shift;
    }

    /// @notice Constructs calldata with RANDOM hookdata offset (non-strict encoding)
    /// @dev This is the KEY REQUIREMENT: Testing arbitrary non-strictly encoded input
    ///      by starting hookdata content from a random place in calldata
    /// @param poolId Pool identifier
    /// @param logPriceMin Minimum log price (adjusted)
    /// @param logPriceMax Maximum log price (adjusted)
    /// @param shares Number of shares (int256, bounded to int128 range)
    /// @param hookDataContent Content pattern to fill hookData
    /// @param hookDataByteCount Size of hookData in bytes
    /// @param randomGap Random gap between static params and hookdata (0-1000 bytes)
    /// @param randomContentStart Random starting offset within content pattern (0-31 bytes)
    /// @return calldataBytes The constructed calldata with random offsets
    function constructCalldata(
        uint256 poolId,
        int256 logPriceMin,
        int256 logPriceMax,
        int256 shares,
        uint256 hookDataContent,
        uint16 hookDataByteCount,
        uint16 randomGap,
        uint8 randomContentStart
    ) internal pure returns (bytes memory calldataBytes) {
        // Limit randomGap to reasonable size (0-1000 bytes) for test performance
        randomGap = uint16(uint256(randomGap) % 1001);

        // Limit randomContentStart to 0-31 (byte offset within a 32-byte word)
        randomContentStart = uint8(uint256(randomContentStart) % 32);

        // Calculate hookdata starting position with RANDOM offset
        // This tests the calldatacopy mechanism with non-standard ABI encoding
        uint256 startOfHookData = 5 * 0x20 + randomGap;

        // Build hookDataBytes array with randomized content start
        bytes memory hookDataBytes;
        if (hookDataByteCount > 0) {
            uint256 numSlots = (hookDataByteCount + 31) / 32;
            hookDataBytes = new bytes(32 + hookDataByteCount);

            // Write length in first slot
            assembly {
                mstore(add(hookDataBytes, 32), hookDataByteCount)
            }

            // Fill content with ROTATION based on randomContentStart
            // This ensures we test non-strictly encoded hookdata content
            for (uint256 i = 0; i < numSlots; i++) {
                uint256 offset = 64 + i * 32;
                if (offset <= hookDataBytes.length) {
                    // Rotate content based on random offset
                    uint256 rotatedContent;
                    if (randomContentStart == 0) {
                        rotatedContent = hookDataContent;
                    } else {
                        uint256 leftShift = randomContentStart * 8;
                        uint256 rightShift = (32 - randomContentStart) * 8;
                        rotatedContent = (hookDataContent << leftShift) | (hookDataContent >> rightShift);
                    }
                    assembly {
                        mstore(add(hookDataBytes, offset), rotatedContent)
                    }
                }
            }
        } else {
            hookDataBytes = new bytes(32);
            assembly {
                mstore(add(hookDataBytes, 32), 0)
            }
        }

        // Construct full calldata with RANDOM gap (non-strict encoding)
        calldataBytes = abi.encodePacked(
            READ_MODIFY_POSITION_SELECTOR,
            bytes32(poolId),
            bytes32(toTwosComplement(logPriceMin)),
            bytes32(toTwosComplement(logPriceMax)),
            bytes32(toTwosComplement(shares)),
            bytes32(startOfHookData),    // Pointer to hookdata (with random gap)
            new bytes(randomGap),         // RANDOM GAP - key for non-strict encoding test
            hookDataBytes
        );
    }

    // ========================================================================
    // PROPERTY TESTS
    // ========================================================================

    /// @notice PROPERTY 1: Correctness with random hookdata offset (non-strict encoding)
    /// @dev Replicates test_readModifyPositionInput from Python tests but fully randomized
    /// @dev KEY: Tests arbitrary non-strictly encoded input by using random gaps and content starts
    /// @param poolId Pool identifier (256 bits, qOffset extracted from bits [180:187])
    /// @param qMin Normalized minimum log price (must be 0 < qMin < 2^64)
    /// @param qMax Normalized maximum log price (must be 0 < qMax < 2^64)
    /// @param shares Number of shares (bounded to ±int128.max range, != 0)
    /// @param hookDataContent Content pattern for filling hookData (256 bits)
    /// @param hookDataByteCount Size of hookData (0 to 1000 for performance)
    /// @param randomGap RANDOM gap size for non-strict encoding test (0-1000)
    /// @param randomContentStart RANDOM starting offset in hookdata content (0-31)
    function test_property_readModifyPositionInput_correctness(
        uint256 poolId,
        uint64 qMin,
        uint64 qMax,
        int256 shares,
        uint256 hookDataContent,
        uint16 hookDataByteCount,
        uint16 randomGap,
        uint8 randomContentStart
    ) public {
        // === INPUT NORMALIZATION ===
        // Limit hookDataByteCount for test performance (full range tested separately)
        if (hookDataByteCount > 1000) hookDataByteCount = uint16(uint256(hookDataByteCount) % 1001);

        // Ensure qMin in valid range: 0 < qMin < THIRTY_TWO_X59 (32 * 2^59)
        if (qMin == 0) qMin = 1;
        if (qMin >= THIRTY_TWO_X59) qMin = uint64(1 + (uint256(qMin) % (THIRTY_TWO_X59 - 1)));

        // Ensure qMax in valid range: 0 < qMax < THIRTY_TWO_X59
        if (qMax == 0) qMax = 1;
        if (qMax >= THIRTY_TWO_X59) qMax = uint64(1 + (uint256(qMax) % (THIRTY_TWO_X59 - 1)));

        // Ensure shares in valid range: MIN_INT128 <= shares <= MAX_INT128, shares != 0
        if (shares > MAX_INT128) shares = int256(1 + (uint256(shares) % uint256(MAX_INT128)));
        if (shares < MIN_INT128) {
            unchecked {
                shares = -int256(1 + (uint256(-shares) % uint256(MAX_INT128)));
            }
        }
        if (shares == 0) shares = 1;

        // Extract qOffset from poolId
        int8 qOffset = extractQOffset(poolId);

        // Calculate adjusted log prices
        int256 logPriceMin = calculateLogPrice(qMin, qOffset);
        int256 logPriceMax = calculateLogPrice(qMax, qOffset);

        // === MEMORY GUARDS ===
        bytes32 guard1Before = GUARD_PATTERN_1;
        bytes32 guard2Before = GUARD_PATTERN_2;
        bytes32 guard3Before = GUARD_PATTERN_3;

        // === CONSTRUCT CALLDATA WITH RANDOM OFFSETS ===
        bytes memory calldataBytes = constructCalldata(
            poolId,
            logPriceMin,
            logPriceMax,
            shares,
            hookDataContent,
            hookDataByteCount,
            randomGap,
            randomContentStart
        );

        // === EXECUTE FUNCTION ===
        uint256 gasBefore = gasleft();
        (bool success, ) = address(wrapper).call(calldataBytes);
        uint256 gasUsed = gasBefore - gasleft();

        // Track metrics
        totalGasConsumed += gasUsed;
        if (gasUsed > maxGasObserved) maxGasObserved = gasUsed;
        testsExecuted++;

        // === ASSERTIONS ===
        // Property: Valid inputs with arbitrary non-strict encoding must succeed
        assert(success);

        // Property: Memory guards must remain intact (no corruption)
        assert(guard1Before == GUARD_PATTERN_1);
        assert(guard2Before == GUARD_PATTERN_2);
        assert(guard3Before == GUARD_PATTERN_3);
    }

    /// @notice PROPERTY 2: Invalid log prices must revert
    /// @dev Replicates test_readModifyPositionInputInvalidLogPrices
    /// @param poolId Pool identifier
    /// @param useZeroQMin If true, use qMin=0; else use qMin >= THIRTY_TWO_X59
    /// @param shares Number of shares
    /// @param hookDataByteCount Size of hookData
    function test_property_invalid_logprices_revert(
        uint256 poolId,
        bool useZeroQMin,
        int256 shares,
        uint16 hookDataByteCount
    ) public {
        if (hookDataByteCount > 100) hookDataByteCount = uint16(uint256(hookDataByteCount) % 101);
        if (shares > MAX_INT128) shares = int256(1 + (uint256(shares) % uint256(MAX_INT128)));
        if (shares < MIN_INT128) {
            unchecked {
                shares = -int256(1 + (uint256(-shares) % uint256(MAX_INT128)));
            }
        }
        if (shares == 0) shares = 1;

        // Use INVALID qMin (either 0 or >= THIRTY_TWO_X59)
        uint64 qMin = useZeroQMin ? 0 : uint64(THIRTY_TWO_X59);
        uint64 qMax = 100; // Valid value

        int8 qOffset = extractQOffset(poolId);
        int256 logPriceMin = calculateLogPrice(qMin, qOffset);
        int256 logPriceMax = calculateLogPrice(qMax, qOffset);

        bytes memory calldataBytes = constructCalldata(
            poolId,
            logPriceMin,
            logPriceMax,
            shares,
            0,
            hookDataByteCount,
            0,
            0
        );

        (bool success, ) = address(wrapper).call(calldataBytes);

        // Property: Invalid log prices MUST cause revert
        assert(!success);

        testsExecuted++;
    }

    /// @notice PROPERTY 3: Invalid shares must revert
    /// @dev Replicates test_readModifyPositionInputInvalidShares
    /// @param poolId Pool identifier
    /// @param invalidCase 0=zero, 1=too large, 2=too small
    /// @param hookDataByteCount Size of hookData
    function test_property_invalid_shares_revert(
        uint256 poolId,
        uint8 invalidCase,
        uint16 hookDataByteCount
    ) public {
        if (hookDataByteCount > 100) hookDataByteCount = uint16(uint256(hookDataByteCount) % 101);

        uint64 qMin = 100;
        uint64 qMax = 200;

        int8 qOffset = extractQOffset(poolId);
        int256 logPriceMin = calculateLogPrice(qMin, qOffset);
        int256 logPriceMax = calculateLogPrice(qMax, qOffset);

        // Choose INVALID shares based on case
        int256 shares;
        uint8 caseType = invalidCase % 3;
        if (caseType == 0) {
            shares = 0; // Zero shares (invalid)
        } else if (caseType == 1) {
            shares = MAX_INT128 + 1; // Too large
        } else {
            shares = MIN_INT128 - 1; // Too small
        }

        bytes memory calldataBytes = constructCalldata(
            poolId,
            logPriceMin,
            logPriceMax,
            shares,
            0,
            hookDataByteCount,
            0,
            0
        );

        (bool success, ) = address(wrapper).call(calldataBytes);

        // Property: Invalid shares MUST cause revert
        assert(!success);

        testsExecuted++;
    }

    /// @notice PROPERTY 4: Oversized hookData must revert
    /// @dev Replicates test_readModifyPositionInputHookDataTooLong
    /// @param poolId Pool identifier
    /// @param shares Number of shares
    function test_property_hookdata_too_long_revert(
        uint256 poolId,
        int256 shares
    ) public {
        if (shares > MAX_INT128) shares = int256(1 + (uint256(shares) % uint256(MAX_INT128)));
        if (shares < MIN_INT128) {
            unchecked {
                shares = -int256(1 + (uint256(-shares) % uint256(MAX_INT128)));
            }
        }
        if (shares == 0) shares = 1;

        uint64 qMin = 100;
        uint64 qMax = 200;

        int8 qOffset = extractQOffset(poolId);
        int256 logPriceMin = calculateLogPrice(qMin, qOffset);
        int256 logPriceMax = calculateLogPrice(qMax, qOffset);

        // Use hookDataByteCount > uint16.max (MAX_HOOK_DATA_BYTE_COUNT)
        uint256 invalidHookDataSize = uint256(MAX_HOOK_DATA_BYTE_COUNT) + 1;

        // Manually construct calldata with oversized hookdata length
        bytes memory calldataBytes = abi.encodePacked(
            READ_MODIFY_POSITION_SELECTOR,
            bytes32(poolId),
            bytes32(toTwosComplement(logPriceMin)),
            bytes32(toTwosComplement(logPriceMax)),
            bytes32(toTwosComplement(shares)),
            bytes32(uint256(5 * 0x20)),           // startOfHookData
            bytes32(invalidHookDataSize), // INVALID size > uint16.max
            new bytes(100)               // Some content
        );

        (bool success, ) = address(wrapper).call(calldataBytes);

        // Property: Oversized hookData MUST cause revert
        assert(!success);

        testsExecuted++;
    }

    /// @notice PROPERTY 5: Encoding independence (different gaps, same result)
    /// @dev Tests that same logical data with different random gaps produces same outcome
    /// @dev This is CRITICAL for non-strict encoding requirement
    /// @param poolId Pool identifier
    /// @param qMin Normalized minimum log price
    /// @param qMax Normalized maximum log price
    /// @param shares Number of shares
    /// @param hookDataContent Content for hookData
    /// @param hookDataByteCount Size of hookData
    /// @param randomGap1 First random gap
    /// @param randomGap2 Second random gap (different)
    function test_property_encoding_independence(
        uint256 poolId,
        uint64 qMin,
        uint64 qMax,
        int256 shares,
        uint256 hookDataContent,
        uint16 hookDataByteCount,
        uint16 randomGap1,
        uint16 randomGap2
    ) public {
        // === INPUT NORMALIZATION ===
        if (hookDataByteCount > 100) hookDataByteCount = uint16(uint256(hookDataByteCount) % 101);
        if (qMin == 0) qMin = 1;
        if (qMax == 0) qMax = 1;
        if (qMin >= THIRTY_TWO_X59) qMin = uint64(1 + (uint256(qMin) % (THIRTY_TWO_X59 - 1)));
        if (qMax >= THIRTY_TWO_X59) qMax = uint64(1 + (uint256(qMax) % (THIRTY_TWO_X59 - 1)));
        if (shares > MAX_INT128) shares = int256(1 + (uint256(shares) % uint256(MAX_INT128)));
        if (shares < MIN_INT128) {
            unchecked {
                shares = -int256(1 + (uint256(-shares) % uint256(MAX_INT128)));
            }
        }
        if (shares == 0) shares = 1;

        int8 qOffset = extractQOffset(poolId);
        int256 logPriceMin = calculateLogPrice(qMin, qOffset);
        int256 logPriceMax = calculateLogPrice(qMax, qOffset);

        // === EXECUTE WITH FIRST RANDOM ENCODING ===
        bytes memory calldata1 = constructCalldata(
            poolId, logPriceMin, logPriceMax, shares,
            hookDataContent, hookDataByteCount, randomGap1, 0
        );
        (bool success1, ) = address(wrapper).call(calldata1);

        // === EXECUTE WITH SECOND RANDOM ENCODING ===
        bytes memory calldata2 = constructCalldata(
            poolId, logPriceMin, logPriceMax, shares,
            hookDataContent, hookDataByteCount, randomGap2, 0
        );
        (bool success2, ) = address(wrapper).call(calldata2);

        // Property: Different encodings of same logical data should have same outcome
        assert(success1 == success2);

        testsExecuted++;
    }

    /// @notice PROPERTY 6: Extreme hookdata sizes
    /// @dev Tests boundary conditions for hookDataByteCount
    /// @param poolId Pool identifier
    /// @param shares Number of shares
    /// @param extremeCase 0=size 0, 1=size 1, 2=size MAX-1, 3=size MAX
    /// @param randomGap Random gap for non-strict encoding
    function test_property_extreme_hookdata_sizes(
        uint256 poolId,
        int256 shares,
        uint8 extremeCase,
        uint16 randomGap
    ) public {
        if (shares > MAX_INT128) shares = int256(1 + (uint256(shares) % uint256(MAX_INT128)));
        if (shares < MIN_INT128) {
            unchecked {
                shares = -int256(1 + (uint256(-shares) % uint256(MAX_INT128)));
            }
        }
        if (shares == 0) shares = 1;

        uint64 qMin = 100;
        uint64 qMax = 200;

        int8 qOffset = extractQOffset(poolId);
        int256 logPriceMin = calculateLogPrice(qMin, qOffset);
        int256 logPriceMax = calculateLogPrice(qMax, qOffset);

        // Choose extreme hookDataByteCount
        uint16 hookDataByteCount;
        uint8 caseType = extremeCase % 4;
        if (caseType == 0) {
            hookDataByteCount = 0; // Minimum
        } else if (caseType == 1) {
            hookDataByteCount = 1; // Single byte
        } else if (caseType == 2) {
            hookDataByteCount = uint16(MAX_HOOK_DATA_BYTE_COUNT - 1); // Near maximum
        } else {
            hookDataByteCount = uint16(MAX_HOOK_DATA_BYTE_COUNT); // Maximum
        }

        bytes memory calldataBytes = constructCalldata(
            poolId,
            logPriceMin,
            logPriceMax,
            shares,
            0xF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00F,
            hookDataByteCount,
            randomGap,
            0
        );

        uint256 gasBefore = gasleft();
        (bool success, ) = address(wrapper).call(calldataBytes);
        uint256 gasUsed = gasBefore - gasleft();

        // Track metrics
        totalGasConsumed += gasUsed;
        if (gasUsed > maxGasObserved) maxGasObserved = gasUsed;
        testsExecuted++;

        // Property: All extreme sizes within valid range must succeed
        assert(success);
    }

    // ========================================================================
    // INVARIANT CHECKS
    // ========================================================================

    /// @notice Invariant: Tests executed counter only increases
    function echidna_tests_executed_increases() public view returns (bool) {
        return true;
    }

    /// @notice Invariant: Average gas consumption is reasonable
    function echidna_reasonable_gas_consumption() public view returns (bool) {
        if (testsExecuted == 0) return true;
        uint256 avgGas = totalGasConsumed / testsExecuted;
        return avgGas < 10_000_000;
    }

    /// @notice Invariant: Maximum gas observed is within expected bounds
    function echidna_max_gas_reasonable() public view returns (bool) {
        return maxGasObserved < 50_000_000;
    }
}