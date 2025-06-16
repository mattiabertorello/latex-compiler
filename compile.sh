  #!/bin/bash

  set -e

  # Colors for output
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  NC='\033[0m' # No Color

  # Default values
  INPUT_FILE="main.tex"
  OUTPUT_DIR="."
  CLEAN=false

  # Function to display usage
  usage() {
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  -i, --input FILE     Input LaTeX file (default: main.tex)"
      echo "  -o, --output DIR     Output directory (default: current directory)"
      echo "  -c, --clean          Clean auxiliary files after compilation"
      echo "  -h, --help           Display this help message"
      exit 1
  }

  # Function to clean auxiliary files
  clean_files() {
      local base_name=$(basename "$INPUT_FILE" .tex)
      echo -e "${YELLOW}Cleaning auxiliary files...${NC}"
      rm -f "$base_name.aux" "$base_name.log" "$base_name.out" "$base_name.fls" "$base_name.fdb_latexmk" "$base_name.synctex.gz"
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
              CLEAN=true
              shift
              ;;
          -h|--help)
              usage
              ;;
          *)
              echo -e "${RED}Unknown option: $1${NC}"
              usage
              ;;
      esac
  done

  # Check if input file exists
  if [[ ! -f "$INPUT_FILE" ]]; then
      echo -e "${RED}Error: Input file '$INPUT_FILE' not found${NC}"
      exit 1
  fi

  # Create output directory if it doesn't exist
  mkdir -p "$OUTPUT_DIR"

  # Get base name without extension
  BASE_NAME=$(basename "$INPUT_FILE" .tex)

  echo -e "${GREEN}Compiling LaTeX document: $INPUT_FILE${NC}"

  # First compilation pass
  echo -e "${YELLOW}Running first pdflatex pass...${NC}"
  if ! pdflatex -interaction=nonstopmode -output-directory="$OUTPUT_DIR" "$INPUT_FILE"; then
      echo -e "${RED}Error: First compilation pass failed${NC}"
      exit 1
  fi

  # Second compilation pass (for references, TOC, etc.)
  echo -e "${YELLOW}Running second pdflatex pass...${NC}"
  if ! pdflatex -interaction=nonstopmode -output-directory="$OUTPUT_DIR" "$INPUT_FILE"; then
      echo -e "${RED}Error: Second compilation pass failed${NC}"
      exit 1
  fi

  # Check if PDF was generated
  PDF_FILE="$OUTPUT_DIR/$BASE_NAME.pdf"
  if [[ -f "$PDF_FILE" ]]; then
      echo -e "${GREEN}✓ Compilation successful!${NC}"
      echo -e "${GREEN}PDF generated: $PDF_FILE${NC}"
  else
      echo -e "${RED}Error: PDF file was not generated${NC}"
      exit 1
  fi

  # Clean auxiliary files if requested
  if [[ "$CLEAN" == true ]]; then
      clean_files
  fi

  echo -e "${GREEN}Done!${NC}"
