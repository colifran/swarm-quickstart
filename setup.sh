#!/usr/bin/env bash
set -euo pipefail

REPO_PATH=""
CLONE=false
OUT_DIR="$HOME/swarm-quickstart"
BRANCH="colifran/interp-libs"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Scaffold a standalone swarm quick start project.

Options:
  --repo PATH    Path to an existing deepagentsjs checkout
  --clone        Clone deepagentsjs to ~/.swarm-quickstart-repo
  --dir PATH     Output directory (default: ~/swarm-quickstart)
  --help         Show this help

Either --repo or --clone is required.

Examples:
  $(basename "$0") --repo ~/dev/deepagentsjs
  $(basename "$0") --clone
  $(basename "$0") --clone --dir ~/projects/my-swarm-demo
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_PATH="$2"; shift 2 ;;
    --clone) CLONE=true; shift ;;
    --dir) OUT_DIR="$2"; shift 2 ;;
    --help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

if [[ -z "$REPO_PATH" ]] && [[ "$CLONE" == false ]]; then
  echo "Error: either --repo or --clone is required"
  echo ""
  usage
fi

# --- Step 1: Get the repo ready ---

if [[ "$CLONE" == true ]]; then
  REPO_PATH="$HOME/.swarm-quickstart-repo"
  if [[ -d "$REPO_PATH" ]]; then
    echo "Using existing clone at $REPO_PATH"
    cd "$REPO_PATH"
    git fetch origin
    git checkout "$BRANCH"
    git pull origin "$BRANCH" || true
  else
    echo "Cloning deepagentsjs to $REPO_PATH..."
    git clone https://github.com/langchain-ai/deepagentsjs.git "$REPO_PATH"
    cd "$REPO_PATH"
    git checkout "$BRANCH"
  fi
fi

REPO_PATH="$(cd "$REPO_PATH" && pwd)"

echo "Using repo at $REPO_PATH"
echo "Building..."
cd "$REPO_PATH"
pnpm install --frozen-lockfile 2>/dev/null || pnpm install
pnpm build

DEEPAGENTS_PKG="$REPO_PATH/libs/deepagents"
QUICKJS_PKG="$REPO_PATH/libs/providers/quickjs"

# --- Step 2: Scaffold the quickstart directory ---

echo ""
echo "Creating quickstart at $OUT_DIR..."
mkdir -p "$OUT_DIR"

# package.json
cat > "$OUT_DIR/package.json" <<'PKGJSON'
{
  "name": "swarm-quickstart",
  "private": true,
  "type": "module",
  "dependencies": {
    "deepagents": "DEEPAGENTS_LINK",
    "@langchain/quickjs": "QUICKJS_LINK",
    "@langchain/anthropic": "^1.3.26",
    "@langchain/tavily": "^1.2.0",
    "dotenv": "^17.2.4",
    "dedent": "^1.7.1"
  },
  "devDependencies": {
    "@types/node": "^22.0.0",
    "tsx": "^4.21.0",
    "typescript": "^6.0.2"
  }
}
PKGJSON

# Replace link placeholders with actual paths
if [[ "$(uname)" == "Darwin" ]]; then
  sed -i '' "s|DEEPAGENTS_LINK|link:$DEEPAGENTS_PKG|g" "$OUT_DIR/package.json"
  sed -i '' "s|QUICKJS_LINK|link:$QUICKJS_PKG|g" "$OUT_DIR/package.json"
else
  sed -i "s|DEEPAGENTS_LINK|link:$DEEPAGENTS_PKG|g" "$OUT_DIR/package.json"
  sed -i "s|QUICKJS_LINK|link:$QUICKJS_PKG|g" "$OUT_DIR/package.json"
fi

# .env
cat > "$OUT_DIR/.env" <<'DOTENV'
ANTHROPIC_API_KEY=""
TAVILY_API_KEY=""
DOTENV

# tsconfig.json
cat > "$OUT_DIR/tsconfig.json" <<'TSCONFIG'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "Node16",
    "moduleResolution": "Node16",
    "esModuleInterop": true,
    "strict": true,
    "skipLibCheck": true
  }
}
TSCONFIG

# --- Step 3: Write example files ---

cat > "$OUT_DIR/01-sentiment-classification.ts" <<'EXAMPLE1'
/**
 * 01 — Sentiment Classification (invoke mode, single pass)
 *
 * The simplest swarm example. Creates a table from inline records,
 * classifies sentiment in invoke mode (direct model call, no tools),
 * and aggregates results in JavaScript.
 *
 * Usage: npx tsx 01-sentiment-classification.ts
 */
import "dotenv/config";
import { HumanMessage } from "@langchain/core/messages";
import { ChatAnthropic } from "@langchain/anthropic";
import { createDeepAgent } from "deepagents";
import { createCodeInterpreterMiddleware, swarm } from "@langchain/quickjs";

const model = new ChatAnthropic({ model: "claude-sonnet-4-20250514" });

const swarmLib = swarm({
  defaultModel: "anthropic:claude-sonnet-4-20250514",
  subagents: [],
});

const agent = createDeepAgent({
  model,
  middleware: [
    createCodeInterpreterMiddleware({
      libraries: [swarmLib],
      executionTimeoutMs: -1,
    }) as any,
  ],
});

const result = await agent.invoke({
  messages: [
    new HumanMessage(
      `Classify the sentiment of these customer reviews using swarm.

      Reviews:
      1. "Love the new update, easy fix for the login bug!"
      2. "Works fine, nothing special."
      3. "Crashes every time I open it. Uninstalling."
      4. "Pretty good overall, a few rough edges."
      5. "Absolutely brilliant, ship it!"
      6. "Worst experience I've ever had with an app."
      7. "Decent but needs more features."
      8. "The team clearly cares about quality."

      Create a swarm table with these reviews, classify each as positive/negative/neutral
      with a confidence score, then tell me the distribution and average confidence.`
    ),
  ],
});

const last = result.messages[result.messages.length - 1];
console.log(typeof last.content === "string" ? last.content : JSON.stringify(last.content));
EXAMPLE1

cat > "$OUT_DIR/02-file-review.ts" <<'EXAMPLE2'
/**
 * 02 — File Review (agent mode with tools)
 *
 * Creates a table from TypeScript files, dispatches each to a reviewer
 * subagent with web search tools, and reads back flagged files.
 *
 * This example reviews its own directory. Point the glob at your own
 * codebase for a real review.
 *
 * Usage: npx tsx 02-file-review.ts
 */
import "dotenv/config";
import { HumanMessage } from "@langchain/core/messages";
import { ChatAnthropic } from "@langchain/anthropic";
import { TavilySearch } from "@langchain/tavily";
import { createDeepAgent } from "deepagents";
import { createCodeInterpreterMiddleware, swarm } from "@langchain/quickjs";

const model = new ChatAnthropic({ model: "claude-sonnet-4-20250514" });

const swarmLib = swarm({
  defaultModel: "anthropic:claude-sonnet-4-20250514",
  subagents: [
    {
      name: "reviewer",
      description: "Reviews code files for quality issues",
      systemPrompt: `You are a code reviewer. Review the file for:
        - Security issues (injection, auth bypass, path traversal)
        - Performance problems (unnecessary allocations, O(n²) loops)
        - Error handling gaps
        Be specific about line numbers and suggest fixes.`,
      tools: [new TavilySearch({ maxResults: 2 })],
    },
  ],
});

const agent = createDeepAgent({
  model,
  middleware: [
    createCodeInterpreterMiddleware({
      libraries: [swarmLib],
      executionTimeoutMs: -1,
    }) as any,
  ],
});

const result = await agent.invoke({
  messages: [
    new HumanMessage(
      `Review all .ts files in the current directory using swarm.
      Use the "reviewer" subagent type and provide context that these are
      TypeScript examples using the Deep Agents framework.
      Summarize findings by severity.`
    ),
  ],
});

const last = result.messages[result.messages.length - 1];
console.log(typeof last.content === "string" ? last.content : JSON.stringify(last.content));
EXAMPLE2

cat > "$OUT_DIR/03-multi-pass-pipeline.ts" <<'EXAMPLE3'
/**
 * 03 — Multi-Pass Pipeline (review, verify, filter)
 *
 * Demonstrates the core swarm pattern for high-confidence analysis:
 *   Pass 1: Review files with one subagent type
 *   Pass 2: Verify each finding with a different subagent type
 *   Filter: Read back only confirmed findings
 *
 * This creates two tables — one for files, one for findings — showing
 * how structured results accumulate across passes.
 *
 * Usage: npx tsx 03-multi-pass-pipeline.ts
 */
import "dotenv/config";
import { HumanMessage } from "@langchain/core/messages";
import { ChatAnthropic } from "@langchain/anthropic";
import { TavilySearch } from "@langchain/tavily";
import { createDeepAgent } from "deepagents";
import { createCodeInterpreterMiddleware, swarm } from "@langchain/quickjs";

const model = new ChatAnthropic({ model: "claude-sonnet-4-20250514" });

const swarmLib = swarm({
  defaultModel: "anthropic:claude-sonnet-4-20250514",
  subagents: [
    {
      name: "reviewer",
      description: "Reviews code for bugs and issues",
      systemPrompt: `You are a bug finder. Review code thoroughly and report
        concrete bugs with file, title, and description. Do not report style
        issues — only real bugs that would cause incorrect behavior.`,
      tools: [new TavilySearch({ maxResults: 2 })],
    },
    {
      name: "verifier",
      description: "Independently verifies whether a reported bug is real",
      systemPrompt: `You are a skeptical code verifier. Given a reported bug,
        determine if it is a real issue or a false positive. Read the actual
        code and reason carefully. Default to marking things as false positives
        unless you can confirm the bug with evidence.`,
      tools: [new TavilySearch({ maxResults: 2 })],
    },
  ],
});

const agent = createDeepAgent({
  model,
  middleware: [
    createCodeInterpreterMiddleware({
      libraries: [swarmLib],
      executionTimeoutMs: -1,
    }) as any,
  ],
});

const result = await agent.invoke({
  messages: [
    new HumanMessage(
      `Do a two-pass review of the .ts files in this directory:

      Pass 1: Use the "reviewer" subagent to find bugs in each file.
      Use a response schema with a "findings" array where each finding
      has title, description, and severity.

      Then flatten the findings into a new table and run Pass 2:
      Use the "verifier" subagent to independently check each finding.
      Use a response schema with "confirmed" (boolean) and "reason" (string).

      Finally, filter to only confirmed findings and summarize what was
      real vs what was a false positive.`
    ),
  ],
});

const last = result.messages[result.messages.length - 1];
console.log(typeof last.content === "string" ? last.content : JSON.stringify(last.content));
EXAMPLE3

# --- Step 4: Install dependencies ---

echo ""
echo "Installing dependencies..."
cd "$OUT_DIR"
pnpm install

# --- Done ---

echo ""
echo "============================================"
echo "  Swarm Quick Start ready!"
echo "============================================"
echo ""
echo "  Directory: $OUT_DIR"
echo ""
echo "  Next steps:"
echo "    1. cd $OUT_DIR"
echo "    2. Edit .env and add your API keys"
echo "    3. Run an example:"
echo "       npx tsx 01-sentiment-classification.ts"
echo "       npx tsx 02-file-review.ts"
echo "       npx tsx 03-multi-pass-pipeline.ts"
echo ""
