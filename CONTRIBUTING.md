# Contributing to Sill

Thank you for helping improve Sill. Issues and pull requests may be written in English or Chinese.

## Before starting

- Search existing issues and pull requests for related work.
- For a significant behavior change, open an issue describing the problem and proposed approach first.
- Keep changes focused. Avoid unrelated refactoring or formatting changes in a bug fix.
- Use public macOS APIs and preserve window privacy. Do not add window-title telemetry or arbitrary keyboard monitoring.

## Local setup and validation

See [development notes](docs/DEVELOPMENT.md) for requirements, architecture, and signing.

```sh
swift test
CODE_SIGN_IDENTITY=- ./scripts/build-app.sh
git diff --check
```

The explicit ad-hoc identity keeps this check independent of personal signing certificates. For repeated interactive use, follow the stable-signing instructions in the development notes.

Add regression tests for changes to search, geometry, or other testable logic. For UI and Accessibility changes, manually exercise the affected flow and describe what you observed. Automated tests do not establish that Spaces, permissions, or window switching work correctly on every Mac.

Update both [English](README.md) and [Chinese](README.zh-CN.md) READMEs when shared user-facing instructions change. Keep interface strings available in both languages.

## Reporting a bug

Include the Sill version or commit, macOS version, CPU architecture, steps to reproduce, expected behavior, and actual behavior. For window-management issues, include relevant display, Space, and target-app details.

Remove personal window titles, file paths, credentials, and other private information from screenshots or logs before sharing them. Never submit signing certificates or private keys.

## Pull requests

Describe the problem, the resulting behavior, and the checks performed. Note any remaining limitations or manual checks you could not perform. Include screenshots for visible UI changes when useful, with private information removed.

Use descriptive commit messages and make sure the macOS CI checks pass. For documentation-only changes, check links, commands, and language parity; no new application tests are needed.

Be respectful and constructive when discussing changes. By submitting a contribution, you agree that it may be distributed under the project's [MIT license](LICENSE).
