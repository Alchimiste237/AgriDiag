# API Testing Guide — Crop Disease Detector

This folder contains a ready-to-import Postman/Thunder Client collection for testing the backend APIs.

## Files

- `CropDiseaseAPI.postman_collection.json` — Import into Postman or Thunder Client

---

## How to Import

### Postman
1. Open Postman → **Import** → **File** → select `CropDiseaseAPI.postman_collection.json`
2. Go to the **Variables** tab and update:
   - `user_email` → your Supabase admin email
   - `user_password` → your Supabase admin password

### Thunder Client (VS Code)
1. Open Thunder Client → **Collections** → **Import** → select the JSON file
2. Edit the collection variables in the Variables tab

---

## Testing Flow

### Step 1: Login (POST)

**Endpoint:**
```
POST {{supabase_url}}/auth/v1/token?grant_type=password
```

**Headers:**
| Key | Value |
|-----|-------|
| Content-Type | application/json |
| apikey | {{supabase_anon_key}} |

**Body (JSON):**
```json
{
  "email": "your-admin@email.com",
  "password": "your-password"
}
```

**Expected Response (200):**
```json
{
  "access_token": "eyJhbGci...",
  "token_type": "bearer",
  "expires_in": 3600,
  "refresh_token": "...",
  "user": { ... }
}
```

> The collection auto-saves the `access_token` to a variable so the next request uses it.

---

### Step 2: Get Farmer Scans (GET)

**Endpoint:**
```
GET {{supabase_url}}/rest/v1/scans?select=*&order=device_timestamp.desc
```

**Headers:**
| Key | Value |
|-----|-------|
| Content-Type | application/json |
| apikey | {{supabase_anon_key}} |
| Authorization | Bearer {{access_token}} |

**Expected Response (200):**
```json
[
  {
    "id": "...",
    "device_farmer_id": "AGD-4821",
    "farmer_name": "John Doe",
    "farmer_village": "Chikun",
    "crop_species": "plantain",
    "disease_label": "sigatoka",
    "confidence": 0.87,
    "latitude": 10.5,
    "longitude": 7.4,
    "verified": false,
    ...
  }
]
```

---

### Step 3: Insert Test Scan (POST)

**Endpoint:**
```
POST {{supabase_url}}/rest/v1/scans
```

**Headers:**
| Key | Value |
|-----|-------|
| Content-Type | application/json |
| apikey | {{supabase_anon_key}} |
| Authorization | Bearer {{access_token}} |
| Prefer | return=representation |

**Body (JSON):**
```json
{
  "device_farmer_id": "AGD-TEST01",
  "farmer_name": "Test Farmer",
  "farmer_village": "Chikun",
  "farmer_phone": "+2348012345678",
  "crop_species": "plantain",
  "disease_label": "sigatoka",
  "confidence": 0.87,
  "latitude": 10.5325,
  "longitude": 7.4264,
  "state": "Kaduna",
  "lga": "Chikun",
  "device_timestamp": "2026-08-24T12:00:00Z"
}
```

**Expected Response (201):** Returns the inserted row with auto-generated `id` and `synced_at`.

> The `Prefer: return=representation` header tells Supabase to return the inserted row instead of an empty response.

---

## Quick Reference — All Endpoints

| # | Method | Endpoint | Description |
|---|--------|----------|-------------|
| 1 | POST | `/auth/v1/token?grant_type=password` | Login → get access token |
| 2 | GET | `/rest/v1/scans?select=*&order=device_timestamp.desc` | Get all farmer scans |
| 3 | GET | `/rest/v1/scans?select=*&order=device_timestamp.desc&limit=50` | Get latest 50 scans |
| 4 | GET | `/rest/v1/scans?select=*&disease_label=eq.sigatoka` | Filter scans by disease |
| 5 | POST | `/rest/v1/scans` | Insert a test scan |
| 6 | GET | `/rest/v1/farmers?select=*` | Get all farmers |

---

## Common Query Filters (PostgREST syntax)

| Filter | Example | Meaning |
|--------|---------|---------|
| `eq` | `?disease_label=eq.sigatoka` | equals |
| `neq` | `?crop_species=neq.cassava` | not equals |
| `like` | `?farmer_name=like.*john*` | contains |
| `gt` | `?confidence=gt.0.8` | greater than |
| `lt` | `?confidence=lt.0.5` | less than |
| `order` | `?order=device_timestamp.desc` | sort descending |
| `limit` | `?limit=10` | limit results |
| `select` | `?select=id,farmer_name,disease_label` | select specific columns |

---

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| 401 Unauthorized | Wrong email/password | Verify credentials in Supabase Dashboard → Auth → Users |
| 401 Unauthorized on GET | Token expired or missing | Re-run Login request first |
| 403 Forbidden | RLS policy blocking | Check RLS policies in schema.sql |
| Empty array `[]` | No scans synced yet | Use Insert Test Scan or sync from the mobile app |
| 201 but empty response | Missing `Prefer: return=representation` header | Add the header to get the inserted row back |
