#!/bin/bash
set +x
set -euo pipefail

cd "$(dirname "$0")/.."
case "${1:-}" in
    --compile-only) ;;
    "")
        if [[ "${CALLI_LIVE_TEST:-}" != 1 ]]; then
            echo "Refusing live test: set CALLI_LIVE_TEST=1." >&2
            exit 1
        fi
        ;;
    *) echo "Usage: $0 [--compile-only]" >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || exit 2

mkdir -p .build-dd
swiftc -parse-as-library -module-cache-path .build-dd/ModuleCache.noindex \
    freewrite/Publishing/*.swift \
    freewrite/Storage/EntryFrontmatter.swift \
    freewrite/Security/KeychainStore.swift \
    scripts/NotionLiveTest/main.swift \
    -o .build-dd/notion-live-test
[[ "${1:-}" != --compile-only ]] || exit 0

CALLI_NOTION_TOKEN="$(security find-generic-password -s com.calli.secrets -a notion-token -w 2>/dev/null)" \
    .build-dd/notion-live-test
