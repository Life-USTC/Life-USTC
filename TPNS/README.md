#  `TPNS/`

TPNS is a mobile app notification SDK provided by Tencent Cloud,
and we've removed TPNSService to avoid collecting user information.

Lifecycle and functions are mainly implemented in `Models/AppDelegate.swift`,
and this folder contains lib and headers provided by Tencent only,
and it's not open-sourced by them.

One shall notice that TPNS is a paid service,
and you should use your own key and client secret when building your own app.
