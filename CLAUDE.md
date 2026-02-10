# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is prhub

A Helix editor plugin for reviewing GitHub PRs, built as a Steel dylib (Rust cdylib loaded by Steel/Scheme). Renders inside Helix as a component overlay — not a standalone binary.

## Architecture

```
prhub.scm                    ← Entry point: registers :prhub command
├── ui/pr_list.scm            ← PR list view, state machine, event routing
├── ui/diff_view.scm          ← Diff rendering with syntax coloring
├── ui/drawing.scm            ← Box-drawing primitives (borders, text, layout)
├── ui/styles.scm             ← Theme integration via Helix scopes
└── Rust cdylib (steel/prhub) ← Heavy lifting: GitHub API, data structs, threading
    ├── src/lib.rs             ← FFI module registration (declare_module!)
    ├── src/pr.rs              ← PrHub state + GhPr struct, background fetch threads
    └── src/github.rs          ← Shells out to `gh` CLI, parses JSON
```

**Pattern**: Rust handles data fetching/parsing on background threads via `crossbeam`. Steel/Scheme handles UI rendering, keybindings, and Helix component integration. Follows the same architecture as [scooter.hx](https://github.com/thomasschafer/scooter.hx).

## Build & Install

Requires the Steel-enabled Helix fork (not mainline Helix):

```bash
# Build the dylib
cargo steel-lib

# Or install via Forge
forge pkg install --git <repo-url>
```

The `cargo steel-lib` command compiles the cdylib and places it where Steel can find it. Requires `steel-core`, `cargo-steel-lib`, and `forge` to be installed (all come from `cargo xtask steel` in the Helix Steel fork).

## Configure in Helix

Add to `~/.config/helix/init.scm`:

```scheme
;; If installed via forge:
(require "prhub/prhub.scm")
;; If built from source:
(require "/path/to/prhub/prhub.scm")
```

Then use `:prhub` in Helix to open.

## Key conventions

- **Steel FFI functions** follow `TypeName-method-name` naming (e.g., `PrHub-start-fetch`, `GhPr-title`)
- **Struct fields** exposed to Steel must derive `Steel` and `Clone`
- **Background work** uses `Arc<Mutex<T>>` + `Arc<AtomicBool>` for done/cancel flags, polled from Steel render loop
- **`gh` CLI** is the GitHub API layer — user must have `gh` authenticated
- **cog.scm** is the Forge package manifest — bump version there and in Cargo.toml together
