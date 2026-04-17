# Life@USTC iOS Client — Features

> Client version: **3.0.0**
> Server: `life-ustc.tiankaima.dev`

---

## Table of Contents

1. [Authentication](#1-authentication)
2. [Curriculum & Courses](#2-curriculum--courses)
3. [Exams](#3-exams)
4. [Scores](#4-scores)
5. [Homework](#5-homework)
6. [Todos](#6-todos)
7. [Comments](#7-comments)
8. [Bus Schedule](#8-bus-schedule)
9. [Feed (News Sources)](#9-feed-news-sources)
10. [Calendar Subscriptions](#10-calendar-subscriptions)
11. [Server Sync](#11-server-sync)
12. [Settings & Configuration](#12-settings--configuration)

---

## 1. Authentication

### USTC CAS Login
- Native login form for `id.ustc.edu.cn` (Central Authentication Service)
- Supports demo mode (`demo`/`demo`) for UI testing and screenshots
- On success, stores session cookies for subsequent USTC API requests
- Triggers onboarding flow on first login

### Server OAuth2 (PKCE)
- OAuth2 Authorization Code flow with PKCE (S256)
- Client ID: `life-ustc-ios`, redirect URI: `dev.tiankaima.life-ustc://auth/callback`
- Uses `ASWebAuthenticationSession` for the browser-based consent
- JWT access tokens stored in Keychain (shared via app group)
- `resource` parameter included for JWT (not opaque) token issuance
- Token refresh handled automatically by `ServerClient`

### Data Sources
| Data | Source | Auth |
|------|--------|------|
| Courses, curriculum, exams, scores | `jw.ustc.edu.cn` | USTC CAS |
| Blackboard homework | `www.bb.ustc.edu.cn` | USTC CAS |
| Todos, comments, bus, calendar | `life-ustc.tiankaima.dev` | OAuth2 JWT |
| News feeds | Various `*.ustc.edu.cn` RSS | None |

---

## 2. Curriculum & Courses

### From USTC (scraping)
- Scrapes current semester curriculum from `jw.ustc.edu.cn`
- Parses lesson codes, names, instructors, time slots
- Stores locally via SwiftData for offline access
- Displayed in weekly timetable view

### From Server
- `GET /api/courses` — search courses with pagination
- `GET /api/courses/{jwId}` — course detail (description, credits, sections)
- `GET /api/sections` — search sections (filter by semester, course)
- `GET /api/sections/{jwId}` — section detail with schedules, exams
- `GET /api/sections/{jwId}/schedules` — section schedule entries
- `GET /api/semesters` — list all semesters
- `GET /api/semesters/current` — current semester

### Sync
- After scraping USTC curriculum, lesson codes are matched against the server
  via `POST /api/calendar-subscriptions/match-codes`
- Matched sections are subscribed via `PUT /api/calendar-subscriptions/current`
- This enables server-side features (comments, homework) for the user's courses

---

## 3. Exams

### From USTC
- Scrapes exam schedule from `jw.ustc.edu.cn`
- Shows exam name, date, time, location
- Configurable display in Settings → Exam Settings

### From Server
- Exam data embedded in section detail responses (`ServerSectionDetail.exams`)
- Includes room, building, start/end time, date

---

## 4. Scores

### From USTC
- Scrapes grade/score data from `jw.ustc.edu.cn`
- Shows per-course grades with GPA calculation
- Historical score access across semesters

---

## 5. Homework

### From Blackboard (scraping)
- Scrapes assignment list from `www.bb.ustc.edu.cn`
- Shows title, due date, course association

### From Server
- `GET /api/homeworks` — list homeworks (filter by section, subscribed only)
- `GET /api/homeworks/{id}` — homework detail
- `POST /api/homeworks` — create homework
- `PATCH /api/homeworks/{id}` — update homework
- `DELETE /api/homeworks/{id}` — delete homework

---

## 6. Todos

### From Server
- `GET /api/todos` — list user's todos
- `POST /api/todos` — create todo
- `PATCH /api/todos/{id}` — update todo (title, done status)
- `DELETE /api/todos/{id}` — delete todo

---

## 7. Comments

### From Server
- `GET /api/comments?sectionId={id}` — list comments for a section
- `POST /api/comments` — create comment
- `PATCH /api/comments/{id}` — update comment
- `DELETE /api/comments/{id}` — delete comment
- Comments are tied to course sections for community discussion

---

## 8. Bus Schedule

### From Server
- `GET /api/bus` — inter-campus bus schedule
- Supports origin/destination campus filtering
- Shows routes, stops, trips, and next-departure recommendations
- Day type awareness (weekday, weekend, holiday)

---

## 9. Feed (News Sources)

### From USTC
- Aggregates RSS/news feeds from multiple `*.ustc.edu.cn` sources
- Configurable source selection in Settings → Feed Settings
- Catalog of available news sources from static configuration

---

## 10. Calendar Subscriptions

### From Server
- `GET /api/calendar-subscriptions/current` — current user's subscribed sections
- `PUT /api/calendar-subscriptions/current` — update subscriptions
- `POST /api/calendar-subscriptions/match-codes` — match USTC lesson codes to server sections
- Drives personalized schedule, homework, and exam views

---

## 11. Server Sync

### Push Flow (Client → Server)
The iOS client is the **only actor** that can scrape `*.ustc.edu.cn` (requires student credentials).
After scraping, it pushes data to the server so other clients and features can reference it.

1. **Curriculum codes** → matched and subscribed via calendar subscription endpoints
2. **Homework** → (planned) push scraped BB homework to server for deduplication

### Pull Flow (Server → Client)
- Overview dashboard: `GET /api/overview`
- Schedule queries: `GET /api/schedules`
- Teacher lookup: `GET /api/teachers`, `GET /api/teachers/{id}`

---

## 12. Settings & Configuration

### Pages
- **Home Settings** — configure home screen widgets/cards
- **Feed Settings** — select news sources
- **Exam Settings** — exam display preferences
- **Server Account** — OAuth2 login/logout, server connection status
- **About** — app version, credits
- **Legal** — privacy policy, terms

### Test Infrastructure
- Demo mode: login with `demo`/`demo` to enter demo mode with in-memory SwiftData
- `UI_TEST_RESET_ONBOARDING` launch argument resets first-login state
- E2E UI tests cover login, navigation, and feature access
- Unit tests cover ServerClient, USTC services, and model decoding

---

## Architecture

```
App/                    — Entry point, ContentView, AppDelegate
Views/                  — UI organized by feature (Home, Features, Feed, Settings, ...)
Server/                 — Server SDK (ServerClient, ServerAuth, models, endpoints, sync)
Schools/USTC/           — USTC-specific services (AAS, BB, Catalog, CAS login)
General/                — Shared utilities (SwiftData stack, extensions)
Widget/                 — iOS widget extension
Tests/                  — Unit tests + UI tests
```

### Server SDK Layer
- `ServerClient` — authenticated HTTP client with token management
- `ServerAuth` — OAuth2 PKCE flow
- `ServerEndpoints` — type-safe endpoint definitions
- `ServerModels` — response/request types (auth, homework, todo, bus, etc.)
- `ServerAcademicModels` — academic domain types (courses, sections, teachers, schedules)
- `ServerSync` — background sync logic (curriculum push)

### USTC Service Layer
- `USTCAASClient` — Academic Affairs System scraping
- `USTCBBClient` — Blackboard scraping
- `USTCCatalogClient` — Course catalog data
- `USTCStaticClient` — Static data (bus schedules, news sources)
