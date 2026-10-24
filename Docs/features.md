# Life@USTC iOS capabilities

The server's feature specifications define business behavior and permissions.
[The client inventory](server-capabilities.json) maps every feature capability at
its pinned server revision to the intended native, Web or service-only surface.
Entries record source coverage, not a claim that every requirement is verified.
The complete delivery outcome and remaining work live in
[Task #101](https://github.com/Life-USTC/Life-USTC/issues/101).

## Navigation and accounts

The app opens with a Life@USTC sign-in or anonymous browsing choice. University
CAS setup remains optional for grades and Blackboard assignments. The four main
entries are Home, Calendar, Discover and Account, shared by iPhone and iPad.
Discover retains the university tools and existing news-source reader.

Life@USTC uses Authorization Code with PKCE through ASWebAuthenticationSession.
The fixed public client is `life-ustc-ios`; its redirect is
`dev.tiankaima.life-ustc://auth/callback`. Tokens stay in Keychain. Logout and
backend changes discard in-flight private responses and clear the learning
cache used by timetable and Widget views. Grades, Blackboard data and feeds
remain independent university/local data sources.

Production registration and a real native grant are tracked separately in
[#100](https://github.com/Life-USTC/Life-USTC/issues/100). Fixture tests do not
establish production authentication.

## Catalog and subscriptions

- Courses, teaching sections and teachers have public searchable, paginated
  native lists and details. Sections can be filtered by semester; courses by
  education level. Course and teacher histories include retired sections through
  the dedicated history routes. Historical detail retains calendar export and
  suppresses new subscriptions.
- Section details use stable server IDs for schedules, exams and subscription
  actions. Meeting lists exhaust the scoped section-schedules pagination,
  including retired sections. No course-name search fallback chooses a write target.
- Owners can inspect all subscribed semesters, append/remove one membership,
  and change its regular, auditor or teaching-assistant kind. These changes do
  not alter official university enrollment or replace other memberships.
- Subscriptions group by semester and show teachers. Meeting rows retain their
  teaching week, teacher links and available campus/building context.
- A complete subscribed-section snapshot refreshes the existing timetable and
  exam cache. Explicit meeting dates win over weekly patterns; failed partial
  reads retain the preceding snapshot. An empty subscription set clears it.
- The personal calendar reads the complete paginated date-range endpoint and
  includes classes, exams, assignment/task deadlines and Young activities.

The native subscription journey uses `/api/workspace/subscriptions/current`,
PATCH/DELETE `/api/workspace/subscriptions`, and PATCH
`/api/workspace/subscriptions/{jwId}`. Catalog identities and permissions follow
the pinned OpenAPI contract.

## Learning workspace

Home reads the server action hierarchy: current focus, urgent items, upcoming
items and today, next-three-day and all-pending deadline groups. Calendar and
home rows open the matching section, exam, homework, todo or activity. Only the
current account and selected period can expose a cached snapshot; failed reads
within that boundary retain the last complete result and offer retry.

The todo list exhausts filtered pages and retains global completion counts.
Editors send only changed fields and can explicitly clear notes or due dates;
mutation failures retain the draft or confirmed state. Shared homework includes
complete subscription coverage, server completion timestamps and the
teaching-assistant rule that a passed deadline archives work without manual
completion. The exam list retains past semesters and unknown dates.

The calendar subscription screen copies or shares the private URL supplied by
the server. Missing access and failed reads have explicit recovery states; the
app does not construct a feed token or place that URL in logs.

Personal calendars provide day, Monday-first week, month and subscribed-semester
agendas, period navigation and Today. Weeks retain all seven day headings.
Section details share or copy the public iCal URL using the section JW identity;
combined exports select up to 50 subscriptions and use sorted, unique internal
section IDs.

## Community and files

Course, section, teacher, teaching-assignment and homework entries lead to their
own comments. Replies, reactions and focused threads use the server's viewer
permissions; suspended and hidden nodes do not expose contribution actions.
Comment drafts support visibility, anonymous posting and attachments, including
preserving or removing existing attachments when editing.

Uploads use reservation, byte transfer and completion before their IDs can be
submitted with a comment. Failed stages remain retryable. My Files provides
complete owned-file listing, quota, rename, deletion and authenticated local
previews. Public profiles show the server's public contribution projection.

Descriptions expose collaborative editing and the latest 20 changes. Teaching
sections expose shared-homework creation, editing, creator deletion and up to
50 audit entries. Public homework text can be read while signed out; personal
completion requires a Life@USTC account. Section homework editors include
collapsible writing suggestions that do not add validation restrictions.

Current comments and descriptions consume the canonical server HTML through
the shared native WebKit reader. Publications use the server's rendered body,
retaining block content and image order. Description history keeps exact source
Markdown because its API does not provide historical rendered HTML.

## Campus and activity discovery

Discover includes server publications and source filters, searchable campus links,
account pins, bus routes and saved boarding preferences, weather provenance and
forecasts, and room-map lookup. Campus search opens native catalog details. The
legacy feed reader remains under University services.

Young subscriptions and organizer follows retain confirmed settings on failed
writes. Notifications support unread filtering and refresh after marking a
reminder read. Activity-time calendars report interval conflicts separately from
registration windows. Private lists clear when the account changes.
Public Young week/month views use Sunday-first start-day grouping; the day view
also retains continuing events. Source signup-list membership is distinct from
registration status, and official signup remains the primary action.

Bus maps show timetable estimates and refresh each minute; they do not report
GPS positions. Valid recent local routes are restored, while authenticated bus
preferences take priority. Version selection uses localized effective dates.

## Account management

Account management opens the supported website pages for profile/avatar,
preferences, linked logins and passkeys, sessions and security activity,
authorizations, and account deletion. The website authenticates its own session
and confirms destructive actions. Administration uses the same supported Web
entry; an ordinary app grant does not confer administrator rights. Returning
refreshes the account and notifies workspace views to reload changed state.

This App's Activity reads only the current OAuth authorization's activity and
paginates using the server cursor. Failed pages retain already loaded history.
`AccountJourneyTests` exercises website handoff, return refresh, activity-page
retry and signed-out access; production account actions still need real-account
acceptance.

## Remaining parity

The final acceptance pass verifies native rendering, calendar exports, content
links and the remaining presentation requirements on iPhone and iPad. Public
details share canonical website URLs; registered custom URLs and associated
website links route to native destinations. Production associated-link delivery
requires the server association file, and publication rendering and complete
catalog history require their companion server routes to be deployed.

Campus search uses the public catalog scope and provides a workspace-search
website entry. Campus links use the canonical resolver; workspace search and
counted link visits require the website's own session. Help links open the public
mobile, bot, MCP, CLI, Markdown and comment guides.
Account security and administration retain their declared session-only Web
boundaries. Service transports such as ingestion, GraphQL/MCP hosting and
operational metrics do not require mobile screens.

Private Blackboard data is never automatically published as shared homework.
Undated exams cannot be represented as instants in the existing Widget cache;
the complete native exam list must retain their unknown-date state.

## Verification

`ServerLearningTests` verifies native catalog/subscription wire contracts and
state transitions. `ServerDataProviderTests` covers snapshot identity, dates,
empty/failed reads and independent cached data. Session/auth tests cover stale
responses and token/callback binding. `ServerJourneyTests` drives the actual
app and URLSession against a bounded loopback HTTP fixture; it does not claim
server-side permission enforcement. Existing university/demo tests remain.

`WorkspaceJourneyTests` exercises home destinations, todo mutations, homework
completion, unknown-date exams and private calendar-feed actions using HTTP
fixtures. CI runs all unit tests, the native journey suites and the signed IPA build.
Manual branch validation uses `ci.yaml` with `beta=false`; the workflow's normal
main-branch delivery handles TestFlight. Visual changes include matched evidence
in their PR. macOS runner configuration belongs in personal environment setup,
not this repository's product documentation.

`CampusJourneyTests` and `YoungCampusJourneyTests` cover native discovery,
preferences, reminder recovery, publication filters and source navigation.
`CatalogParityJourneyTests` and `ParityNavigationJourneyTests` cover historical
catalog presentation, calendar modes and exports, sharing and guide handoff.
