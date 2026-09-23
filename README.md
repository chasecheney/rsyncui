# rsyncUI

A small native macOS front-end for `rsync`, written in Swift / SwiftUI.

Pick a source and destination (local paths or `user@host:/path`), tick the
options you want, review the exact command it will run, then Dry Run or Run.
Output streams live into the window and can be stopped at any time.

## Features

- Each path row has a dashed "Drop file or folder here" well; drag from the
  Finder onto it to set the path (typed paths and Choose… also work).
- Checkboxes for the common rsync options, grouped as Common, Preserve,
  Transfer, Deletion and Output, each with a tooltip explaining the flag.
- Exclude patterns, remote shell (`-e`), bandwidth limit and free-form extra
  arguments.
- Live command preview with a Copy button.
- Dry Run button (adds `-n`) and a confirmation before running with any
  `--delete*` / `--remove-source-files` option enabled.
- Streams rsync output (stdout + stderr) with the exit code explained.
- Picks up Homebrew rsync (`/opt/homebrew/bin/rsync`) if installed, falling
  back to the system `/usr/bin/rsync`; the binary path is editable.
- Remembers your last settings between launches.

## Building

1. Open `rsyncUI.xcodeproj` in Xcode 15 or later.
2. Select your signing team under Signing & Capabilities if you want to run a
   signed build (automatic signing is configured).
3. Build and run (⌘R). Requires macOS 13 Ventura or later.

The app runs without the App Sandbox so that rsync can read and write any
path you point it at. macOS will still prompt for access to protected folders
such as Desktop, Documents and external volumes the first time.

## Notes

- The system rsync on macOS is an older 2.6.x / openrsync build; some options
  such as `--info=progress2` need rsync 3.x (`brew install rsync`).
- A trailing slash on the source copies the *contents* of the folder rather
  than the folder itself. The "Append trailing slash" checkbox controls this.
