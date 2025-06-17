#!/bin/bash

# LaTeX compilation helper script
set -e

# Default values
INPUT_FILE="main.tex"
OUTPUT_DIR="."
CLEAN_FILES=false
COMPILER="pdflatex"

# Function to display help
show_help() {
    cat << EOF
LaTeX Compilation Helper Script

Usage: compile.sh [OPTIONS]

Options:
    -i, --input FILE     Input LaTeX file (default: main.tex)
    -o, --output DIR     Output directory (default: current directory)
    -c, --clean          Clean auxiliary files after compilation
    -e, --engine ENGINE  LaTeX engine (pdflatex, xelatex, lualatex) (default: pdflatex)
    -h, --help           Display this help message

Examples:
    compile.sh -i document.tex -c
    compile.sh --input report.tex --output ./build --clean
    compile.sh -i thesis.tex -e xelatex
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--input)
            INPUT_FILE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -c|--clean)
            CLEAN_FILES=true
            shift
            ;;
        -e|--engine)
            COMPILER="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check if input file exists
if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: Input file '$INPUT_FILE' not found!"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Get the base name without extension
BASENAME=$(basename "$INPUT_FILE" .tex)

echo "Compiling $INPUT_FILE with $COMPILER..."

# Compile the document
if [[ "$OUTPUT_DIR" != "." ]]; then
    $COMPILER -output-directory="$OUTPUT_DIR" "$INPUT_FILE"
else
    $COMPILER "$INPUT_FILE"
fi

# Clean auxiliary files if requested
if [[ "$CLEAN_FILES" == true ]]; then
    echo "Cleaning auxiliary files..."
    rm -f "$OUTPUT_DIR/$BASENAME".{aux,log,out,toc,lof,lot,fls,fdb_latexmk,synctex.gz,bbl,blg,idx,ind,ilg,glo,gls,glg,acn,acr,alg}
fi

echo "Compilation completed successfully!"
