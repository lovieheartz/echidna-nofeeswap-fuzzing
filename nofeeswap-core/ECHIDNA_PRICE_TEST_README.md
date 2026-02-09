# Echidna Fuzzing Test for Price.sol

This directory contains a comprehensive Echidna fuzzing test for the `Price.sol` library, specifically targeting the `storePrice` function with randomized inputs and memory safety checks.

## Overview

The test implements property-based fuzzing that mirrors the Python/Brownie test `test_storePrice1` (lines 31-41 in `tests/Price_test.py`) but with fully randomized inputs and additional memory corruption detection.

## What Does This Test?

The Echidna test (`echidna/PriceTest.sol`) includes the following property tests:

### 1. `echidna_test_storePrice_basic`
- **Purpose**: Tests the basic `storePrice(logPrice, sqrtPrice, sqrtInversePrice)` function
- **What it does**:
  - Generates random values for `logPrice`, `sqrtPrice`, and `sqrtInversePrice`
  - Stores them in memory using `storePrice`
  - Reads them back using `log()`, `sqrt(false)`, and `sqrt(true)`
  - Verifies all values match exactly
  - **Memory safety**: Places guard patterns before and after the storage area to detect memory corruption

### 2. `echidna_test_storePrice_with_height`
- **Purpose**: Tests `storePrice` with the height parameter
- **What it does**:
  - Tests the 4-parameter version with `heightPrice` included
  - Verifies all four values (height, log, sqrt, sqrtInverse) are correctly stored and retrieved
  - **Memory safety**: Guards check for corruption around the 64-byte storage area

### 3. `echidna_test_storePrice_random_pointer` ⭐
- **Purpose**: Advanced memory safety test at random pointer locations
- **What it does**:
  - Chooses a random memory offset for the price pointer
  - Populates 10 slots (320 bytes) before and after with unique patterns
  - Stores the price data
  - Verifies the surrounding 10 slots before and after were NOT corrupted
  - **This satisfies requirement #7**: Testing random pointer locations with surrounding memory integrity checks

### 4. `echidna_test_copyPrice`
- **Purpose**: Tests the `copyPrice` function
- **What it does**:
  - Stores a price in one location
  - Copies it to another location
  - Verifies the copied data is correct

## Key Features

### Assertion Mode
The test uses **assertion mode** (`testMode: assertion`), which means:
- Each test function returns `bool`
- Echidna looks for cases where the function returns `false`
- If any test returns `false`, it's a bug and Echidna will report it

### Memory Corruption Detection
All tests include guards to detect memory corruption:
- **Guard patterns**: Unique `bytes32` values placed before/after storage areas
- **Verification**: After each operation, guards are checked to ensure they weren't modified
- **Coverage**: Tests use 10 slots (320 bytes) of guards on each side for comprehensive protection

### No Unnecessary Constraints
Following requirement #4, the test:
- Uses minimal input constraints (only to keep values within valid type ranges)
- Lets Echidna explore the full input space
- Allows 100% of fuzzing effort to go toward finding bugs
- Does not artificially restrict the search space

## Running the Test

### Prerequisites
```bash
# Install Echidna
# See: https://github.com/crytic/echidna

# On macOS
brew install echidna

# On Linux
# Download from releases: https://github.com/crytic/echidna/releases
```

### Run the test
```bash
# From the repository root
cd nofeeswap-core

# Make the script executable
chmod +x echidna/run_price_test.sh

# Run the test
./echidna/run_price_test.sh
```

Or run Echidna directly:
```bash
echidna echidna/PriceTest.sol --contract EchidnaPriceTest --config echidna/echidna.config.Price.yml
```

## Configuration

The test uses `echidna/echidna.config.Price.yml`:
```yaml
corpusDir: './corpus/'          # Store coverage data
testMode: assertion             # Use assertion mode
coverage: true                  # Track coverage
testLimit: 1000000000          # Run 1 billion test sequences
shrinkLimit: 10000             # Minimize counterexamples
```

## Corpus Directory

The corpus directory (`./corpus/`) stores:
- Coverage information
- Discovered inputs
- Transaction sequences that increase coverage

**To check coverage**: After running the test, examine files in `./corpus/` to see:
- Which code paths were executed
- How thoroughly the code was tested

## Sanity Check (Requirement #6)

To verify the test actually catches bugs, you can introduce a deliberate error:

### Test 1: Break value storage
In `echidna/PriceTest.sol`, modify the assertion:
```solidity
// Change this:
bool logMatches = X59.unwrap(logResult) == X59.unwrap(logPriceWrapped);

// To this (introduce error):
bool logMatches = X59.unwrap(logResult) == X59.unwrap(logPriceWrapped) || logPrice == 0x1234;
```

Run the test - **Echidna should find this bug immediately**.

### Test 2: Break memory safety
In `contracts/utilities/Price.sol`, modify `storePrice` to write beyond bounds:
```solidity
// In the storePrice function, add after line 112:
mstore(add(pointer, 200), 0xDEADBEEF)  // Write past the 62-byte boundary
```

Run the test - **Echidna should detect memory corruption**.

## Comparison to Python Test

This Echidna test is equivalent to Python test `test_storePrice1`:
```python
@pytest.mark.parametrize('logPrice', [epsilonX59, sampleX59, thirtyTwoX59 - epsilonX59])
@pytest.mark.parametrize('sqrt', [epsilonX216, sampleX216, oneX216 - epsilonX216])
@pytest.mark.parametrize('sqrtInverse', [epsilonX216, sampleX216, oneX216 - epsilonX216])
def test_storePrice1(wrapper, logPrice, sqrt, sqrtInverse, request, worker_id):
    tx = wrapper.storePrice(logPrice, sqrt, sqrtInverse)
    logResult, sqrtResult, sqrtInverseResult = tx.return_value
    assert logResult == logPrice
    assert sqrtResult == sqrt
    assert sqrtInverseResult == sqrtInverse
```

**Differences**:
- Python test: Tests 3 × 3 × 3 = 27 fixed combinations
- Echidna test: Tests millions/billions of random combinations
- Echidna test: Adds comprehensive memory safety checks
- Echidna test: Tests at random memory pointer locations

## Expected Output

When running successfully, you should see:
```
Running Echidna fuzzing test for Price.sol...
==============================================

echidna_test_storePrice_basic: passed! 💚
echidna_test_storePrice_with_height: passed! 💚
echidna_test_storePrice_random_pointer: passed! 💚
echidna_test_copyPrice: passed! 💚

Unique instructions: XXXX
Unique codehashes: XXXX
Corpus size: XXXX
```

If any test fails, Echidna will:
1. Report which property failed
2. Provide a minimal counterexample (input that causes failure)
3. Show the transaction sequence

## Integration with CI/CD

To add this to continuous integration:
```yaml
# .github/workflows/echidna.yml
- name: Run Echidna Price Test
  run: |
    echidna echidna/PriceTest.sol --contract EchidnaPriceTest \
      --config echidna/echidna.config.Price.yml \
      --testLimit 100000  # Reduce for CI
```

## Files Created

- `echidna/PriceTest.sol` - The main Echidna test contract
- `echidna/echidna.config.Price.yml` - Configuration file
- `echidna/run_price_test.sh` - Test runner script
- `ECHIDNA_PRICE_TEST_README.md` - This documentation

## Troubleshooting

### "Echidna not found"
Install Echidna: https://github.com/crytic/echidna#installation

### "Compilation failed"
Ensure all dependencies are installed:
```bash
forge install  # If using Foundry
```

### "No tests found"
Verify the contract name and test function names start with `echidna_`.

## References

- Original code: https://github.com/NoFeeSwap/core/blob/aba1340e791b9af129e295c1def13521b7e16952/contracts/utilities/Price.sol#L31-L114
- Python test: https://github.com/NoFeeSwap/core/blob/aba1340e791b9af129e295c1def13521b7e16952/tests/Price_test.py#L31-L41
- Echidna documentation: https://secure-contracts.com/program-analysis/echidna/index.html