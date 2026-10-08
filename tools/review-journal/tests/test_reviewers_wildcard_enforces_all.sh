#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
start_test "test_reviewers_wildcard_enforces_all"

fixture="$TEST_WORKDIR/human-thread.json"
journal_dir="$TEST_WORKDIR/journal"
mkdir -p "$journal_dir"

python3 - "$TESTS_DIR/fixtures/small-pr.json" "$fixture" <<'PY'
import json, sys
src, dst = sys.argv[1:3]
data = json.load(open(src))
nodes = data["data"]["repository"]["pullRequest"]["reviewThreads"]["nodes"]
thread = next(n for n in nodes if n["id"] == "PRRT_block_missing")
thread["comments"]["nodes"][0]["author"]["login"] = "some-human-reviewer"
data["data"]["repository"]["pullRequest"]["reviewThreads"]["nodes"] = [thread]
json.dump(data, open(dst, "w"))
PY

cat > "$TEST_WORKDIR/.review-journal.json" <<'JSON'
{
  "enforcement_mode": "strict",
  "reviewers": ["*"],
  "journal_dir": "journal"
}
JSON

set +e
stderr=$(cd "$TEST_WORKDIR" && "$SYNC_PR" 1 \
  --repo test/repo \
  --threads-from "$fixture" \
  --enforce strict 2>&1 >/dev/null)
ec=$?
set -e

if [ "$ec" -eq 0 ]; then
  TEST_FAILURES=$((TEST_FAILURES + 1))
  echo "${CRED}FAIL${CRST}: $TEST_NAME: wildcard reviewer policy should enforce human thread"
fi
assert_contains "BACKFILL NEEDED" "$stderr" "wildcard tracks arbitrary reviewer"
assert_contains "some-human-reviewer" "$stderr" "stderr identifies arbitrary reviewer"

finish_test
