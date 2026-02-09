#!/bin/bash

# Run Echidna Test for Question 2: readModifyPositionInput with Non-Strict Encoding
# This script runs the property-based fuzzing tests for the Calldata.sol readModifyPositionInput function

set -e

echo "=========================================="
echo "Question 2: Calldata readModifyPositionInput Fuzzing Test"
echo "=========================================="
echo ""

# Navigate to the echidna directory
cd "$(dirname "$0")"

echo "Current directory: $(pwd)"
echo ""

# Check if echidna is installed
if ! command -v echidna &> /dev/null; then
    echo "ERROR: Echidna is not installed or not in PATH"
    echo "Please install Echidna: https://github.com/crytic/echidna"
    exit 1
fi

echo "Echidna version:"
echidna --version
echo ""

# Check if solc is installed
if ! command -v solc &> /dev/null; then
    echo "ERROR: Solidity compiler (solc) is not installed or not in PATH"
    exit 1
fi

echo "Solidity compiler version:"
solc --version | grep Version
echo ""

# Clean previous corpus if exists
if [ -d "./corpus-calldata" ]; then
    echo "Cleaning previous corpus directory..."
    rm -rf ./corpus-calldata
fi

echo "Creating corpus directory..."
mkdir -p ./corpus-calldata
echo ""

# Run Echidna with the configuration file
echo "=========================================="
echo "Running Echidna Fuzzing Tests..."
echo "=========================================="
echo ""
echo "Test Configuration:"
echo "  - Test Mode: Assertion"
echo "  - Test Limit: 50,000 sequences"
echo "  - Sequence Length: 20 transactions"
echo "  - Workers: 4"
echo "  - Coverage: Enabled"
echo "  - Corpus Directory: ./corpus-calldata"
echo ""
echo "Key Test Focus:"
echo "  1. Random hookdata offsets (non-strict encoding)"
echo "  2. Random content starting positions"
echo "  3. Edge cases for log prices, shares, hookDataByteCount"
echo "  4. Encoding independence verification"
echo ""

# Store start time
START_TIME=$(date +%s)

# Run Echidna and save output to log file
echidna CalldataTestIndustryGrade.sol \
    --config echidna.config.calldata.yml \
    --contract CalldataTestIndustryGrade \
    --corpus-dir ./corpus-calldata \
    2>&1 | tee ../echidna_calldata_run.log

# Calculate elapsed time
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo ""
echo "=========================================="
echo "Test Execution Complete"
echo "=========================================="
echo ""
echo "Elapsed Time: ${ELAPSED} seconds"
echo ""
echo "Results Summary:"
echo "  - Log file: ../echidna_calldata_run.log"
echo "  - Corpus directory: ./corpus-calldata"
echo "  - Coverage reports: ./corpus-calldata/coverage/"
echo "  - Reproducers (if any failures): ./corpus-calldata/reproducers/"
echo ""

# Check if corpus directory was created and has content
if [ -d "./corpus-calldata/coverage" ]; then
    CORPUS_COUNT=$(ls -1 ./corpus-calldata/coverage 2>/dev/null | wc -l)
    echo "Corpus test cases generated: ${CORPUS_COUNT}"
fi

if [ -d "./corpus-calldata/reproducers" ]; then
    REPRO_COUNT=$(ls -1 ./corpus-calldata/reproducers 2>/dev/null | wc -l)
    if [ ${REPRO_COUNT} -gt 0 ]; then
        echo "⚠️  Failed test cases found: ${REPRO_COUNT}"
        echo "   See ./corpus-calldata/reproducers/ for details"
    else
        echo "✓ No failures found - all properties passed!"
    fi
fi

echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo "1. Review the log file: ../echidna_calldata_run.log"
echo "2. Check corpus for interesting test cases"
echo "3. Review coverage reports in ./corpus-calldata/coverage/"
echo "4. If failures exist, analyze reproducers"
echo ""
