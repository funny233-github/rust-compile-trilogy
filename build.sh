#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"

rm -rf "$BUILD"
mkdir -p "$BUILD"

echo "==> 编译 Rust 编译三部曲"
echo ""

for project in proc-macro-guide rust2mlog compilation-theory; do
    echo "  [$project]"
    typst compile "$ROOT/$project/main.typ" "$BUILD/$project.pdf"
    echo "    → build/$project.pdf"
done

echo ""
echo "==> 完成"
ls -lh "$BUILD"/
