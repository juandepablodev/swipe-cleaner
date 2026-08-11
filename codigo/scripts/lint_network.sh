#!/usr/bin/env bash

# Network Guardrail Lint Script for SwipeCleaner
# Verifies absolute privacy by ensuring zero network APIs or imports exist in the codebase.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Running Network Guardrail Lint on directory: ${ROOT_DIR}"

PATTERNS=(
  "import[[:space:]]+URLSession"
  "import[[:space:]]+FoundationNetworking"
  "import[[:space:]]+Network"
  "import[[:space:]]+CFNetwork"
  "import[[:space:]]+Alamofire"
  "import[[:space:]]+WebKit"
  "import[[:space:]]+NetworkExtension"
  "URLSession\."
  "URLSessionConfiguration"
  "NSAllowsArbitraryLoads"
)

COMBINED_PATTERN=$(IFS="|" ; echo "${PATTERNS[*]}")

VIOLATIONS=$(grep -rnE "${COMBINED_PATTERN}" "${ROOT_DIR}" \
  --exclude-dir="DerivedData" \
  --exclude-dir="build" \
  --exclude-dir=".git" \
  --exclude="lint_network.sh" || true)

if [ -n "${VIOLATIONS}" ]; then
  echo -e "\033[0;31m[ERROR] Network Guardrail Lint Failed! Forbidden network symbols found:\033[0m"
  echo "${VIOLATIONS}"
  echo -e "\033[0;31mAbsolute privacy requirement violated. No network calls or imports are allowed.\033[0m"
  exit 1
fi

echo -e "\033[0;32m[SUCCESS] Network Guardrail Lint Passed! Zero network dependencies found.\033[0m"
exit 0
