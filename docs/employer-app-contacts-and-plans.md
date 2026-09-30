# Super Karigar **Employer app**: contact unlocks, My contacts and the new plans

The changes the **employer** app needs to match the website. Nothing here
affects the worker app.

Full reference: `docs/employer-app-api.md` (§7 Find Workers, §7b My contacts,
§13 Credits & Plans). Postman: `docs/karigar-employer-app.postman_collection.json`.
Base URL is `{{base_url}}/api/v1`, auth as before (`Authorization: Bearer <token>`).

**Server status (29 Sep 2026):** §1 (unlocking from Find Workers) is already
live. Everything else ships with the next server deploy.

**Summary of what to change in the app**

| # | Screen | Change | Priority |
|---|---|---|---|
| 1 | Find Workers | Numbers are hidden until unlocked: add an "Unlock contact" button (`can_unlock`) | **Must**. Without it the employer cannot get any number from the database |
| 2 | Worker profile | Same unlock button on the profile (`can_unlock`) | **Must** |
| 3 | Find Workers | Two new tabs: **Database contacts** and **Applicant contacts**, with counts | **Must** |
| 4 | My contacts | Contact lists with filters, call / WhatsApp / email buttons | **Must** |
| 5 | My contacts | Plan banner: unlocks used this cycle, split database / applicants | Should |
| 6 | Credits & Plans | Four plans now; show all of them, text from `feature_list` | **Must** |
| 7 | Credits card | Unlocks renew every billing cycle: show "renews on" (`unlocks_reset_at`) | Should |
| 8 | Error handling | `422` with `code: no_plan` / `out_of_credits` on unlock | **Must** |

---

## 1. Find Workers: unlock a karigar's number 🔒

**What changed:** the directory used to show the phone number of the first N
results for free (N = the plan's database quota). Changing a filter showed a new
first N, so an employer could see far more numbers than the plan allowed. Now a
number shows only after the karigar is **unlocked**, and an unlock uses one
contact unlock from the plan, the same pool applicant unlocks use.

`GET /employer/workers`: every row has two new fields.

```jsonc
{
  "id": 41,                   // worker PROFILE id
  "user_id": 88,
  "name": "Meena Devi",
  "phone": null,              // null until unlocked
  "locked": true,             // true until unlocked
  "contact_unlocked": false,  // new
  "can_unlock": true          // new: show the "Unlock contact" button
  // ...rest unchanged
}
```

The response also has `"contact_counts": { "database_total": 4, "applicants_total": 3 }`
for the tab badges (see §3).

| Row state | Show |
|---|---|
| `contact_unlocked: true` | The number, with Call / WhatsApp buttons |
| `can_unlock: true` | **Unlock contact** button |
| both false | Locked. "Beyond your plan" if the employer has a plan, "Subscribe" if not |

`GET /employer/workers/{worker}`: the profile has the same `contact_unlocked` and
`can_unlock`. Show the unlock button there too.

### `POST /employer/workers/{worker}/unlock`
`{worker}` is the **profile id**.

```jsonc
// 200
{ "message": "Contact unlocked.",
  "worker": { "id": 41, "user_id": 88, "phone": "9876543210", "email": "…", "contact_unlocked": true },
  "credits": { /* CreditSummary: refresh the credits card */ } }

// 422: no active plan
{ "message": "Subscribe to a plan to unlock karigar contacts.", "code": "no_plan" }

// 422: plan allowance and purchased credits both used up
{ "message": "You have reached your plan's contact unlock limit.",
  "code": "out_of_credits", "credits": { /* CreditSummary */ } }
```

On `no_plan` open the Plans screen. On `out_of_credits` offer an upgrade or a
credit top-up. Branch on `code`, not on `message`: the message is English.

A karigar already unlocked costs nothing: unlocking again returns `200`.

---

## 2. How unlocks are counted now

- **One pool.** Applicant unlocks (`POST /employer/applicants/{id}/unlock`) and
  Find Workers unlocks use the same allowance.
- **Karigars, not clicks.** A karigar unlocked once stays unlocked for good. If
  they later apply to another job, or were unlocked from the directory first,
  opening their application is free, even with 0 unlocks left.
- **Renews every billing cycle**, like job posts. `CreditSummary` has a new
  `unlocks_reset_at` (ISO date, `null` without a plan). `unlocks_used` now counts
  only this cycle.
- **Chat:** the employer can message a karigar unlocked from the directory, not
  only applicants (`POST /conversations` with `worker_id`).

---

## 3. My contacts: two new tabs 🔒

Next to Find Workers, add two tabs. Badge counts come from `contact_counts` on
`GET /employer/workers`, or from `usage` on the lists themselves.

| Tab | Endpoint | Shows |
|---|---|---|
| Find karigars | `GET /employer/workers` | The existing search |
| **Database contacts** (`database_total`) | `GET /employer/contacts/database` | Karigars unlocked from Find Workers with the plan |
| **Applicant contacts** (`applicants_total`) | `GET /employer/contacts/applicants` | Applicants to the employer's own jobs whose contact is unlocked |

Both lists use 20 rows per page. Every row has the number, so this is the
employer's phone book.

### Filters

| Param | Lists | Notes |
|---|---|---|
| `q` | both | Name or phone, partial match |
| `skill` | both | A whole skill, any case ("weaving" matches "Weaving") |
| `state`, `city` | both | Exact, from `/reference` |
| `sort` | both | `recent` (default), `oldest`, `name` |
| `period` | database | `all` (default) or `cycle` (unlocked this billing cycle) |
| `job` | applicants | One of the employer's job ids. The response's `jobs` feeds the picker |
| `stage` | applicants | `all`, `pending`, `shortlisted`, `interview`, `hired`, `rejected` |

`filters` in the response echoes what was applied, and is always an object.
An unknown `stage` or `sort` returns `422`.

### Row

```jsonc
{
  "worker_id": 88, "profile_id": 41,       // profile_id opens the worker profile
  "name": "Meena Devi", "avatar_url": "https://…",
  "phone": "9876543210", "email": "…",
  "city": "Jaipur", "state": "Rajasthan",
  "skills": ["Weaving", "Dyeing"], "experience_years": 6,
  "expected_wage": "800.00", "wage_type": "daily",

  // Database contacts only
  "unlocked_at": "2026-09-12T10:04:11+05:30",
  "unlocked_by": "Rahul",                  // who unlocked it: owner or team member

  // Applicant contacts only
  "application_id": 512,
  "job": { "id": 153, "title": "Handloom weaver" },
  "stage": "shortlisted",
  "applied_at": "2026-09-10T18:22:03+05:30"
}
```

Buttons per row, as on the website: **Call** (`tel:`), **WhatsApp**
(`https://wa.me/91<10 digits>`), **Email** (`mailto:`) when present, and
**View profile** (database) or **Applicants** for the job (applicants).

### Plan banner (`usage`)

```jsonc
{ "plan": "Pro", "limit": 150, "used": 12, "remaining": 138, "purchased": 50,
  "resets_at": "2026-10-02T07:14:09+00:00",
  "used_database": 8, "used_applicants": 4,
  "database_total": 23, "applicants_total": 17 }
```

Website text, for reference: *"**Pro** plan: 150 contact unlocks per month.
**12** used this cycle (8 from the database, 4 applicants), **138** left + 50
purchased credits. Renews 2 Oct 2026."*

- `limit: 0` / `remaining: null` means unlimited unlocks.
- `plan: null` means no active plan: show "Subscribe to a plan to unlock karigar
  contacts" with a button to Plans.

---

## 4. Plans: four now 🔒

`GET /employer/plans` returns four plans, cheapest first:

| Plan | Price + 18% GST | Job posts / month | Contact unlocks / month | Database access |
|---|---|---|---|---|
| Basic | ₹499 (₹588.82) | 5 | 25 | 1,000 |
| **Standard** (recommended) | ₹999 (₹1,178.82) | 10 | 60 | 3,000 |
| Pro | ₹1,999 (₹2,358.82) | 25 | 150 | 10,000 |
| Enterprise | ₹4,999 (₹5,898.82) | Unlimited | 500 | 50,000 |

- Show every plan the API returns. Do not hard-code three cards. The admin can
  change prices and limits at any time.
- Take the card text from `feature_list` as it is. The unlock line now reads
  "25 contact unlocks per month", and Enterprise says "Unlimited job posts".
- `purchasable: false` means payments are not configured on the server.
  Razorpay plans are created at checkout, so a new plan can be bought straight
  away.

---

## Checklist

- [ ] Find Workers: unlock button on `can_unlock` rows; number on `contact_unlocked` rows
- [ ] Worker profile: unlock button
- [ ] `no_plan` / `out_of_credits` handling on unlock
- [ ] Tabs: Find karigars / Database contacts / Applicant contacts, with counts
- [ ] Both contact lists with filters, pagination, and Call / WhatsApp / Email
- [ ] Plan banner from `usage`
- [ ] Plans screen renders any number of plans from `feature_list`
- [ ] Credits card shows when unlocks renew (`unlocks_reset_at`)
