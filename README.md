# Swarm Quick Start

Get a working [swarm](https://langchain-5e9cc07a-preview-colifr-1780798128-0ed8717.mintlify.app/oss/javascript/deepagents/swarm) project running in one command. The setup script builds deepagentsjs, copies real source files into `sample-code/` for the examples to review, and scaffolds everything into this directory.

## Documentation

Familiarize yourself with the docs before diving into the examples — they cover the core concepts behind interpreter libraries and swarm that these examples build on.

- [Interpreter Libraries](https://langchain-5e9cc07a-preview-colifr-1780798128-0ed8717.mintlify.app/oss/javascript/deepagents/interpreters#interpreter-libraries) — How to package reusable capabilities that agents can import, and how libraries compose on top of each other.
- [Swarm](https://langchain-5e9cc07a-preview-colifr-1780798128-0ed8717.mintlify.app/oss/javascript/deepagents/swarm) — The table-based data model for parallel task fan-out, batching, dispatch modes, and patterns.

For a more complex example where a custom `evaluator` library imports swarm internally to build a multi-pass evaluation pipeline, see `examples/repl/interpreter-libraries/` in the deepagentsjs repo.

## Prerequisites

- Node.js 20+
- pnpm 10+
- An Anthropic API key
- A Tavily API key (optional, needed for examples 02, 03, and 04)

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

## Run your first example

```bash
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

### 02 — Code Review

Reviews 5 TypeScript backend source files from deepagents. Each file is dispatched to a reviewer subagent with web search, and findings are aggregated by severity.

**What it demonstrates:**
- `create` with `glob` over a real codebase
- Agent-mode subagents with tools (Tavily web search)
- `responseSchema` for structured findings
- Single-pass aggregation

**Needs:** `ANTHROPIC_API_KEY` and `TAVILY_API_KEY`

### 03 — Review, Verify, and Filter

The review-verify-filter pattern applied to real code. Pass 1 fans out files to a bug-finder subagent. Pass 2 flattens all reported findings into a new table and dispatches each to a skeptical verifier. Only confirmed findings survive the filter.

**What it demonstrates:**
- Multiple tables in one pipeline
- Flattening results from one table into a new table
- Different subagent types per pass (finder vs verifier)
- Filtering on structured output columns
- False positive elimination

**Needs:** `ANTHROPIC_API_KEY` and `TAVILY_API_KEY`

### 04 — Custom Interpreter Library

Shows how to compose a higher-level abstraction on top of swarm. A custom `code-auditor` library in `libraries/code-auditor/` imports swarm internally and exposes a single `audit()` function. The agent just calls `audit({ glob: "sample-code/backends/*.ts" })` — it doesn't need to know about tables, dispatches, or multi-pass flows.

**What it demonstrates:**
- Building a custom `InterpreterLibrary` with source, instructions, and PTC tools
- Library-to-library composition (code-auditor imports swarm)
- Encapsulating a multi-pass pipeline behind a simple API
- Writing structured results to the filesystem via PTC

**Needs:** `ANTHROPIC_API_KEY` and `TAVILY_API_KEY`
