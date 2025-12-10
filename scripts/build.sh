#!/bin/bash

set -xeuo pipefail

xcodegen
xcode-build-server config -project Life-USTC.xcodeproj -scheme Life-USTC
exec xcodebuild -project "Life-USTC.xcodeproj" -scheme "Life-USTC" -configuration Debug -quiet build | xcbeautify