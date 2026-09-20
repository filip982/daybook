# Phase 1, Step 6: Release Pipeline to TestFlight — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pushing a `v*` tag that sits on `main` archives the app, uploads it to TestFlight from GitHub Actions after the owner approves the job, with the version taken from the tag and a human-readable build number.

**Architecture:** Everything release-specific is a Makefile target or a small bash script, so the workflow only wires steps together and the same commands run locally. The archive is built **unsigned**; signing happens once, at export, with Apple's cloud-managed distribution certificate through the App Store Connect API key. The key is therefore needed by one step only.

**Tech Stack:** GNU Make, bash, XcodeGen 2.45.4, `xcodebuild archive` and `xcodebuild -exportArchive`, GitHub Actions environments.

**Spec:** `docs/superpowers/specs/2026-09-19-phase1-weather-ios-design.md`, sections 11 and 12 (step 6), decisions 15 to 17.

Step 6 runs before step 5 by owner-side readiness: the manual Apple steps are done and the spec allows step 6 "any time after step 1". The first TestFlight build therefore shows the Release placeholder screen; that is expected.

## Ruling recorded before execution

The spec says the API key flags go on both `xcodebuild` calls, which means a signed archive. On a fresh CI runner the keychain is empty, so automatic signing creates a new Apple Development certificate on every run, and the team's development certificate cap is reached after a few releases ("Your account has reached the maximum number of certificates"). This app has no capabilities and no entitlements file, so nothing is lost by archiving unsigned and letting `-exportArchive` do the whole distribution signing in the cloud. Task 5 amends the spec. If the first real export rejects the unsigned archive, the fallback is a signed archive plus a step that revokes the certificate the run created; that fallback is not built now.

## Global Constraints

- Every task is exactly one commit on branch `develop`. Never commit to `main`. Never push. Never create or push tags.
- Commit messages have a subject and a short body that says why. No `Co-Authored-By` trailer and no tool attribution. After committing, check `git log -1 --format=%B` and amend if a trailer appeared.
- Never read, print, create or request any secret value. Secrets exist only as the names `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_PRIVATE_KEY` in the GitHub environment `testflight`. No `.p8` file is ever created inside the repo.
- Never run `make ios-upload` with real values and never run `xcodebuild -exportArchive`. Local verification stops at the unsigned archive.
- Team ID `KTS29DB5CZ` and bundle identifier `com.replicantstudio.daybook` are plain values, not secrets.
- Workflow `run:` blocks never contain `${{ … }}` expressions. Values enter through `env:`.
- Third-party actions stay pinned by commit SHA. Top-level `permissions: contents: read` stays.
- Xcode 26.5, iOS 18.0 minimum. No new third-party packages. No fastlane.
- Build outputs go under `ios/build/`, which is already git-ignored.
- Bash scripts start with `#!/usr/bin/env bash` and `set -euo pipefail`, match the style of `scripts/verify-bundle.sh`, and are executable (`chmod +x`).
- No comments unless the reason would genuinely surprise a reader.

## File Structure

```
ios/App/Assets.xcassets/Contents.json                      asset catalog root
ios/App/Assets.xcassets/AppIcon.appiconset/Contents.json   single 1024 px icon slot
ios/App/Assets.xcassets/AppIcon.appiconset/AppIcon.png     1024x1024, sRGB, no alpha
ios/ExportOptions.plist                                    export settings for -exportArchive
scripts/release-info.sh                                    tag -> VERSION and BUILD, refuses tags off main
scripts/test-release-info.sh                               tests for the above in a throwaway git repo
scripts/verify-bundle.sh                                   + icon check, + optional version/build check
ios/project.yml                                            + team, signing style, icon name, LSRequiresIPhoneOS
Makefile                                                   + scripts-test, ios-archive, ios-verify-archive, ios-upload
.github/workflows/ios.yml                                  + tag trigger, scripts-test step, release job
README.md, the spec                                        status, build log, releasing notes, signing amendment
```

---

### Task 1: App icon and signing settings

An upload without a 1024 px icon is rejected by App Store Connect validation. The icon is a placeholder the owner can replace later.

**Files:**
- Create: `ios/App/Assets.xcassets/Contents.json`
- Create: `ios/App/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `ios/App/Assets.xcassets/AppIcon.appiconset/AppIcon.png`
- Modify: `ios/project.yml`
- Modify: `scripts/verify-bundle.sh`

**Interfaces:**
- Produces: a bundle whose `Info.plist` has `CFBundleIcons.CFBundlePrimaryIcon.CFBundleIconName` = `AppIcon`, and a `verify-bundle.sh` that fails without it. Task 3 adds more checks to the same script.

- [ ] **Step 1: Make the check fail first.** Add to `scripts/verify-bundle.sh`, directly before the `PrivacyInfo.xcprivacy` lines:

```bash
[ "$(plutil -extract CFBundleIcons.CFBundlePrimaryIcon.CFBundleIconName raw "$plist" 2>/dev/null)" = "AppIcon" ] \
  || fail "app icon missing from Info.plist"
[ -f "$app/Assets.car" ] || fail "asset catalog missing from bundle"
```

- [ ] **Step 2: Run `make ios-verify-bundle`.** Expected: FAIL with `verify-bundle: app icon missing from Info.plist`.

- [ ] **Step 3: Generate the icon.** Write this script to a temporary directory outside the repo (for example `$TMPDIR/make-icon.swift`), run it with `swift "$TMPDIR/make-icon.swift" ios/App/Assets.xcassets/AppIcon.appiconset/AppIcon.png` from the repo root after creating the folder. Do not commit the script. Do not use SF Symbols in the icon; their licence forbids it.

```swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let side = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(
    data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
)!

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [red / 255, green / 255, blue / 255, alpha])!
}

let sky = CGGradient(
    colorsSpace: space,
    colors: [color(0x2F, 0x66, 0xB8), color(0x8C, 0xBD, 0xEE)] as CFArray,
    locations: [0, 1]
)!
context.drawLinearGradient(sky, start: CGPoint(x: 0, y: side), end: CGPoint(x: 0, y: 0), options: [])

context.setFillColor(color(0xFF, 0xD6, 0x66))
context.fillEllipse(in: CGRect(x: 322, y: 414, width: 380, height: 380))

context.setFillColor(color(0xFF, 0xFF, 0xFF, 0.92))
for line in [CGRect(x: 292, y: 256, width: 440, height: 48), CGRect(x: 292, y: 168, width: 300, height: 48)] {
    context.addPath(CGPath(roundedRect: line, cornerWidth: 24, cornerHeight: 24, transform: nil))
    context.fillPath()
}

let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("could not write \(output.path)") }
```

- [ ] **Step 4: Verify the PNG.** Run `sips -g pixelWidth -g pixelHeight -g hasAlpha ios/App/Assets.xcassets/AppIcon.appiconset/AppIcon.png`. Expected: `pixelWidth: 1024`, `pixelHeight: 1024`, `hasAlpha: no`. Open the file with the Read tool and confirm it shows a blue gradient, a yellow sun and two white lines. If `hasAlpha` is `yes`, the upload would be rejected; fix the script, do not post-process.

- [ ] **Step 5: Write the catalog files.**

`ios/App/Assets.xcassets/Contents.json`:

```json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

`ios/App/Assets.xcassets/AppIcon.appiconset/Contents.json`:

```json
{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 6: Update `ios/project.yml`.** Under `targets.Daybook.info.properties` add `LSRequiresIPhoneOS: true` (next to `UILaunchScreen`). Under `targets.Daybook.settings.base` add:

```yaml
        DEVELOPMENT_TEAM: KTS29DB5CZ
        CODE_SIGN_STYLE: Automatic
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
```

- [ ] **Step 7: Run `make ios-verify-bundle`.** Expected: `verify-bundle: ok`. Then run `make` (the default goal). Expected: everything green.

- [ ] **Step 8: Commit.** Subject: `Add a placeholder app icon and the signing team`. Body: why (App Store Connect rejects uploads without a 1024 px icon; the team and automatic style let the owner run on a device and let export sign for distribution).

---

### Task 2: Version and build number from the tag

**Files:**
- Create: `scripts/release-info.sh`
- Create: `scripts/test-release-info.sh`
- Modify: `Makefile`
- Modify: `.github/workflows/ios.yml`

**Interfaces:**
- Produces: `scripts/release-info.sh <tag> [main-ref]`, default `main-ref` is `origin/main`. On success prints exactly two lines, `VERSION=<x.y.z>` and `BUILD=<n>`, and exits 0. On any problem prints one line starting with `release-info: ` to stderr and exits 1. Task 4 appends its output to `$GITHUB_ENV`.
- `BUILD` is the number of commits reachable from the tagged commit. For a tag on the tip of `main` that equals the commit count on `main`; using the tagged commit keeps a re-run of an old tag reproducible.

- [ ] **Step 1: Write the failing test** `scripts/test-release-info.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

repo="$tmp/repo"
git init --quiet --initial-branch=main "$repo"
cd "$repo"
git config user.name test
git config user.email test@example.com
git config commit.gpgsign false
git config tag.gpgsign false

for n in 1 2 3; do git commit --quiet --allow-empty -m "main $n"; done
git tag v1.2.3
git tag v1.2
git tag v1.2.3-beta
git tag 1.2.3
git checkout --quiet -b side
git commit --quiet --allow-empty -m "side 1"
git tag v9.9.9
git checkout --quiet main
git commit --quiet --allow-empty -m "main 4"

out="$("$here/release-info.sh" v1.2.3 main)"
[ "$out" = $'VERSION=1.2.3\nBUILD=3' ] || { echo "FAIL: expected VERSION=1.2.3 and BUILD=3, got: $out"; exit 1; }

reject() {
  if "$here/release-info.sh" "$1" main >/dev/null 2>&1; then echo "FAIL: $2 was accepted"; exit 1; fi
}

reject v1.2 "a two-part version"
reject v1.2.3-beta "a pre-release suffix"
reject 1.2.3 "a tag without the v prefix"
reject v0.0.1 "a tag that does not exist"
reject v9.9.9 "a tag that is not on main"
reject "" "an empty tag"

message="$("$here/release-info.sh" v9.9.9 main 2>&1 >/dev/null || true)"
[ "$message" = "release-info: tag v9.9.9 is not on main" ] || { echo "FAIL: unexpected message: $message"; exit 1; }

echo "test-release-info: ok"
```

- [ ] **Step 2: Run it.** `chmod +x scripts/test-release-info.sh && scripts/test-release-info.sh`. Expected: FAIL, because `scripts/release-info.sh` does not exist.

- [ ] **Step 3: Write** `scripts/release-info.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

tag="${1:-}"
main_ref="${2:-origin/main}"

fail() { echo "release-info: $1" >&2; exit 1; }

[[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "tag must look like v1.2.3, got '$tag'"
commit="$(git rev-parse --verify --quiet "refs/tags/$tag^{commit}")" || fail "tag $tag does not exist"
git merge-base --is-ancestor "$commit" "$main_ref" || fail "tag $tag is not on $main_ref"

echo "VERSION=${tag#v}"
echo "BUILD=$(git rev-list --count "$commit")"
```

- [ ] **Step 4: Run the test.** `chmod +x scripts/release-info.sh && scripts/test-release-info.sh`. Expected: `test-release-info: ok`.

- [ ] **Step 5: Wire it in.** In `Makefile`, change the `all` line to `all: lint scripts-test ios-test ios-verify-bundle` and add after the `lint` target:

```make
.PHONY: scripts-test
scripts-test:
	scripts/test-release-info.sh
```

In `.github/workflows/ios.yml`, add directly after the `Lint` step of the `test` job:

```yaml
      - name: Test scripts
        run: make scripts-test
```

- [ ] **Step 6: Run `make lint scripts-test`.** Expected: both green.

- [ ] **Step 7: Commit.** Subject: `Derive the release version and build number from the tag`. Body: why (the build number must be readable and reproducible, and a tag that is not on `main` must never ship).

---

### Task 3: Archive, verify and upload targets

**Files:**
- Create: `ios/ExportOptions.plist`
- Modify: `Makefile`
- Modify: `scripts/verify-bundle.sh`

**Interfaces:**
- Consumes: `verify-bundle.sh` from Task 1.
- Produces, for Task 4: `make ios-archive VERSION=<x.y.z> BUILD=<n>`, `make ios-verify-archive VERSION=<x.y.z> BUILD=<n>`, and `make ios-upload ASC_KEY_PATH=<absolute path>` which reads `ASC_KEY_ID` and `ASC_ISSUER_ID` from the environment. The archive lands at `ios/build/Daybook.xcarchive`.

- [ ] **Step 1: Extend `scripts/verify-bundle.sh`.** Add directly before the final `echo`:

```bash
if [ -n "${EXPECT_VERSION:-}" ]; then
  [ "$(plutil -extract CFBundleShortVersionString raw "$plist")" = "$EXPECT_VERSION" ] \
    || fail "marketing version is not $EXPECT_VERSION"
fi
if [ -n "${EXPECT_BUILD:-}" ]; then
  [ "$(plutil -extract CFBundleVersion raw "$plist")" = "$EXPECT_BUILD" ] \
    || fail "build number is not $EXPECT_BUILD"
fi
```

- [ ] **Step 2: Write** `ios/ExportOptions.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>upload</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>teamID</key>
	<string>KTS29DB5CZ</string>
	<key>manageAppVersionAndBuildNumber</key>
	<false/>
	<key>uploadSymbols</key>
	<true/>
</dict>
</plist>
```

`manageAppVersionAndBuildNumber` is false so App Store Connect never rewrites the build number that came from the tag. Run `plutil -lint ios/ExportOptions.plist`. Expected: `OK`.

- [ ] **Step 3: Add the targets to `Makefile`**, after the `ios-verify-bundle` target:

```make
ARCHIVE := ios/build/Daybook.xcarchive
VERSION ?= 0.0.0
BUILD ?= 1

.PHONY: ios-archive ios-verify-archive ios-upload
ios-archive: project
	xcodebuild archive -project ios/Daybook.xcodeproj -scheme Daybook -configuration Release -destination 'generic/platform=iOS' -archivePath $(ARCHIVE) -derivedDataPath $(DERIVED) -quiet MARKETING_VERSION=$(VERSION) CURRENT_PROJECT_VERSION=$(BUILD) CODE_SIGNING_ALLOWED=NO

ios-verify-archive:
	EXPECT_VERSION=$(VERSION) EXPECT_BUILD=$(BUILD) scripts/verify-bundle.sh $(ARCHIVE)/Products/Applications/Daybook.app

ios-upload:
	@test -n "$(ASC_KEY_PATH)" -a -n "$(ASC_KEY_ID)" -a -n "$(ASC_ISSUER_ID)" || { echo "ios-upload: ASC_KEY_PATH, ASC_KEY_ID and ASC_ISSUER_ID are required" >&2; exit 1; }
	@xcodebuild -exportArchive -archivePath $(ARCHIVE) -exportOptionsPlist ios/ExportOptions.plist -exportPath ios/build/export -allowProvisioningUpdates -authenticationKeyPath "$(ASC_KEY_PATH)" -authenticationKeyID "$(ASC_KEY_ID)" -authenticationKeyIssuerID "$(ASC_ISSUER_ID)"
```

The upload recipe starts with `@` so make does not echo the key identifiers.

- [ ] **Step 4: Verify the archive locally.** Run `make ios-archive ios-verify-archive VERSION=0.1.0 BUILD=7`. Expected: the archive builds and the last line is `verify-bundle: ok`. Then run `make ios-verify-archive VERSION=0.1.1 BUILD=7`. Expected: FAIL with `verify-bundle: marketing version is not 0.1.1`.

- [ ] **Step 5: Verify the guard.** Run `env -u ASC_KEY_ID -u ASC_ISSUER_ID make ios-upload`. Expected: exit code 2 and the line `ios-upload: ASC_KEY_PATH, ASC_KEY_ID and ASC_ISSUER_ID are required`. Do not run `ios-upload` in any other form.

- [ ] **Step 6: Run `make`.** Expected: everything green, and `git status` shows nothing under `ios/build/`.

- [ ] **Step 7: Commit.** Subject: `Add archive, archive check and TestFlight upload targets`. Body: why the archive is unsigned (a signed archive on a fresh runner creates a new development certificate per run until the team's cap is hit; the app has no entitlements, so export can do all signing in the cloud).

---

### Task 4: Release job

**Files:**
- Modify: `.github/workflows/ios.yml`

**Interfaces:**
- Consumes: `scripts/release-info.sh` (Task 2), the three make targets (Task 3), GitHub environment `testflight` with secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY` (already created by the owner).

- [ ] **Step 1: Add the tag trigger.** Under `on.push`, next to `branches` and `paths`, add:

```yaml
    tags:
      - "v*"
```

GitHub does not evaluate path filters for tag pushes, so a tag always runs the workflow.

- [ ] **Step 2: Never cancel a release in flight.** Change the `concurrency` block to:

```yaml
concurrency:
  group: ios-${{ github.ref }}
  cancel-in-progress: ${{ !startsWith(github.ref, 'refs/tags/') }}
```

- [ ] **Step 2b: Set an explicit default shell.** Add directly after the `permissions:` block and before `concurrency:`:

```yaml
defaults:
  run:
    shell: bash
```

- [ ] **Step 3: Add the job** after the `test` job, using the same checkout SHA the `test` job uses:

```yaml
  release:
    if: startsWith(github.ref, 'refs/tags/v')
    needs: test
    runs-on: macos-26
    timeout-minutes: 45
    environment: testflight
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          # Full history: the build number is a commit count and the tag must be an ancestor of origin/main.
          fetch-depth: 0

      - name: Select Xcode 26.5
        run: |
          sudo xcode-select -s /Applications/Xcode_26.5.app
          xcodebuild -version
          xcodebuild -version | grep -q "Xcode 26.5"

      - name: Install XcodeGen
        run: |
          brew install xcodegen
          xcodegen --version

      - name: Resolve version and build number
        env:
          TAG: ${{ github.ref_name }}
        run: |
          info="$(scripts/release-info.sh "$TAG" origin/main)"
          echo "$info"
          echo "$info" >> "$GITHUB_ENV"

      - name: Archive
        run: make ios-archive ios-verify-archive VERSION="${VERSION:?}" BUILD="${BUILD:?}"

      - name: Upload to TestFlight
        env:
          ASC_KEY_ID: ${{ secrets.ASC_KEY_ID }}
          ASC_ISSUER_ID: ${{ secrets.ASC_ISSUER_ID }}
          ASC_PRIVATE_KEY: ${{ secrets.ASC_PRIVATE_KEY }}
        run: |
          umask 077
          printf '%s\n' "$ASC_PRIVATE_KEY" > "$RUNNER_TEMP/AuthKey.p8"
          make ios-upload ASC_KEY_PATH="$RUNNER_TEMP/AuthKey.p8"

      - name: Remove API key
        if: always()
        run: rm -f "$RUNNER_TEMP/AuthKey.p8"
```

GitHub runs a step with an unspecified shell as `bash -e {0}`, without pipefail, so the workflow sets `defaults.run.shell: bash` and the version step avoids a pipe; a refused tag must stop the job.

- [ ] **Step 4: Validate.** Run `ruby -ryaml -e 'y = YAML.load_file(".github/workflows/ios.yml"); abort("release job missing") unless y["jobs"]["release"]["environment"] == "testflight"; abort("tag trigger missing") unless y[true]["push"]["tags"] == ["v*"]; puts "ok"'`. Expected: `ok`. (Ruby's YAML reads the key `on` as boolean `true`.) Then run `grep -n '\${{' .github/workflows/ios.yml` and confirm that no match is inside a `run:` block.

- [ ] **Step 5: Commit.** Subject: `Add the TestFlight release job for v* tags`. Body: why (a tag on `main` plus the owner's approval is the whole release; the key exists on disk for one step and is removed even when the upload fails).

---

### Task 5: Documentation

**Files:**
- Modify: `README.md`
- Modify: `docs/superpowers/specs/2026-09-19-phase1-weather-ios-design.md`

- [ ] **Step 1: README status.** Replace the first sentence of the Status paragraph, `Phase 1, iOS, step 4 of 6.`, with `Phase 1, iOS, steps 1 to 4 and 6 of 6.` and append to the same paragraph: ` Releases go to TestFlight from a tag; the first build still shows the placeholder screen.`

- [ ] **Step 2: README build log.** Add the row:

```
| 2026-09-20 | iOS step 6: app icon, version and build number from the tag, unsigned archive, cloud-signed upload to TestFlight behind an approval gate. |
```

- [ ] **Step 3: README releasing section.** Add between "Build log" and "Layout":

```markdown
## Releasing (iOS)

1. Merge `develop` into `main`.
2. Tag the commit on `main`, for example `git tag v0.1.0 && git push origin v0.1.0`.
3. Approve the `release` job in GitHub Actions.

The version comes from the tag and the build number is the commit count at the tag, for example `0.1.0 (142)`. The archive is built unsigned and signed once, in the cloud, at upload. The App Store Connect API key lives only in the protected `testflight` environment.
```

- [ ] **Step 4: Spec section 11.** Replace the sentence `Writes the API key to \`$RUNNER_TEMP\`, runs \`make ios-archive\` and \`make ios-upload\` with the key flags on both \`xcodebuild\` calls, deletes the key in an \`always()\` step.` with:

```
Runs `make ios-archive` unsigned and checks the archive with `make ios-verify-archive`, then writes the API key to `$RUNNER_TEMP`, runs `make ios-upload` with the key flags on the `-exportArchive` call only, and deletes the key in an `always()` step. The archive is unsigned because a signed archive on a fresh runner creates a new Apple Development certificate on every run until the team's certificate cap is reached; the app has no entitlements, so export does all signing. If a capability is added later, revisit this.
```

In the same section, replace `run three \`gh secret set\` commands for the environment` with `run three \`gh secret set\` commands for the environment (\`ASC_KEY_ID\`, \`ASC_ISSUER_ID\`, \`ASC_PRIVATE_KEY\`)`.

In the layout block near the top of the spec, replace `project, ios-test, ios-snapshots-record, ios-archive, ios-upload, lint-layers` with `project, ios-test, ios-snapshots-record, ios-archive, ios-verify-archive, ios-upload, scripts-test, lint`.

- [ ] **Step 5: Commit.** Subject: `Document the release flow; README step 6`. Body: why (the spec described a signed archive; the record has to match what ships and say when to revisit it).
