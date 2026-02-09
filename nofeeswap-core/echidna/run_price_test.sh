#!/bin/bash

# Run Echidna test for Price.sol
# Usage: ./run_price_test.sh

echo "Running Echidna fuzzing test for Price.sol..."
echo "=============================================="
echo ""
echo "Test configuration:"
echo "  - Test mode: assertion"
echo "  - Corpus directory: ./corpus/"
echo "  - Test limit: 1,000,000,000 sequences"
echo "  - Coverage tracking: enabled"
echo ""
echo "This test will:"
echo "  1. Fuzz the storePrice function with random inputs"
echo "  2. Verify values are correctly stored and retrieved"
echo "  3. Check for memory corruption in surrounding memory space"
echo "  4. Test at random pointer locations in memory"
echo ""

# Create corpus directory if it doesn't exist
mkdir -p corpus

# Run echidna with the Price test configuration
echidna echidna/PriceTest.sol --contract EchidnaPriceTest --config echidna/echidna.config.Price.yml

echo ""
echo "=============================================="
echo "Test completed!"
echo "Check corpus/ directory for coverage information"