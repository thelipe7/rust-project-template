# Contributing

Use GitHub Discussions for support and early ideas, and Issues for reproducible
defects or agreed work.

## Verification

```bash
python -m unittest -v tests/test_template.py
```

Nothing here is compiled by this repository: the Rust under `template/` is
Jinja until Copier renders it. The suite stands in for the compiler — it
generates a real project of each kind and runs that project's own
`cargo xtask ci`, where a stray blank line left by a Jinja block shows up as a
`cargo fmt` failure.

It needs the tools that gate calls out to:

```bash
cargo install cargo-deny cargo-machete cargo-hack cargo-nextest taplo-cli typos-cli
uv tool install copier
```

`actionlint` and `dist` are optional locally; the test that needs each skips
when it is absent, and this repository's CI installs both so neither skips
there.

## Where a change goes

Four rules decide almost every question about this repository:

- **Every question is asked and none carries a default.** A default is an
  answer nobody gave, and it lands in a generated project looking like a
  decision somebody made. Adding a question means adding it to `ANSWERS` in
  the test suite, which answers every question like any other caller.
- **Excludes come in pairs.** `_exclude` in `copier.yml` names a path to leave
  out, or — where the condition does not hold — a path that does not exist,
  which is how Copier spells "exclude nothing". Both halves or neither.
- **A file holding `{{ ... }}` needs the `.jinja` suffix.** Without it Copier
  copies the file verbatim and the placeholder ships. Nothing else notices: the
  result is valid YAML, valid Markdown, and wrong. There is a test for this.
- **Every external action is pinned to a commit, with the tag in a comment.**
  A tag is a name the publisher can move. Both a reader and Dependabot use the
  comment to know which version the SHA is, so a wrong comment is worse than
  no comment. CI fails on an unpinned action, and `zizmor` runs over
  `template/` as well — a workflow finding here is copied into every generated
  repository.

## Trying the template out

```bash
copier copy --vcs-ref=HEAD . /tmp/try-it
```

Mind that `--vcs-ref=HEAD`. Copier reads a local template from its **latest
tag** when the working tree is clean, so a change that is committed and not
tagged is silently not what you are testing. An uncommitted working tree is used
as it stands, with no flag needed.

## Releasing the template

A generated project pins the template by tag, and `copier update` moves it to
the newest one. So a release is a tag, and until there is one, a change is not
reachable by anybody who already generated a project.

## Pull requests

Pull requests merge by rebase, so every commit lands on the default branch
exactly as it was written. That is why each rule below is about the individual
commit rather than the pull request:

- Conventional Commits: `<type>(scope): <description>`, imperative mood, and
  CI checks it — on every commit, and on the pull request title. The types
  are `build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`,
  `revert`, `style` and `test`. Mark a breaking change with `!` before the
  colon — a break that does not say so ships as a patch.
- Every commit carries a `Signed-off-by` line (`git commit -s`) under the
  Developer Certificate of Origin 1.1, which CI checks commit by commit.
  There is no CLA.
- Hard-wrap commit body lines at 72 characters.
- Atomic commits: one self-sufficient change per commit.
