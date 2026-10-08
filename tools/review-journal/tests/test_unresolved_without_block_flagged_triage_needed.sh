#!/usr/bin/env bash
# Strict enforcement must reject a tracked review thread that is still open
# and has no structured disposition at all.
source "$(dirname "$0")/lib.sh"
start_test "test_unresolved_without_block_flagged_triage_needed"

journal_dir="$TEST_WORKDIR/journal"
fixture="$TEST_WORKDIR/unresolved-no-verdict.json"
mkdir -p "$journal_dir"

python3 - "$TESTS_DIR/fixtures/small-pr.json" "$fixture" <<'PY'
import json, sys
src, dst = sys.argv[1:3]
data = json.load(open(src))
for thread in data["data"]["repository"]["pullRequest"]["reviewThreads"]["nodes"]:
    if thread["id"] == "PRRT_unresolved_with_block":
        thread["comments"]["nodes"] = thread["comments"]["nodes"][:1]
json.dump(data, open(dst, "w"))
PY

set +e
stderr=$("$SYNC_PR" 1 \
  --repo test/repo \
  --threads-from "$fixture" \
  --journal-dir "$journal_dir" \
  --enforce strict 2>&1 >/dev/null)
ec=$?
set -e

if [ "$ec" -eq 0 ]; then
  TEST_FAILURES=$((TEST_FAILURES + 1))
  echo "${CRED}FAIL${CRST}: $TEST_NAME: strict mode should reject unresolved/no-verdict thread"
fi
assert_contains "TRIAGE NEEDED" "$stderr" "stderr names the triage-needed condition"
assert_contains "PRRT_unresolved_with_block" "$stderr" "stderr names the open undispositioned thread"

finish_test
