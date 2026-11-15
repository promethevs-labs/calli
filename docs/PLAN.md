# Calli plan

Calli is short for Calliope, the eldest of the nine Muses and the muse of eloquence and epic poetry, usually shown with a writing tablet. Prometheus Labs already names projects after Greek myth, and that origin should stay in the docs.

Calli is a fork of [freewrite](https://github.com/farzaa/freewrite) by Farza Majeed, kept under his MIT license with credit in the README. Wenlong likes Farza's apps because they feel like something Apple would ship, so the writing surface should stay calm and minimal. The goal is one quiet control panel for freewriting, shaping drafts, and sending work to Notion and Substack.

## Current state

Main is the upstream app plus the Calli README from PR #1. The default branch is `main`. There is no CI. The Xcode project, bundle id (`app.humansongs.freewrite`), and folder are still named freewrite. It is a SwiftUI macOS 14+ app of about 3,500 lines, most of it in `ContentView.swift`, with video journaling in `VideoRecordingView.swift` and `VideoPlayerView.swift`.

Entries are plain markdown files named `[UUID]-[yyyy-MM-dd-HH-mm-ss].md` in a `Freewrite` folder under the app Documents directory (upstream docs call this `~/Documents/Freewrite`; Phase 1 confirms the real sandbox path). Video entries add a `.mov`, thumbnail, and optional transcript under `Videos/`. The app autosaves about once a second, starts a fresh text entry when you open it on a new day, and already has Farza's timed, optional no-backspace ritual, font and theme controls, a local history sidebar, PDF export, and a Chat button that opens ChatGPT or Claude with a baked-in prompt. Tests are empty stubs. Against [farzaa/freewrite](https://github.com/farzaa/freewrite), Calli is ahead only by docs (README, this plan and FEATURES.md).

This document is the plan. It does not propose code changes as immediate work.

## Storage

Keep plain markdown and the current filename so existing Freewrite folders stay readable. The `Freewrite` folder stays for now. A rename to a Calli folder comes later, so every path goes through one storage-location resolver, and the later migration only has to change that resolver and still accept the old path.

Add optional YAML frontmatter for draft status and publish target ids (Notion page id, Substack draft id). Files with no frontmatter remain valid. The loader should ignore unknown keys. Write frontmatter on a later save or publish, and do not rewrite every old file up front.

## Notion

First sync is one-way push into Wenlong's capyscript workspace, using the official Notion API. The token lives in the macOS Keychain, never in git, chat, or logs.

Prefer the markdown endpoints on `Notion-Version: 2026-03-11`: `POST /v1/pages` with `markdown` and `markdown_version: "v2"` to create, and `PATCH /v1/pages/:page_id/markdown` with `replace_content` to update. If frontmatter already has a page id, update that page; if the update is not found, create one and store the new id. Persist a new id before any retry, so the operation stays idempotent. The target is the existing [Blog Posts](https://app.notion.com/p/capyscript/30830b139a6480dbad67f1c9244194d4) database in capyscript (data source `collection://30830b13-9a64-80c6-8bb0-000b67499f3d`). Calli maps onto its current properties and never changes the schema; any schema change goes through [HS] Lead first.

- `Title` (title) comes from the entry's first heading or first line.
- `Status` (status) is set to `writing` on first push. Calli only writes `concept`, `writing`, `paused` or `published`, and omits Status on update unless frontmatter explicitly sets `calli_status`. Phase 2 performs no remote read: omission preserves `kiv`, `not worth` or `give up`, but an explicit local status can overwrite them. Protecting those remote values even with explicit local status requires a future read/conflict policy.
- `Categories` (multi-select) comes from optional frontmatter, using only the existing options.
- `Tags` (multi-select, no options yet) comes from optional frontmatter.
- `Published Date` (date) is set only when an entry is marked published.
- `Writing Notes` (text) comes from an optional frontmatter note.
- `ID` (auto-increment) and `Reminder` (formula) are system-managed and never written.

The entry body becomes the page content.

If those endpoints cannot be used, fall back to blocks and respect official limits: 2,000 characters per `text.content`, 100 elements in any array of blocks or rich text, 100 children per append-children call, and 1,000 block elements / 500 KB per payload. Markdown create also fails above 5,000 blocks. Split long entries rather than oversizing a request. Calli stays the source of truth; do not pull edits back in v1.

## Substack

Substack has no official publish API. The Developer API, per its [terms](https://substack.com/api-tos), returns public profile data and forbids replicating core features. The official MCP server is read-only. Drafts and scheduling only exist through unofficial routes.

The practical options are: self-host [Substack Gateway OSS](https://github.com/jakub-k-slys/substack-gateway-oss) (MIT), a Python gateway with REST at `/api/v1/*` and MCP at `/mcp`, authenticated by a base64 token holding `publication_url`, `substack_sid`, and `connect_sid`; use [python-substack](https://github.com/ma2za/python-substack) (MIT), a Markdown-first unofficial library with draft-only defaults; or drive Wenlong's logged-in browser. The Gateway draft calls are confirmed in its API reference (`POST /api/v1/drafts`, `PUT` with optional `expected_updated_at` and `409` on conflict). The project looks maintained into November 2026. Cookies are password-grade: Keychain only, never git, chat, or logs.

Decision: put every Substack call behind one `PublishTarget` adapter, implement the first adapter against a local Gateway, and push drafts only. The Gateway runs as a launchd LaunchAgent that starts at login and binds to `127.0.0.1` only. Its launcher reads the Substack cookies from the Keychain at start, so they never sit in the plist, a file, git or logs. Wenlong reviews, schedules, and publishes in Substack. A later adapter (python-substack or the browser) can replace the Gateway when unofficial routes break, without touching the rest of Calli.

    protocol PublishTarget {
        var name: String { get }
        func pushDraft(_ doc: PublishDocument) async throws -> PublishResult
        func updateDraft(_ doc: PublishDocument, remoteId: String) async throws -> PublishResult
    }

`PublishDocument` is a title, markdown body, and local entry id. `PublishResult` is a remote id and optional URL, stored in frontmatter. Surface auth failures, expired cookies, a down gateway, conflicts, and a stale draft id in the UI. Never log cookie values.

## Keep, drop, and leave alone

Keep the freewrite ritual and quiet chrome: timer, optional no-backspace, fonts and size, theme, autosave, history, Finder path, and PDF export. Publish actions should live off the writing canvas, in history or a small panel.

Keep video journaling as it is. It is already a substantial local flow and fits thinking out loud, but it should not expand in the early publish phases.

Keep the ChatGPT and Claude prompt for now. It is a distinctive Farza feature and only opens a browser or copies text. Leave the unmerged `local-llm` and `all-entries` branches alone unless a later phase needs them. Do not add an in-app model early.

Leave obvious leftovers (unused `HeartEmoji`, unused `saveText` / `loadText`, debug history logs left on) for ordinary cleanup later.

## Upstream and phases

Keep an `upstream` remote on farzaa/freewrite and pull `upstream/main` when the diff is cheap. Put new Calli work in new files so `ContentView.swift` stays mergeable. Do not merge experimental upstream branches by default.

Phase 0 is this documentation. Phase 1 is frontmatter, Keychain, and a settled Documents path plus entitlements before any network call. Phase 2 is Notion one-way push. Phase 3 is the Substack adapter, push-to-draft only. Phase 4 is the quiet publish panel. Browser fallback, a folder rename, and the display-name and bundle id change come later. Transcripts are never published.

## Decisions (Nov 15 2026)

1. Keep the `Freewrite` folder for now and design for a later migration to a Calli folder.
2. Notion pages go into the existing Blog Posts database, mapped to its current properties, with no schema changes without asking [HS] Lead.
3. Substack goes through a local Substack Gateway, started at login by a LaunchAgent on `127.0.0.1` only, with cookies read from the Keychain.
4. Calli settles the sandbox path question in Phase 1 by checking a real build.
5. Video transcripts stay local and are never pushed.
6. The display name and bundle id rename comes later.
