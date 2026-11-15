# Storage foundations

The entries root is computed only in `freewrite/Storage/StorageLocation.swift`.
It appends `Freewrite` to Foundation's user Documents URL, exactly as upstream
did. ContentView still creates the directories; filenames and video lookup order
are unchanged. The resolver itself does no file I/O and accepts a Documents URL
for isolated tests.

## Sandbox finding (2026-11-15)

The built app keeps bundle id `app.humansongs.freewrite`. Inspection with
`codesign -d --entitlements - .build-dd/Build/Products/Debug/freewrite.app`
confirmed `com.apple.security.app-sandbox = true` and the new
`com.apple.security.network.client = true`, alongside the existing file, camera,
microphone and speech permissions. (`-d` displays signing information;
`--entitlements -` prints embedded entitlements.)

With that sandbox enabled, Foundation's Documents URL is inside the app's
container, so entries resolve to
`~/Library/Containers/app.humansongs.freewrite/Data/Documents/Freewrite`.
`~/Documents/Freewrite` would apply to an unsandboxed process. The user-selected
file entitlement does not redirect this automatic Documents lookup outside the
container. This conclusion follows from the resolver and signed entitlements;
the app was not launched against personal storage to prove it by writing a file.
A directory-only `ls -d` check found neither candidate folder on this Mac. No
entry files were listed, read, created, or migrated.

## Build and isolated tests

`xcodebuild -list -project freewrite.xcodeproj` confirmed the `freewrite` scheme.
The requested Debug build failed because the upstream team's development signing
certificate is absent. Local verification uses ad-hoc signing overrides, without
changing the project's signing team or bundle id:

```sh
xcodebuild -project freewrite.xcodeproj -scheme freewrite -configuration Debug -derivedDataPath .build-dd CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build
xcodebuild -project freewrite.xcodeproj -scheme freewrite -configuration Debug -derivedDataPath .build-dd -destination 'platform=macOS' -only-testing:freewriteTests CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= test
```

`-project` selects the project, `-scheme` selects its build/test scheme,
`-configuration` selects Debug, and `-derivedDataPath` keeps generated files in
ignored `.build-dd/`. `-destination` selects this Mac; `-only-testing` runs only
the foundation unit tests. The signing settings select an ad-hoc identity,
manual signing, and no developer team for this invocation. Xcode requires access
outside the terminal sandbox to run compiler macros and its test runner.

The unit-test target compiles the production storage helper files directly with
an empty test host. It never launches the editor or accesses personal entries.
The upstream UI-test templates are excluded because they launch the real app.

## Frontmatter boundary

The optional frontmatter codec is standalone and is not connected to loading,
previews, export, or autosave. The current editor still displays frontmatter as
ordinary text. Do not add metadata to live entries yet: safe integration needs
body-only editing and metadata preservation across entry selection and saves.
Plain existing entries retain their current behavior. The codec preserves raw
unknown keys and unedited formatting; it is a small YAML subset, not a general
YAML engine. Unsupported known values cannot be overwritten through its API.
The Keychain helper is also unused until a later phase. No networking exists.

Verification completed: the ad-hoc Debug build passed, and all nine hostless unit
tests passed. The shared `freewrite` scheme now includes those tests. Gitleaks
reported no leaks. No Keychain values were created during verification.
