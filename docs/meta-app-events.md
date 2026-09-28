# Meta app events

App ID: `2316068148934163`. The mobile Client Token is configured in Android
`res/values/meta.xml` and iOS `Info.plist`. Never substitute a Meta App Secret.
Integration uses [facebook_app_events](https://pub.dev/packages/facebook_app_events)
0.30.5, which wraps Meta's native Android/iOS SDKs. Desktop/web builds do not emit.
The current Flutter toolchain migrated iOS to a 15.0 minimum deployment target
and added Swift Package Manager integration; Razorpay still uses CocoaPods.

## Event map

| Trigger | Event |
| --- | --- |
| Install / foreground activation | Native SDK automatic app events |
| Registration profile saved successfully | `fb_mobile_complete_registration` |
| Job first published successfully | `job_published` |
| Worker contact unlocked successfully | `worker_contact_unlocked` |
| Applicant successfully hired | `worker_hired` |
| Plans opened | `fb_mobile_content_view` for the employer plan catalog |
| User confirms checkout, before Razorpay opens | `fb_mobile_initiated_checkout` |
| Backend verifies payment | `fb_mobile_purchase`; subscription also emits `Subscribe` without duplicating revenue |
| Verified payment without a documented currency-unit total | `credit_topup_completed` / `subscription_payment_completed`, without guessed revenue |

Only essential conversion events are enabled. Navigation, OTP/login/logout,
searches, worker profile views, drafts/edits, shortlists, invites, interviews,
messages, invoice downloads, payment failures and cancellations emit no custom
Meta events. A central allowlist also blocks accidental nonessential events.

Purchase amount comes from the server's `amounts.total`, including GST. Legacy
credit top-up `amount` has no documented unit, so it is not guessed or divided by
100. To enable revenue for those top-ups, return `amounts.total` in currency units.
Pending checkout metadata survives app restarts. Recent 100 payment IDs are
persisted for local callback deduplication; this is not server-side exactly-once
analytics. Recurring renewals without an app callback need server-side events.
SDK errors never fail a business operation. Failed backend calls emit no success
conversion. Native advertiser-ID collection is disabled; there is no ATT prompt
or IDFA collection in this integration. Event parameters exclude phone, OTP,
email, GSTIN, names, job descriptions, query text and chat contents.

## Verify on a device

1. Fully rebuild/reinstall (hot reload cannot register the native SDK).
2. In Meta dashboard, configure Android package `com.superkarigar.employerapp`
   and activity `com.superkarigar.employerapp.MainActivity`. Configure the iOS
   platform with the app's actual bundle ID.
3. Select this app in Meta Events Manager → Test Events. Open the app, complete
   registration, publish a job, unlock a contact, hire and open plans.
4. Confirm/cancel checkout; cancellation must not produce Purchase. A successful
   backend-verified payment must produce one Purchase with its GST-inclusive
   amount and INR currency. Replaying the callback must not add another Purchase.
5. Save/edit drafts, search workers, send a message and download a PDF. These
   actions must not emit custom Meta events.

Native compilation and mocked automated tests validate wiring; actual event
receipt must be checked in Meta Events Manager with dashboard access.
