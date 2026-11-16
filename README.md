# My Snake Arcade

**Play now:** https://my-snake-arcade.vercel.app/

A small Snake game in two implementations: dependency-free browser/PWA and
native Swift/SwiftUI for iPhone. Swipe or use the arrow pad; walls wrap; apples
add one point; rats multiply the current score by five. Levels follow score;
speed increases to a practical cap. Scores remain on the device.

## Status of this delivery

- Public Vercel production game: deployed and responding successfully.
- Native source, core tests, and a GitHub macOS build workflow: included.
- GitHub repository creation, first Xcode build, physical-device installation:
  **not completed in this environment**. Run the Windows publisher to begin.
- App Store/TestFlight: not submitted. No Apple paid program was purchased.

## Publish the GitHub build from Windows

Extract this entire ZIP, review the scripts, then open `Publish-GitHub.cmd`.
It asks before installing missing free prerequisites through Windows Package
Manager, uses GitHub's browser login, verifies the destination account, and
creates a **new public** `my-snake-arcade` repository. It refuses to overwrite
an existing repository or to use a directory already inside a Git repository.
Only files listed and SHA-256-verified in `PUBLISH-MANIFEST.json` are committed.
You can cancel at any prompt. No token or password belongs in this source.

On a successful initial push, `Build native iPhone app` starts under **Actions**.
After it succeeds, **Releases** contains a prerelease with `MySnake-unsigned.ipa`,
checksums, build information, and installation instructions. The workflow uses
no Apple credentials, GitHub Actions cache, or Actions artifact storage. It is
restricted to public repositories and main-branch code on a standard macOS runner.

Git and GitHub CLI official downloads: https://git-scm.com/downloads/win and
https://cli.github.com/. The script requires Windows PowerShell 5.1 or newer.
The publisher has been inspected, but not executed on a Windows machine here.
A failed initial upload may leave a local `.git` folder or an empty newly created
remote; review that state rather than deleting or overwriting existing content.

## Install on iPhone

Browser option: open the live game in Safari, tap Share, Add to Home Screen,
keep Open as Web App enabled when offered, and Add. Launch from the icon.
Wait for the menu's offline-ready message before relying on cached play.
Offline storage can be cleared or evicted by the browser/OS. Browser/system
controls and iOS Home gestures cannot be forcibly disabled by this game.

Native option: follow [Windows installation](docs/INSTALL-WINDOWS.md).
The unsigned IPA is a real native device binary, but it is not directly installable
by tapping it in Safari. Personal free-account signing normally needs renewal
every seven days. Neither that route nor GitHub Releases is App Store publication.

## Project layout

- `Web/`: static browser game, manifest, service worker, icon, Vercel configuration.
- `iOS/`: native Xcode project, exact engine sources and 18 unit tests.
- `.github/workflows/build-ios.yml`: tests, device build, and unsigned prerelease.
- `scripts/build-ios.sh`: reproducible build commands, no signing.
- `docs/`: native installation and release explanations.

Run engine tests with `swift test --package-path iOS`.
Run the full build on macOS with Xcode using `bash scripts/build-ios.sh`.
The native target supports iPhone with iOS 16 or later. Its Xcode build still
needs to succeed in the cloud before an installable, signed app can be produced.

## Vercel and source updates

The published Vercel project is `my-snake-arcade`. It was deployed directly, not
from GitHub, and it is **not automatically connected to the new repository**.
After creating the repository, connect it to this existing project through
Vercel Project Settings > Git, set Root Directory to `Web`, and keep the
framework preset Other, with no install/build command and no output override.
Do not import a second project unnecessarily. Future approved main-branch
changes can then deploy through that connection. The native workflow itself
does not alter Vercel or require a Vercel token.

## Costs, privacy, and rights

Vercel Hobby is free within its personal/noncommercial rules and quotas; this
package enables no paid plans, purchases, domains, or add-ons. GitHub standard
public runners have no compute-minute charges; this workflow uses GitHub Release
assets rather than Actions artifact/cache storage. Provider rules can change.
Apple's public App Store route normally requires US$99/year membership unless
eligible for a fee waiver. Free web publishing does not make App Store publishing
free.

The public game can be accessed by anyone with the link. The proposed public
repository exposes its source. No analytics, ads, game accounts, or remote
score service are included; hosting providers may retain ordinary request logs.
Native and web scores are stored separately. No broad license has been added.

References: [Vercel Hobby](https://vercel.com/docs/plans/hobby),
[GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions),
[GitHub Releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases),
[Apple membership](https://developer.apple.com/programs/whats-included/).
