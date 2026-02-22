#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# LLM BOUNDARY GUARD
#
# Enforces the "no direct LLM calls outside server/llm/" rule.
# Allowed paths: server/llm/invokeLLMWithHalo.ts and server/llm/adapters/*
#
# Checks:
#   1. No direct import of the OpenAI SDK (openai) outside server/llm/
#   2. No fetch() calls targeting api.openai.com outside server/llm/
#      (env-var assignments in __tests__ are excluded as they are test setup, not API calls)
# =============================================================================

echo "=== LLM Boundary Guard ==="

ALLOWED_DIR="server/llm"
VIOLATIONS=0

# -----------------------------------------------------------------------
# 1. Direct OpenAI SDK imports outside server/llm/
# -----------------------------------------------------------------------
echo "Checking for direct OpenAI SDK imports outside ${ALLOWED_DIR}/..."

SDK_VIOLATIONS=$(grep -rn \
  'from ["'"'"'\`]openai["'"'"'\`]\|require(["'"'"'\`]openai["'"'"'\`])' \
  server/ client/ shared/ \
  --include='*.ts' --include='*.tsx' \
  | grep -v "^server/llm/" \
  | grep -v "node_modules" \
  || true)

if [ -n "$SDK_VIOLATIONS" ]; then
  echo "::error::Direct OpenAI SDK import detected outside ${ALLOWED_DIR}/:"
  echo "$SDK_VIOLATIONS"
  VIOLATIONS=$((VIOLATIONS + 1))
fi

# -----------------------------------------------------------------------
# 2. fetch() calls / URL literals for api.openai.com outside server/llm/
#    __tests__ directories are excluded: they may set env vars for test setup
#    but must not perform actual fetch() calls to the upstream API.
# -----------------------------------------------------------------------
echo "Checking for api.openai.com fetch targets outside ${ALLOWED_DIR}/..."

FETCH_VIOLATIONS=$(grep -rn \
  'https\?://api\.openai\.com\|["'"'"'\`]api\.openai\.com' \
  server/ client/ shared/ \
  --include='*.ts' --include='*.tsx' \
  | grep -v "^server/llm/" \
  | grep -v "__tests__" \
  | grep -v "node_modules" \
  || true)

if [ -n "$FETCH_VIOLATIONS" ]; then
  echo "::error::Direct api.openai.com URL reference detected outside ${ALLOWED_DIR}/:"
  echo "$FETCH_VIOLATIONS"
  VIOLATIONS=$((VIOLATIONS + 1))
fi

# -----------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------
if [ "$VIOLATIONS" -gt 0 ]; then
  echo ""
  echo "::error::LLM boundary violated. All LLM calls MUST go through server/llm/invokeLLMWithHalo.ts."
  echo "::error::Direct OpenAI SDK imports and api.openai.com fetch calls are only permitted in server/llm/."
  exit 1
fi

echo "LLM boundary guard passed: no direct LLM calls outside ${ALLOWED_DIR}/"
