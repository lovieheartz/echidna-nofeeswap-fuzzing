#!/bin/bash

# Run Echidna SANITY CHECK test for Price.sol
# This test contains DELIBERATE BUGS to verify Echidna catches them
# Usage: ./run_sanity_check.sh

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          SANITY CHECK - DELIBERATE BUG TEST                    ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "⚠️  WARNING: This test is SUPPOSED to FAIL!"
echo "⚠️  It contains intentional bugs to verify Echidna catches them."
echo ""
echo "Expected failures:"
echo "  1. echidna_test_wrong_assertion - Accepts wrong value for 0x1234ABCD"
echo "  2. echidna_test_memory_corruption - Deliberately corrupts memory"
echo "  3. echidna_test_offbyone_error - Allows off-by-one errors"
echo ""
echo "If Echidna finds these bugs quickly, it proves our tests work!"
echo "=============================================="
echo ""

# Create corpus directory if it doesn't exist
mkdir -p corpus-sanity

# Run echidna with the sanity check configuration
echo "Running Echidna (this should find bugs quickly)..."
echidna echidna/PriceTestSanityCheck.sol --contract PriceTestSanityCheck --config echidna/echidna.config.PriceSanityCheck.yml

echo ""
echo "=============================================="
echo "✅ Sanity check completed!"
echo ""
echo "If you saw failures (red X marks), that's GOOD - it means:"
echo "  ✓ Echidna successfully detected the deliberate bugs"
echo "  ✓ Our property tests are effective at catching errors"
echo "  ✓ The fuzzing infrastructure is working correctly"
echo ""
echo "Now you can confidently run the real tests knowing they work!"