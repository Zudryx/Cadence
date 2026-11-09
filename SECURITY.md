# Security Policy

## Supported versions

Only the [latest release](https://github.com/Zudryx/Tactara/releases/latest) gets fixes. If you're on an older version, update first (run the updater, or download the newest `Tactara-x.y.z.zip`).

## What counts as a security problem

- **The Windows updater** (`Update Tactara.bat` / `Update-Tactara.ps1`). It downloads files and replaces the addon folder on your PC, so anything that could make it download from somewhere else, write outside the AddOns and backup folders, or run code it shouldn't is a security problem.
- **The addon doing something you didn't ask for**, such as casting without your key press, sending chat messages, or changing your keybinds or settings outside Tactara's own.
- Anything in a release download that doesn't match the code in this repository.

Wrong rotations, Lua errors and other bugs aren't security problems. Please use the [bug report](https://github.com/Zudryx/Tactara/issues/new/choose) form for those.

## How to report

Please **don't open a public issue** for a security problem. Instead, go to this repository's **Security** tab and click **Report a vulnerability**. That sends a private report only the maintainer can see.

Include what you found, how to reproduce it, and which version you were using.

## What happens next

- You'll get a reply within a week.
- If it's confirmed, a fix goes out in a new release as soon as it's ready, and the changelog will mention it once it's safe to.
- You'll be credited in the changelog if you'd like to be.
