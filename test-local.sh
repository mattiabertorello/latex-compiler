#!/usr/bin/env bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
REGISTRY="ghcr.io"
IMAGE_NAME="latex-compiler"
LOCAL_TAG_PREFIX="local-test"
TEST_RESULTS_DIR="test-results"
BUILD_LOGS_DIR="build-logs"

# Test suites configuration
declare -A VARIANTS=(
    ["minimal"]="texlive-packages-minimal.txt:apt-packages-minimal.txt:basic,minimal,standard"
    ["standard"]="texlive-packages-standard.txt:apt-packages-standard.txt:basic,standard"
    ["full"]="texlive-packages-full.txt:apt-packages-full.txt:basic,minimal,full,advanced"
)

# Functions
print_header() {
    echo -e "${CYAN}================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}================================${NC}"
}

print_step() {
    echo -e "${BLUE}➤ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

cleanup() {
    print_step "Cleaning up temporary files..."
    # Clean up any temporary LaTeX files
    find . -name "*.aux" -o -name "*.log" -o -name "*.out" -o -name "*.fls" -o -name "*.fdb_latexmk" -o -name "*.synctex.gz" | xargs rm -f 2>/dev/null || true
}

# Trap cleanup on exit
trap cleanup EXIT

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -v, --variant VARIANT    Test specific variant (minimal|full|all) [default: all]"
    echo "  -s, --suite SUITE        Test specific suite (basic|minimal|full|advanced|all) [default: all]"
    echo "  -b, --build-only         Only build images, don't run tests"
    echo "  -t, --test-only          Only run tests, don't build images"
    echo "  -c, --clean              Clean up previous results before running"
    echo "  -k, --keep-pdfs          Keep generated PDF files"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                       # Build and test all variants"
    echo "  $0 -v minimal            # Test only minimal variant"
    echo "  $0 -s basic              # Test only basic suite on all variants"
    echo "  $0 -v full -s advanced   # Test advanced suite on full variant only"
    echo "  $0 -b                    # Only build images"
    echo "  $0 -t                    # Only test (assumes images exist)"
    exit 1
}

check_dependencies() {
    print_step "Checking dependencies..."

    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running or not accessible"
        exit 1
    fi

    print_success "All dependencies satisfied"
}

build_image() {
    local variant=$1
    local texlive_packages=$2
    local apt_packages=$3
    local image_tag="${LOCAL_TAG_PREFIX}-${variant}"

    print_step "Building ${variant} variant..."

    mkdir -p "${BUILD_LOGS_DIR}"
    local log_file="${BUILD_LOGS_DIR}/build-${variant}.log"

    if docker build \
        --build-arg PACKAGE_LIST="${texlive_packages}" \
        --build-arg APT_PACKAGES="${apt_packages}" \
        -t "${image_tag}" \
        . > "${log_file}" 2>&1; then
        print_success "Built ${variant} variant successfully"
        return 0
    else
        print_error "Failed to build ${variant} variant"
        echo -e "${RED}Build log (last 20 lines):${NC}"
        tail -50 "${log_file}"
        return 1
    fi
}

run_test_suite() {
    local variant=$1
    local suite=$2
    local image_tag="${LOCAL_TAG_PREFIX}-${variant}"

    print_step "Running ${suite} tests on ${variant} variant..."

    # Check if test suite directory exists
    if [ ! -d "tests/${suite}" ]; then
        print_warning "Test suite directory tests/${suite} not found, skipping"
        return 0
    fi

    # Create results directory
    local results_dir="${TEST_RESULTS_DIR}/${variant}/${suite}"
    mkdir -p "${results_dir}"

    local test_count=0
    local passed_count=0
    local failed_tests=()

    # Find all .tex files in the test suite
    for tex_file in tests/${suite}/*.tex; do
        if [ -f "$tex_file" ]; then
            test_count=$((test_count + 1))
            local base_name=$(basename "$tex_file" .tex)
            local test_name="${suite}/${base_name}"

            print_step "  Testing: ${test_name}"

            # Copy test file to working directory
            cp "$tex_file" ./

            # Copy any additional files (assets)
            if [ -d "tests/${suite}/assets" ]; then
                cp -r tests/${suite}/assets/* ./ 2>/dev/null || true
            fi

            # Run compilation with timeout
            local compile_log="${results_dir}/${base_name}-compile.log"
            if docker run --rm -v $(pwd):/data "${image_tag}" \
               bash -c "timeout 300 /usr/local/bin/compile.sh -i ${base_name}.tex -c || exit 1" > "${compile_log}" 2>&1; then
                # Check if PDF was generated
                if [ -f "${base_name}.pdf" ]; then
                    print_success "    ✅ ${test_name} - PDF generated"
                    passed_count=$((passed_count + 1))

                    # Move PDF to results directory if keeping PDFs
                    if [ "$KEEP_PDFS" = true ]; then
                        mv "${base_name}.pdf" "${results_dir}/${base_name}.pdf"
                    else
                        rm -f "${base_name}.pdf"
                    fi
                else
                    print_error "    ❌ ${test_name} - No PDF generated"
                    failed_tests+=("${test_name} (no PDF)")
                fi
            else
                print_error "    ❌ ${test_name} - Compilation failed"
                failed_tests+=("${test_name} (compilation error)")

                # Show last few lines of error log
                echo -e "${RED}    Last 5 lines of error log:${NC}"
                tail -5 "${compile_log}" | sed 's/^/      /'
            fi

            # Clean up temporary files
            rm -f "${base_name}.tex"
            rm -f *.aux *.log *.out *.fls *.fdb_latexmk *.synctex.gz 2>/dev/null || true

            # Clean up copied assets
            if [ -d "tests/${suite}/assets" ]; then
                # Remove files that were copied from assets
                find tests/${suite}/assets -type f -exec basename {} \; | while read file; do
                    rm -f "$file" 2>/dev/null || true
                done
            fi
        fi
    done

    # Summary for this test suite
    if [ $test_count -eq 0 ]; then
        print_warning "  No tests found in ${suite} suite"
    elif [ $passed_count -eq $test_count ]; then
        print_success "  All ${test_count} tests passed in ${suite} suite"
    else
        local failed_count=$((test_count - passed_count))
        print_error "  ${failed_count}/${test_count} tests failed in ${suite} suite"
        for failed_test in "${failed_tests[@]}"; do
            echo -e "${RED}    - ${failed_test}${NC}"
        done
        return 1
    fi

    return 0
}

run_tests() {
    local variant=$1
    local test_suites=$2
    local image_tag="${LOCAL_TAG_PREFIX}-${variant}"

    print_step "Testing ${variant} variant with suites: ${test_suites}"

    # Check if image exists
    if ! docker image inspect "${image_tag}" &> /dev/null; then
        print_error "Image ${image_tag} not found. Build it first or run with -b flag."
        return 1
    fi

    # Test basic functionality first
    print_step "Testing basic image functionality..."
    if ! docker run --rm "${image_tag}" bash -c "echo 'Image is working'"; then
        print_error "Basic image test failed"
        return 1
    fi

    local total_suites=0
    local passed_suites=0

    # Split test suites by comma and run each
    IFS=',' read -ra SUITES <<< "$test_suites"
    for suite in "${SUITES[@]}"; do
        total_suites=$((total_suites + 1))
        if run_test_suite "$variant" "$suite"; then
            passed_suites=$((passed_suites + 1))
        fi
    done

    # Variant summary
    if [ $passed_suites -eq $total_suites ]; then
        print_success "All test suites passed for ${variant} variant"
        return 0
    else
        local failed_suites=$((total_suites - passed_suites))
        print_error "${failed_suites}/${total_suites} test suites failed for ${variant} variant"
        return 1
    fi
}

generate_report() {
    print_header "Test Report"

    local report_file="${TEST_RESULTS_DIR}/test-report.md"
    mkdir -p "${TEST_RESULTS_DIR}"

    cat > "$report_file" << EOF
# LaTeX Compiler Test Report

**Date:** $(date)
**Script:** $0
**Arguments:** $@

## Test Results Summary

EOF

    local total_variants=0
    local passed_variants=0

    for variant in "${!VARIANTS[@]}"; do
        if [ "$TARGET_VARIANT" != "all" ] && [ "$TARGET_VARIANT" != "$variant" ]; then
            continue
        fi

        total_variants=$((total_variants + 1))

        echo "### ${variant^} Variant" >> "$report_file"
        echo "" >> "$report_file"

        if [ -d "${TEST_RESULTS_DIR}/${variant}" ]; then
            passed_variants=$((passed_variants + 1))
            echo "✅ **Status:** PASSED" >> "$report_file"

            # List generated PDFs if any
            if [ "$KEEP_PDFS" = true ]; then
                echo "" >> "$report_file"
                echo "**Generated PDFs:**" >> "$report_file"
                find "${TEST_RESULTS_DIR}/${variant}" -name "*.pdf" | while read pdf; do
                    echo "- $(basename "$pdf")" >> "$report_file"
                done
            fi
        else
            echo "❌ **Status:** FAILED" >> "$report_file"
        fi

        echo "" >> "$report_file"
    done

    echo "## Overall Summary" >> "$report_file"
    echo "" >> "$report_file"
    echo "- **Total Variants Tested:** $total_variants" >> "$report_file"
    echo "- **Passed:** $passed_variants" >> "$report_file"
    echo "- **Failed:** $((total_variants - passed_variants))" >> "$report_file"

    print_success "Test report generated: $report_file"
}

# Parse command line arguments
TARGET_VARIANT="all"
TARGET_SUITE="all"
BUILD_ONLY=false
TEST_ONLY=false
CLEAN=false
KEEP_PDFS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--variant)
            TARGET_VARIANT="$2"
            shift 2
            ;;
        -s|--suite)
            TARGET_SUITE="$2"
            shift 2
            ;;
        -b|--build-only)
            BUILD_ONLY=true
            shift
            ;;
        -t|--test-only)
            TEST_ONLY=true
            shift
            ;;
        -c|--clean)
            CLEAN=true
            shift
            ;;
        -k|--keep-pdfs)
            KEEP_PDFS=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate arguments
if [ "$TARGET_VARIANT" != "all" ] && [ "$TARGET_VARIANT" != "minimal" ] && [ "$TARGET_VARIANT" != "full" ]; then
    print_error "Invalid variant: $TARGET_VARIANT. Must be 'minimal', 'full', or 'all'"
    exit 1
fi

if [ "$TARGET_SUITE" != "all" ] && [ "$TARGET_SUITE" != "basic" ] && [ "$TARGET_SUITE" != "minimal" ] && [ "$TARGET_SUITE" != "full" ] && [ "$TARGET_SUITE" != "advanced" ]; then
    print_error "Invalid suite: $TARGET_SUITE. Must be 'basic', 'minimal', 'full', 'advanced', or 'all'"
    exit 1
fi

# Main execution
print_header "LaTeX Compiler Local Test Script"

check_dependencies

# Clean up previous results if requested
if [ "$CLEAN" = true ]; then
    print_step "Cleaning up previous results..."
    rm -rf "${TEST_RESULTS_DIR}" "${BUILD_LOGS_DIR}"
    print_success "Cleanup completed"
fi

# Create directories
mkdir -p "${TEST_RESULTS_DIR}" "${BUILD_LOGS_DIR}"

# Build phase
if [ "$TEST_ONLY" = false ]; then
    print_header "Building Docker Images"

    build_failed=false
    for variant in "${!VARIANTS[@]}"; do
        if [ "$TARGET_VARIANT" != "all" ] && [ "$TARGET_VARIANT" != "$variant" ]; then
            continue
        fi

        IFS=':' read -ra CONFIG <<< "${VARIANTS[$variant]}"
        texlive_packages="${CONFIG[0]}"
        apt_packages="${CONFIG[1]}"

        if ! build_image "$variant" "$texlive_packages" "$apt_packages"; then
            build_failed=true
        fi
    done

    if [ "$build_failed" = true ]; then
        print_error "Some builds failed. Check build logs in ${BUILD_LOGS_DIR}/"
        exit 1
    fi

    print_success "All images built successfully"
fi

# Test phase
if [ "$BUILD_ONLY" = false ]; then
    print_header "Running Tests"

    test_failed=false
    for variant in "${!VARIANTS[@]}"; do
        if [ "$TARGET_VARIANT" != "all" ] && [ "$TARGET_VARIANT" != "$variant" ]; then
            continue
        fi

        IFS=':' read -ra CONFIG <<< "${VARIANTS[$variant]}"
        available_suites="${CONFIG[2]}"

        # Determine which suites to run
        if [ "$TARGET_SUITE" = "all" ]; then
            test_suites="$available_suites"
        else
            # Check if target suite is available for this variant
            if [[ ",$available_suites," == *",$TARGET_SUITE,"* ]]; then
                test_suites="$TARGET_SUITE"
            else
                print_warning "Suite '$TARGET_SUITE' not available for variant '$variant', skipping"
                continue
            fi
        fi

        if ! run_tests "$variant" "$test_suites"; then
            test_failed=true
        fi
    done

    if [ "$test_failed" = true ]; then
        print_error "Some tests failed. Check test results in ${TEST_RESULTS_DIR}/"
        generate_report
        exit 1
    fi

    print_success "All tests passed successfully"
fi

# Generate report
generate_report

print_header "Test Completed Successfully"
print_success "Results available in: ${TEST_RESULTS_DIR}/"
if [ "$KEEP_PDFS" = true ]; then
    print_success "Generated PDFs saved in test results directories"
fi

# Show quick summary
echo ""
echo -e "${CYAN}Quick Summary:${NC}"
if [ "$BUILD_ONLY" = false ]; then
    total_pdfs=$(find "${TEST_RESULTS_DIR}" -name "*.pdf" 2>/dev/null | wc -l)
    total_logs=$(find "${TEST_RESULTS_DIR}" -name "*-compile.log" 2>/dev/null | wc -l)
    echo -e "  📄 Test files processed: ${total_logs}"
    if [ "$KEEP_PDFS" = true ]; then
        echo -e "  📋 PDFs generated: ${total_pdfs}"
    fi
fi

if [ "$TEST_ONLY" = false ]; then
    echo -e "  🐳 Docker images built: $(docker images --filter "reference=${LOCAL_TAG_PREFIX}-*" --format "table {{.Repository}}:{{.Tag}}" | tail -n +2 | wc -l)"
fi