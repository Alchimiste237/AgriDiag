# AgroDiag — A Simple Guide

**A phone app that checks your crops for disease from a single photo, and a website that helps agricultural offices see where problems are spreading.**

*This page is written for everyone, whether or not you work with computers. If you are a developer looking for setup instructions, see the [technical README](../README.md).*

---

## The problem we are solving

Smallholder farmers often cannot get an agronomist to look at a sick plant quickly. By the time someone qualified arrives, the disease may have spread through a whole field — or a whole village.

AgroDiag puts a trained pair of eyes on every phone:

- the farmer takes **one photo of a leaf**,
- the app says **what disease it is** and **how serious it is**,
- and it explains **what to do about it** — in plain language, out loud if the farmer prefers to listen.

And because every scan is recorded, extension officers and ministries can see **where** diseases are appearing **before** they become an outbreak.

## Who is it for?

| If you are a… | AgroDiag gives you… |
|---|---|
| **Farmer** | An instant second opinion on a sick plant, day or night, even with no internet and no reading required. |
| **Extension officer / agronomist** | Verified field data, a list of scans to check, and early warning when a disease is trending upward in your area. |
| **NGO / ministry / development programme** | A live overview of disease pressure by region, with maps and charts you can put straight into a report. |
| **Data scientist** | A growing, human-verified image dataset ready for retraining the models. |

## Using the mobile app

You do not need an account to start. From the home screen, tap **Get started**.

### 1. Scan a plant

Open the **Scanner** tab and point your camera at a leaf.

> **Tip:** lay the leaf flat and fill the frame. Good light and a clear view of the whole leaf give the most reliable answer.

Press the shutter. The app first works out **which crop** the leaf belongs to, then runs the matching disease model — all on your phone, in about a second, without using your data.

If the photo is not one of the supported crops (a table, a wall, a hand), the app will say so rather than guess.

### 2. Read or listen to the result

You get:

- **The diagnosis** — for example, *Mosaic disease of cassava*,
- **A confidence score** — how sure the model is (92% in the example above),
- **A severity level** — Low, Medium or High,
- **What the disease does** — a short description,
- **What to do** — practical steps such as removing infected plants or using resistant varieties.

Tap **Listen to the recommendation** to hear it read aloud. The app speaks **English or French**, and the language can be changed in **Profile**.

### 3. Your history is kept on the phone

Every scan is saved locally, so you can look back at it later — no signal needed. When the phone next gets internet, scans are sent quietly in the background so agronomists can see them.

### Supported crops

Banana · Cacao · Cassava · Maize

More crops are on the way — see the [roadmap](../README.md#roadmap).

## Using the monitoring website

The dashboard is for people who **review and manage** the data rather than collect it.

Open it in any browser and sign in with the account your administrator gave you.

- **Overview** — the big picture: total farmers, total scans, open alerts, and a **map** showing where detections are clustering.
- **Analytics** — which diseases are affecting which crops, and how outbreaks have moved over time.
- **Farmer Scans** — every scan received from the phones. An agronomist can confirm or correct the label; these confirmations are what make the data trustworthy.
- **Alerts** — automatic flags when a disease spikes above its normal level, plus a simple composer for drafting an advisory message to farmers in that area.
- **Retraining** — how many verified images are ready to be used to improve the models.

> **Note:** the dashboard needs an internet connection. The phone app does not.

## Questions you might have

**Does it cost money to use?**
No. The app is free, and once installed it works without mobile data.

**What happens if the internet is down?**
Nothing is lost. Scans are stored on the phone and uploaded automatically as soon as a connection returns.

**Is my photo or phone number private?**
Scans are shared only with the administrators running the programme. Photos are stored in a private cloud bucket, and access is controlled by database rules rather than by app settings.

**What if the app is wrong?**
Every diagnosis includes a confidence score, and low-confidence results should be confirmed by a person. That is exactly what the dashboard's *Farmer Scans* verification step is for — and confirmed scans are what the model learns from next time.

**Which languages does it speak?**
English and French.

**Can I try it?**
Ask your programme administrator for the install file, or see the [technical README](../README.md#run-the-app) if you have the Flutter tools installed.

## Where to go next

- **Developers:** [technical README](../README.md) · [dashboard setup](../app/adminDashboard/SETUP.md) · [model training](../app/crop_disease_app/README_crop_detector.md)
- **Programme managers:** start with [the repository overview](../README.md#whats-in-this-repository)

---

*AgroDiag — diagnose your crops today, for a healthier tomorrow.*
