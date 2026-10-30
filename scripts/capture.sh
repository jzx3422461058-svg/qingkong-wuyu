#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
module="${1:-home}"
output="${2:-docs/qa/$module-screen.png}"
qa_dir="$(mktemp -d /tmp/qingyu-capture.XXXXXX)"
open -n dist/晴空物语.app --args --qa --data-dir "$qa_dir" --module "$module" "${@:3}"
sleep 1
window_id="$(swift -e 'import CoreGraphics; import Foundation; if let windows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String:Any]] { for w in windows where ["Campus", "晴空物语"].contains(w[kCGWindowOwnerName as String] as? String ?? "") { if let b = w[kCGWindowBounds as String] as? [String:Any], let h = b["Height"] as? Double, h > 500 { print(w[kCGWindowNumber as String]!); break } } }')"
test -n "$window_id"
screencapture -x -o -l "$window_id" "$output"
osascript -e 'tell application id "local.qingyu.campus" to quit'
