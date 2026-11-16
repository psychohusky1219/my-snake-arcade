# Install the native app from Windows

## What you downloaded

`MySnake-unsigned.ipa` is a compiled, native iPhone app that needs to be signed
for your phone. It is not a Safari installer, App Store listing, or TestFlight app.
The native app and browser edition keep separate local high scores.

## Personal installation

1. Download `MySnake-unsigned.ipa` from the repository's Releases page on Windows.
2. Obtain Sideloadly only from its official website: https://sideloadly.io/
   Follow its current Windows prerequisites (including the required Apple device
   software). This is third-party software; review its own instructions and policies.
3. Connect your iPhone with a USB cable and accept the phone's Trust prompt.
4. Open Sideloadly, select the iPhone, and select the IPA. Enter your Apple account
   directly in that application, never in this repository or in ChatGPT. Follow
   any Apple two-factor authentication, developer trust, and Developer Mode prompts.
5. Complete installation and open My Snake on the phone. Free-account installations
   normally require renewal every seven days. Follow Sideloadly's auto-refresh
   instructions and keep the Windows computer available for refreshes.

Do not disable Windows security or use unknown signing certificates/profiles.
This package does not install signing software, change phone settings, or collect
credentials. Installation has not been tested on your physical iPhone.

## Costs and publishing

The workflow uses a standard macOS runner only when the repository is public.
It does not run in private repositories, use larger runners, cache dependencies,
or upload GitHub Actions artifacts. Successful IPAs are published as Release assets.
No Apple membership or Vercel upgrade is purchased by any included script.

The public browser game is free within Vercel Hobby's personal/noncommercial limits.
Publishing a native app through Apple's App Store normally requires a paid
Apple Developer Program membership (US$99/year, unless eligible for a waiver).
An unsigned GitHub release does not bypass Apple signing or App Store review.

## Official references (checked November 2026)

- GitHub Actions: https://docs.github.com/en/billing/concepts/product-billing/github-actions
- GitHub Releases: https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases
- Apple accounts: https://developer.apple.com/help/account/basics/about-your-developer-account
- Apple membership: https://developer.apple.com/programs/whats-included/
- Sideloadly instructions: https://sideloadly.io/faq
