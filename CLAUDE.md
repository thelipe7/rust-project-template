# rust-project-template

A Copier template. Nothing here is compiled by this repository — the Rust lives
under `template/` as Jinja and is only ever built inside a generated project.
So the test suite is the compiler: it generates real projects and runs their
own `cargo xtask ci`.

```bash
python -m unittest -v tests/test_template.py
```

Run it before saying a change is done. It needs `copier`, `cargo-deny`,
`cargo-machete`, `cargo-hack`, `cargo-nextest`, `taplo-cli` and `typos-cli`;
`actionlint` and `dist` are optional locally and skip one test each when
missing.

Read [CONTRIBUTING.md](CONTRIBUTING.md) for how commits and pull requests are
written, and for the four rules that decide where a change goes.
