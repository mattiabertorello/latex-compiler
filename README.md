# LaTeX Compiler Docker Image

A Docker image for compiling LaTeX documents with TeX Live, designed to be lightweight yet comprehensive for most LaTeX compilation needs.

## Features

- **Ubuntu-based** with latest TeX Live installation
- **Multi-architecture support** (linux/amd64, linux/arm64)
- **Configurable package sets** (minimal, standard, full)
- **Built-in compilation helper script** with advanced features
- **Automated builds** via GitHub Actions
- **Non-root user** for security
- **Volume support** for easy file access

## Quick Start

### Pull the Image

```bash
docker pull ghcr.io/[your-username]/latex-compiler:latest
```

### Basic Usage

Compile a LaTeX document in your current directory:

```bash
# Using the built-in helper script (recommended)
docker run --rm -v $(pwd):/data ghcr.io/[your-username]/latex-compiler:latest compile.sh

# Using pdflatex directly
docker run --rm -v $(pwd):/data ghcr.io/[your-username]/latex-compiler:latest pdflatex main.tex
```

## Usage Examples

### Using the Built-in Helper Script (Recommended)

The image includes a `compile.sh` script with advanced features and error handling:

```bash
# Basic compilation (compiles main.tex by default)
docker run --rm -v $(pwd):/data ghcr.io/[your-username]/latex-compiler:latest compile.sh

# Specify input file and clean auxiliary files
docker run --rm -v $(pwd):/data ghcr.io/[your-username]/latex-compiler:latest compile.sh -i document.tex -c

# Specify output directory
docker run --rm -v $(pwd):/data ghcr.io/[your-username]/latex-compiler:latest compile.sh -o output/

# Compile with cleanup (removes .aux, .log, .out files)
docker run --rm -v $(pwd):/data ghcr.io/[your-username]/latex-compiler:latest compile.sh -c

# Show help for the helper script
docker run --rm -v $(pwd):/data ghcr.io/[your-username]/latex-compiler:latest compile.sh -h
```

**Helper Script Features:**
- ✅ **Automatic two-pass compilation** for references and TOC
- ✅ **Colored output** for better readability
- ✅ **Error handling** with clear error messages
- ✅ **Automatic cleanup** option for auxiliary files
- ✅ **Flexible input/output** directory specification
- ✅ **Success verification** ensures PDF generation

### Direct LaTeX Commands

For more control or specific engines:

```bash
# Basic PDF compilation
docker run --rm -v $(pwd):/data ghcr.io/[your-username]/latex-compiler:latest pdflatex main.tex

# XeLaTeX (for advanced font support)
docker run --rm -v $(pwd):/data ghcr.io/[your-username]/latex-compiler:latest xelatex main.tex

# LuaLaTeX (for Lua scripting support)
docker run --rm -v $(pwd):/data ghcr.io/[your-username]/latex-compiler:latest lualatex main.tex

# Multiple passes for references/bibliography
docker run --rm -v $(pwd):/data ghcr.io/[your-username]/latex-compiler:latest bash -c "pdflatex main.tex && pdflatex main.tex"
```

### Using latexmk

```bash
# Automatic compilation with dependency tracking
docker run --rm -v $(pwd):/data ghcr.io/[your-username]/latex-compiler:latest latexmk -pdf main.tex

# Clean auxiliary files after compilation
docker run --rm -v $(pwd):/data ghcr.io/[your-username]/latex-compiler:latest latexmk -pdf -c main.tex
```

### Interactive Mode

For debugging or multiple operations:

```bash
docker run --rm -it -v $(pwd):/data ghcr.io/[your-username]/latex-compiler:latest bash
```

## Package Variants

The image is available in three variants based on the included packages:

### Minimal (Default)
- **Size**: Smallest image size
- **Packages**: Essential LaTeX packages only
- **Use case**: Basic documents, faster builds

**Included packages:**
- enumitem, hyperref, geometry, xcolor, titlesec

### Standard
- **Size**: Medium image size
- **Packages**: Balanced selection of common LaTeX packages
- **Use case**: Academic papers, reports, presentations with moderate complexity

**Included packages:**
- enumitem, hyperref, geometry, xcolor, titlesec, url, graphics, tools, amsmath, amscls, babel, parskip, listings, fontspec, booktabs, graphicx, caption, fancyhdr

### Full
- **Size**: Largest image size
- **Packages**: Comprehensive LaTeX package set
- **Use case**: Complex documents, scientific papers, theses

**Additional packages:**
- All standard packages plus: texliveonfly, tikz, pgfplots, algorithms, bibtex, biblatex, beamer, glossaries, index, and many more specialized packages

## Docker Compose

Create a `docker-compose.yml` for easier usage:

```yaml
version: '3.8'
services:
  latex:
    image: ghcr.io/mattiabertorello/latex-compiler:latest
    volumes:
      - .:/data
    working_dir: /data
    command: ["compile.sh", "-c"]

  latex-standard:
    image: ghcr.io/mattiabertorello/latex-compiler:latest-standard
    volumes:
      - .:/data
    working_dir: /data
    command: ["compile.sh", "-c"]

  latex-full:
    image: ghcr.io/mattiabertorello/latex-compiler:latest-full
    volumes:
      - .:/data
    working_dir: /data
    command: ["compile.sh", "-c"]

  latex-watch:
    image: ghcr.io/mattiabertorello/latex-compiler:latest
    volumes:
      - .:/data
    working_dir: /data
    command: ["bash", "-c", "while inotifywait -e modify *.tex; do compile.sh -c; done"]
```

Then run:

```bash
# Minimal variant
docker-compose run --rm latex

# Standard variant
docker-compose run --rm latex-standard

# Full variant
docker-compose run --rm latex-full

# Watch mode (requires inotify-tools in image)
docker-compose run --rm latex-watch
```

## Makefile Integration

Add to your `Makefile`:

```makefile
DOCKER_IMAGE = ghcr.io/[your-username]/latex-compiler:latest
DOCKER_IMAGE_STANDARD = ghcr.io/[your-username]/latex-compiler:latest-standard
DOCKER_IMAGE_FULL = ghcr.io/[your-username]/latex-compiler:latest-full

.PHONY: pdf clean docker-pdf docker-pdf-standard docker-pdf-full docker-clean

pdf:
	pdflatex main.tex
	pdflatex main.tex

docker-pdf:
	docker run --rm -v $(PWD):/data $(DOCKER_IMAGE) compile.sh -c

docker-pdf-standard:
	docker run --rm -v $(PWD):/data $(DOCKER_IMAGE_STANDARD) compile.sh -c

docker-pdf-full:
	docker run --rm -v $(PWD):/data $(DOCKER_IMAGE_FULL) compile.sh -c

docker-pdf-custom:
	docker run --rm -v $(PWD):/data $(DOCKER_IMAGE) compile.sh -i $(FILE) -c

clean:
	rm -f *.aux *.log *.out *.fls *.fdb_latexmk *.synctex.gz

docker-clean:
	docker run --rm -v $(PWD):/data $(DOCKER_IMAGE) bash -c "rm -f *.aux *.log *.out *.fls *.fdb_latexmk *.synctex.gz"

# Usage: make docker-pdf-custom FILE=document.tex
```

## GitHub Actions Integration

Use in your CI/CD pipeline:

```yaml
name: Build LaTeX Document

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build-pdf:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Compile LaTeX document
        run: |
          docker run --rm -v ${{ github.workspace }}:/data \
            ghcr.io/[your-username]/latex-compiler:latest-standard \
            compile.sh -i main.tex -c

      - name: Upload PDF
        uses: actions/upload-artifact@v3
        with:
          name: compiled-pdf
          path: main.pdf

      - name: Upload to Release (on tag)
        if: startsWith(github.ref, 'refs/tags/')
        uses: softprops/action-gh-release@v1
        with:
          files: main.pdf
```

## Helper Script Options

The built-in `compile.sh` script supports the following options:

| Option | Description | Default |
|--------|-------------|---------|
| `-i, --input FILE` | Input LaTeX file | `main.tex` |
| `-o, --output DIR` | Output directory | `.` (current directory) |
| `-c, --clean` | Clean auxiliary files after compilation | `false` |
| `-h, --help` | Display help message | - |

**Examples:**

```bash
# Compile specific file with cleanup
docker run --rm -v $(pwd):/data ghcr.io/[your-username]/latex-compiler:latest compile.sh -i thesis.tex -c

# Output to specific directory
docker run --rm -v $(pwd):/data ghcr.io/[your-username]/latex-compiler:latest compile.sh -o build/

# Combine options
docker run --rm -v $(pwd):/data ghcr.io/[your-username]/latex-compiler:latest compile.sh -i document.tex -o output/ -c
```

## Available Tags

- `latest` - Latest stable minimal build
- `latest-standard` - Latest stable standard build
- `latest-full` - Latest stable full build
- `main` - Latest build from main branch
- `YYYYMMDD` - Monthly scheduled builds
- `main-<sha>` - Specific commit builds

## Troubleshooting

### Common Issues

**Permission Denied:**
```bash
# Ensure your files are readable
chmod -R 755 .
```

**Missing Packages:**
```bash
# Check if package is available
docker run --rm ghcr.io/[your-username]/latex-compiler:latest tlmgr search <package-name>

# Install additional packages (temporary)
docker run --rm -it -v $(pwd):/data ghcr.io/[your-username]/latex-compiler:latest bash
# Inside container: tlmgr install <package-name>
```

**Compilation Errors:**
```bash
# Use the helper script for better error reporting
docker run --rm -v $(pwd):/data ghcr.io/[your-username]/latex-compiler:latest compile.sh -i your-file.tex

# Check log files
docker run --rm -v $(pwd):/data ghcr.io/[your-username]/latex-compiler:latest cat main.log
```

**Large Files:**
```bash
# For documents with many images, increase Docker memory if needed
docker run --rm -v $(pwd):/data --memory=2g ghcr.io/[your-username]/latex-compiler:latest compile.sh
```

### Debugging Compilation

```bash
# Run with verbose output using direct pdflatex
docker run --rm -v $(pwd):/data ghcr.io/[your-username]/latex-compiler:latest pdflatex -interaction=nonstopmode -file-line-error main.tex

# Interactive debugging
docker run --rm -it -v $(pwd):/data ghcr.io/[your-username]/latex-compiler:latest bash
```

## Building Custom Images

To build your own version with different packages:

```bash
# Build with minimal packages (default)
docker build -t my-latex-compiler .

# Build with standard package set
docker build --build-arg PACKAGE_LIST=texlive-packages-standard.txt --build-arg APT_PACKAGES=apt-packages-standard.txt --build-arg TEXLIVE_PROFILE=texlive-profile-standard.txt -t my-latex-compiler:standard .

# Build with full package set
docker build --build-arg PACKAGE_LIST=texlive-packages-full.txt --build-arg APT_PACKAGES=apt-packages-full.txt --build-arg TEXLIVE_PROFILE=texlive-profile-full.txt -t my-latex-compiler:full .
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request


## License

This project is dual-licensed:

- **Open Source**: [AGPL-3.0](LICENSE) for open source and non-commercial use
- **Commercial**: Separate commercial license available for commercial use

For more details, see the [LICENSE](LICENSE) file.
## Acknowledgments

- Built on Ubuntu and TeX Live
- Inspired by the LaTeX community's need for consistent compilation environments
- Thanks to all contributors and users providing feedback
