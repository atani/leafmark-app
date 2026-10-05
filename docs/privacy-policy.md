# Leafmark — Privacy Policy

_Last updated: October 5, 2026_

Leafmark is built on a simple principle: **your books, highlights, and
reading habits belong to you — and to no one else, including us.**

## What we collect

Books, highlights, notes and reading habits stay on your device or in your own iCloud.
Purchase processing in enabled versions is described below.

- No account. You never sign up, log in, or give us an email address.
- No reading-behavior tracking or advertising. Enabled versions use RevenueCat for purchase analytics.
- No Leafmark cloud. Leafmark has no server. Your books, highlights, notes,
  reading positions, and reading statistics are stored on your device, in
  plain files you can inspect. Some of them are also synced through your own
  iCloud (see iCloud sync below).
- No reading content is sent to us. Core reading features work offline. Apple and, in enabled versions, RevenueCat handle purchase requests.

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

## Purchase processing with RevenueCat

Versions enabling RevenueCat use its purchase service for validation, fraud prevention,
purchase reliability and purchase analytics. Currently distributed versions keep it disabled.
When enabled, the SDK automatically sends past and new Apple purchase records, product and
transaction IDs, purchase dates and status, and applicable renewal, expiry or revocation data.
It uses a randomly generated anonymous app user ID. Request information includes app and OS
versions, locale, currency and network IP address. Production and Sandbox purchases may be included.

Names, email addresses, advertising identifiers, a custom cross-app identity and reading content
are not added to RevenueCat. Automatic device-identifier collection is disabled.
See [RevenueCat's Privacy Policy](https://www.revenuecat.com/privacy).

Apple StoreKit continues to determine ownership and eligible Family Sharing access.
Existing purchases, prices and free features remain unchanged. A repeat purchase is not required.
Uninstalling does not delete Apple's purchase history or RevenueCat records.
Send deletion requests privately; do not post receipts or transaction IDs in public issues.

## Changes

This policy describes automatic purchase processing in enabled versions.
Other future changes will be documented before activation.

## Contact

Privacy questions or deletion requests: <mailto:andphoto.co@gmail.com>
