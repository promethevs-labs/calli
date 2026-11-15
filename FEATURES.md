# Calli features

## Current (from the code on main)

- Distraction-free SwiftUI macOS editor with a hidden title bar and a writing canvas that stays mostly empty.
- Local-first text entries saved as `[UUID]-[yyyy-MM-dd-HH-mm-ss].md` in the app Documents `Freewrite` folder.
- Autosave roughly once a second, with a new empty text entry created when you open the app and have nothing for today.
- First-run welcome guide loaded from bundled `default.md` (Farza's freewrite introduction).
- Timed writing sessions, default 15 minutes, adjustable by scrolling the timer, with bottom chrome fading while the timer runs.
- Optional no-backspace mode that blocks delete keys so a session stays forward-only.
- Font presets (Lato, Arial, system, Times New Roman), a random system font, and sizes from 16px to 26px.
- Light and dark color schemes, remembered in UserDefaults.
- History sidebar with previews, hover delete, PDF export, and a clickable path that reveals the folder in Finder.
- Chat button that opens ChatGPT or Claude with Farza's reflection prompt, or copies the prompt when the URL would be too long; refused for very short entries.
- Video journaling: camera and mic recording, live speech captions, local `.mov` plus thumbnail and optional `transcript.md`, and in-app playback with persisted volume.
- Copy transcript for a selected video entry, and the same Chat flow against the transcript when one exists.
- Fullscreen writing, randomized placeholder lines, and no spellcheck or markdown preview in the editor (by design).

## Phase 0

- Publish this plan and feature list; no product behavior changes.

## Phase 1

- Optional YAML frontmatter for draft status and publish target ids, with old files still loading as-is.
- Keychain storage for the Notion token and Substack session cookies (never files, git, or logs).
- Settled storage path and sandbox/network entitlements, documented before any live publish call.

## Phase 2

- One-way Notion push of a text entry as a page, via the official API, into the capyscript workspace.
- Store the Notion page id in frontmatter and reuse it for idempotent updates.

## Phase 3

- `PublishTarget` adapter with a Substack Gateway implementation that only creates or updates a draft.
- Keychain-backed cookie handoff to a local gateway; failed auth, conflicts, and a down gateway surfaced in the UI.

## Phase 4

- A small publish panel off the writing canvas, showing Notion and Substack status per entry and offering push actions.
- Open the resulting Notion page or Substack draft URL after a successful push.

## Later (not scheduled)

- Browser-driver fallback if unofficial Substack routes break.
- Optional push of a video transcript as a draft.
- Optional folder rename from `Freewrite` to `Calli`, and a later app display name / bundle id change.
- Ordinary cleanup of unused leftovers, and any careful fix to the Chat URL or stale welcome-guide guard.
