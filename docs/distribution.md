# Distribution

How Circle OLED Saver is packaged and shipped.

## Current approach: ad-hoc signed, no notarization

Releases are built by [`.github/workflows/release.yml`](../.github/workflows/release.yml) on every `v*` tag. The workflow:

1. Builds `CircleApp` in Release configuration on a GitHub-hosted `macos-14` runner.
2. **Ad-hoc signs** the resulting `Circle.app` (`CODE_SIGN_IDENTITY=-`). This produces a valid code signature using a null identity — no Apple Developer account, no certificate, no notarization.
3. Zips the bundle with `ditto -c -k --keepParent --sequesterRsrc` (preserves extended attributes correctly for `.app` bundles — `zip` does not).
4. Attaches `Circle.zip` to a GitHub Release for the tag.

### Why ad-hoc signing (not unsigned)?

On Apple Silicon (arm64), the kernel refuses to launch any binary with **no** signature whatsoever — a truly-unsigned `.app` shows *"Circle is damaged and can't be opened"* even before Gatekeeper gets involved. Ad-hoc signing satisfies the kernel's "must have some signature" check at zero cost.

### What users see

Because the build is not signed with a Developer ID certificate and not notarized:

- **Double-clicking the app the first time** → Gatekeeper blocks: *"Apple cannot check it for malicious software."*
- **Workaround:** right-click the app → **Open** → **Open** in the warning dialog. Required only on the first launch; subsequent launches work normally.

This experience is documented in the GitHub Release body and on the landing page.

### Tradeoffs

| | Ad-hoc (current) | Developer ID + Notarization |
|---|---|---|
| Cost | Free | $99/year Apple Developer Program |
| First launch | Right-click → Open required | Double-click works |
| Update mechanism | Manual download | Same, plus Sparkle integration possible |
| CI complexity | Minimal | Requires cert in keychain, app-specific password, or App Store Connect API key |

If/when an Apple Developer account is acquired, the workflow can be extended to:

1. Import a Developer ID Application certificate into the runner keychain (from `secrets.SIGNING_CERTIFICATE_P12_BASE64` + `secrets.SIGNING_CERTIFICATE_PASSWORD`).
2. Re-sign with `CODE_SIGN_IDENTITY="Developer ID Application: <Name> (<TeamID>)"` and the hardened runtime entitlement.
3. Submit to Apple's notary service via `xcrun notarytool submit --wait`.
4. Staple the ticket with `xcrun stapler staple Circle.app` before zipping.

## Releasing a new version

**The git tag is the single source of truth for version.** Both `Info.plist` files use placeholder values (`$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)`); `project.yml` provides defaults for local Xcode builds, and the release workflow overrides them at build time from the pushed tag.

To cut a release:

```bash
git tag v1.4.0
git push origin v1.4.0
```

That's the entire procedure — no file edits required. The workflow:

- Validates the tag matches `vMAJOR.MINOR.PATCH`.
- Strips the leading `v` and passes the rest as `MARKETING_VERSION` to `xcodebuild` → embedded as `CFBundleShortVersionString` in the built `Circle.app`.
- Passes `github.run_number` as `CURRENT_PROJECT_VERSION` → embedded as `CFBundleVersion` (monotonically increasing across all workflow runs in the repo).
- Verifies the embedded version matches the tag before publishing.
- Auto-generates release notes from PRs/commits since the previous tag.

The first release (`v1.3.4`) reflects the version already declared in `Info.plist` when this pipeline was added — the binary itself was not previously published, just versioned during development.

### Updating the local-build default

The defaults in `project.yml` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`) only affect local Xcode builds — they don't influence releases. They're useful when running the app from Xcode for development and want the About dialog to reflect a sensible version. Bump them when convenient (e.g. alongside a release tag) but it's not required.

A manual run is also available via **Actions → Release → Run workflow** (provide the tag name).

## Public-repo CI hardening

The release workflow is safe to run on a public repository:

- **Trigger is `push` of `v*` tags only** (plus manual `workflow_dispatch`). No `pull_request` trigger, so fork PRs cannot run this workflow. Tags can only be pushed by repo collaborators.
- **`permissions: contents: write`** is set at the workflow level. The auto-provided `GITHUB_TOKEN` has only the permissions needed to create a release — no broader repo access.
- **No external secrets** are used. Ad-hoc signing requires nothing beyond what GitHub provides. Nothing to leak in logs.
- **Third-party actions** are pinned to major versions (`actions/checkout@v4`, `softprops/action-gh-release@v2`). For stricter supply-chain hygiene, pin to commit SHAs instead.

The repository default workflow permissions can also be tightened under **Settings → Actions → General → Workflow permissions** to "Read repository contents and packages permissions" — the workflow above explicitly opts back in to `contents: write`, so the stricter default is recommended.
