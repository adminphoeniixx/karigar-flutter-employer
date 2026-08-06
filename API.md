# Karigar — Employer App API (v1)

Token-based JSON API for the **employer** mobile app. Same stack as the worker
API — **Laravel Sanctum** personal access tokens issued after mobile-OTP
verification. Additive and independent of the web (Inertia/Fortify) app.

- **Base URL:** `https://<host>/api/v1`
- **Auth header:** `Authorization: Bearer <token>`
- **Content type:** `application/json` (file uploads use `multipart/form-data`)
- **Always send:** `Accept: application/json`

Validation errors return `422` with `{ "message": ..., "errors": { field: [msg] } }`.
Auth failures `401`; role/permission failures `403`. 🔒 = requires a token.
All `employer/*` routes require the token's user to have the **employer** role.

Jobs, applicants, contact-unlock quota and reviews are scoped to the
**employer account** (owner + team members see the same data), exactly like the web.

---

## 1. Auth (public/shared)

Same endpoints as the worker app — pass `role: "employer"` when verifying.

### `POST /auth/otp/send`
```json
// body → 200
{ "phone": "9876543210" }
{ "message": "OTP sent successfully", "cooldown": 30 }
```

### `POST /auth/otp/verify`
Verify OTP → issue a token. Registers the account (and an empty employer profile)
on first login.
```json
// body
{ "phone": "9876543210", "otp": "4821", "role": "employer", "device_name": "iPhone 15" }
// 200
{
  "token": "12|xxxxxxxx...",
  "is_new": true,
  "needs_registration": true,   // route new employers into the "Set up your business" wizard
  "user": { "id": 8, "name": "Employer 3210", "phone": "9876543210", "role": "employer",
            "locale": "en", "avatar_url": null, "company_name": null,
            "rating": { "average": 0, "count": 0 } }
}
```

### `POST /auth/logout` 🔒 → `{ "message": "Logged out." }`
### `GET /auth/me` 🔒 → `{ "user": { ...UserResource }, "unread_notifications": 3 }`
### `DELETE /account` 🔒 — body `{ "confirm": true }`, revokes all tokens.
### `POST /locale` 🔒 — body `{ "locale": "hi" }`, updates app language.

---

## 2. Reference data (public)
`GET /reference` now also returns the employer-app dropdowns:
```json
{
  "states": [...], "skills": [...], "job_categories": [...],
  "wage_types": ["hourly", "daily", "monthly"],
  "shifts": ["day", "night", "rotational", "flexible"],
  "perks": ["Food", "Accommodation", "Travel allowance", "Bonus", "Overtime pay", "Weekly off"],
  "contact_modes": ["apply", "call", "both"],
  "industries": ["Construction & Real Estate", "Interiors & Furnishing", ...],
  "company_sizes": ["1–10", "11–50", "51–200", "200+"],
  "hiring_as": ["business", "contractor", "individual"],
  "interview_modes": ["site", "phone", "video"],
  "worker_sorts": ["best_match", "nearest", "rating", "experience", "wage_low"],
  "credit_packs": [{ "key": "topup_25", "credits": 25, "price": 299, "label": "25 credits" }],
  "boost_tiers": [{ "key": "standard", "credits": 1, "days": 3, "label": "Standard boost" }],
  "app_languages": [...]
}
```
`GET /reference/cities?state=Tamil%20Nadu` → `{ "cities": [...] }`

---

## 3. Dashboard (home screen) 🔒

### `GET /employer/dashboard`
Everything the home screen needs in one call.
```json
{
  "greeting": "Sri Sai Constructions",
  "profile": { ...EmployerProfileResource },
  "credits": { ...CreditSummary },          // home "12 contact credits" card
  "stats": {
    "active_jobs": 4, "total_applicants": 37, "shortlisted": 9,
    "interview": 2, "hired": 5,
    "unread_notifications": 3, "unread_messages": 1,
    "verified": true, "profile_completion": 88
  },
  "features": { "verification_enabled": true },
  "active_jobs": [ { ...EmployerJobResource } ],       // up to 5 active jobs
  "recent_applicants": [ { ...ApplicantResource } ]    // up to 5 newest
}
```

---

## 4. Business profile 🔒

### `GET /employer/profile` → `EmployerProfileResource`
```json
{
  "id": 3, "name": "Anil Sharma", "company_name": "Sri Sai Constructions",
  "hiring_as": "business", "industry": "Construction & Real Estate",
  "company_size": "11–50", "hiring_categories": ["Plumbing", "Electrical"],
  "gstin": "22ABCDE1234F1Z5", "phone": "9876543210", "about": "...",
  "address": "...", "city": "Chennai", "state": "Tamil Nadu",
  "location_label": "Chennai, Tamil Nadu", "latitude": 13.08, "longitude": 80.27,
  "logo_url": "https://.../storage/logos/x.jpg", "verified": true,
  "rating": { "average": 4.6, "count": 18 }, "completion": 88
}
```

### `PUT|PATCH /employer/profile`
Create/update the business profile — also used to finish the registration wizard.
`name` is the contact person (saved on the user); everything else on the profile.
```json
// body (all optional)
{ "name": "Anil Sharma", "company_name": "Sri Sai Constructions",
  "hiring_as": "business",                    // business | contractor | individual
  "industry": "Construction & Real Estate",
  "company_size": "11–50",                    // from reference company_sizes
  "hiring_categories": ["Plumbing", "Electrical"],
  "phone": "9876543210", "about": "...", "address": "...",
  "city": "Chennai", "state": "Tamil Nadu", "latitude": 13.08, "longitude": 80.27,
  "gstin": "22ABCDE1234F1Z5" }
// 200 → EmployerProfileResource
```

### `POST /employer/profile/logo` — `multipart/form-data`, field `logo` (image ≤2 MB)
→ `{ "logo_url": "https://.../storage/logos/x.jpg" }`

---

## 5. Jobs 🔒

**EmployerJobResource** includes the full editable field set plus
`status`, `status_label`, `wage_label`, `location_label`, `share_url`,
`boost: { active, tier, until }` and
`stats: { views, applicants, shortlisted, interview, hired }` — everything the
Manage Job funnel needs.

### `GET /employer/jobs?status=active|closed|draft&q=<search>`
Paginated (15/page), newest first. `status`/`q` optional (the My Jobs tabs).

### `GET /employer/jobs/{job}` → `EmployerJobResource`

### `POST /employer/jobs`
Post a job (or save a draft with `status: "draft"`). Notifies matching workers
when `status: "active"`. Returns `422` if the plan's job-post limit is reached.
```json
// body
{
  "title": "Plumber for Apartment Project",
  "description": "12-floor residential project...",
  "category": "Plumbing", "skills": ["Plumbing", "Pipe Fitting"],
  "wage_min": 800, "wage_max": 1000, "wage_type": "daily",
  "city": "Chennai", "state": "Tamil Nadu", "latitude": 13.08, "longitude": 80.27,
  "vacancies": 3, "experience_min": 1,
  "shift": "day", "perks": ["Food", "Accommodation"],
  "contact_mode": "both", "contact_phone": "9876543210",
  "requires_worker_fee": false, "status": "active"
}
// 201 → { "message": "Job posted.", "job": { ...EmployerJobResource } }
```
Rules: `title` req; `description` req ≤5000; `vacancies` req ≥1;
`wage_type` in hourly/daily/monthly; `wage_max` ≥ `wage_min`;
`experience_min` 0–60; `shift` in day/night/rotational/flexible;
`contact_mode` in apply/call/both
(`contact_phone` required for call/both); `status` in draft/active/closed;
`perks.*` from the reference `perks` list.

### `PUT|PATCH /employer/jobs/{job}` — same body → `{ "message", "job" }`
### `POST /employer/jobs/{job}/close` → sets status `closed`, `{ "message", "job" }`
### `DELETE /employer/jobs/{job}` → `{ "message": "Job deleted." }`

### `POST /employer/jobs/{job}/boost`
Promote a job (Boost sheet). Costs purchased credits — `standard` = 1 credit /
3 days, `turbo` = 3 credits / 7 days (see `boost_tiers` in `/reference`).
Boosting a boosted job extends it instead of shortening it.
```json
// body → 200
{ "tier": "standard" }
{ "message": "Job boosted for 3 days.", "job": {...}, "credits": { ...CreditSummary } }
// 422 when short on credits → drives the "out of credits" sheet
{ "message": "You do not have enough credits to boost this job.",
  "code": "out_of_credits", "credits": {...} }
```

### `GET /employer/jobs/{job}/matches`
"✨ Matched for this job" — available workers whose skills/category, city and
minimum experience fit the job and who have **not** applied yet.
```json
{ "workers": [ { "id", "user_id", "name", "avatar_url", "skills": [...], "city",
    "experience_years", "expected_wage", "wage_type", "available", "verified",
    "rating", "invited": false } ], "total": 6 }
```

### `POST /employer/jobs/{job}/invite`
Invite a matched worker to apply — pushes + in-app notification. Idempotent:
inviting twice returns `200` with `"invited": true` and sends nothing.
```json
// body → 201
{ "worker_id": 42, "message": "Site is in Guindy, start Monday." }
{ "message": "Invite sent to Ravi.", "invited": true }
```

---

## 6. Applicants 🔒

**ApplicantResource** carries the application (`status`, `stage`, `shortlisted`,
`cover_note`, `expected_wage`, `contact_unlocked`, `ai`, `offer`, `interview`)
and an embedded `worker` summary. Worker `phone`/`email` are `null` until the
contact is unlocked. `stage` is one of
`pending | shortlisted | interview | hired | rejected` — the stages are
exclusive, so the segmented tabs add up.

### `GET /employer/jobs/{job}/applicants?stage=all|pending|shortlisted|interview|hired|rejected&sort=best_match|recent`
Paginated (20/page). Response `additional`:
```json
{
  "data": [ { ...ApplicantResource } ],
  "counts": { "all": 12, "pending": 8, "shortlisted": 3, "interview": 1, "hired": 1, "rejected": 0 },
  "links": {...}, "meta": {...}
}
```

### `GET /employer/applicants/{application}` → single `ApplicantResource`

### `PATCH /employer/applicants/{application}/status`
Hire or reject — notifies the worker (in-app + email). The Hire sheet's offer
fields are stored on the application and echoed back as `applicant.offer`
(ignored on a reject).
```json
// body → 200
{ "status": "accepted",            // or "rejected"
  "offered_wage": 900, "start_date": "2026-08-05", "message": "Report by 9 AM" }
{ "message": "Applicant Accepted.", "applicant": { ...ApplicantResource } }
```

### `POST /employer/applicants/{application}/interview`
Schedule (or reschedule) an interview — moves the applicant into the Interview
stage, auto-shortlists them and notifies the worker (in-app + push).
```json
// body → 200
{ "interview_at": "2026-08-02T10:30:00+05:30", "mode": "site", "note": "Gate 2, ask for Anil" }
{ "message": "Interview invite sent.", "applicant": { ...stage: "interview" } }
```
`mode` is one of `site | phone | video` (see `interview_modes` in `/reference`).

### `DELETE /employer/applicants/{application}/interview`
Cancel it — the applicant drops back to `shortlisted`.

### `POST /employer/applicants/{application}/shortlist`
Toggle shortlist. Shortlisting notifies the worker.
→ `{ "message", "applicant": { ...ApplicantResource } }`

### `POST /employer/applicants/{application}/unlock`
Reveal the worker's contact, spending one contact credit — the plan's unlock
allowance first, then purchased top-up credits.
→ `{ "message": "Contact unlocked.", "applicant": {...}, "credits": { ...CreditSummary } }`
`422` with `"code": "out_of_credits"` when nothing is left.

### `POST /employer/jobs/{job}/rescore`
Queue AI scoring for the job's applicants (`force=1` re-scores everyone).
→ `{ "message": "...", "queued": 7 }`

---

## 7. Find Workers 🔒
Typesense-powered directory. Rows beyond the plan's contact quota are returned
`locked: true` with `phone: null`.

### `GET /employer/workers?q=&state=&city=&skill=&page=`
Full filter-sheet support:
`experience_min` (years), `wage_min` / `wage_max`, `languages[]`,
`verified=1` (KYC only), `available=1` (available now),
`sort=best_match|nearest|rating|experience|wage_low`, and
`latitude` + `longitude` (+ optional `radius_km`) for "distance from site".
When a point is given, each row also carries `distance_km`.
```json
{
  "workers": { "data": [ { "id", "user_id", "name", "avatar_url", "bio",
      "skills": [...], "city", "state", "experience_years", "expected_wage",
      "wage_type", "available", "verified", "rating", "phone", "locked" } ],
    "links": {...}, "meta": {...} },
  "filters": { "q": null, ... },
  "access": { "quota": 25, "accessible": 6, "total": 6, "has_plan": true }
}
```

### `GET /employer/workers/{worker}`
`{worker}` is a **worker profile id**. Contact revealed only if this employer
has unlocked the worker through any application.
```json
{
  "worker": { "id", "user_id", "name", "avatar_url", "bio", "skills": [...],
    "spoken_languages": [...], "city", "state", "experience_years", "education",
    "expected_wage", "wage_type", "available", "verified",
    "phone": null, "email": null, "contact_unlocked": false },
  "rating": { "average": 4.8, "count": 23 },
  "reviews": [ { ...ReviewResource } ]
}
```

---

## 8. Business verification (KYC) 🔒
GSTIN is stored on the profile; business PAN + proof docs on the shared KYC record.

### `GET /employer/kyc`
→ `{ "gstin": "22ABCDE1234F1Z5", "kyc": { "status": "verified", "status_label": ...,
     "masked_pan": "ABCXX1234F", "remarks": null, ... } | null }`

### `POST /employer/kyc` — `multipart/form-data`
```
gstin=22ABCDE1234F1Z5   pan_number=ABCDE1234F
gst_doc=@gst.pdf        pan_doc=@pan.jpg      (jpg/png/pdf ≤5 MB; docs optional on re-submit)
// 201 → { "message": "Business verification submitted for review.", "gstin", "kyc": {...} }
```

---

## 9. Notifications 🔒 (shared with worker app)

### `GET /notifications` → `{ "notifications": { paginated }, "unread": 3 }`
### `POST /notifications/{id}/read` → `{ "unread": 2 }`
### `POST /notifications/read-all` → `{ "unread": 0 }`

---

## 10. Reviews 🔒

### `GET /employer/reviews`
Reviews workers left for this employer, paginated (15/page).
```json
{
  "data": [ { "id", "rating": 5, "comment": "...", "created_ago": "1 month ago",
              "reviewer": { "id", "name" }, "job": { "id", "title" } } ],
  "summary": { "average": 4.6, "count": 18 },
  "links": {...}, "meta": {...}
}
```

### `POST /employer/applicants/{application}/review`
Rate a **hired** worker (application must be `accepted`; one review per worker+job).
```json
// body → 201
{ "rating": 5, "comment": "Neat work, finished ahead of time." }
{ "message": "Review submitted.", "review": { ...ReviewResource } }
```

---

## 11. Team members 🔒 (account owner only)
Owner invites staff by mobile number; they log in with their own OTP.
Roles: `manager` (posts & manages jobs) · `recruiter` (works applicants only).
Non-owners get `403`.

### `GET /employer/team`
→ `{ "members": [ { "id", "name", "phone", "role", "added_ago" } ], "roles": ["manager", "recruiter"] }`

### `POST /employer/team`
```json
// body → 201
{ "name": "Ravi", "phone": "9876500000", "role": "recruiter" }
{ "message": "Team member added — they can log in with their mobile number.",
  "member": { "id", "name", "phone", "role", "added_ago" } }
```
`422` if the number is your own, belongs to a worker, already runs/joins a team,
or already has its own job posts.

### `PATCH /employer/team/{member}` — body `{ "role": "manager" }` → `{ "message", "role" }`
### `DELETE /employer/team/{member}` → `{ "message": "Team member removed." }`

---

## 12. Messages 🔒 (chat — shared with the worker app)
Employer ↔ worker threads, scoped to the employer **account** so team members
share one inbox. An employer may only open a thread with a worker who applied
to one of their jobs (unlocking a contact implies an application).

### `GET /conversations`
```json
{
  "data": [ { "id": 4, "job": { "id", "title" },
      "participant": { "id", "name", "role", "avatar_url" },
      "last_message": { "body", "sent_by_me", "created_ago" },
      "unread": 2, "last_message_at": "..." } ],
  "unread_total": 3, "links": {...}, "meta": {...}
}
```

### `POST /conversations`
Start or re-open a thread. Employers send `worker_id`, workers send
`employer_id`; `job_id` (optional) pins the thread to a job and `body`
(optional) sends the first message.
→ `201` (new) / `200` (existing) `{ "conversation": { ...ConversationResource } }`
`422 { "code": "chat_not_allowed" }` when there is no application between them.

### `GET /conversations/{conversation}`
Latest 30 messages (oldest→newest) and marks the thread read.
```json
{ "conversation": {...},
  "messages": [ { "id", "body", "sender_id", "sent_by_me", "read", "created_at", "created_ago" } ],
  "meta": { "current_page": 1, "last_page": 2, "per_page": 30, "total": 34 } }
```

### `POST /conversations/{conversation}/messages` — body `{ "body": "Can you start Monday?" }`
→ `201 { "message": { ...ChatMessageResource } }`, pushes to the other side.

### `POST /conversations/{conversation}/read` → `{ "unread": 0, "unread_total": 1 }`

Non-participants get `403`.

---

## 13. Credits & Plans 🔒

**CreditSummary** (returned by the dashboard, unlock, boost and plan calls):
```json
{ "balance": 12, "unmetered": false, "purchased": 12, "plan_limit": 50,
  "plan_remaining": 0, "unlocks_used": 50, "plan": "Starter",
  "plan_label": "Starter · renews 28 Aug 2026", "directory_quota": 25 }
```
Credits come from the plan's contact-unlock allowance plus purchased top-ups.
Unlocks spend the plan allowance first; boosts always spend purchased credits.
A `plan_limit` of 0 means the plan does not meter unlocks (`unmetered: true`).

### `GET /employer/plans`
```json
{
  "credits": { ...CreditSummary },
  "plans": [ { "id", "name", "slug", "price", "currency", "interval",
               "features": {...}, "is_current": false, "purchasable": true } ],
  "current": { "id", "plan", "status", "starts_at", "ends_at" } | null,
  "credit_packs": [ { "key": "topup_25", "credits": 25, "price": 299, "label": "25 credits" } ],
  "boost_tiers": [ { "key": "standard", "credits": 1, "days": 3, "label": "Standard boost" } ],
  "invoices": [ { "id", "invoice_number", "plan", "total", "date", "url" } ],
  "payment": { "configured": true, "key": "rzp_live_xxx", "gst_percent": 18 }
}
```

### `POST /employer/plans/{plan}/subscribe`
Owner only. Creates the Razorpay subscription; the app opens Razorpay checkout
with `razorpay_subscription_id` + `razorpay_key`.
```json
// body (optional) → 201
{ "coupon": "FIRST20" }
{ "subscription_id": 12, "razorpay_subscription_id": "sub_xxx", "razorpay_key": "rzp_...",
  "plan": { "id", "name", "price" },
  "amounts": { "discount": 100, "subtotal": 399, "gst_percent": 18, "gst": 71.82, "total": 470.82 } }
```
`422` when payments are unconfigured, the plan has no Razorpay plan id, or the
coupon is invalid.

### `POST /employer/plans/callback`
Verify checkout and activate (issues the tax invoice + records the coupon).
```json
// body → 200
{ "razorpay_payment_id": "pay_x", "razorpay_subscription_id": "sub_x", "razorpay_signature": "..." }
{ "message": "Subscription activated!", "credits": { ...CreditSummary } }
```

### `POST /employer/credits/top-up` — body `{ "pack": "topup_25" }`
→ `201 { "purchase_id", "razorpay_order_id", "razorpay_key", "amount", "credits", "currency" }`

### `POST /employer/credits/callback`
```json
// body → 200
{ "razorpay_payment_id": "pay_x", "razorpay_order_id": "order_x", "razorpay_signature": "..." }
{ "message": "25 credits added.", "credits": { ...CreditSummary } }
```
Idempotent — replaying the same order does not double-credit.

---

## 14. Settings 🔒 (shared with the worker app)

### `GET /preferences` → `{ "preferences": { "theme": "system", "applicant_alerts": true, "job_alerts": true, "message_alerts": true } }`
### `PUT|PATCH /preferences` — any subset of the same keys (`theme` in `system|light|dark`)
→ `{ "message": "Preferences saved.", "preferences": {...} }`

### `GET /auth/sessions`
Signed-in devices (Sanctum tokens) for "Login & security".
→ `{ "sessions": [ { "id", "device", "current", "last_used_ago", "last_used_at", "created_at" } ] }`
### `DELETE /auth/sessions/{token}` → `{ "message": "Device signed out." }` (`404` if not yours)

---

## Not included (still no backend)
- **Job "Share" link** — no dedicated endpoint; use `job.share_url` from
  EmployerJobResource (the public web job page).
- **Escrow / worker payouts** — separate payment surface, unrelated to the
  employer app screens.

---

## Deploy notes for this pass

1. `php artisan migrate` — adds employer-profile wizard fields + `credit_balance`,
   job `experience_min` / `views_count` / boost columns, application offer +
   interview columns, and the `conversations`, `chat_messages`, `job_invites`,
   `credit_purchases` tables.
2. **Typesense schema changed** (worker `spoken_languages`, `available`,
   `verified`, `rating`; job `boosted`). Recreate the collections so the new
   filters/sorts work:
   ```
   php artisan scout:delete-index "App\Models\WorkerProfile"
   php artisan scout:import "App\Models\WorkerProfile"
   php artisan scout:delete-index "App\Models\JobListing"
   php artisan scout:import "App\Models\JobListing"
   ```
3. Credit packs and boost tiers live in `config/billing.php` — edit there, not
   in code. Top-ups need the same Razorpay keys as subscriptions.

