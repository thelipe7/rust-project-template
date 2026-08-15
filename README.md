# Rust Project Template

A Copier template for Rust projects. One command is the gate, every workflow
lives in the repository where it can be read, and the release path fits what
is being released — a library published to crates.io, or a workspace of
applications shipped as binaries.

## Requirements

Git 2.27+, Python 3.10+, and Copier 9.17 or newer:

```console
uv tool install copier
```

The floor is declared in `copier.yml`, so an older Copier refuses the template
rather than half-rendering it.

## Create a project

```console
copier copy gh:thelipe7/rust-project-template my-project
```

Every question is asked and none carries a default: a default is an answer
nobody gave, and it lands in the generated project looking like a decision
somebody made.

Commit the `.copier-answers.yml` it writes — `copier update` needs it.

## Finish the setup

Three things a template cannot do for itself. Copier prints them again at the
end of a generation, which is the moment somebody is looking.

**Every project.** The settings GitHub keeps in its own database rather than
in a file — rebase-only merges, the branch ruleset and the checks it requires,
Dependabot, secret scanning and CodeQL, the labels automation opens issues
with, the `release` environment, and immutable releases:

```console
scripts/apply-repository-settings.sh
```

It asks which repository and which settings, or takes `--repo` and `--only`
and asks nothing. Running it again is how a setting changed by hand gets put
back.

**An application.** Generate the release workflow. `dist-workspace.toml`
already says what to build and for which targets; the workflow that reads it
is generated rather than shipped, because a hand-written copy would be stale
the day dist changes:

```console
dist generate
```

Commit the `.github/workflows/release.yml` it writes. Until you do, the
project has a release configuration and nothing that runs it. Rerun it after
editing `dist-workspace.toml`; `dist generate --check` is what says the two
have drifted.

Not `dist init`: that command is for a project with no configuration yet, and
it rewrites `dist-workspace.toml` from its own template — deleting the
comments that record why each setting is what it is.

**A library.** The one-time crates.io setup for Trusted Publishing, spelled
out in the generated project's own `CONTRIBUTING.md`.

## What a generated project gets

- **One gate.** `cargo xtask ci` — a compile, formatting for Rust and TOML,
  spelling, Clippy with warnings denied, `cargo deny`, `cargo machete`,
  `cargo hack --each-feature`, nextest, the doctests and rustdoc. It is what
  CI runs, it is required by the branch ruleset, and it passes on a project
  generated a minute ago.
- **Every platform it ships to.** The gate runs once on Linux, because most of
  what it asks answers the same everywhere; compiling and testing then run on
  Linux, macOS and Windows, on x86_64 and aarch64 each, plus a musl build.
- **A reproducible first build.** `Cargo.lock` ships with the project, and
  every task passes `--locked`.
- **Workflows that can be read.** CI, a daily advisory check, a DCO gate, a
  Conventional Commits check, weekly Dependabot with a cooldown, a release
  pull request kept open by release-plz, and a scheduled check for template
  updates. Every external action pinned to a commit, a job that fails if one
  is not, and `actionlint` and `zizmor` over the lot — zizmor asks whether a
  workflow is safe, a question actionlint does not ask.
- **Rebase-only merges**, so every commit lands as it was written — the
  premise for asking each one to be atomic, conventional and signed off, and
  what release-plz reads to build the changelog.
- **One `[workspace.lints]` table**, inherited by every crate so that none can
  quietly exempt itself.
- **A `deny.toml` allowing only the licenses the project itself carries**, so
  accepting a dependency's license is a line someone writes.
- **The license text the answer names.** One license lands as `LICENSE`; two
  land as `LICENSE-MIT` and `LICENSE-APACHE-2.0`.
- **A Miri workflow**, when the project allows scoped `unsafe`.
- **Deeper verification, each behind a question.** An OpenSSF Scorecard
  workflow publishing a supply-chain score, weekly mutation testing with
  cargo-mutants, and — for a library — a cargo-fuzz harness under `fuzz/`
  and a pull-request check of the public API against the version on
  crates.io. A project that answers no carries nothing.
- Issue forms, a pull request template and a `SECURITY.md` in the repository
  rather than inherited, so a fork carries them too. Plus `CONTRIBUTING.md`,
  `CHANGELOG.md`, `CLAUDE.md` with `AGENTS.md` symlinked to it, `.gitignore`,
  `.editorconfig`, and a `clippy.toml`, `taplo.toml` and
  `.config/nextest.toml` saying what each is for.
- **`cargo xtask bench`**, deliberately outside the gate: a benchmark in CI
  measures the runner it landed on, so this is for running twice on one
  machine, either side of a change.

## Library or application

A library is compiled by people who chose their own toolchain and is published
to a registry. An application is run as a binary by people who never compile
it. Nearly everything else follows from that, so neither kind carries the
other's:

|                   | Published library                     | Application workspace                    |
| ----------------- | ------------------------------------- | ---------------------------------------- |
| Release           | merge the release PR → crates.io      | dispatch `dist` with a tag → binaries    |
| Release gate      | the `release` environment on publish  | a plan-phase job, before anything builds |
| MSRV              | `rust-version`, and CI builds with it | none — the pinned toolchain is the floor |
| Dependency floors | `-Z direct-minimal-versions` in CI    | none — nobody resolves against it        |
| Layout            | `src/`, `tests/`                      | `apps/*`, `crates/*`                     |
| Packaging         | `cargo xtask package`, in the gate    | `cargo xtask dist`, outside it           |
| Manifest metadata | description, keywords, categories     | description only, for installer metadata |
| `clippy::cargo`   | on                                    | off — nothing is published               |
| Build profiles    | `bench` only, ignored by consumers    | `release`, `dist`, `bench`               |
| Bug report asks   | crate version and `rustc -V`          | its version and how it was installed     |
| Also generated    | a consumer fixture the gate builds    | an SBOM, and binaries `cargo audit` reads |
| docs.rs           | built with `--all-features`           | not published                            |

## Update a project

```console
copier update
```

Review the three-way merge, run `cargo xtask ci`, and commit it as a normal
pull request.

## Work on the template

```console
python -m unittest -v tests/test_template.py
```

The suite generates real projects and runs their own `cargo xtask ci`, so it
needs every tool that gate shells out to:

```console
cargo install cargo-deny cargo-machete cargo-hack cargo-nextest taplo-cli typos-cli
```

`actionlint` and `dist` are optional locally; without each, one test skips. CI
installs both and fails if anything skips there.

[CONTRIBUTING.md](CONTRIBUTING.md) has the four rules that decide where a
change goes.

To try the template out, point Copier at the directory instead of at GitHub:

```console
copier copy /path/to/rust-project-template /tmp/try-it
```

Mind which version that reads. Copier takes a local template from its **latest
tag** when the working tree is clean — so a change that is committed but not
tagged is silently not what you are testing. Add `--vcs-ref=HEAD` to read the
current commit. An uncommitted working tree is used as it stands, with no flag
needed.

## License

The template is dedicated to the public domain under CC0-1.0. Generated
projects select and carry their own license.
