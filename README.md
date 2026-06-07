# Swarm Quick Start

Get a working [swarm](https://langchain-5e9cc07a-preview-colifr-1780798128-0ed8717.mintlify.app/oss/javascript/deepagents/swarm) project running in one command. The setup script scaffolds a standalone directory with three examples that cover the main swarm patterns.

## Prerequisites

- Node.js 20+
- pnpm 10+
- An Anthropic API key
- A Tavily API key (optional, needed for examples 02 and 03)

## Setup

```bash
git clone https://github.com/colifran/swarm-quickstart.git
cd swarm-quickstart
```

### If you already have deepagentsjs cloned

```bash
./setup.sh --repo /path/to/deepagentsjs
```

### If you don't have the repo

```bash
./setup.sh --clone
```

Both options automatically check out the `colifran/interp-libs` branch and build.

### Custom output directory

```bash
./setup.sh --repo /path/to/deepagentsjs --dir ~/my-swarm-demo
```

Default output directory is `~/swarm-quickstart`.

## What you get

```
swarm-quickstart/
├── .env                              # Add your API keys here
├── package.json                      # Links to local deepagentsjs packages
├── tsconfig.json
├── 01-sentiment-classification.ts    # Invoke mode, single pass
├── 02-file-review.ts                 # Agent mode with tools
└── 03-multi-pass-pipeline.ts         # Multi-pass review → verify → filter
```

## Run your first example

```bash
cd ~/swarm-quickstart
# Edit .env and add your ANTHROPIC_API_KEY
npx tsx 01-sentiment-classification.ts
```

## Examples

### 01 — Sentiment Classification

The simplest swarm example. Creates a table from inline records, classifies sentiment in invoke mode (a single model call per dispatch, no tools), and aggregates results in JavaScript.

**What it demonstrates:**
- `create` with inline `tasks`
- `run` with `responseSchema` (invoke mode)
- `rows` with filters
- Aggregation via `console.log`

**Only needs:** `ANTHROPIC_API_KEY`

### 02 — File Review

Creates a table from TypeScript files via glob, dispatches each to a `reviewer` subagent with Tavily search, and reads back flagged files.

**What it demonstrates:**
- `create` with `glob`
- `subagentType` for agent mode dispatch (full agentic loop with tools)
- `context` (shared background) vs `instruction` (per-row template)

**Needs:** `ANTHROPIC_API_KEY` and `TAVILY_API_KEY`

### 03 — Multi-Pass Pipeline

The review-verify-filter pattern. Pass 1 reviews files with a `reviewer` subagent. Findings are flattened into a new table. Pass 2 verifies each finding with a `verifier` subagent. Only confirmed findings are returned.

**What it demonstrates:**
- Multiple tables in one pipeline
- Different subagent types per pass
- Filtering on structured output columns
- Structured accumulation across passes

**Needs:** `ANTHROPIC_API_KEY` and `TAVILY_API_KEY`

## Documentation

- [Swarm](https://langchain-5e9cc07a-preview-colifr-1780798128-0ed8717.mintlify.app/oss/javascript/deepagents/swarm) — Full API reference, batching details, and more patterns.
- [Interpreter Libraries](https://langchain-5e9cc07a-preview-colifr-1780798128-0ed8717.mintlify.app/oss/javascript/deepagents/interpreters#interpreter-libraries) — Build custom libraries that compose on top of swarm.

For a more complex example where a custom `evaluator` library imports swarm internally to build a multi-pass evaluation pipeline, see `examples/repl/interpreter-libraries/` in the deepagentsjs repo.
