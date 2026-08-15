# Security Policy

## Reporting a Vulnerability

Do not open a public issue. Use GitHub's private vulnerability reporting form
on the repository's **Security** tab. Include reproduction steps, affected
versions, impact, and any suggested mitigation.

Security reports receive an acknowledgment in the GitHub advisory and remain
private until a coordinated disclosure is agreed.

## What is in scope

This repository generates other repositories, so a defect here can be copied
into every project made from it. Treat as reportable anything that would make a
generated project less safe than it claims to be:

- An action pinned to a tag rather than a commit, or a SHA whose comment names
  a version it is not.
- A workflow that interpolates untrusted text — a pull request title, a branch
  name, an issue body — directly into a shell script rather than passing it
  through the environment.
- A permissions block wider than the job needs, or a `persist-credentials`
  left on where the checkout token is not used.
- Anything that would let a release be published without passing through the
  `release` environment.
