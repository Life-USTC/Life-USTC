# Catalog identity presentation

This is the native implementation contract for [UI task #144](https://github.com/Life-USTC/Life-USTC/issues/144), aligned with the server's model-first prototype. Field order is shared across platforms; native controls and list navigation remain native.

| Model | Identity | Supporting context | State/actions |
| --- | --- | --- | --- |
| Course | Quiet monospace course code, then dominant localized course name | Category and education level in the detail facts | Open course or an offering; do not imply course enrollment |
| Teaching section | Dominant localized course name, then teacher names | Monospace section code, then semester | Historical status; subscription role and explicit actions remain separate |

Compact rows and detail headers use this same semantic order. Detail headers increase title size rather than rearranging fields. Missing course names fall back to the section code once; missing teachers or semester are omitted without inventing data. Long names and codes wrap vertically, including Dynamic Type; no fixed height or one-line truncation is applied.

## Native adoption

- Course catalog and course detail share `ServerCourseIdentityView`.
- Catalog, course history, teacher history and import preview share `ServerSectionRow`.
- Section detail and subscriptions use the same `ServerSectionIdentityView` through their existing response types.
- Detail facts, teacher links, history indicators, subscription role controls and authentication affordances retain their existing ownership.

## Visual and interaction review

Compare one actual course and one offering across catalog → course detail → section detail → subscription/import preview. Review English and Chinese, current and historical offerings, missing optional fields, long names, large text, iPhone and iPad. Confirm the same offering remains recognizable and that sign-in/subscription controls still act on the exact section ID.

Source reuse is an implementation safeguard, not visual acceptance. Retain matched native screenshots and interaction evidence with the PR. Linux cannot render SwiftUI; macOS CI and native gallery review remain required before this task closes. The separate PR #140 full-device/release investigation is not completed by this presentation change.
