#!/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

echo "================================================================================"
echo -e "${BOLD}  MOOVE EDUCATION PLATFORM – DOCUMENTATION BUILD (latexmk)${NC}"
echo "  Started: $(date)"
echo "================================================================================"

DOCS=("SRS" "SDD" "TDD" "UserGuide" "Security")
FAILED=0

for d in "${DOCS[@]}"; do
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Building: ${d}_OpenEdX.tex${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    cd "$d"
    # Run latexmk with -pdf and show output in real time
    if latexmk -pdf -interaction=nonstopmode -halt-on-error "${d}_OpenEdX.tex"; then
        echo -e "${GREEN}  ✅ ${d}_OpenEdX.pdf generated${NC}"
    else
        echo -e "${RED}  ❌ Build failed for ${d}${NC}"
        FAILED=1
    fi
    cd ..
done

echo ""
echo "================================================================================"
echo -e "${BOLD}  BUILD SUMMARY${NC}"
echo "================================================================================"
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All documents compiled successfully!${NC}"
else
    echo -e "${RED}❌ Some documents failed. Check logs above.${NC}"
fi
echo "  Finished: $(date)"
echo "================================================================================"