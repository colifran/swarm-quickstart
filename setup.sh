#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_PATH=""
CLONE=false
BRANCH="colifran/interp-libs"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Set up this swarm quick start project.

Options:
  --repo PATH    Path to an existing deepagentsjs checkout
  --clone        Clone deepagentsjs to ~/.swarm-quickstart-repo
  --help         Show this help

Either --repo or --clone is required.

Examples:
  $(basename "$0") --repo ~/dev/deepagentsjs
  $(basename "$0") --clone
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_PATH="$2"; shift 2 ;;
    --clone) CLONE=true; shift ;;
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
cd "$REPO_PATH"
echo "Checking out $BRANCH..."
git checkout "$BRANCH"
echo "Building..."
pnpm install --frozen-lockfile 2>/dev/null || pnpm install
pnpm build

DEEPAGENTS_PKG="$REPO_PATH/libs/deepagents"
QUICKJS_PKG="$REPO_PATH/libs/providers/quickjs"

# --- Step 2: Scaffold into this directory ---

echo ""
echo "Setting up quickstart in $SCRIPT_DIR..."

# package.json
cat > "$SCRIPT_DIR/package.json" <<'PKGJSON'
{
  "name": "swarm-quickstart",
  "private": true,
  "type": "module",
  "dependencies": {
    "deepagents": "DEEPAGENTS_LINK",
    "@langchain/quickjs": "QUICKJS_LINK",
    "@langchain/core": "^1.1.44",
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
  sed -i '' "s|DEEPAGENTS_LINK|link:$DEEPAGENTS_PKG|g" "$SCRIPT_DIR/package.json"
  sed -i '' "s|QUICKJS_LINK|link:$QUICKJS_PKG|g" "$SCRIPT_DIR/package.json"
else
  sed -i "s|DEEPAGENTS_LINK|link:$DEEPAGENTS_PKG|g" "$SCRIPT_DIR/package.json"
  sed -i "s|QUICKJS_LINK|link:$QUICKJS_PKG|g" "$SCRIPT_DIR/package.json"
fi

# .env
cat > "$SCRIPT_DIR/.env" <<'DOTENV'
ANTHROPIC_API_KEY=""
TAVILY_API_KEY=""

# Optional: LangSmith tracing
# LANGSMITH_TRACING=true
# LANGSMITH_API_KEY=""
# LANGSMITH_PROJECT=""
# LANGSMITH_ENDPOINT="https://api.smith.langchain.com"
DOTENV

# tsconfig.json
cat > "$SCRIPT_DIR/tsconfig.json" <<'TSCONFIG'
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

# --- Step 3: Copy sample code from deepagentsjs ---

echo "Copying sample code from deepagentsjs..."
SAMPLE_DIR="$SCRIPT_DIR/sample-code"
mkdir -p "$SAMPLE_DIR/backends"

# Copy selected backend source files (keep it small for quick examples)
KEEP_FILES="composite.ts langsmith.ts local-shell.ts protocol.ts state.ts"
for f in $KEEP_FILES; do
  src="$REPO_PATH/libs/deepagents/src/backends/$f"
  if [[ -f "$src" ]]; then
    cp "$src" "$SAMPLE_DIR/backends/"
  fi
done

echo "  Copied $(find "$SAMPLE_DIR" -name '*.ts' | wc -l | tr -d ' ') files to sample-code/"

# --- Step 4: Write example files ---

cat > "$SCRIPT_DIR/01-sentiment-classification.ts" <<'EXAMPLE1'
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
import { createDeepAgent, LocalShellBackend } from "deepagents";
import { createCodeInterpreterMiddleware, swarm } from "@langchain/quickjs";

const model = new ChatAnthropic({ model: "claude-sonnet-4-6" });

const swarmLib = swarm({
  defaultModel: "anthropic:claude-sonnet-4-6",
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

cat > "$SCRIPT_DIR/02-code-review.ts" <<'EXAMPLE2'
/**
 * 02 — Code Review (agent mode with tools)
 *
 * Globs the sample-code/backends/ directory into a swarm table,
 * dispatches each file to a reviewer subagent with web search,
 * and aggregates findings with structured output.
 *
 * Usage: npx tsx 02-code-review.ts
 */
import "dotenv/config";
import * as path from "node:path";
import * as url from "node:url";
import { HumanMessage } from "@langchain/core/messages";
import { ChatAnthropic } from "@langchain/anthropic";
import { TavilySearch } from "@langchain/tavily";
import { createDeepAgent, LocalShellBackend } from "deepagents";
import { createCodeInterpreterMiddleware, swarm } from "@langchain/quickjs";

const __dirname = path.dirname(url.fileURLToPath(import.meta.url));

const model = new ChatAnthropic({ model: "claude-sonnet-4-6" });

const swarmLib = swarm({
  defaultModel: "anthropic:claude-sonnet-4-6",
  subagents: [
    {
      name: "reviewer",
      description: "Reviews code for bugs and security issues",
      systemPrompt:
        "You are a code reviewer. Find real bugs — race conditions, resource leaks, injection vectors, error handling gaps. Cite line numbers. Ignore style issues.",
      tools: [new TavilySearch({ maxResults: 2 })],
    },
  ],
});

const agent = createDeepAgent({
  model,
  backend: () => new LocalShellBackend({ rootDir: __dirname, virtualMode: true }),
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
      `Review the TypeScript files in sample-code/backends/ using swarm.

      Create a table from the .ts files using glob, dispatch each to the
      "reviewer" subagent with a response schema for findings (title, file,
      severity, description), then summarize the top issues by severity.`
    ),
  ],
});

const last = result.messages[result.messages.length - 1];
console.log(typeof last.content === "string" ? last.content : JSON.stringify(last.content));
EXAMPLE2

cat > "$SCRIPT_DIR/03-review-verify-filter.ts" <<'EXAMPLE3'
/**
 * 03 — Review, Verify, and Filter (multi-pass pipeline)
 *
 * The review-verify-filter pattern applied to real code. Pass 1 fans out
 * sample-code/ files to bug-finder subagents. Pass 2 takes every reported
 * finding, creates a new table, and dispatches each to a skeptical verifier
 * that independently checks whether the bug is real. Only confirmed findings
 * survive.
 *
 * Usage: npx tsx 03-review-verify-filter.ts
 */
import "dotenv/config";
import * as path from "node:path";
import * as url from "node:url";
import { HumanMessage } from "@langchain/core/messages";
import { ChatAnthropic } from "@langchain/anthropic";
import { TavilySearch } from "@langchain/tavily";
import { createDeepAgent, LocalShellBackend } from "deepagents";
import { createCodeInterpreterMiddleware, swarm } from "@langchain/quickjs";

const __dirname = path.dirname(url.fileURLToPath(import.meta.url));

const model = new ChatAnthropic({ model: "claude-sonnet-4-6" });

const swarmLib = swarm({
  defaultModel: "anthropic:claude-sonnet-4-6",
  subagents: [
    {
      name: "bug-finder",
      description: "Finds bugs and potential issues in code",
      systemPrompt:
        "Find real bugs: race conditions, resource leaks, injection vectors, error handling gaps. Cite line numbers. Ignore style.",
      tools: [new TavilySearch({ maxResults: 2 })],
    },
    {
      name: "verifier",
      description: "Independently verifies whether a reported bug is real",
      systemPrompt:
        "Determine if a reported bug is REAL or a FALSE POSITIVE. Check the code for guards or constraints that prevent the issue. Default to false positive unless you have concrete evidence.",
      tools: [new TavilySearch({ maxResults: 2 })],
    },
  ],
});

const agent = createDeepAgent({
  model,
  backend: () => new LocalShellBackend({ rootDir: __dirname, virtualMode: true }),
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
      `Two-pass review of sample-code/backends/*.ts using swarm.

      Pass 1: glob the files into a table, dispatch each to "bug-finder" with
      a findings schema (title, file, severity, description).

      Pass 2: flatten all findings into a new table, dispatch each to "verifier"
      with a verdict schema (confirmed boolean, reason).

      Filter to confirmed findings and summarize what survived.`
    ),
  ],
});

const last = result.messages[result.messages.length - 1];
console.log(typeof last.content === "string" ? last.content : JSON.stringify(last.content));
EXAMPLE3

# --- Step 5: Write the custom code-auditor library ---

mkdir -p "$SCRIPT_DIR/libraries/code-auditor"

cat > "$SCRIPT_DIR/libraries/code-auditor/index.ts" <<'LIBSOURCE'
import { create, run, rows } from "swarm";

declare const tools: {
  writeFile?: (args: { file_path: string; content: string }) => Promise<string>;
};

interface AuditOptions {
  glob: string;
  outputDir?: string;
}

/**
 * Run a two-pass code audit: find bugs, then verify each finding.
 *
 * Pass 1 dispatches every file to a "bug-finder" subagent.
 * Pass 2 flattens findings into a new table and dispatches each to a "verifier".
 * Results are written to outputDir as JSON files.
 */
export async function audit(options: AuditOptions): Promise<void> {
  const outputDir = options.outputDir ?? "/audit";

  // Pass 1 — find bugs
  const files = await create({ glob: options.glob });
  await run(files.id, {
    instruction: "Review {file} for bugs. Report concrete issues only — no style or naming feedback.",
    subagentType: "bug-finder",
    responseSchema: {
      type: "object",
      properties: {
        findings: {
          type: "array",
          items: {
            type: "object",
            properties: {
              title: { type: "string" },
              line: { type: "number" },
              description: { type: "string" },
              severity: { type: "string", enum: ["critical", "high", "medium", "low"] },
            },
            required: ["title", "description", "severity"],
          },
        },
      },
      required: ["findings"],
    },
  });

  // Flatten findings into a new table
  const fileRows = await rows(files.id);
  const allFindings: { file: string; title: string; line?: number; description: string; severity: string }[] = [];
  for (const row of fileRows) {
    const findings = (row.findings as any[]) ?? [];
    const file = row.file as string;
    for (const f of findings) {
      allFindings.push({ file, ...f });
    }
  }

  if (allFindings.length === 0) {
    console.log("No findings to verify.");
    await tools.writeFile!({
      file_path: `${outputDir}/results.json`,
      content: JSON.stringify({ total: 0, confirmed: 0, findings: [] }, null, 2),
    });
    return;
  }

  // Pass 2 — verify each finding
  const findingsTable = await create({
    tasks: allFindings.map((f, i) => ({ id: `f${i}`, ...f })),
  });
  await run(findingsTable.id, {
    instruction:
      "Verify this reported bug in {file}: {title} — {description}. " +
      "Is this a real bug or a false positive? Read the code carefully.",
    subagentType: "verifier",
    responseSchema: {
      type: "object",
      properties: {
        confirmed: { type: "boolean" },
        confidence: { type: "string", enum: ["high", "medium", "low"] },
        reason: { type: "string" },
      },
      required: ["confirmed", "reason"],
    },
  });

  // Filter and write results
  const verifiedRows = await rows(findingsTable.id);
  const confirmed = verifiedRows.filter((r) => r.confirmed === true);
  const rejected = verifiedRows.filter((r) => r.confirmed !== true);

  const results = {
    total: verifiedRows.length,
    confirmed: confirmed.length,
    rejected: rejected.length,
    findings: confirmed.map((r) => ({
      file: r.file,
      title: r.title,
      severity: r.severity,
      description: r.description,
      confidence: r.confidence,
      reason: r.reason,
    })),
  };

  await tools.writeFile!({
    file_path: `${outputDir}/results.json`,
    content: JSON.stringify(results, null, 2),
  });

  console.log(
    `Audit complete: ${confirmed.length}/${verifiedRows.length} findings confirmed. ` +
    `Results written to ${outputDir}/results.json`
  );
}
LIBSOURCE

cat > "$SCRIPT_DIR/libraries/code-auditor/INSTRUCTIONS.md" <<'LIBINSTRUCTIONS'
# Code Auditor

Run a two-pass bug audit on a set of files. Built on top of the `swarm`
library — you don't need to manage tables or dispatches yourself.

## Quick Start

```javascript
import { audit } from "code-auditor";

await audit({ glob: "sample-code/backends/*.ts" });

// Results are written to /audit/results.json
```

## How It Works

1. **Pass 1 (bug-finder subagent)** — Every file matching the glob is
   dispatched to a bug-finder that looks for real bugs: race conditions,
   resource leaks, error handling gaps, security issues.

2. **Pass 2 (verifier subagent)** — Every finding from Pass 1 is
   flattened into a new table and dispatched to a skeptical verifier
   that independently checks whether the bug is real.

3. **Output** — Confirmed findings are written to `results.json` with
   severity, description, and verification reasoning.

## API

### `audit(options)`

| Parameter | Type | Description |
|-----------|------|-------------|
| `options.glob` | `string` | Glob pattern for files to audit |
| `options.outputDir` | `string` | Directory for results (default: `/audit`) |

Returns `void`. Results are written to `{outputDir}/results.json`.
LIBINSTRUCTIONS

cat > "$SCRIPT_DIR/04-custom-library.ts" <<'EXAMPLE4'
/**
 * 04 — Custom Interpreter Library (composing on top of swarm)
 *
 * Demonstrates how to build a higher-level abstraction as a custom
 * interpreter library. The "code-auditor" library imports swarm
 * internally and exposes a single `audit()` function that orchestrates
 * a two-pass pipeline (find bugs → verify findings) under the hood.
 *
 * The agent just calls audit() with a glob pattern — it
 * doesn't need to know about tables, dispatches, or multi-pass flows.
 *
 * Usage: npx tsx 04-custom-library.ts
 */
import "dotenv/config";
import * as fs from "node:fs";
import * as path from "node:path";
import * as url from "node:url";
import { HumanMessage } from "@langchain/core/messages";
import { ChatAnthropic } from "@langchain/anthropic";
import { TavilySearch } from "@langchain/tavily";
import { createDeepAgent, LocalShellBackend } from "deepagents";
import { createCodeInterpreterMiddleware, swarm } from "@langchain/quickjs";
import type { InterpreterLibrary } from "@langchain/quickjs";

const __dirname = path.dirname(url.fileURLToPath(import.meta.url));

const model = new ChatAnthropic({ model: "claude-sonnet-4-6" });

// Built-in swarm library with bug-finder and verifier subagents
const swarmLib = swarm({
  defaultModel: "anthropic:claude-sonnet-4-6",
  subagents: [
    {
      name: "bug-finder",
      description: "Finds bugs and potential issues in code",
      systemPrompt:
        "Find real bugs: race conditions, resource leaks, injection vectors, error handling gaps. Cite line numbers. Ignore style.",
      tools: [new TavilySearch({ maxResults: 2 })],
    },
    {
      name: "verifier",
      description: "Independently verifies whether a reported bug is real",
      systemPrompt:
        "Determine if a reported bug is REAL or a FALSE POSITIVE. Check the code for guards or constraints that prevent the issue. Default to false positive unless you have concrete evidence.",
      tools: [new TavilySearch({ maxResults: 2 })],
    },
  ],
});

// Custom code-auditor library — imports swarm internally and exposes audit()
const libDir = path.join(__dirname, "libraries", "code-auditor");
const codeAuditorLib: InterpreterLibrary = {
  name: "code-auditor",
  description: "Two-pass code audit pipeline built on swarm",
  ptcTools: ["write_file"],
  source: fs.readFileSync(path.join(libDir, "index.ts"), "utf-8"),
  instructions: fs.readFileSync(path.join(libDir, "INSTRUCTIONS.md"), "utf-8"),
};

const agent = createDeepAgent({
  model,
  backend: () => new LocalShellBackend({ rootDir: __dirname, virtualMode: true }),
  middleware: [
    createCodeInterpreterMiddleware({
      libraries: [swarmLib, codeAuditorLib],
      executionTimeoutMs: -1,
    }) as any,
  ],
});

const result = await agent.invoke({
  messages: [
    new HumanMessage(
      `Audit the sample code for bugs using the code-auditor library.

      Run: audit({ glob: "sample-code/backends/*.ts" })

      Then read /audit/results.json and summarize:
      1. How many findings were reported vs confirmed
      2. Each confirmed finding with its file, severity, and verification reasoning
      3. Your overall assessment of the code quality`
    ),
  ],
});

const last = result.messages[result.messages.length - 1];
console.log(typeof last.content === "string" ? last.content : JSON.stringify(last.content));
EXAMPLE4

# --- Step 6: Install dependencies ---

echo ""
echo "Installing dependencies..."
cd "$SCRIPT_DIR"
pnpm install

# --- Done ---

echo ""
echo "============================================"
echo "  Quickstart ready!"
echo "============================================"
echo ""
echo "  sample-code/ contains $(find "$SAMPLE_DIR" -name '*.ts' | wc -l | tr -d ' ') TypeScript files from deepagentsjs"
echo ""
echo "  Next steps:"
echo "    1. Edit .env and add your API keys"
echo "    2. Run an example:"
echo "       npx tsx 01-sentiment-classification.ts"
echo "       npx tsx 02-code-review.ts"
echo "       npx tsx 03-review-verify-filter.ts"
echo "       npx tsx 04-custom-library.ts"
echo ""
