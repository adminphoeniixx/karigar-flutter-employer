# Super Karigar — Employer App API (v1)

Token-based JSON API for the **employer** mobile app. Same stack as the worker
API — **Laravel Sanctum** personal access tokens issued after mobile-OTP
verification. Additive and independent of the web (Inertia/Fortify) app.

- **Base URL:** `https://<host>/api/v1`
- **Auth header:** `Authorization: Bearer <token>`
- **Content type:** `application/json` (file uploads use `multipart/form-data`)
- **Always send:** `Accept: application/json`

🔒 = requires a token. All `employer/*` routes additionally require the token's
user to have the **employer** role (`403` otherwise).

| Code | When |
| --- | --- |
| `401` | missing / revoked token |
| `403` | wrong role, not your job/applicant, not the account owner, suspended account |
| `404` | not found — **also** what the KYC routes return while admin has verification switched off |
| `422` | validation (`{ "message", "errors": { field: [msg] } }`) or a business rule (`out_of_credits`, `chat_not_allowed`, plan limits) |
| `429` | OTP throttles |

Jobs, applicants, contact-unlock quota, chat and reviews are scoped to the
**employer account** (owner + team members see the same data), exactly like the web.

**Response envelope.** Endpoints that return a single resource on their own wrap
it in `data` — `GET /employer/profile`, `PUT|PATCH /employer/profile`,
`GET /employer/jobs/{job}` and `GET /employer/applicants/{application}` all come
back as `{ "data": { …resource } }`. Paginated lists use the usual
`{ "data": [...], "links": {...}, "meta": {...} }`. Everywhere else the resource
is a named key inside a plain object (`{ "message": ..., "job": {...} }`,
`dashboard.profile`, …) with **no** `data` wrapper.

---

## 1. Auth (public / shared with the worker app)

### `POST /auth/otp/send`
Route throttle `6/min`; on top of that 3 OTPs per minute per phone+IP.
```json
// body → 200
{ "phone": "9876543210" }
{ "message": "OTP sent successfully", "cooldown": 30 }
```

### `POST /auth/otp/verify`
Verify the OTP → issue a token. Registers the account (and an empty employer
profile) on first login. Route throttle `10/min`; 5 verify attempts per minute
per phone+IP.

**OTP is 4 digits** (`digits:4`), not 6.
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
`role` only applies when the number is **new** — an existing account keeps the
role it already has, so check `user.role` in the response before routing.
A suspended account gets `403`.

### `POST /auth/logout` 🔒 → `{ "message": "Logged out." }` (revokes only this device's token)
### `GET /auth/me` 🔒 → `{ "user": { ...UserResource }, "unread_notifications": 3 }`
### `DELETE /account` 🔒 — body `{ "confirm": true }`, revokes all tokens and deletes the user.
### `POST /locale` 🔒 — body `{ "locale": "hi" }` → `{ "locale", "supported": [...] }`

---

## 2. Reference data (public)

### `GET /reference`
One call the app can cache on first launch:
```json
{
  "states": [...], "skills": [...], "spoken_languages": [...],
  "education_levels": [...], "job_categories": [...],
  "wage_types": ["hourly", "daily", "monthly"],
  "shifts": ["day", "night", "rotational", "flexible"],
  "perks": ["Food", "Accommodation", "Travel allowance", "Bonus", "Overtime pay", "Weekly off"],
  "contact_modes": ["apply", "call", "both"],
  "industries": ["Construction & Real Estate", "Interiors & Furnishing", ...],
  "company_sizes": ["1–10", "11–50", "51–200", "200+"],
  "hiring_as": ["business", "contractor", "individual"],
  "interview_modes": ["site", "phone", "video"],
  "worker_sorts": ["best_match", "nearest", "rating", "experience", "wage_low"],
  "credit_packs": [{ "key": "topup_25", "credits": 25, "price": 299, "label": "25 credits" },
                   { "key": "topup_60", "credits": 60, "price": 649, "label": "60 credits" }],
  "boost_tiers": [{ "key": "standard", "credits": 1, "days": 3, "label": "Standard boost" },
                  { "key": "turbo", "credits": 3, "days": 7, "label": "Turbo boost" }],
  "app_languages": [{ "code": "en", "native": "English", "english": "English" }, ...]
}
```

### `GET /reference/cities?state=Tamil%20Nadu` → `{ "cities": [...] }`
### `GET /reference/job-categories` → `{ "job_categories": [...] }`

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
    "hired": 5, "interview": 2,
    "unread_notifications": 3, "unread_messages": 1,
    "verified": true, "profile_completion": 88
  },
  "features": { "verification_enabled": true },
  "active_jobs": [ { ...EmployerJobResource } ],       // up to 5 active jobs
  "recent_applicants": [ { ...ApplicantResource } ]    // up to 5 newest
}
```
`features.verification_enabled` is the admin verification switch — when it is
`false` the app must hide every KYC screen, badge and prompt (the `kyc`
endpoints `404` in that state).

---

## 4. Business profile 🔒

### `GET /employer/profile` → `{ "data": EmployerProfileResource }`
```json
{
  "id": 3, "name": "Anil Sharma", "company_name": "Sri Sai Constructions",
  "hiring_as": "business", "industry": "Construction & Real Estate",
  "company_size": "11–50", "hiring_categories": ["Plumbing", "Electrical"],
  "gstin": "22ABCDE1234F1Z5", "phone": "9876543210", "about": "...",
  "address": "...", "city": "Chennai", "state": "Tamil Nadu",
  "location_label": "Chennai, Tamil Nadu", "latitude": 13.08, "longitude": 80.27,
  "logo_url": "https://cdn.../logos/x.jpg", "verified": true,
  "rating": { "average": 4.6, "count": 18 }, "completion": 88
}
```
`completion` is a 0–100 score over company_name, phone, about, address, city,
state, latitude, gstin, industry and hiring_categories — the dashboard nudge.

### `PUT|PATCH /employer/profile`
Create/update the business profile — also how the registration wizard finishes.
`name` and `email` are saved on the **user**; everything else on the profile.
```json
// body (all optional)
{ "name": "Anil Sharma", "email": "anil@sri-sai.in",
  "company_name": "Sri Sai Constructions",
  "hiring_as": "business",                    // business | contractor | individual
  "industry": "Construction & Real Estate",
  "company_size": "11–50",                    // from reference company_sizes
  "hiring_categories": ["Plumbing", "Electrical"],
  "phone": "9876543210", "about": "...", "address": "...",
  "city": "Chennai", "state": "Tamil Nadu", "latitude": 13.08, "longitude": 80.27,
  "gstin": "22ABCDE1234F1Z5" }
// 200 → { "data": EmployerProfileResource }
```
Limits: `about` ≤2000, `address` ≤500, `hiring_categories` ≤20 items,
`gstin` exactly 15 chars matching `22ABCDE1234F1Z5`, `email` unique across users.
Setting a real `email` here is what makes transactional email actually reach the
employer — OTP-created accounts start with a placeholder `<phone>@phone.karigar`
address, which the mailer skips.

### `POST /employer/profile/logo`
`multipart/form-data`, field `logo` (image ≤2 MB) → `{ "logo_url": "https://cdn.../logos/x.jpg" }`
Use this rather than sending the logo on `PATCH /employer/profile` — PHP does
not parse multipart bodies on PUT/PATCH. Images go to BunnyCDN.

---

## 5. Jobs 🔒

**EmployerJobResource**
```json
{
  "id": 12, "title": "...", "description": "...", "category": "Plumbing",
  "skills": [...], "wage_min": 800, "wage_max": 1000, "wage_type": "daily",
  "wage_label": "₹800–1000 / daily",
  "city": "Chennai", "state": "Tamil Nadu", "location_label": "Chennai, Tamil Nadu",
  "latitude": 13.08, "longitude": 80.27,
  "vacancies": 3, "experience_min": 1, "shift": "day", "perks": [...],
  "contact_mode": "both", "contact_phone": "9876543210",
  "requires_worker_fee": false, "worker_fee_amount": null,
  "status": "active", "status_label": "Active",
  "stats": { "views": 240, "applicants": 12, "shortlisted": 3, "interview": 1, "hired": 1 },
  "boost": { "active": true, "tier": "standard", "until": "2026-08-09T..." },
  "share_url": "https://.../jobs/12",
  "created_at": "...", "created_ago": "2 days ago", "expires_at": null
}
```

### `GET /employer/jobs?status=draft|active|closed&q=<search>`
Paginated (15/page), newest first — the My Jobs tabs. `q` matches the title.

### `GET /employer/jobs/suggest-description`
AI drafts for the Post Job screen's description box, so the employer is not
staring at an empty textarea. Throttled to 20/min.
```
?title=Plumber for apartment project&category=Plumbing&city=Chennai&state=Tamil Nadu&skills[]=Pipe Fitting
```
```json
{ "suggestions": [ "We need an experienced plumber…", "Looking for a skilled plumber…" ] }
```
`title` is required (3–150 chars); everything else is optional and only sharpens
the draft. Normally two suggestions come back — show them as pickable cards and
let the employer edit after choosing. With no AI key configured (or the provider
down) you get **one** template-built draft instead, so always render whatever
length the array is. Same wording returns cached drafts for a day.

### `GET /employer/jobs/{job}` → `{ "data": EmployerJobResource }`

### `POST /employer/jobs`
Post a job (or save a draft with `status: "draft"`). An active job notifies
matching workers (same city or overlapping skill; everyone if nothing matches)
and emails the employer a confirmation.
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
Rules: `title` required ≤255 · `description` required ≤5000 ·
`vacancies` required 1–10000 · `status` required in draft/active/closed ·
`wage_type` in hourly/daily/monthly · `wage_max` ≥ `wage_min` ·
`experience_min` 0–60 · `shift` in day/night/rotational/flexible ·
`perks.*` from the reference `perks` list (≤10) · `skills.*` ≤30 items ·
`contact_mode` in apply/call/both (defaults to `apply`; `contact_phone`
required for call/both) · `requires_worker_fee` boolean (defaults false;
`worker_fee_amount` required when true) · `expires_at` optional, after today.

**Posting gate** — `422` before anything is created:
- `"Subscribe to a plan to post jobs."` — no active plan and the free first post
  is used up / switched off in admin.
- `"You have reached your plan's job posting limit."` — plan limit hit.

### `PUT|PATCH /employer/jobs/{job}` — same body → `{ "message": "Job updated.", "job": {...} }`
A draft flipped to `active` fires the same worker notifications as a fresh post.
### `POST /employer/jobs/{job}/close` → `{ "message": "Job closed.", "job": {...} }`
### `DELETE /employer/jobs/{job}` → `{ "message": "Job deleted." }`

### `POST /employer/jobs/{job}/boost`
Promote a job (Boost sheet). Paid for out of **purchased** credits only —
plan allowance does not cover boosts. `standard` = 1 credit / 3 days,
`turbo` = 3 credits / 7 days (see `boost_tiers` in `/reference`).
Boosting an already-boosted job extends it instead of shortening it.
```json
// body → 200
{ "tier": "standard" }
{ "message": "Job boosted for 3 days.", "job": {...}, "credits": { ...CreditSummary } }
// 422 when short on credits → drives the "out of credits" sheet
{ "message": "You do not have enough credits to boost this job.",
  "code": "out_of_credits", "credits": {...} }
```

### `GET /employer/jobs/{job}/matches`
"✨ Matched for this job" — up to 20 **available** workers whose skills or
category, city and minimum experience fit the job and who have **not** applied
yet, best experience first.
```json
{ "workers": [ { "id", "user_id", "name", "avatar_url", "skills": [...], "city", "state",
    "experience_years", "expected_wage", "wage_type", "available", "verified",
    "rating", "invited": false } ], "total": 6 }
```
`id` is the worker **profile** id; `invited` is true once you have invited them.

### `POST /employer/jobs/{job}/invite`
Invite a matched worker to apply — in-app + push notification. Idempotent:
inviting twice returns `200` with `"invited": true` and sends nothing.
```json
// body (worker_id is the worker's USER id) → 201
{ "worker_id": 42, "message": "Site is in Guindy, start Monday." }
{ "message": "Invite sent to Ravi.", "invited": true }
// 200 on a repeat
{ "message": "This worker has already been invited.", "invited": true }
```

---

## 6. Applicants 🔒

**ApplicantResource**
```json
{
  "id": 14, "status": "pending", "status_label": "Pending", "stage": "pending",
  "shortlisted": false, "cover_note": "...", "expected_wage": 900,
  "contact_unlocked": false,
  "offer": { "wage": 900, "start_date": "2026-08-10", "message": "Report by 9 AM" } | null,
  "interview": { "at": "2026-08-02T10:30:00+05:30", "at_label": "02 Aug 2026, 10:30 AM",
                 "mode": "site", "note": "Gate 2" } | null,
  "resume": { "name": "suresh-plumber.pdf", "uploaded_at": "...", "download_url": "..." } | null,
  "ai": { "score": 82, "recommendation": "shortlist", "summary": "...",
          "matched_skills": [...], "red_flags": [...] } | null,
  "created_at": "...", "created_ago": "3 hours ago", "tracking_steps": [...],
  "job": { "id": 12, "title": "..." },
  "worker": { "id", "name", "rating", "reviews_count", "avatar_url", "bio",
              "skills": [...], "spoken_languages": [...], "experience_years",
              "city", "state", "expected_wage", "wage_type", "available",
              "verified", "phone": null, "email": null }
}
```
Worker `phone` / `email` stay `null` until the contact is unlocked. `stage` is
one of `pending | shortlisted | interview | hired | rejected` and the stages are
**exclusive**, so the segmented tabs add up to `all`.

### `GET /employer/jobs/{job}/applicants?stage=all|pending|shortlisted|interview|hired|rejected&sort=best_match|recent`
Paginated (20/page). **`sort` defaults to `best_match`** (AI score descending,
unscored applicants last); `recent` is newest first.
```json
{
  "data": [ { ...ApplicantResource } ],
  "counts": { "all": 12, "pending": 8, "shortlisted": 3, "interview": 1, "hired": 1, "rejected": 0 },
  "links": {...}, "meta": {...}
}
```

### `GET /employer/shortlisted`
Everyone shortlisted across **all** of the employer's jobs — the app's own
Shortlisted screen, not scoped to one job. Paginated (20/page), most recently
shortlisted first, each row carrying its `job`.
```json
{ "data": [ { ...ApplicantResource } ], "links": {...}, "meta": {...} }
```
(The per-job tab is the applicants list with `stage=shortlisted`.)

### `GET /employer/applicants/{application}` → `{ "data": ApplicantResource }`

### `PATCH /employer/applicants/{application}/status`
Hire or reject — notifies the worker (in-app + push + email). The Hire sheet's
offer fields are stored on the application and echoed back as `applicant.offer`
(ignored on a reject).
```json
// body → 200
{ "status": "accepted",            // or "rejected"
  "offered_wage": 900, "start_date": "2026-08-05", "message": "Report by 9 AM" }
{ "message": "Applicant Accepted.", "applicant": { ...ApplicantResource } }
```

### `POST /employer/applicants/{application}/shortlist`
Toggle shortlist. Shortlisting notifies + emails the worker; un-shortlisting is silent.
→ `{ "message", "applicant": { ...ApplicantResource } }`

### `POST /employer/applicants/{application}/interview`
Schedule (or reschedule) an interview — moves the applicant into the Interview
stage, auto-shortlists them and notifies the worker (in-app + push).
```json
// body → 200
{ "interview_at": "2026-08-02T10:30:00+05:30", "mode": "site", "note": "Gate 2, ask for Anil" }
{ "message": "Interview invite sent.", "applicant": { ...stage: "interview" } }
```
`mode` is one of `site | phone | video` (`interview_modes` in `/reference`),
`note` ≤1000 chars.

### `DELETE /employer/applicants/{application}/interview`
Cancel it — the applicant drops back to `shortlisted`.
→ `{ "message": "Interview cancelled.", "applicant": {...} }`

### `POST /employer/applicants/{application}/unlock`
Reveal the worker's contact, spending one contact credit — the plan's unlock
allowance first, then purchased top-up credits.
```json
// 200
{ "message": "Contact unlocked.", "applicant": {...}, "credits": { ...CreditSummary } }
// 422 — nothing left
{ "message": "You have reached your plan's contact unlock limit.",
  "code": "out_of_credits", "credits": {...} }
```
Already unlocked → `200 { "applicant": {...} }` only (no `message`, no `credits`,
nothing charged), so treat both shapes as success.

Unlocks count **karigars, not clicks**, and applicants share one pool with the
Find Workers directory (§7). A worker already unlocked on another job, or from
the directory, opens free even when the allowance is at 0.

### `POST /employer/jobs/{job}/rescore`
Queue AI scoring for the job's applicants — unscored ones only, or everyone with
`?force=1`.
→ `{ "message": "7 applicants queued for AI scoring.", "queued": 7 }`

### Applicant resumes
When the worker has uploaded one, `ApplicantResource.resume` carries it:
```json
"resume": { "name": "suresh-plumber.pdf",
            "uploaded_at": "2026-07-30T05:20:11+00:00",
            "download_url": "https://…/api/v1/employer/applicants/14/resume" }
```
`null` when the worker has no resume. The resume's text feeds the AI score, so
an applicant with a resume is scored on it rather than on their profile alone.

### `GET /employer/applicants/{application}/resume`
Streams the PDF (`application/pdf`, `Content-Disposition: attachment` with the
worker's original filename). **Token-authenticated** — send the same
`Authorization: Bearer` header as every other call, so the app can preview or
save the file in-place rather than kicking the user out to a browser.
`403` when the application is not on one of your jobs; `404` when the worker has
no resume on record. This is the URL `resume.download_url` already points at.

### AI scoring, shortlisting and rejection
Scoring always runs and always drives `sort=best_match` — nothing gates it. What
the **admin** controls (Admin → Settings, both off by default) is whether the
score also *acts*:

| Setting | Effect when on |
| --- | --- |
| `ai_auto_shortlist_enabled` + `ai_auto_shortlist_threshold` (default 80) | An applicant at or above the threshold is shortlisted and notified. |
| `ai_auto_reject_enabled` + `ai_auto_reject_below` (default 30) | An applicant below the floor is set to `rejected` and notified. |

Auto-reject only ever touches an untouched application — still `pending`, never
shortlisted, no interview booked — so an employer decision is never overwritten.
When both gates could fire on the same applicant, shortlisting wins.

---

## 6b. AI screening calls 🔒
The platform rings the applicant on a real phone line, asks in their language
whether they are still interested, and collects an interview time to offer. The
agent never books anything — **the employer confirms the slot**, because the
agent has no idea what the employer's week looks like.

**ScreeningCallResource**
```json
{
  "id": 7, "application_id": 14, "attempt": 1, "language": "hi",
  "status": "completed", "status_label": "Completed",
  "outcome": "interested", "outcome_label": "Interested",
  "summary": "Suresh is interested and can come Thursday morning.",
  "proposed_interview_at": "2026-08-06T10:00:00+05:30",
  "proposed_interview_label": "06 Aug 2026, 10:00 AM",
  "proposed_mode": "site", "employer_confirmed": false,
  "awaiting_confirmation": true, "duration_seconds": 74,
  "failure_reason": null, "created_at": "...", "created_ago": "20 minutes ago",
  "transcript": [...]
}
```
`status` ∈ `queued | dialing | in_progress | completed | no_answer | busy |
failed | cancelled`; `outcome` ∈ `interested | not_interested | callback_later |
already_placed | unclear` (`null` until the call completes). `transcript` is
only included when you pass `?with_transcript=1` — it is long, so ask for it on
the call-detail screen only. The worker's phone number is deliberately **not**
in this payload; it stays behind the contact-unlock paywall.

### `GET /employer/applicants/{application}/screening-calls`
```json
{ "calls": [ { ...ScreeningCallResource } ],
  "can_call": false, "blocked_because": "already_screened" }
```
Drive the "Call & schedule" button off `can_call`. When it is `false`,
`blocked_because` says why — show it as the disabled reason:

| code | meaning |
| --- | --- |
| `provider_not_configured` | Calling is not switched on yet. |
| `no_caller_id` | No calling number is configured yet. |
| `application_closed` | The application is rejected or withdrawn. |
| `interview_already_scheduled` | An interview is already booked. |
| `no_phone_number` | This worker has no phone number on file. |
| `worker_opted_out` | The worker opted out of automated calls (TRAI). |
| `call_in_progress` | A call is already on its way. |
| `already_screened` | This worker has already been screened. |

### `POST /employer/applicants/{application}/screening-calls`
No body. → `202`
```json
{ "message": "Call queued for 06 Aug, 9:00 AM.", "calling_at": "2026-08-06T09:00:00+05:30" }
```
Calls are only placed inside the permitted daytime window — one queued at night
is held until morning, and `calling_at` is that time (compare it to now to
decide between "Calling now…" and "Queued for …"). `422 { "code": <blocker> }`
with one of the codes above when the applicant cannot be called.

The call runs in the background; the app learns the result from the push
notification and by re-fetching this list. There is no websocket.

### `POST /employer/screening-calls/{call}/confirm`
Books the interview the worker offered and notifies them.
```json
// body — both optional; omit to accept the slot exactly as proposed
{ "interview_at": "2026-08-06T11:00:00+05:30", "mode": "site" }
{ "message": "Interview confirmed — the worker has been notified.",
  "applicant": { ...ApplicantResource }, "call": { ...ScreeningCallResource } }
```
Send `interview_at` only to **move** the slot (must be in the future); `mode` is
one of the interview modes from `GET /reference`. `422 { "code":
"no_proposed_slot" }` when the call produced no time to confirm — e.g. the
worker said no, or never answered.

---

## 7. Find Workers 🔒
Typesense-powered directory, 15/page. A number is shown only for karigars this
employer has **unlocked**: `POST /employer/workers/{worker}/unlock` spends one
contact unlock from the same pool as applicant unlocks. The plan's database
quota (`access.quota`) says how far down the results can be unlocked:
`can_unlock: true` marks the rows the employer can unlock now. Show an
"Unlock contact" button on those rows and a locked state on the rest.

### `GET /employer/workers?q=&state=&city=&skill=&page=`
Full filter-sheet support:
`experience_min` (0–60), `wage_min` / `wage_max`, `languages[]` (≤10),
`verified=1` (KYC only), `available=1` (available now),
`sort=best_match|nearest|rating|experience|wage_low`, and
`latitude` + `longitude` (send both) with optional `radius_km` (1–500) for
"distance from site". With a point, every row also carries `distance_km`;
`sort=nearest` needs the point or it falls back to relevance.
```json
{
  "workers": { "data": [ { "id", "user_id", "name", "avatar_url", "bio",
      "skills": [...], "city", "state", "experience_years", "expected_wage",
      "wage_type", "available", "verified", "rating", "distance_km",
      "phone", "locked", "contact_unlocked", "can_unlock" } ],
    "links": {...}, "meta": {...} },
  "filters": { "q": null, ... },
  "access": { "quota": 25, "accessible": 6, "total": 6, "has_plan": true },
  "credits": { ...CreditSummary },      // unlocks left for the counter
  "contact_counts": { "database_total": 4, "applicants_total": 3 }   // tab badges, see §7b
}
```
`phone` is `null` and `locked: true` until the karigar is unlocked.

### `GET /employer/workers/{worker}`
`{worker}` is a **worker profile id**. Contact is revealed only if this employer
account has unlocked that worker, through an application or the directory.
```json
{
  "worker": { "id", "user_id", "name", "avatar_url", "bio", "skills": [...],
    "spoken_languages": [...], "city", "state", "experience_years", "education",
    "expected_wage", "wage_type", "available", "verified",
    "phone": null, "email": null, "contact_unlocked": false, "can_unlock": true },
  "rating": { "average": 4.8, "count": 23 },
  "reviews": [ { ...ReviewResource } ]        // latest 10
}
```

### `POST /employer/workers/{worker}/unlock`
Reveal a directory karigar's number, spending one contact unlock (plan
allowance first, then purchased credits). A karigar already unlocked costs
nothing. After an unlock the employer can also open a chat with the karigar.
```json
// 200
{ "message": "Contact unlocked.",
  "worker": { "id", "user_id", "phone": "9876543210", "email", "contact_unlocked": true },
  "credits": { ...CreditSummary } }
// 422 — no active plan / database quota
{ "message": "Subscribe to a plan to unlock karigar contacts.", "code": "no_plan" }
// 422 — nothing left
{ "message": "You have reached your plan's contact unlock limit.",
  "code": "out_of_credits", "credits": {...} }
```

---

## 7b. My contacts 🔒
The karigars whose numbers the employer holds, as two lists (two tabs next to
Find Workers): **Database contacts** (unlocked from Find Workers with the plan)
and **Applicant contacts** (applicants to the employer's own jobs whose contact
is unlocked). Every row carries the number, so the list is also the employer's
phone book. 20 per page; the paginator is Laravel's plain one (`data`,
`current_page`, `last_page`, `total`, `next_page_url`, ...).

Both take `q` (name or phone, partial), `skill` (a whole skill, any case),
`state`, `city`, `sort=recent|oldest|name` and `page`. `filters` echoes what was
applied and is always an object (`{}` when empty).

**Row** (both lists):
```json
{ "worker_id": 88, "profile_id": 41, "name": "Meena Devi", "avatar_url": "https://…",
  "phone": "9876543210", "email": "meena@…", "city": "Jaipur", "state": "Rajasthan",
  "skills": ["Weaving", "Dyeing"], "experience_years": 6,
  "expected_wage": "800.00", "wage_type": "daily" }
```
Database rows add `unlocked_at` (ISO) and `unlocked_by` (team member's name).
Applicant rows add `application_id`, `job: { id, title }`, `stage`
(`pending|shortlisted|interview|hired|rejected`, as on the applicants screen)
and `applied_at`. `profile_id` opens `GET /employer/workers/{worker}`.

**`usage`** (both lists): the plan banner and the tab badges.
```json
{ "plan": "Pro", "limit": 150, "used": 12, "remaining": 138, "purchased": 50,
  "resets_at": "2026-10-02T07:14:09+00:00",
  "used_database": 8, "used_applicants": 4,
  "database_total": 23, "applicants_total": 17 }
```
`used` counts karigars first unlocked this billing cycle (`used_database` +
`used_applicants`), `remaining` is the plan allowance left (`null` = unlimited),
`purchased` the top-up credits on top. `plan: null` means no active plan.

### `GET /employer/contacts/database`
Extra filter: `period=all|cycle` (`cycle` = unlocked this billing cycle).
```json
{ "contacts": { "data": [ { ...Row, "unlocked_at", "unlocked_by" } ], "total": 23, ... },
  "filters": { "skill": "Weaving" },
  "usage": { ... } }
```

### `GET /employer/contacts/applicants`
Extra filters: `job` (one of the employer's job ids) and
`stage=all|pending|shortlisted|interview|hired|rejected`. `jobs` lists the
employer's jobs for the job picker.
```json
{ "contacts": { "data": [ { ...Row, "application_id", "job": { "id", "title" },
                            "stage", "applied_at" } ], "total": 17, ... },
  "filters": { "stage": "hired" },
  "usage": { ... },
  "jobs": [ { "id": 153, "title": "Handloom weaver" } ] }
```
An unknown `stage` or `sort` is a `422`.

---

## 8. Business verification (KYC) 🔒
GSTIN is stored on the profile; business PAN + proof docs on the shared KYC
record. Docs stay on the local private disk (never BunnyCDN).

**Both routes `404` while `features.verification_enabled` is `false`** — that is
the admin switch, not an error; hide the screens instead of showing "not found".

### `GET /employer/kyc`
```json
{ "gstin": "22ABCDE1234F1Z5",
  "kyc": { "status": "verified", "status_label": "Verified", "masked_pan": "ABCXX1234F",
           "masked_aadhaar": null, "remarks": null,
           "reviewed_at": "...", "submitted_at": "..." } | null }
```

### `POST /employer/kyc` — `multipart/form-data`
```
gstin=22ABCDE1234F1Z5      (required, 15 chars, format 22ABCDE1234F1Z5)
pan_number=ABCDE1234F      (required, format ABCDE1234F)
gst_doc=@gst.pdf           (jpg/png/pdf ≤5 MB)
pan_doc=@pan.jpg           (jpg/png/pdf ≤5 MB)
// 201 → { "message": "Business verification submitted for review.", "gstin", "kyc": {...} }
```
Both files are **required on the first submission** and optional on a re-submit
(existing files are kept). A re-submit resets the status to `pending` and clears
the admin's remarks.

---

## 9. Notifications & push 🔒 (shared with the worker app)

### `GET /notifications` → `{ "notifications": { paginated 20/page }, "unread": 3 }`
Each row: `{ id, type, message, url, read, created_at, created_ago }`.
### `POST /notifications/{id}/read` → `{ "unread": 2 }`
### `POST /notifications/read-all` → `{ "unread": 0 }`

### `POST /device-tokens`
Register/refresh this device's FCM token — call after login and on every FCM
token rotation.
```json
// body → 200
{ "token": "fcm-token...", "platform": "android" }   // platform: android | ios | web
{ "registered": true }
```
### `DELETE /device-tokens` — body `{ "token": "fcm-token..." }` → `{ "removed": true }`
Call this on logout so the device stops receiving pushes.

---

## 10. Reviews 🔒

### `GET /employer/reviews`
Reviews workers left for this employer account, paginated (15/page).
```json
{
  "data": [ { "id", "rating": 5, "comment": "...", "created_at", "created_ago": "1 month ago",
              "reviewer": { "id", "name" }, "job": { "id", "title" } } ],
  "summary": { "average": 4.6, "count": 18 },
  "links": {...}, "meta": {...}
}
```

### `POST /employer/applicants/{application}/review`
Rate a **hired** worker — the application must be `accepted` (`403` otherwise)
and one review per worker+job (`422` on a repeat).
```json
// body → 201
{ "rating": 5, "comment": "Neat work, finished ahead of time." }
{ "message": "Review submitted.", "review": { ...ReviewResource } }
```

---

## 11. Team members 🔒 (account owner only)
The owner invites staff by mobile number; they log in with their own OTP.
Roles: `manager` (posts & manages jobs) · `recruiter` (works applicants only).
Non-owners get `403` on every route here.

### `GET /employer/team`
→ `{ "members": [ { "id", "name", "phone", "role", "added_ago" } ], "roles": ["manager", "recruiter"] }`

### `POST /employer/team`
```json
// body → 201
{ "name": "Ravi", "phone": "9876500000", "role": "recruiter" }
{ "message": "Team member added — they can log in with their mobile number.",
  "member": { "id", "name", "phone", "role", "added_ago" } }
```
`phone` must be a valid 10-digit Indian mobile. `422` if the number is your own,
belongs to a worker account, already runs or belongs to another team, or already
has its own job posts.

### `PATCH /employer/team/{member}` — body `{ "role": "manager" }` → `{ "message": "Role updated.", "role" }`
### `DELETE /employer/team/{member}` → `{ "message": "Team member removed." }`

---

## 12. Messages 🔒 (chat — shared with the worker app)
Employer ↔ worker threads, scoped to the employer **account** so team members
share one inbox. An employer may only open a thread with a worker who applied to
one of their jobs (unlocking a contact implies an application).

### `GET /conversations`
Paginated 20/page, newest activity first.
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
Start or re-open a thread. Employers send `worker_id` (worker's user id),
workers send `employer_id`; `job_id` optionally pins the thread to a job and
`body` (≤2000) sends the first message.
→ `201` (new) / `200` (existing) `{ "conversation": { ...ConversationResource } }`
→ `422 { "code": "chat_not_allowed" }` when there is no application between you.

### `GET /conversations/{conversation}`
Latest 30 messages (returned oldest→newest) and marks the thread read.
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
  "plan_remaining": 0, "unlocks_used": 50, "unlocks_reset_at": "2026-08-28T10:00:00+05:30",
  "plan": "Starter", "plan_label": "Starter · renews 28 Aug 2026", "directory_quota": 25 }
```
Credits come from the plan's contact-unlock allowance plus purchased top-ups.
Unlocks spend the plan allowance first; boosts always spend purchased credits.
The allowance renews every billing cycle, like job posts: `unlocks_used` counts
karigars first unlocked in the cycle now running, and `unlocks_reset_at` is when
it next renews (`null` without a subscription). A karigar unlocked once stays
unlocked across cycles and never costs again.
`plan_limit: 0` means the plan does not meter unlocks — then `unmetered` is
`true` and `plan_remaining` is `null`. With no subscription, `plan_label` reads
"Free plan · unlock worker numbers".

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
`purchasable: false` means payments are not configured on the server — hide or
disable the buy buttons. Razorpay plans are created at checkout, so a new plan
is buyable straight away. Show every plan `plans` returns (there are four now,
cheapest first) using its `feature_list` lines as they are. `invoices[].url` is the token-auth JSON endpoint below;
`invoices[].web_url` is the printable web page, for "open in browser" / share.

### `GET /employer/invoices/{subscription}`
The tax invoice as data, so the app lays it out natively (and can print or share
from there) instead of opening a session-authenticated web page.
```json
{
  "invoice": { "number": "KRG-2026-00001", "date": "28 Jul 2026",
               "plan": { "name": "Starter", "interval": "monthly", "price": 399 },
               "coupon_code": "FIRST20", "discount": 100, "subtotal": 399,
               "gst_percent": 18, "gst_amount": 71.82, "total": 470.82,
               "period": { "from": "28 Jul 2026", "to": "28 Aug 2026" },
               "payment_ref": "sub_xxx" },
  "seller": { "name", "address", "gstin", "email" },
  "buyer": { "name", "address", "gstin", "email", "phone" }
}
```
`403` for another account's invoice, `404` before the subscription is paid (no
invoice number yet). Team members read the **owner's** invoices, matching the
rest of billing.

### `POST /employer/plans/{plan}/subscribe`
**Owner only** (`403` for team members). Creates the Razorpay subscription; the
app then opens Razorpay checkout with `razorpay_subscription_id` + `razorpay_key`.
```json
// body (optional) → 201
{ "coupon": "FIRST20" }
{ "subscription_id": 12, "razorpay_subscription_id": "sub_xxx", "razorpay_key": "rzp_...",
  "plan": { "id", "name", "price" },
  "amounts": { "discount": 100, "subtotal": 399, "gst_percent": 18, "gst": 71.82, "total": 470.82 } }
```
`422` when payments are unconfigured, the plan has no Razorpay plan id, or the
coupon is invalid/expired (the message says which).

### `POST /employer/plans/callback`
Verify the checkout signature and activate — issues the tax invoice and records
the coupon redemption.
```json
// body → 200
{ "razorpay_payment_id": "pay_x", "razorpay_subscription_id": "sub_x", "razorpay_signature": "..." }
{ "message": "Subscription activated!", "credits": { ...CreditSummary } }
```
`422 { "message": "Payment verification failed." }` on a bad signature.

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

### `GET /preferences`
→ `{ "preferences": { "theme": "system", "applicant_alerts": true, "job_alerts": true, "message_alerts": true } }`
### `PUT|PATCH /preferences` — any subset of the same keys (`theme` in `system|light|dark`)
→ `{ "message": "Preferences saved.", "preferences": {...} }`

### `GET /auth/sessions`
Signed-in devices (Sanctum tokens) for "Login & security".
→ `{ "sessions": [ { "id", "device", "current", "last_used_ago", "last_used_at", "created_at" } ] }`
### `DELETE /auth/sessions/{token}` → `{ "message": "Device signed out." }` (`404` if not yours)

---

## 15. Terms & Privacy and Help & Support (public)

Both settings rows, and neither needs a token — the OTP screen links to the
legal documents before an account exists, and someone who cannot sign in still
needs help.

### `GET /legal`
The two documents without their bodies, for the settings row.
```json
{ "documents": [
  { "key": "terms", "title": "Terms of use", "summary": "The rules for using…",
    "updated_at": "2026-09-03", "updated_label": "3 September 2026", "web_url": null },
  { "key": "privacy", "title": "Privacy policy", "summary": "What we hold about you…",
    "updated_at": "2026-08-12", "updated_label": "12 August 2026",
    "web_url": "https://superkarigar.com/privacy" }
] }
```
`web_url` is the same text as a web page, for an "open in browser" link — it is
**`null` for the terms** (no web page yet), so handle null rather than assuming
a URL. `updated_label` is pre-formatted; `updated_at` is there for comparing.

### `GET /legal/{document}` — `document` is `terms` or `privacy`
The full document, as sections of blocks the app renders in its own type.
```json
{ "document": {
  "key": "privacy", "title": "Privacy policy",
  "updated_at": "2026-08-12", "updated_label": "12 August 2026",
  "summary": "…", "intro": "Super Karigar connects skilled karigars with…",
  "web_url": "https://superkarigar.com/privacy",
  "sections": [
    { "id": "what-we-collect", "title": "What we collect", "blocks": [
      { "type": "heading", "text": "Everyone" },
      { "type": "list", "items": ["Your mobile number…", "Your name…"] },
      { "type": "paragraph", "text": "We use your information to…" }
    ] }
  ]
} }
```
**There are exactly three block types** — `paragraph` and `heading` carry
`text`, `list` carries `items`. Nothing else will ever appear, so a client only
needs three renderers. `heading` is a sub-heading *inside* a section: render it
smaller than the section title and keep it out of any contents rail (build that
from `sections[].title` / `sections[].id`).

`404` for any other document key. The privacy policy's identity-document
section **disappears** when an admin switches verification off, so build the
screen from what you get rather than from a fixed list of sections.

Content is English only for now.

### `GET /support?audience=worker|employer`
```json
{ "channels": { "email": "support@superkarigar.com", "whatsapp": "919000000000",
                "phone": "…", "hours": "Monday to Saturday, 10 AM to 7 PM IST" },
  "faqs": [ { "id": "otp-not-received", "audience": "all",
              "question": "I did not get my OTP.", "answer": "The code takes a few seconds…" } ] }
```
- **A channel that is not configured is left out entirely** — don't render a row
  for a missing key. `whatsapp` is digits with the country code and no `+`, so
  the app builds its own `wa.me` link.
- Pass `audience` to get the entries for your app plus the shared ones; omit it
  and you get all of them. `audience` on each row is `worker | employer | all`.
  Anything else → `422`.
- `id` is stable — safe to deep-link to one answer.

---

## Endpoint index

| Method | Path | Section |
| --- | --- | --- |
| POST | `/auth/otp/send` · `/auth/otp/verify` | 1 |
| GET/POST | `/auth/me` · `/auth/logout` · `/locale` · `DELETE /account` | 1 |
| GET | `/reference` · `/reference/cities` · `/reference/job-categories` | 2 |
| GET | `/employer/dashboard` | 3 |
| GET/PUT/PATCH/POST | `/employer/profile` · `/employer/profile/logo` | 4 |
| GET/POST/PATCH/DELETE | `/employer/jobs`, `/employer/jobs/{job}`, `/close`, `/boost`, `/matches`, `/invite`, `/employer/jobs/suggest-description` | 5 |
| GET/PATCH/POST/DELETE | `/employer/jobs/{job}/applicants`, `/employer/shortlisted`, `/employer/applicants/{application}` (+ `/status`, `/shortlist`, `/unlock`, `/interview`, `/resume`), `/employer/jobs/{job}/rescore` | 6 |
| GET/POST | `/employer/applicants/{application}/screening-calls` · `/employer/screening-calls/{call}/confirm` | 6b |
| GET | `/employer/workers` · `/employer/workers/{worker}` | 7 |
| GET/POST | `/employer/kyc` | 8 |
| GET/POST | `/notifications` (+ `/{id}/read`, `/read-all`) · `/device-tokens` | 9 |
| GET/POST | `/employer/reviews` · `/employer/applicants/{application}/review` | 10 |
| GET/POST/PATCH/DELETE | `/employer/team` · `/employer/team/{member}` | 11 |
| GET/POST | `/conversations` (+ `/{id}`, `/messages`, `/read`) | 12 |
| GET/POST | `/employer/plans` (+ `/{plan}/subscribe`, `/callback`) · `/employer/credits/top-up` (+ `/callback`) · `/employer/invoices/{subscription}` | 13 |
| GET/PUT/PATCH/DELETE | `/preferences` · `/auth/sessions` (+ `/{token}`) | 14 |
| GET | `/legal` · `/legal/{document}` · `/support` (all public) | 15 |

Postman collection: `docs/karigar-employer-app.postman_collection.json`.

---

## Not included (no backend yet)
- **Job "Share" link** — no dedicated endpoint; use `job.share_url` from
  EmployerJobResource (the public web job page).
- **Escrow / worker payouts** — a separate payment surface, unrelated to the
  employer app screens.

---

## Deploy notes

1. `php artisan migrate` — employer-profile wizard fields + `credit_balance`,
   job `experience_min` / `views_count` / boost columns, application offer +
   interview + AI-score columns, worker `resume_*` columns, and the
   `conversations`, `chat_messages`, `job_invites`, `credit_purchases` tables.
2. **Typesense** — the worker collection carries `spoken_languages`, `available`,
   `verified`, `rating`, `location`, and jobs carry `boosted`. Recreate the
   collections after deploying so the filters/sorts work:
   ```
   php artisan scout:delete-index "App\Models\WorkerProfile"
   php artisan scout:import "App\Models\WorkerProfile"
   php artisan scout:delete-index "App\Models\JobListing"
   php artisan scout:import "App\Models\JobListing"
   ```
3. Credit packs, boost tiers and GST live in `config/billing.php` — edit there,
   not in code. Top-ups use the same Razorpay keys as subscriptions.
4. A queue worker must be running: AI scoring (`ScoreApplication`), push
   notifications and emails are all queued.
