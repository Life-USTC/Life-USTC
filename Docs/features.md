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
  native lists and details. Sections can be filtered by semester.
- Section details use stable server IDs for schedules, exams and subscription
  actions. Meeting lists exhaust the scoped section-schedules pagination,
  including retired sections. No course-name search fallback chooses a write target.
- Owners can inspect all subscribed semesters, append/remove one membership,
  and change its regular, auditor or teaching-assistant kind. These changes do
  not alter official university enrollment or replace other memberships.
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
completion requires a Life@USTC account. Markdown text currently uses native
inline rendering; advanced math and tables still need acceptance in the final
content-rendering pass.

## Existing capabilities and remaining parity

Second Classroom already has native activity/organizer browsing, calendars,
subscriptions, follows and notification views. Comment/reply/reaction workflows
and basic todos also exist. Their complete parity acceptance remains part of the
inventory; an existing screen alone does not establish it.

Further work includes shared-homework creation and maintenance, description
and file workflows, server publications, campus links/pins, weather,
map and bus preferences, global discovery, and complete account/governance
entries. Account security and administration retain their declared session-only
Web boundaries unless a separately reviewed supported API is added. Service
transports such as crawler ingestion, GraphQL/MCP hosting and operational
metrics do not require mobile screens.

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
