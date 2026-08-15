# crates

The libraries this workspace is built from. `apps/` wires them together and
owns the binaries; anything a binary does that could be exercised without one
belongs here instead.

A crate earns its own directory when it is genuinely separable — a boundary
somebody would defend in review, not tidiness. A parallel dependency graph
compiles faster and enforces those boundaries, while a serial chain of tiny
crates buys neither.

Declare a shared dependency once in the root `[workspace.dependencies]` and
take it here with `{ workspace = true }`, so that two crates cannot end up
disagreeing about the version of a type they pass to each other.
