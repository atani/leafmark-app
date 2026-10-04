# Leafmark — Privacy Policy

_Last updated: October 4, 2026_

Leafmark is built on a simple principle: **your books, highlights, and
reading habits belong to you — and to no one else, including us.**

## What we collect

**Nothing.**

- No account. You never sign up, log in, or give us an email address.
- No tracking. The app runs no analytics, no advertising, and no third-party
  trackers of any kind.
- No Leafmark cloud. Leafmark has no server. Your books, highlights, notes,
  reading positions, and reading statistics are stored on your device, in
  plain files you can inspect. Some of them are also synced through your own
  iCloud (see iCloud sync below).
- No network requests to us. The app does not phone home. It works fully
  offline.

## What stays on your device

- Imported EPUB files (stored in the app's Documents folder, included in your
  own iCloud/iTunes device backup if you have backups enabled — that backup is
  managed by Apple under your Apple account, not by us)
- Highlights and notes (a local JSON file, exportable as Markdown at any time)
- Reading positions and appearance settings
- Reading statistics (local sessions history)

Deleting the app deletes all of this from your device. Copies already synced
to iCloud stay in your iCloud account. We could not recover any of it even if
you asked us to, because we never had it.

## iCloud sync

- When you are signed in to iCloud with iCloud Drive turned on, Leafmark
  automatically copies your highlights (with their text and notes), bookmarks,
  reading positions, and the title and author of each book in your library to
  the app's folder in your iCloud Drive, so your other devices can pick them up.
- There is no switch for this in the app. Signing out of iCloud or turning off
  iCloud Drive stops it, and the app keeps working on its own.
- EPUB files, reading statistics, imported fonts, and appearance settings are
  not synced.
- The transfer is done by iOS, and the data is stored in your iCloud account.
  None of it is sent to us.

## Third parties

Leafmark uses the open-source [Readium Swift Toolkit](https://github.com/readium/swift-toolkit)
to render EPUB files. It runs entirely on your device and sends nothing
anywhere.

Starting with version 1.18, Leafmark includes the [RevenueCat purchases SDK](https://github.com/RevenueCat/purchases-ios).
It is currently disabled: it is never started and sends nothing to RevenueCat.
If we ever enable it, this policy will describe what it sends before it is
turned on.

## Changes

If a future feature ever needs to send data anywhere other than your device and
your own iCloud, it will be opt-in and documented here first.

## Contact

Questions: open an issue at <https://github.com/atani/epub-reader-ios/issues>
