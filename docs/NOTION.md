# Phase 2 Notion adapter

This phase is tested only with mocked transport against the requested API contract.
No live Notion call, token creation, Keychain read/write, or UI change is required
for verification. The URLSession implementation is available only through explicit
injection; the app does not instantiate the publishing service.

The fixed Blog Posts database and data source identifiers, API version, and
allowed category names live in `freewrite/Publishing/NotionConfiguration.swift`.
The target uses markdown create and replacement. The separately tested block
chunker is available for a future explicit fallback integration; automatic append
fallback would risk duplicating content after partial success.

## Metadata and status

Supported optional fields are `calli_status`, `categories`, `tags`, `notes`,
`published_date` and `notion_page_id`. Dates use Notion date strings, for example
`2026-11-15`. The Phase 1 YAML subset applies; unsupported known values fail closed.
The page title uses the first ATX or Setext heading outside fenced code, or the first
nonempty line, falling back to Untitled. The page body excludes frontmatter.

First push always starts as writing. Updates omit Status unless `calli_status` is
explicitly one of concept, writing, paused or published. There is no remote fetch,
so explicit local status can overwrite a remote terminal status. Leave local
status absent to preserve Notion's status. Published Date is omitted unless the
outgoing status is published; omission does not clear a pre-existing remote date.
Unknown categories are dropped. ID and Reminder are never written.

## Persistence and recovery

Use one sync service instance for the publishing session. Overlapping calls for
one canonical file are refused. Successful create/recreate IDs are written before
the service returns; unknown metadata and the current body are preserved. After
a local write failure, the service keeps the returned ID in memory and retries
only that write on its next call. The error also carries the ID for recovery.
Do not discard that service and blindly repeat a create after a persistence error.

There is no distributed transaction across Notion and the local file. If a create
response is lost or the process exits before ID persistence, inspect Notion and
restore the page ID manually before retrying. No automatic network retries hide
this ambiguity. Likewise, a failed body update may leave updated properties;
retrying replacement on the stored ID is safe once the error is resolved.

## Wenlong's later live test

A live test needs separate authorization and disposable content,
not personal entries or video transcripts. The smoke harness below uses fixed
in-memory content and does not open local entries. The current editor is not yet safe for
frontmatter-backed entries, so keep the app closed and wait for Phase 4 before
using normal editor workflows. Provide a Notion integration with access to Blog
Posts and store its token through the Keychain helper under service
`com.calli.secrets`, account `notion-token`, without shell arguments or logs.
Explicitly inject the URLSession transport only in that authorized test harness.
Verify the actual markdown endpoint contract and schema with one create and one
update, confirm a stable remote ID and exact local body, and inspect Status and
Published Date behavior. No schema changes are needed or authorized by this phase.

## Opt-in smoke script

Run `scripts/notion-live-test.sh --compile-only` to compile without reading the
Keychain or making requests. It compiles the existing publishing sources and their
storage/security dependencies into `.build-dd/notion-live-test`.
The compiler's `-parse-as-library` supports the async entry point,
`-module-cache-path` keeps compiler cache files in derived data, and `-o`
sets the binary output path.

Only an explicitly authorized operator should run
`CALLI_LIVE_TEST=1 scripts/notion-live-test.sh`. With shell tracing disabled,
the script reads service `com.calli.secrets` (`security -s`), account
`notion-token` (`-a`), requesting only its password (`-w`), directly into
the binary's inline `CALLI_NOTION_TOKEN` environment. It never stores the
credential in a file. The binary injects this token; it does not use Keychain.

Each run creates one Blog Posts page titled "Calli test", Status "writing",
with body "Created by Calli live smoke test. Safe to delete.", then invokes
one update with a second line "Updated once by Calli.". The existing adapter
implements that update as a properties PATCH and a markdown replacement PATCH.
The smoke transport permits only that POST and those two PATCHes to the returned
UUID. It refuses replacement creates and redirects, and never reads, queries,
deletes, or touches another page. Output contains only HTTP outcomes, the created
page ID, and its derived URL. Failures exit nonzero without printing error bodies.
A lost response can still leave a page created: inspect Notion manually before
rerunning. Every rerun creates a new disposable page; cleanup is manual.
