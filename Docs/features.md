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

## Existing capabilities and remaining parity

Second Classroom already has native activity/organizer browsing, calendars,
subscriptions, follows and notification views. Comment/reply/reaction workflows
and basic todos also exist. Their complete parity acceptance remains part of the
inventory; an existing screen alone does not establish it.

Further work includes the rich actionable home, complete homework/todo editing,
description and file workflows, server publications, campus links/pins, weather,
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

CI runs all unit tests, both native journey suites and the signed IPA build.
Manual branch validation uses `ci.yaml` with `beta=false`; the workflow's normal
main-branch delivery handles TestFlight. Visual changes include matched evidence
in their PR. macOS runner configuration belongs in personal environment setup,
not this repository's product documentation.
