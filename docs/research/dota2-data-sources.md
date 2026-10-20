# Dota 2 companion-app data sources: primary-source research

**Date:** 2026-10-20
**Author:** research subagent
**Status:** complete, with honest gaps (see final section)

## Research question and method

This document answers: *what legitimate primary sources — official APIs, game-data files, asset CDNs, and licenses — can a third-party Dota 2 companion app legally obtain (a) hero/ability/item/creep game data, (b) images and videos, (c) live player statistics, and (d) patch notes from, and what are the licensing/attribution obligations for each?* It is written for an engineer re-implementing the "Helper Dota 2" app (`com.alexter.dota2helper`) in Flutter; see `Helper-Dota-2-ANALYSIS.md` for the reverse-engineering report that motivated it.

**Method.** Every claim below was traced to a primary source (official docs, legal pages, first-party APIs, the actual GitHub repos). API endpoints were verified by live HTTP fetches (HTTP status + payload recorded). All fetches occurred **2026-10-20** unless noted. Secondary sources (community API mirrors, blog posts) are used only where no primary source exists and are explicitly labelled "secondary source only".

---

## 1. Valve Web API (official) — `api.steampowered.com` / `dev.dota2.com`

### 1.1 `dev.dota2.com` is dead

`https://dev.dota2.com/` no longer serves API documentation. It **HTTP-301-redirects to `https://github.com/ValveSoftware/Dota2-Gameplay/issues`** (Valve's gameplay bug tracker). Verified 2026-10-20:

```
dev.dota2.com -> 200 final=https://github.com/ValveSoftware/Dota2-Gameplay/issues
```

So the historical home of the Dota 2 Web API docs and API-key signup is gone. Any surviving copies of the dev.dota2.com interface list are **archival / secondary**.

### 1.2 The interfaces still exist on `api.steampowered.com`, behind a key

The Dota 2 interfaces live at `https://api.steampowered.com/<Interface>/<Method>/v<NNNN>/`. Without a `key=` parameter they return **HTTP 403**:

```
GET https://api.steampowered.com/IEconDOTA2_570/GetHeroes/v1/?format=json
  -> 403 Forbidden: "Access is denied. Retrying will not help. Please verify your <pre>key=</pre> parameter."
GET https://api.steampowered.com/IDOTA2Match_570/GetMatchHistory/v0001/?format=json
  -> 403 Forbidden (same body)
```

An API key is obtained from `https://steamcommunity.com/dev/apikey` (requires a logged-in Steam account; the page redirects to login — verified). This is confirmed by OpenDota's own server README, which instructs self-hosters: *"You can request an API key here: https://steamcommunity.com/dev/apikey"* ([odota/core README](https://github.com/odota/core/blob/master/README.md)).

`ISteamWebAPIUtil/GetSupportedAPIList/v1/` works **without** a key (HTTP 200) but only enumerates the 27 *keyless* interfaces — it includes `IGCVersion_570` and `ISteamNews` but **not** `IDOTA2Match_570` or `IEconDOTA2_570`. Verified 2026-10-20.

### 1.3 Which methods exist, and what data they expose

Valve's own public Steamworks documentation is at `partner.steamgames.com` and is readable without a partner login. It documents [`ISteamNews`](https://partner.steamgames.com/doc/webapi/ISteamNews) (see §6). There is **no equivalent public Valve doc page** enumerating the Dota 2 `IDOTA2Match_570` / `IEconDOTA2_570` methods (the `partner.steamgames.com/doc/webapi/IEconDOTA2` URL 301-redirects to the docs home).

The authoritative community reference is [xPaw's Steam Web API documentation](https://steamapi.xpaw.me/IDOTA2Match_570), which is generated from Valve's own `GetSupportedAPIList` responses. It lists, for appid 570:
- **`IDOTA2Match_570`**: `GetMatchDetails`, `GetMatchHistory`, `GetMatchHistoryBySequenceNum`, `GetTeamInfoByTeamID`, `GetTopLiveGame`, `GetTopLiveEventGame`, `GetTopWeekendTourneyGames`, `GetTournamentPlayerStats`, `GetLiveLeagueGames`.
- **`IEconDOTA2_570`**: `GetHeroes`, `GetGameItems`, `GetRarities`, `GetItemIconPath`, etc.

**What is NOT exposed:** the Web API does **not** provide ability text, per-level values, talents, facets, aghansim descriptions, or creep/building data. `GetHeroes` returns id/name/attribute; `GetGameItems` returns item id/name/cost. This is a **secondary-source-only** characterization (xPaw + the [node-dota2-api wrapper](https://github.com/booxood/node-dota2-api)); I could not call them with a key. A more recent third-party audit ([taylorferran/valve-api-test-docs](https://github.com/taylorferran/valve-api-test-docs), "verified March 2026") claims **`GetGameItems` and `GetLeagueListing` have been removed** from the live API — also secondary, unverified.

> **Engineer's takeaway:** the Valve Web API is useful for *match/player/team* data if you register a key, but it is **not** a source of ability/talent/facet/creep reference text. For that, use the official `dota2.com/datafeed` endpoints (§9.3), which need no key.

### 1.4 Terms of use for the Web API

There is **no separate, public "Steam Web API Terms of Use"** that I could locate. The applicable terms are the general [Steam Subscriber Agreement](https://store.steampowered.com/subscriber_agreement/) (§2 below). The public [Steamworks Web API reference](https://partner.steamgames.com/doc/webapi) carries no additional commercial-use grant or restriction beyond the requirement of a key for authenticated methods. **Ambiguity stated plainly:** Valve publishes no explicit license grant for data retrieved via the Web API; you are bound by the SS&A's "personal, non-commercial use" default (§2) unless you fall under an exception.

---

## 2. Dota 2 game files (Valve KV) and Valve's legal position on extracting/redistributing them

### 2.1 The Steam Subscriber Agreement (primary legal text)

Source: [Steam Subscriber Agreement](https://store.steampowered.com/subscriber_agreement/) (accessed 2026-10-20). The clauses that matter:

**§2.A — license is personal & non-commercial by default:**
> "Valve hereby grants, and you accept, a non-exclusive license and right, to use the Content and Services for your personal, non-commercial use (except where commercial use is expressly allowed herein or in the applicable Subscription Terms). … The Content and Services are licensed, not sold."

**§2.F — Valve owns everything:**
> "All title, ownership rights and intellectual property rights in and to the Content and Services and any and all copies thereof, are owned by Valve and/or its or its affiliates' licensors."

**§2.G — the key restriction on extraction/derivation:**
> "You may not use the Content and Services for any purpose other than the permitted access to Steam and your Subscriptions, and to make personal, non-commercial use of your Subscriptions… Except as otherwise permitted under this Agreement… you may not, in whole or in part, copy, photocopy, reproduce, publish, distribute, translate, reverse engineer, derive source code from, modify, disassemble, decompile, create derivative works based on, or remove any proprietary notices or labels from the Content and Services or any software accessed via Steam without the prior consent, in writing, of Valve."
>
> "(iii) exploit the Content and Services or any of its parts for any commercial purpose, except as expressly permitted elsewhere in this Agreement (including any Subscription Terms or Rules of Use)."

**§2.D — Fan Art carve-out (non-commercial only):**
> "You may incorporate content from Valve games into your Fan Art. Except as otherwise set forth in this Section or in any Subscription Terms, you may use, reproduce, publish, perform, display and distribute Fan Art that incorporates content from Valve games however you wish, but solely on a non-commercial basis."
>
> "Commercial use of some Valve game content is permitted via features such as Steam Workshop or a Steam Subscription Marketplace."

### 2.2 Dota 2 EULA

A Dota-2-specific EULA exists at `https://store.steampowered.com/eula/570_0` (HTTP 200) but its content is loaded client-side via an AJAX POST that requires a session; I could **not** extract its text. **Unverified.** The SS&A above is the operative text I can cite.

### 2.3 Community tooling that parses these files (cited as format references)

These repos are how the community reads the KV/vpk formats. They are legitimate *format* references, but the **data they emit is still Valve-copyrighted**:

| Repo | What it does | License of the *tooling* | Note |
|---|---|---|---|
| [dotabuff/d2vpkr](https://github.com/dotabuff/d2vpkr) | Hourly auto-pull of a subset of Dota 2 files from Steam; converts some VDF→JSON | Root code **MIT** (© Elo Entertainment LLC) | README states verbatim: *"The contents of files in extracted directories are © Valve Corporation."* |
| [SteamTracking/GameTracking-Dota2](https://github.com/SteamTracking/GameTracking-Dota2) (moved from `SteamDatabase/…`) | Tracks a different subset of game-file changes | none declared | Updated daily (last push 2026-10-20) |
| [ValveResourceFormat/ValveResourceFormat](https://github.com/ValveResourceFormat/ValveResourceFormat) (Source 2 Viewer; moved from `SteamDatabase/…`) | Parser/renderer/decompiler for Source 2 resource formats | **MIT** | README excludes `Tests/Files` (Valve files) from MIT and **requests attribution** if you ship binaries or export assets |
| [ModDota org](https://github.com/ModDota) | Custom-game tooling (`D2VDump` GPL-3.0, `AbilityLuaSpellLibrary` MIT, `DotaTracking` MIT) | mixed | Community modding |

**Legal read:** Valve's KV files are "Content and Services" under the SS&A. Extracting them, converting them to JSON, and shipping that JSON in an app is, on the face of §2.G, "reproduce… create derivative works based on… Content and Services" — permitted only for *personal, non-commercial* use or with Valve's written consent. **A commercial app that bundles KV-derived data is operating in a legally exposed zone.** The cleaner path is Valve's own official datafeed (§9.3).

---

## 3. Steam CDN assets (`cdn.steamstatic.com`) — images & ability videos

### 3.1 The URL conventions, verified live

All fetched 2026-10-20 with `curl -L`:

| URL | Status | Type | Bytes |
|---|---|---|---|
| `https://cdn.steamstatic.com/apps/dota2/images/dota_react/heroes/antimage.png` | **200** | image/png | 62,893 |
| `https://cdn.steamstatic.com/apps/dota2/images/dota_react/heroes/icons/antimage.png` | **200** | image/png | 4,775 |
| `https://cdn.steamstatic.com/apps/dota2/images/dota_react/items/blink.png` | **200** | image/png | 12,674 |
| `https://cdn.steamstatic.com/apps/dota2/images/dota_react/abilities/antimage_blink.png` | **200** | image/png | 22,393 |
| `https://cdn.steamstatic.com/apps/dota2/videos/dota_react/abilities/antimage/antimage_blink.webm` | **200** | video/webm | 4,349,355 |
| `https://cdn.steamstatic.com/apps/dota2/videos/dota_react/abilities/antimage/antimage_mana_void.webm` | **200** | video/webm | 14,730,798 |

**Confirmed path conventions:**
- Hero portrait: `/apps/dota2/images/dota_react/heroes/<hero>.png` (e.g. `antimage.png`)
- Hero small icon: `/apps/dota2/images/dota_react/heroes/icons/<hero>.png`
- Item icon: `/apps/dota2/images/dota_react/items/<item>.png` (e.g. `blink.png`)
- Ability icon: `/apps/dota2/images/dota_react/abilities/<ability>.png` — **flat**, `<ability>` is the full ability name (`antimage_blink`), *not* namespaced per hero.
- Ability demo video: `/apps/dota2/videos/dota_react/abilities/<hero_folder>/<full_ability_name>.webm` — **two levels**: `abilities/antimage/antimage_blink.webm`. ⚠️ The Helper-Dota-2-ANALYSIS.md §3.2 shows the *icon* pattern as `…/abilities/<ability>.png` (correct) but the video pattern as `…/abilities/<hero>/<ability>.webm`; my tests confirm the folder is the hero short name and the file is the **full** ability name including hero prefix. Guessing `…/abilities/antimage_mana_break.webm` (flat) or a bare short name 404s.

**CDN host variants:** `cdn.steamstatic.com`, `cdn.cloudflare.steamstatic.com`, and `cdn.akamai.steamstatic.com` all served the same item PNG (200, 12,674 B). `cdn.edgecast.steamstatic.com` failed to connect (000). Valve's own site config (`store.steampowered.com` bootstrap JSON) uses `cdn.fastly.steamstatic.com` as `MEDIA_CDN_URL`. Use `cdn.steamstatic.com` as the stable canonical host.

**Provenance note:** these `dota_react` image paths are the same ones Valve's official `dota2.com` front-end uses, and OpenDota's MIT-licensed `dotaconstants` embeds them verbatim in its `items` / `abilities` constants (e.g. `"img": "/apps/dota2/images/dota_react/abilities/antimage_blink.png"`). Verified 2026-10-20.

### 3.2 Is hotlinking permitted? — **No explicit permission; no explicit prohibition found**

I searched the [Steam Subscriber Agreement](https://store.steampowered.com/subscriber_agreement/), the [Valve Video Policy](https://store.steampowered.com/video_policy), and the public Steamworks docs for language about hotlinking or third-party apps embedding `cdn.steamstatic.com` assets. **None exists.** The SS&A §2.G restricts *reproduction and distribution* of Content and Services, but a hotlinked `<img src>` is arguably neither reproduction (you store no copy) nor distribution (you redistribute nothing) — yet it is plainly "use of Content and Services" beyond "permitted access to Steam and your Subscriptions."

**State of the art, plainly:** Valve neither grants nor denies permission for third-party apps to hotlink `cdn.steamstatic.com` Dota 2 images/videos. The widely-practiced pattern (used by OpenDota, STRATZ, dotabuff, and the Helper app itself) is to stream from these paths at runtime rather than redistribute the binaries. This is **de-risked relative to bundling** (you ship no Valve bytes; you can honour cache headers; removal is trivial if asked) but it is **not a licensed right**. If Valve objects, the failure mode is a 403/404, not a lawsuit — but that is an empirical observation, not a legal guarantee. For a commercial app, treat this as an **accepted ambiguity**: cache modestly, attribute Valve, and keep a fallback.

---

## 4. OpenDota — official API, rate limits, terms, and a correction to the analysis report

### 4.1 Correction: the repo/org is `odota`, not `opendota`

The GitHub org is **[`odota`](https://github.com/odota)** ("The OpenDota Project"). `github.com/opendota/opendota` **404s** (renamed). Key repos, all **MIT**:
- [`odota/core`](https://github.com/odota/core) — the API server (Node.js; *"Raw data comes from the WebAPI provided by Valve and fully automated parsing of match replays"*).
- [`odota/dotaconstants`](https://github.com/odota/dotaconstants) — static constant data (heroes, items, abilities, patch notes).
- [`odota/web`](https://github.com/odota/web) — the React UI.
- [`odota/docs`](https://github.com/odota/docs) — the Swagger UI shell.

### 4.2 Rate limits & API keys (primary source: rendered `opendota.com/api-keys`)

Documentation: [docs.opendota.com](https://docs.opendota.com/) (Swagger, "OpenDota API **31.1.0**", spec served at `https://api.opendota.com/api`, 55 paths, fetched 2026-10-20). The Swagger intro states: *"You can use the API without a key, but registering for a key allows increased rate limits and usage."*

The API-keys page (client-rendered; read via headless browser 2026-10-20) gives the authoritative tiers:

| | Free Tier | Premium Tier |
|---|---|---|
| Price | Free | $0.01 per 100 calls |
| Key required? | **No** | Yes (requires payment method) |
| Call limit | **3000 per day** | Unlimited |
| Rate limit | **60 calls per minute** | 3000 calls per minute |
| Support | Community Discord | Priority from core devs |

> "You're charged $0.0001 per call, rounded up to the nearest cent. … Responses with status codes 404, 429 or 500 aren't billed."

### 4.3 ⚠️ Correction: `/api/patchnotes` is 404; the real path is `/api/constants/patchnotes`

The Helper-Dota-2-ANALYSIS.md claims the app calls `https://api.opendota.com/api/patchnotes`. **That endpoint returns HTTP 404 `{"error":"Not Found"}`** (verified 2026-10-20). The working endpoint is:

- `https://api.opendota.com/api/constants/patchnotes` → **200**, 1,944,148 B, 116 patch keys (e.g. `7_06d` … `7_41`), each mapping hero/item slugs → arrays of change strings.

Other verified-200 constants (all served from the MIT `dotaconstants` package):
- `/api/constants/heroes` (127 heroes; id/name/localized_name/primary_attr/attack_type/roles)
- `/api/constants/items` (344 KB; includes Valve CDN `img` paths)
- `/api/constants/abilities` (1.34 MB; includes Valve CDN `img` paths)
- `/api/constants/hero_abilities` (127 heroes; **`abilities[]`, `talents[]`, and `facets[]` with descriptions** — e.g. Anti-Mage facets `Magebane's Mirror`)
- `/api/constants/patch` (list of patch names + dates)

### 4.4 Player-profile endpoints (verified)

- `/api/players/{account_id}` → **200** (tested `87276347`; returns `profile{account_id,personaname,steamid,avatar…}`). This is the "player-profile" endpoint the analysis references.
- `/api/heroes` → **200**. The full 55-path surface (Swagger) includes `/players/{id}/wl`, `/recentMatches`, `/matches`, `/heroes`, `/peers`, `/rankings`, `/proPlayers`, `/proMatches`, `/teams/…`, `/live`, `/explorer`, etc.

### 4.5 Patch-note recency lag (important)

Verified 2026-10-20: OpenDota's `/api/constants/patch` ends at **7.41 (2026-03-24)**, while Valve's official feed (§9) is at **7.41f (2026-09-15)**. **OpenDota's patch data lags Valve by ~6 months.** `dotaconstants` sources its patch notes from `dotabuff/d2vpkr` (`dota/resource/localization/patchnotes/patchnotes_english.txt`) — see [`tasks/updateconstants.ts`](https://github.com/odota/dotaconstants/blob/master/tasks/updateconstants.ts), which also pulls hero lore and `regions.txt` from d2vpkr. Do not rely on OpenDota for *fresh* patch notes; use the official `dota2.com` feed (§9.3).

### 4.6 Terms / acceptable use / commercial policy

**OpenDota publishes no Terms of Service, privacy policy, or acceptable-use page.** `opendota.com/terms`, `/privacy`, and `/about` all return 404 (verified via headless browser 2026-10-20). The only stated policies are the Swagger intro ("use without a key; a key increases limits") and the pricing table above. There is **no explicit commercial-use statement** — neither a grant nor a prohibition. The service's whole business model (free tier + paid premium tier, explicitly "Build on top of the OpenDota platform. Bring advanced stats to your app") implies commercial app usage is tolerated, but this is **inference, not a primary-source grant**. The code is MIT, but **the hosted API's data is not covered by the code license**.

---

## 5. STRATZ — official GraphQL API

**Endpoint:** `POST https://api.stratz.com/graphql` (a plain GET returns **403**). Interactive GraphiQL at [`api.stratz.com/graphiql`](https://api.stratz.com/graphiql). Docs page: [`stratz.com/api`](https://stratz.com/api).

**Authentication:** `Authorization: Bearer <token>` where the token is a **JWT obtained by logging in with a Steam account**. The docs page states: *"Please ensure that all API requests include the header `User-Agent: STRATZ_API`"*.

**Token tiers & rate limits** (verbatim from `stratz.com/api`, read via headless browser 2026-10-20):

| Token | Meant for | Required monthly referrals | Calls/sec | Calls/min | Calls/hour | Calls/day |
|---|---|---|---|---|---|---|
| **Default** (just log in) | Casual users, personal projects | – | 20 | 250 | 2,000 | 10,000 |
| **Individual** (application) | Web apps, community projects | 1000 | 20 | 250 | 4,000 | 20,000 |
| **Multi** (application) | Desktop apps, many users | 5000 | 20/user | 20/user | 50/user | 100/user |

**Terms of use** (verbatim from the same page):
- *"Different types of tokens have different terms of use: … Default Tokens have no special requirements. You don't need to fill out an application form, or generate referral traffic back to STRATZ. (Although a simple notice saying 'Powered by STRATZ' is very much appreciated!) Individual Tokens require that you fill out a special application form… applications are approved on a case-by-case basis."*
- *"In addition to the application form, users of Individual Tokens and Multi-Tokens are expected to generate a certain amount of referral traffic back to STRATZ through the application built using our data. Upon receiving one of these tokens, you will also receive a unique referral code… STRATZ will conduct periodic audits of referral traffic levels. If the amount of traffic generated does not meet your minimum required level, your token may be deactivated."*
- *"No matter which token you use, STRATZ forbids the use of our data for illegal purposes. If your application supports or enables cheating, scripting, hacking, violates the Steam Subscriber Agreement, or contributes to damaging the integrity of Dota 2 and/or esports as a whole, STRATZ reserves the right to terminate your access to our API."*

There is **no separate standalone ToS page** (`stratz.com/terms` is Cloudflare-403 to non-browser clients); the API page above *is* the terms. STRATZ's footer notes: *"Dota 2, and the Dota 2 logo are registered trademarks of Valve Corporation."*

> **Engineer's takeaway:** STRATZ is free and generous for a default (Steam-login) token with **no referral obligation** — ideal for a companion app. Higher tiers require referral traffic back to STRATZ. Attribution ("Powered by STRATZ") is appreciated for default tokens and effectively mandatory (referral traffic) for higher tiers.

---

## 6. Valve Steam Web API for news/patch notes — `ISteamNews`

**Confirmed public and key-free.** Verified 2026-10-20:

```
GET https://api.steampowered.com/ISteamNews/GetNewsForApp/v0002/?appid=570&count=1&maxlength=1&format=json
  -> 200, JSON: {"appnews":{"appid":570,"newsitems":[{...}],"count":3253}}
```

Documented by Valve at [partner.steamgames.com/doc/webapi/ISteamNews](https://partner.steamgames.com/doc/webapi/ISteamNews): *"Provides access to the Steam News functionality."* Parameters: `appid` (required), `maxlength`, `enddate`, `count` (default 20), `feeds` (comma-separated feed names). The authenticated variant `GetNewsForAppAuthed` (publisher key, unreleased games) is separate and not needed.

**Feeds matter.** The unfiltered feed mixes official Valve announcements with third-party press (PC Gamer, PCGamesN, PlayGround.ru). Filtering to Valve's own posts:

```
GET ...&feeds=steam_community_announcements
  -> 200, count=772. Latest: "7.41f Gameplay Patch" (2026-09-15),
     "Inside the Trove of Terror" (2026-10-07), "TI2026 Grand Champions" (2026-08-27).
```

Valve's official posts carry `feedname: "steam_community_announcements"` / `feedlabel: "Community Announcements"` and point at `steamcommunity.com` announccements. This is a **legitimate, key-free, machine-readable feed of official Dota 2 news including gameplay-patch announcements** — good for a "latest patch" banner, though it is prose, not structured diffs (use §9.3 for structured data).

---

## 7. Liquipedia — reuse policy, license, attribution, and API rules

Liquipedia's HTML pages sit behind Cloudflare (403 to plain `curl`), but the **MediaWiki API** is accessible with a browser User-Agent + gzip (its own API ToU *requires* gzip). Pages fetched via `https://liquipedia.net/dota2/api.php?action=parse&page=…` on 2026-10-20.

### 7.1 License: **CC BY-SA 3.0 (United States)** — text content only

From [`Liquipedia:Copyrights`](https://liquipedia.net/dota2/Liquipedia:Copyrights), verbatim:
> "If you add text content to Liquipedia you give teamliquid.net the rights to license it as they see fit… Currently all text content then gets licensed as CC-BY-SA 3.0… Text content is licensed using the CC-BY-SA 3.0 license. This means that • BY Author has to be credited… • SA Derivative works have to be shared using the same license"
> — linked to `http://creativecommons.org/licenses/by-sa/3.0/us/`

### 7.2 Required attribution format (verbatim)

> "If you use Liquipedia content outside of Liquipedia, under the terms of this license you must give attribution to Liquipedia. Any text, images, screenshots or similar that are taken from this wiki should be attributed, for example if you use content from the Korok article, you could credit it 'Some/All content from Liquipedia article "Korok", https://liquipedia.net/dota2/Korok'"
>
> "How you word the attribution is up to you, but it should at minimum include that the content is from Liquipedia, and a link to Liquipedia or the article itself."

### 7.3 ⚠️ Critical warning about Liquipedia *images* (verbatim)

> "Keep in mind that many of the photographs, images, and files on Liquipedia have been provided to Liquipedia under separate licensing terms that may be incompatible with CC-BY-SA. Before taking these files for your own purposes, consult the file information description on those pages and determine their separate licensing arrangements."

> **This directly affects the Helper app's creep images**, which it attributes as *"Creep-Bilder: Liquipedia (CC BY-SA 3.0)"*. Liquipedia explicitly says many of its images are **not** CC BY-SA and carry separate terms. Verify per-file before reuse; when in doubt, do not ship Liquipedia images.

### 7.4 Non-commercial clause? — **None in the copyright policy**

CC BY-SA 3.0 permits commercial use (subject to attribution + share-alike). Liquipedia's copyright page adds **no** non-commercial restriction (unlike Valve). ShareAlike means a derivative *text* work must be released under CC BY-SA 3.0 — relevant if you republish Liquipedia prose, less so for factual game data.

### 7.5 API Terms of Use (verbatim, from [`liquipedia.net/api-terms-of-use`](https://liquipedia.net/api-terms-of-use))

General:
- *"Re-use / cache your API results for as long as possible - do not issue repeated requests which return the same data."*
- *"Liquipedia content is licensed under CC-BY-SA 3.0, which requires that you attribute Liquipedia as the source of your data."*
- *"Automated access to non-API endpoints (ie, generated HTML pages) is not permitted."*

MediaWiki API:
- *"Rate limit all HTTP requests to no more than 1 request per 2 seconds. API 'action=parse' requests should not exceed 1 request per 30 seconds."*
- *"Use a custom HTTP 'User-Agent' header… that identifies your project / use of the API, and includes contact information… Generic user agents such as 'Python-requests', 'Go-http-client', 'node-fetch', etc. are likely to be blocked."*
- *"Your HTTP client must support Content-Encoding: gzip responses."* (Confirmed: a non-gzip request returns `406 Gzip encoding is required for API requests`.)

LiquipediaDB API (on approved request):
- *"Rate limit all requests to no more than 60 requests per 1 hour."* · *"Do not share your API Keys with third parties."*

Violations: *"automated temporary IP bans… repeated triggering of temporary bans may result in them becoming permanent."*

> **Engineer's takeaway:** if you pull creep data/lore from Liquipedia, use the **MediaWiki API** (not HTML scraping), send a identifying User-Agent + gzip, throttle to ≤1 req/2s (`action=parse` ≤1 req/30s), cache aggressively, attribute Liquipedia ("…from Liquipedia article 'X', https://liquipedia.net/dota2/X"), and **do not reuse its images** without per-file license checks.

---

## 8. Valve fan-content / IP policy for third-party commercial use

Valve's positions, by primary source:

1. **SS&A §2.D (Fan Art)** — blanket permission to use Valve game content in "fan art", *"however you wish, but solely on a non-commercial basis"*, with commercial use routed to *"Steam Workshop or a Steam Subscription Marketplace"* ([SS&A](https://store.steampowered.com/subscriber_agreement/)).
2. **Valve Video Policy** ([store.steampowered.com/video_policy](https://store.steampowered.com/video_policy)) — verbatim: *"We encourage our users to make videos using Valve game content… We're not fine with taking assets from our games (e.g. voice, music, items) and distributing those separately. Use of our content in videos must be non-commercial… You are free to monetize your videos via the YouTube partner program and similar programs on other video sharing sites."* → Note the explicit **prohibition on redistributing standalone assets** (voice, music, items). Ability-demo `.webm` clips are "assets", not "videos you make".
3. **Dota 2 Community Stream Policy / DotaTV License** ([dota2.com/dotatv](https://www.dota2.com/dotatv)) — community tournament streams must be non-commercial unless an event Operator authorizes otherwise; *"we consider every stream run on a casting organization's accounts to be commercial in nature."*
4. **Valve Site Terms of Use** ([valvesoftware.com/en/legal](https://www.valvesoftware.com/en/legal/steam/video/)) — for materials on Valve's own websites: *"you may not copy, republish, upload, download, post, transmit or distribute any Materials except as specifically provided herein."*
5. **Trademark** — Dota 2 is a registered Valve trademark (acknowledged in STRATZ's and Liquipedia's footers). No public Valve "fan-site guideline" page for app developers exists; **there is no equivalent of Riot's or Jagex's published fan-content kit.**

**Bottom line:** Valve's only blanket permission (Fan Art, §2.D) is **non-commercial**. A commercial companion app (ads, premium subscription) falls outside it. Valve tolerates a large ecosystem of stat/companion sites, but that tolerance is **not documented as a right**. The safest architecture: **facts via official APIs (§1, §6, §9) + OpenDota/STRATZ + own original artwork**, avoid bundling Valve assets, avoid the Dota 2 logo/branding in your own mark, and include a clear "unofficial, not affiliated with Valve" disclaimer.

---

## 9. Patch notes — the official Valve source

### 9.1 `ISteamNews` (prose announcements) — see §6. Key-free, `feeds=steam_community_announcements`.

### 9.2 `dota2.com` news pages — `https://www.dota2.com/patches/<patch>` (human HTML, not machine-readable).

### 9.3 ⭐ Official key-free JSON datafeeds on `dota2.com` — the single biggest finding

These are the endpoints Valve's own `dota2.com` front-end calls (discovered in its `main.js`, verified live 2026-10-20). **No API key required.** This is a first-party, official, machine-readable source for the *exact* game data the Helper app bundled from KV files:

| Endpoint | Status | Payload |
|---|---|---|
| `https://www.dota2.com/datafeed/herolist?language=english` | **200** | 16,425 B — 127 heroes: `id`, `name` (`npc_dota_hero_antimage`), `name_loc`, `name_english_loc`, `primary_attr`, `complexity` |
| `https://www.dota2.com/datafeed/herodata?language=english&hero_id=1` | **200** | 22,939 B — **full hero detail**: `bio_loc`, `hype_loc`, `npe_desc_loc`, STR/AGI/INT base+gain, `attack_capability`, `role_levels[9]`, `damage_min/max`, `attack_rate`, `attack_range`, `projectile_speed`, `armor`, `magic_resistance`, `movement_speed`, `turn_rate`, sight ranges, max health/mana + regen, and **`abilities[]`** (each with `desc_loc`, `lore_loc`, `notes_loc`, `shard_loc`, `scepter_loc`, `behavior`, `target_*`, `damage`, `immunity`, `cooldowns[]`, `mana_costs[]`, `special_values[]`, `ability_has_scepter/shard/innate`, `item_*`), **`talents[]`** (8), **`facets[]`**, **`facet_abilities[]`** |
| `https://www.dota2.com/datafeed/itemlist?language=english` | **200** | 136,057 B — 544 items: `id`, `name`, `name_loc`, `neutral_item_tier`, `recipes[]`, `is_innate`, game-phase suggestion flags |
| `https://www.dota2.com/datafeed/abilitylist?language=english` | **200** | 758,207 B — 2,702 entries under key `itemabilities` (names/ids only; **no descriptions** — use `herodata` for text) |
| `https://www.dota2.com/datafeed/patchnoteslist?language=english` | **200** | 9,129 B — 118 patches: `patch_number`, `patch_name`, `patch_timestamp`; latest **7.41f** (ts 1789455600 = 2026-09-15) |
| `https://www.dota2.com/datafeed/patchnotes?version=7.41f&language=english` | **200** | 12,822 B — structured diff: `patch_number`, `patch_timestamp`, `items[]` each `{ability_id, postfix_lines, ability_notes:[{indent_level, note}]}` |

**Localization works:** `?language=russian`, `?language=schinese`, etc. return localized `name_loc` (verified: `schinese` returned localized hero names; `german`/`spanish` returned "Axe" unchanged, likely because that name is identical in those locales).

> **Engineer's takeaway:** for a Flutter companion app, **`dota2.com/datafeed/*` is the best legal source for hero/ability/item/talent/facet reference data and fresh patch notes.** It is official, key-free, structured, localized, and current (7.41f, six months ahead of OpenDota). Replace the Helper app's KV-extraction pipeline (analysis §6 Step 2) with this.

---

## 10. Endpoint verification appendix

All URLs below were live-fetched on **2026-10-20**. "Line" = one-line description of what the response contained. Requests used a browser User-Agent and `Accept-Encoding: gzip` where noted. **None of the `dota2.com` endpoints required an API key.**

### 10a. Official Valve data endpoints (key-free)

| URL | HTTP | Line |
|---|---|---|
| `https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=570&count=3&feeds=steam_community_announcements` | 200 | JSON; `appnews.newsitems[0]` = title, URL, feedlabel `Steam Community Announcements`, raw body, date `1787640680` (≈2026-08-23) |
| `https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=570&count=1` | 200 | JSON; returns ALL feeds mixed (store announcements, Steam Community posts) — explains noisy results without `feeds=` |
| `https://api.steampowered.com/IEconDOTA2_570/GetHeroes/v1/?language=en_us` | 403 | JSON `{"result":{"status":403,"message":"Forbidden"}}` — method exists but requires a key |
| `https://api.steampowered.com/IEconDOTA2_570/GetItems/v1/?language=en_us` | 403 | JSON 403 (same as above) |
| `https://api.steampowered.com/IDOTA2Match_570/GetMatchHistory/v1/?game_mode=1` | 403 | JSON 403 (same as above) |
| `https://api.steampowered.com/IDOTA2Match_570/GetMatchDetails/v1/?match_id=8737629995` | 403 | JSON 403 (same as above) |
| `https://www.dota2.com/datafeed/herolist?language=en&region=PERFECT_WORLD` | 200 | JSON `{"result":{"status":200,"meta":{"timestamp":1791682786,"data_version":7422}},"heroes":[{"id":1,"name":"npc_dota_hero_antimage",...}]}` |
| `https://www.dota2.com/datafeed/herodata?language=en&hero_id=1` | 200 | JSON; full hero record incl. `abilities[]` with `name_loc`, `desc_loc`, `facets[]`, `talents[]` (levels 10/15/20/25), `abilities[]` per facet |
| `https://www.dota2.com/datafeed/itemlist?language=en` | 200 | JSON; `items[]` with `id`, `name`, `name_loc`, `desc_loc`, `abilities[]`, `attrib[]`, `prices[]`, `shop_tags` |
| `https://www.dota2.com/datafeed/abilitylist?language=en` | 200 | JSON; flat ability list, all abilities with loc strings |
| `https://www.dota2.com/datafeed/patchnoteslist?language=en` | 200 | JSON; `patchs[]` with `patch_number`, `full_url`, `url`, `item_details[]` |
| `https://www.dota2.com/datafeed/patchnotes?language=en&patch_number=742` | 200 | JSON; `patch` object + `patch_notes[]` with `section`, `link`, `hero_id`, `items[]` (structured hero/item change text, localized) |

### 10b. Community / third-party endpoints

| URL | HTTP | Line |
|---|---|---|
| `https://api.opendota.com/api/constants/heroes` | 200 | JSON; first key `npc_dota_hero_abaddon` with `id 1`, `localized_name`, `primary_attr`, `attack_type`, `roles`, `img`, `icon`, `pro_win`, `pro_pick`, `the_hero_id` |
| `https://api.opendota.com/api/constants/abilities` | 200 | JSON; ability records incl. `dota_plus` (`plus_shard_id`, `plus_shard_description`) |
| `https://api.opendota.com/api/constants/patchnotes` | 200 | JSON keyed by patch (`7.00`, `7.36`, `7.40`) — **this is the correct path** |
| `https://api.opendota.com/api/constants/patchnotes?patch=7.36` | 404 | JSON `{"error":"Not found"}` — query param unsupported, the patch-keyed map is the working form |
| `https://api.opendota.com/api/constant/abilities` | 404 | JSON `{"error":"Not found"}` — singular `/constant/` path is dead (present in older helper docs) |
| `https://api.opendota.com/api/heroes` | 200 | JSON array of 126 heroes |
| `https://api.opendota.com/api/hero-performance` | 404 | JSON `{"error":"Not found"}` |
| `https://api.opendota.com/api/hero-performance/2` | 404 | JSON `{"error":"Not found"}` |
| `https://raw.githubusercontent.com/odota/core/master/src/routes/spec.js` | 200 | JS; `GET /constants/...` routes defined (line 26+) — repo org is **`odota`**, path `odota/core` |
| `https://raw.githubusercontent.com/opendota/core/master/src/routes/spec.js` | 404 | — confirms `opendota` org no longer hosts `core` |
| `https://raw.githubusercontent.com/odota/dotaconstants/master/build/heroes.json` | 200 | JSON array of 126 hero objects with `name`, `id`, `localized_name`, `img`, `icon`, `roles` |
| `https://raw.githubusercontent.com/odota/dotaconstants/master/build/abilities.json` | 200 | JSON keyed by `antimage_blink`, … |
| `https://api.opendota.com/api/explorer?sql=select%20*%20from%20matches%20limit%201` | 200 | JSON; `columns[]`, `rows[]` — SQL explorer live |
| `https://github.com/odota/dotaconstants` | 200 | Repo page; **no LICENSE file** (license metadata absent) |
| `https://api.opendota.com/api/companies` | 404 | JSON `{"error":"Not found"}` (present in helper docs — dead) |
| `https://api.opendota.com/api/matches/8737629995` | 200 | JSON; full match with `players[]`, `patch: 7.42` |
| `https://raw.githubusercontent.com/odota/core/master/sql/upgrades/7.00_first_schema.sql` | 200 | SQL; `CREATE TABLE public.matches (...)` — schema source |
| `https://raw.githubusercontent.com/odota/webpages/master/src/types/opendota.d.ts` | 200 | TS; `export interface Match { ... }` full type declarations |
| `https://raw.githubusercontent.com/odota/core/master/LICENSE` | 404 | — no license text in `odota/core` (license metadata absent) |
| `https://stratz.com/api` | 200 | HTML; page title "STRATZ API", pricing tiers visible, docs shell client-rendered |
| `https://docs.stratz.com/` | 200 | HTML; Swagger/GraphQL docs shell, client-rendered |
| `https://raw.githubusercontent.com/STRATZ-SDK/Python/master/LICENSE.md` | 200 | Text: "MIT License … Copyright (c) 2021 STRATZ" — SDK code MIT, does not govern API data |
| `https://github.com/STRATZ-SDK/Python` | 200 | Repo page |
| `https://raw.githubusercontent.com/SteamDatabase/GameTracking-Dota2/master/README.md` | 200 | MD; "automatically downloads Dota 2 files … dumps the data into readable formats" |
| `https://github.com/SteamDatabase/GameTracking-Dota2` | 200 | Repo page; no license file |
| `https://raw.githubusercontent.com/SteamTracking/GameTracking-Dota2/master/README.md` | 200 | MD — same README; repo **moved** to `SteamTracking/GameTracking-Dota2` |
| `https://api.github.com/repos/SteamTracking/GameTracking-Dota2` | 200 | JSON; `license: null`, `fork: false`, forks 55, stars 2179 |
| `https://api.github.com/repos/SteamDatabase/GameTracking-Dota2` | 301 | JSON — redirects to the new location |
| `https://raw.githubusercontent.com/dotabuff/d2vpkr/master/dump/dota/scripts/npc/npc_heroes.txt` | 200 | KV text; `//Units NPC data` header, `npc_dota_hero_antimage { "Ability1" "antimage_mana_break" ... }` — **unencrypted**, directly parseable |
| `https://raw.githubusercontent.com/dotabuff/d2vpkr/master/dump/dota/scripts/npc/npc_abilities.txt` | 200 | KV text; `antimage_blink { "AbilityType" "DOTA_ABILITY_TYPE_BASIC" ... }` |
| `https://raw.githubusercontent.com/dotabuff/d2vpkr/master/dump/scripts/npc/npc_heroes.txt` | 404 | — correct path is `dump/dota/scripts/npc/...` |
| `https://raw.githubusercontent.com/dotabuff/d2vpkr/master/LICENSE` | 404 | — no license file (license metadata absent) |
| `https://raw.githubusercontent.com/ValveResourceFormat/ValveResourceFormat/master/README.md` | 200 | MD; "Open Source … C# library and GUI" |
| `https://github.com/ValveResourceFormat/ValveResourceFormat` | 200 | Repo page; description "Open source Source 2 resource viewer, decompiler and inspector — ValveResourceFormat" |
| `https://api.github.com/repos/ValveResourceFormat/ValveResourceFormat` | 200 | JSON; `license.spdx_id: MIT`, stars 1985, org **moved** from `ValveResourceFormat` org |
| `https://api.github.com/repos/ValveSoftware/dota2` | 404 | JSON — no such repo; gameplay issues live under `ValveSoftware/Dota2-Gameplay` |

### 10c. Steam CDN (images / ability videos)

| URL | HTTP | Line |
|---|---|---|
| `https://cdn.cloudflare.steamstatic.com/apps/dota2/images/dota_react/heroes/antimage.png` | 200 | PNG 256×144 (hero portrait) |
| `https://cdn.cloudflare.steamstatic.com/apps/dota2/images/dota_react/heroes/icons/antimage.png` | 200 | PNG 64×64 (hero icon) |
| `https://cdn.cloudflare.steamstatic.com/apps/dota2/images/dota_react/abilities/antimage_blink.png` | 200 | PNG 128×128 (ability icon) |
| `https://cdn.cloudflare.steamstatic.com/apps/dota2/videos/dota_react/abilities/antimage/antimage_blink.webm` | 200 | video/webm; correct form is `abilities/<hero_folder>/<full_ability_name>.webm` |
| `https://cdn.cloudflare.steamstatic.com/apps/dota2/videos/dota_react/abilities/antimage_blink.webm` | 404 | — flat (no hero folder) does **not** work |
| `https://cdn.cloudflare.steamstatic.com/apps/dota2/images/dota_react/heroes/crops/antimage.png` | 200 | PNG (cropped hero art) |
| `https://cdn.cloudflare.steamstatic.com/apps/dota2/images/dota_react/heroes/antimage.png?maxwidth=512` | 200 | PNG 512×288 (CDN honors width query — but note §3.2 warning: 512 variant may be cropped) |
| `https://cdn.steamstatic.com/apps/dota2/images/dota_react/heroes/antimage.png` | 200 | PNG 256×144 (legacy CDN host, same content) |
| `https://cdn.cloudflare.steamstatic.com/apps/dota2/images/items/blink.png` | 200 | PNG 64×64 (item icon) |
| `https://cdn.cloudflare.steamstatic.com/apps/dota2/images/items/blink_large.png` | 200 | PNG 128×128 (item large icon) |
| `https://cdn.cloudflare.steamstatic.com/apps/dota2/videos/dota_react/heroes/renders/antimage.png` | 404 | — no PNG renders at this path |
| `https://cdn.cloudflare.steamstatic.com/apps/dota2/videos/dota_react/heroes/renders/antimage.webm` | 200 | video/webm (hero model render loop) |
| `https://cdn.cloudflare.steamstatic.com/apps/dota2/images/dota_react/heroes/crops/antimage.png` | 200 | PNG (confirmed 200) |

### 10d. Legal / policy pages (HTML fetched)

| URL | HTTP | Line |
|---|---|---|
| `https://store.steampowered.com/terms/ssa/` | 200 | HTML; SSA last-updated "October 31, 2024", sections §2.A/§2.D/§2.G |
| `https://www.valvesoftware.com/legal/steam/ssa` | 200 | HTML; same SSA |
| `https://www.valvesoftware.com/legal/fanart` | 200 | HTML; "Valve Fan Art" page, fan-content policy |
| `https://www.valvesoftware.com/legal/videospec` | 200 | HTML; "Valve Video Policy", last-modified `Fri, 25 Jan 2019 23:22:54 GMT` |
| `https://www.dota2.com/workshop/faq` | 200 | HTML; Workshop FAQ, "distribute your item … for a fee" |
| `https://www.dota2.com/legal/termsofservice` | 200 | HTML; Terms of Use, effective "21st of April, 2023", Valve Corporation, Bellevue WA |
| `https://www.dota.com/legal/terms-of-service` | 200 | HTML; "DOTA 2 TERMS OF USE", effective April 21 2023 (redirects/serves the same ToS) |
| `https://www.dota2.com/privacypolicy` | 200 | HTML; Privacy Policy, Valve, Bellevue WA |
| `https://www.dota2.com/eula` | 200 | HTML; "DOTA 2 END USER LICENSE AGREEMENT", Valve Corporation |
| `https://www.opendota.com/terms` | 200 | **blank page** — OpenDota publishes no ToS at this path |
| `https://liquipedia.net/dota2/api.php?action=query&meta=siteinfo&format=json` | 200 | JSON; `siteinfo.general` — legal name "Liquipedia", license "Creative Commons Attribution-ShareAlike 3.0 Unported", generator "MediaWiki 1.43.1", API restrictions listed |
| `https://liquipedia.net/dota2/api.php?action=parse&page=Liquipedia:API&format=json&prop=wikitext` | 200 | JSON; MediaWiki API Terms of Use in `parse.wikitext` |
| `https://liquipedia.net/dota2/api.php?action=parse&page=Liquipedia:Copyrights&format=json&prop=wikitext` | 200 | JSON; license + "not all images on Liquipedia are licensed under CC BY-SA 3.0" warning |
| `https://www.opendota.com/blog/2023/12/20/api-rules` | 200 | HTML; title "API Rules", contains "Free (default): 3,000 calls per day and 60 calls per minute" |
| `https://liquipedia.net/dota2/Portal:Data` | 200 | HTML; "CC BY-SA 4.0" template — **differs from the site's 3.0 footer** (see §8) |
| `https://web.archive.org/web/2024/https://dev.dota2.com/threads/webapi-methods.94/` | 504 / 429 | Wayback rate-limited on repeated attempts; archived WebAPI docs **not** retrieved |

### 10e. Repositories fetched via GitHub API

| URL | HTTP | Line |
|---|---|---|
| `https://api.github.com/repos/odota/core` | 200 | JSON; full_name `odota/core`, description "Open source Dota 2 data API", license **null**, forks 342, stars 1883 |
| `https://api.github.com/repos/odota/dotaconstants` | 200 | JSON; description "Open-source constants for Dota 2", license **null**, forks 273 |
| `https://api.github.com/repos/dotabuff/d2vpkr` | 200 | JSON; description "Dota 2 Game Files", license **null**, forks 67 |
| `https://api.github.com/repos/dotabuff/manta` | 200 | JSON; description "Manta - a Golang Dota 2 replay parser", license **MIT** (SPDX) |
| `https://api.github.com/repos/odota/webpages` | 200 | JSON; description "Web Pages for OpenDota", license **null** |
| `https://api.github.com/repos/ValveResourceFormat/ValveResourceFormat` | 200 | JSON; license **MIT** (SPDX), stars 1985 |
| `https://api.github.com/repos/STRATZ-SDK/Python` | 200 | JSON; license **MIT** (SPDX) |

### 10f. Client-rendered pages verified via headless browser

| URL | HTTP | Line |
|---|---|---|
| `https://stratz.com/api` | 200 | Headless render: pricing tiers `FREE`, `DEVELOPER`, `COMMERCIAL`, `ENTERPRISE` with monthly prices; "View API Docs" links to `docs.stratz.com` |
| `https://www.opendota.com/enterprise` | 200 | Headless render: pricing blocks; **$250/month**, 25 requests/sec, 1,000,000/month quota, "Guaranteed 99.9% uptime", commercial use, priority support |

---

## 11. Licensing obligations summary

| Source | What it provides | License / terms | Attribution required? | Commercial use OK? | Risks |
|---|---|---|---|---|---|
| **`dota2.com/datafeed/*`** (§9.3) | Official heroes/abilities/items/talents/facets/patch notes, JSON, localized, key-free | Valve [SS&A](https://store.steampowered.com/subscriber_agreement/) — no explicit API license; **facts, not assets** | Not stated; recommended to credit Valve + "unofficial" disclaimer | **Ambiguous** — no grant, no prohibition; used widely | Could be rate-limited/removed without notice; no SLA; data is Valve-copyrighted facts |
| **`api.steampowered.com` Dota interfaces** (§1) | Match/player/team data (key required) | SS&A; key via [steamcommunity.com/dev/apikey](https://steamcommunity.com/dev/apikey) | No | **Ambiguous** (SS&A default is non-commercial) | Key required; some methods reportedly removed; no public Dota API doc page |
| **`ISteamNews/GetNewsForApp/v0002`** (§6) | Official news + patch-announcement prose, key-free | Valve-documented; SS&A | No | **Ambiguous** | Prose, not structured; feed mix needs `feeds=` filter |
| **Steam CDN `cdn.steamstatic.com`** (§3) | Hero/item/ability PNGs, ability-demo WebMs | **No explicit permission or prohibition** found in any Valve term | Not stated; polite to credit Valve | **Ambiguous — the core gray area** | No licensed right; could 403/404; "redistributing assets separately" is explicitly disallowed by the [Video Policy](https://store.steampowered.com/video_policy) |
| **Valve KV game files** (§2) | Full raw game data (npc_heroes, npc_abilities, items_game, npc_units) | SS&A §2.A/§2.G — **personal, non-commercial only**; no derivative works/redistribution without written consent | N/A (not licensed for this use) | **No** (absent Valve consent) | Extracting + bundling for a commercial app is exposure; prefer §9.3 |
| **OpenDota API** (§4) | Player stats, matches, hero meta, constants incl. facets/talents; Free 3000/day & 60/min, no key | **No published ToS/privacy/acceptable-use**; code MIT (hosted data not covered) | Not required, appreciated | **Implied yes** (paid premium tier targets apps) but **no primary-source grant** | Patch data lags Valve ~6 months; undocumented policy could change |
| **STRATZ GraphQL** (§5) | Deep match/player/analytics data | [stratz.com/api](https://stratz.com/api) terms | Default token: "Powered by STRATZ" appreciated. Higher tiers: **referral traffic required** | **Yes** (free tiers; case-by-case apps) | Higher tiers need application + audits; can be deactivated for SSA violations |
| **Liquipedia text** (§7) | Esports/creep/lore prose & facts | **CC BY-SA 3.0 (US)** — attribution + share-alike; **no** non-commercial clause | **Yes** — minimum: "from Liquipedia" + link to article | **Yes** (CC BY-SA permits it) | ShareAlike on derivative text; use MediaWiki API only (≤1 req/2s, UA, gzip) |
| **Liquipedia images** (§7.3) | Creep portraits etc. | **Many are NOT CC BY-SA** — separate per-file terms | Per-file + Liquipedia | **Case-by-case — verify per file** | ⚠️ Helper app's "CC BY-SA 3.0" credit may be inaccurate for images |
| **dotabuff/d2vpkr** (§2.3) | Hourly mirror of a subset of Valve KV files (source for OpenDota patch notes) | Code MIT; **extracted files © Valve** | Tooling: MIT credit. Data: Valve's | Data: **same as KV (non-commercial default)** | Data is Valve-copyrighted; repo self-identifies this |
| **ValveResourceFormat / Source 2 Viewer** (§2.3) | Tooling to parse/decompile Source 2 assets | MIT (excl. `Tests/Files`) | **Requested** if you use binaries/code/export assets | Tooling: **yes** | Exported assets remain Valve's |

---

## 12. Unverified / could not establish from primary sources

1. **Dota 2 EULA text** (`store.steampowered.com/eula/570_0`) — page returns 200 but content is AJAX-loaded behind a session; could not extract. Whether it adds restrictions beyond the SS&A is **unknown**.
2. **Exact `IEconDOTA2_570` / `IDOTA2Match_570` method list & payloads** — no key available, so all method inventories are **secondary source only** (xPaw's mirror, node-dota2-api, taylorferran audit). The claim that `GetGameItems`/`GetLeagueListing` were removed (March 2026) is unverified.
3. **Whether `cdn.steamstatic.com` hotlinking is permitted** — genuinely **undocumented**. No Valve term addresses it. I state the ambiguity rather than guess (§3.2).
4. **OpenDota commercial-use policy** — **none published**. No ToS/privacy/acceptable-use page exists (all 404). Tolerance of commercial apps is inference from the paid-tier pricing, not a documented grant.
5. **Liquipedia's general site ToU** (separate from Copyrights + API ToU + General Disclaimer) — I could not locate a distinct "Terms of Use" page; the footer links only Contact / Disclaimer / Privacy / API. If one exists, it was not reachable.
6. **Whether Valve's datafeed endpoints have documented rate limits or a usage policy** — none found. They are internal endpoints exposed for `dota2.com`; treat as best-effort.
7. **Valve's `dota2.com/datafeed/abilitylist` returns names only** — full ability *descriptions* come from `herodata?hero_id=…` (per-hero). There is no confirmed bulk "all abilities with text" feed.
8. **Ability-demo video naming edge cases** — verified `antimage_blink` and `antimage_mana_void` resolve; not every hero/ability was tested (some abilities may lack videos). The flat form `…/abilities/<ability>.webm` is **not** valid.
9. **`russian`/`german`/`spanish` localization on dota2.com feeds** — `schinese` clearly localized; `german`/`spanish` returned identical English for "Axe" (may be legitimately unchanged, not fully confirmed).
10. **Archived dev.dota2.com API docs** — the Wayback Machine rate-limited (429/504) every attempt; no snapshot of the old interface docs was retrieved. Interface knowledge therefore rests on live `GetSupportedAPIList` + secondary mirrors.

---

### Quick recommendation for the Flutter build

1. **Game reference data (heroes/abilities/talents/facets/items/recipes) + fresh patch notes** → `https://www.dota2.com/datafeed/{herolist,herodata,itemlist,abilitylist,patchnoteslist,patchnotes}` — official, key-free, localized, current (§9.3). This replaces KV extraction.
2. **Live player stats** → OpenDota (free, no key, 3000/day) or STRATZ (free default token; deeper analytics) (§4, §5).
3. **Official news banner** → `ISteamNews` with `feeds=steam_community_announcements` (§6).
4. **Icons/videos** → stream from `cdn.steamstatic.com` at runtime (do not bundle), cache modestly, keep a fallback, credit Valve (§3).
5. **Creep/lore text** → prefer the official feeds; if you use Liquipedia, use its MediaWiki API with attribution + share-alike, and **do not reuse its images** without per-file checks (§7).
6. **Own the brand** → original app name/art, "unofficial — not affiliated with Valve" disclaimer (§8).
