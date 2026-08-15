## Summary

Describe what a generated project gets that it did not get before, and why.

## Checklist

- [ ] `python -m unittest -v tests/test_template.py` passes, with no test
      skipped for a missing tool.
- [ ] A test covers the behavior this changes, for both project kinds where
      both are affected.
- [ ] Any new `_exclude` entry has both halves, and any file holding
      `{{ ... }}` has the `.jinja` suffix.

<!--
Deliberately short. CI runs the suite, actionlint, and the pin check, and
checks the Conventional Commit subject and sign-off of every commit — and a
checkbox for something a machine confirms is a box people tick without
reading, which teaches them to tick the rest without reading too.
-->
