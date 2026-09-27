# Admin dashboard — setup

## 1. Create a Supabase project

Go to [supabase.com](https://supabase.com), create a free project, and note down:
- **Project URL** (Settings → API)
- **anon public key** (Settings → API)

## 2. Run the database schema

Dashboard → SQL Editor → New query → paste the contents of `supabase/schema.sql` → Run.

This creates the `farmers` and `scans` tables with sensible row-level security
for a small pilot (the app can insert scans, only logged-in admins can read/edit).

> The dashboard shows **only live data** — there is no static/mock fallback. If the
> database is empty, pages render an explicit "no data yet" state instead of fake
> records. (The old `mockData.js` / `seed.js` files have been removed.)

Optional: if you want scan photos visible in the dashboard, also create a
public Storage bucket named `scan-images` (Storage → New bucket), then run
the two commented-out storage policies at the bottom of `schema.sql`.

### Cleanup demo data (only if you ran the old seed.js)

The removed `seed.js` wrote 200 synthetic scans + 10 fake farmers (codes
`F0001..F0010`) into this database. Delete them so the dashboard only ever
shows real app data:

```sql
delete from scans where farmer_id in (select id from farmers where code like 'F000%');
delete from farmers where code like 'F000%';
```

## 3. Create your admin login

Dashboard → Authentication → Users → Add user. Set an email + password —
this is what you'll use to log into the dashboard.

## 4. Configure this project

```bash
cp .env.example .env
```

Fill in `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` with the values from step 1.

## 5. Install and run

```bash
npm install
npm run dev
```

Opens at `http://localhost:5173`. Log in with the admin account from step 3.

## 6. Deploy (when ready to share with the team)

Any static host works since this is a plain Vite app — Vercel, Netlify, or
Supabase's own hosting all work with zero config. Just set the same two
environment variables in the host's dashboard.

## Connecting the mobile app

The Flutter app POSTs every scan to your Supabase `scans` table via the REST
endpoint:

```
POST https://your-project-ref.supabase.co/rest/v1/scans
Headers:
  apikey: <anon key>
  Authorization: Bearer <anon key>
  Content-Type: application/json
```

Body fields (`crop_species`, `disease_label`, `confidence`, `device_timestamp`,
`latitude`, `longitude`, `device_farmer_id`, `farmer_name`, `farmer_village`,
`farmer_phone`) match the `scans` columns — see `supabase/schema.sql`.

> If your database predates the app-generated Farmer ID flow, re-run the
> updated `supabase/schema.sql` — the `alter table scans add column if not exists
> ...` statements migrate existing projects with zero data loss.

## Targeting advisory SMS recipients

The Alerts page chooses SMS recipients by division:

1. Registered farmers whose `farmers.lga` matches the alert's division
   (`farmers` now has an `lga` column — set it when you add a farmer).
2. Otherwise, the unique farmers seen in scans from that division (the app
   auto-generates Farmer IDs, so this covers most pilots).

## Project structure

```
├── index.html              # Vite entry point
├── package.json
├── vite.config.js
├── .env.example            # Copy to .env and fill in your Supabase credentials
├── src/
│   ├── main.jsx            # React entry point
│   ├── App.jsx             # Root component with auth & routing
│   ├── supabaseClient.js   # Supabase client initialization
│   ├── hooks/
│   │   └── useDashboardData.js  # Live scans+farmers loader (loading/error/reload)
│   ├── components/
│   │   ├── Sidebar.jsx     # Navigation sidebar (live alert badge)
│   │   ├── StatCard.jsx    # Stat display card
│   │   ├── StatePanel.jsx  # Shared empty/error states (no mock fallback)
│   │   └── LeafGauge.jsx   # Leaf-shaped confidence gauge
│   ├── pages/
│   │   ├── Login.jsx       # Admin login form
│   │   ├── Overview.jsx    # Dashboard overview with live map + hotspots
│   │   ├── Analytics.jsx   # Charts built from live scans
│   │   ├── ScanLog.jsx     # Scan verification table (writes to scans)
│   │   └── Alerts.jsx      # Data-driven alerts + SMS composer
│   ├── utils/
│   │   ├── dataService.js  # All Supabase reads live here (no mocks)
│   │   └── alertEngine.js  # Anomaly flags computed from live scans
│   └── styles/
│       ├── global.css      # Global styles & component classes
│       └── tokens.css      # Design tokens (colors, spacing, fonts)
└── supabase/
    └── schema.sql          # Database schema for Supabase
```
