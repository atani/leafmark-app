#!/bin/sh
set -eu

# 設定が途中の archive を作らず、値そのものをビルドログへ出さないための検査です。
[ "${CONFIGURATION:-}" = "Release" ] || exit 0
fail() { printf '%s\n' "error: RevenueCat Release configuration rejected: $1" >&2; exit 1; }

case "${REVENUECAT_MODE:-}" in
    disabled)
        [ -z "${REVENUECAT_PUBLIC_SDK_KEY:-}" ] || fail 'disabled mode requires an empty public SDK key'
        ;;
    observer)
        [ "${PRODUCT_BUNDLE_IDENTIFIER:-}" = 'com.atani.inkwell' ] || fail 'unexpected app bundle'
        [ "${REVENUECAT_DATA_SHARING_APPROVED:-}" = YES ] || fail 'data sharing approval is required'
        [ "${REVENUECAT_INTEGRATION_READY:-}" = YES ] || fail 'verified integration is required'
        [ "${REVENUECAT_PRIVACY_READY:-}" = YES ] || fail 'published policy and ASC privacy verification are required'
        [ "${REVENUECAT_RELEASE_ENABLED:-}" = YES ] || fail 'Release activation approval is required'
        key="${REVENUECAT_PUBLIC_SDK_KEY:-}"
        case "$key" in appl_*) ;; *) fail 'invalid public SDK key format' ;; esac
        body="${key#appl_}"
        [ "${#body}" -ge 10 ] || fail 'invalid public SDK key format'
        case "$body" in *[!a-zA-Z0-9]*) fail 'invalid public SDK key format' ;; esac
        lower=$(printf '%s' "$key" | LC_ALL=C tr '[:upper:]' '[:lower:]')
        case "$lower" in *example*|*placeholder*|*replace*|*your*) fail 'placeholder SDK key is forbidden' ;; esac
        ;;
    *) fail 'unknown or missing mode' ;;
esac
