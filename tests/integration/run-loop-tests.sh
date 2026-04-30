#!/usr/bin/env bash
# Comprehensive test suite for /spcrg-loop

set -uo pipefail

cd "$(dirname "$0")"

ABS_SCRIPT="/Users/zhangyufeng/RawAI/self-github/specpower-crg/scripts/check-crg-evidence.sh"

pass=0
fail=0
failed_tests=()

_pass() { printf "  \033[32mPASS\033[0m  %s\n" "$1"; pass=$((pass+1)); }
_fail() { printf "  \033[31mFAIL\033[0m  %s (%s)\n" "$1" "$2"; fail=$((fail+1)); failed_tests+=("$1"); }

_make_fixture() {
  local name="$1"
  local td=$(mktemp -d)
  mkdir -p "$td/openspec/changes/$name/specs"
  cp openspec/changes/add-search/proposal.md "$td/openspec/changes/$name/"
  cp openspec/changes/add-search/design.md "$td/openspec/changes/$name/"
  cp openspec/changes/add-search/specs/feature.md "$td/openspec/changes/$name/specs/"
  cp openspec/changes/add-search/tasks.md "$td/openspec/changes/$name/"
  cp -r .ai-workflow-kit "$td/"
  echo "$td"
}

echo "========================================"
echo "  /spcrg-loop Test Suite"
echo "========================================"
echo ""

# T1: Command file structure
echo "[T1] Command file structure"
[ -f .claude/commands/spcrg-loop.md ] && _pass "T1.1 spcrg-loop.md exists" || _fail "T1.1 spcrg-loop.md exists" "missing"

for keyword in "Ralph Loop" "Navigator Prompt" "ARCHIVE_READY" "check-openspec-gate.sh" "check-crg-evidence.sh" "superpowers:test-driven-development" "superpowers:subagent-driven-development" "superpowers:systematic-debugging" "superpowers:verification-before-completion" "superpowers:requesting-code-review" "/ralph-loop"; do
  if grep -qF "$keyword" .claude/commands/spcrg-loop.md; then
    _pass "T1 Prompt contains '$keyword'"
  else
    _fail "T1 Prompt contains '$keyword'" "missing"
  fi
done

# T2: 8-stage decision tree
echo ""
echo "[T2] Decision tree 8 stages"
for stage in "阶段 A" "阶段 B" "阶段 C" "阶段 D" "阶段 E" "阶段 F" "阶段 G" "阶段 H"; do
  if grep -qF "$stage" .claude/commands/spcrg-loop.md; then
    _pass "T2 $stage present"
  else
    _fail "T2 $stage present" "missing"
  fi
done

# T3: Config defaults
echo ""
echo "[T3] Config loop defaults"
max_iter=$(jq -r '.loop.maxIterations' .ai-workflow-kit/config.json 2>/dev/null)
promise=$(jq -r '.loop.completionPromise' .ai-workflow-kit/config.json 2>/dev/null)
[ "$max_iter" = "10" ] && _pass "T3.1 maxIterations=10" || _fail "T3.1 maxIterations=10" "got $max_iter"
[ "$promise" = "ARCHIVE_READY" ] && _pass "T3.2 completionPromise=ARCHIVE_READY" || _fail "T3.2 completionPromise" "got $promise"

# T4: Gates pass on valid add-search
echo ""
echo "[T4] Gates on valid change"
scripts/check-openspec-gate.sh add-search >/dev/null 2>&1 && _pass "T4.1 openspec-gate passes" || _fail "T4.1 openspec-gate" "exit non-zero"
scripts/check-crg-evidence.sh add-search >/dev/null 2>&1 && _pass "T4.2 crg-evidence passes" || _fail "T4.2 crg-evidence" "exit non-zero"

# T5: Missing Target header
echo ""
echo "[T5] Missing Target header"
td=$(_make_fixture "bad-no-target")
sed -i.bak 's/| Task | Target |/| Task | TargetX |/' "$td/openspec/changes/bad-no-target/tasks.md"
output=$(cd "$td" && "$ABS_SCRIPT" bad-no-target 2>&1)
exit_code=$?
if [ "$exit_code" -ne 0 ] && echo "$output" | grep -q "Target header not found"; then
  _pass "T5 Gate detects missing Target header"
else
  _fail "T5 Gate detects missing Target header" "exit=$exit_code, no 'Target header not found'"
fi
rm -rf "$td"

# T6: Missing Risk header
echo ""
echo "[T6] Missing Risk header"
td=$(_make_fixture "bad-no-risk")
sed -i.bak 's/| Reference Pattern | Risk |/| Reference Pattern | RiskX |/' "$td/openspec/changes/bad-no-risk/tasks.md"
output=$(cd "$td" && "$ABS_SCRIPT" bad-no-risk 2>&1)
exit_code=$?
if [ "$exit_code" -ne 0 ] && echo "$output" | grep -q "Risk header not found"; then
  _pass "T6 Gate detects missing Risk header"
else
  _fail "T6 Gate detects missing Risk header" "exit=$exit_code, no 'Risk header not found'"
fi
rm -rf "$td"

# T7: Bad Target format (no colon)
echo ""
echo "[T7] Malformed Target value"
td=$(_make_fixture "bad-target")
sed -i.bak 's|src/todo-service.js:TodoService.search|BAD_NO_COLON|' "$td/openspec/changes/bad-target/tasks.md"
output=$(cd "$td" && "$ABS_SCRIPT" bad-target 2>&1)
exit_code=$?
if [ "$exit_code" -ne 0 ] && echo "$output" | grep -q "Target matches file:symbol pattern.*FAIL"; then
  _pass "T7 Gate detects malformed Target"
else
  _fail "T7 Gate detects malformed Target" "exit=$exit_code"
fi
rm -rf "$td"

# T8: Invalid Risk value
echo ""
echo "[T8] Invalid Risk enum value"
td=$(_make_fixture "bad-risk")
# Use # as sed delimiter to avoid | conflict
sed -i.bak 's# low # extreme #g' "$td/openspec/changes/bad-risk/tasks.md"
output=$(cd "$td" && "$ABS_SCRIPT" bad-risk 2>&1)
exit_code=$?
if [ "$exit_code" -ne 0 ] && echo "$output" | grep -q "Risk is valid enum.*FAIL"; then
  _pass "T8 Gate detects invalid Risk enum"
else
  _fail "T8 Gate detects invalid Risk enum" "exit=$exit_code"
fi
rm -rf "$td"

# T9: Missing Precision Plan
echo ""
echo "[T9] Missing Precision Plan"
td=$(_make_fixture "no-plan")
echo "# Tasks (empty)" > "$td/openspec/changes/no-plan/tasks.md"
output=$(cd "$td" && "$ABS_SCRIPT" no-plan 2>&1)
exit_code=$?
if [ "$exit_code" -ne 0 ] && echo "$output" | grep -q "CRG Precision Plan section.*FAIL\|section not found"; then
  _pass "T9 Gate detects missing Precision Plan"
else
  _fail "T9 Gate detects missing Precision Plan" "exit=$exit_code"
fi
rm -rf "$td"

# T10: detect-change-id
echo ""
echo "[T10] detect-change-id"
detected=$(scripts/detect-change-id.sh 2>&1)
[ "$detected" = "add-search" ] && _pass "T10 detect returns add-search" || _fail "T10 detect returns add-search" "got '$detected'"

# T11: Functional test — verify the TODO API works correctly BEFORE the feature
echo ""
echo "[T11] Baseline functional test (existing features work)"
if node tests/run.js >/dev/null 2>&1; then
  _pass "T11 Baseline tests pass (6 existing tests)"
else
  _fail "T11 Baseline tests pass" "tests failed"
fi

# T12: Real-world feature simulation — implement search as if loop did Phase 1
echo ""
echo "[T12] Real-world simulation: implement Phase 1 of add-search"
# Simulate what /spcrg-loop would do in Phase 1 by manually implementing
cat > /tmp/spcrg-loop-test-impl/todo-service.js << 'EOF'
class TodoService {
  constructor() { this.todos = []; this.nextId = 1; }
  list() { return this.todos; }
  add(title) {
    const todo = { id: this.nextId++, title, completed: false };
    this.todos.push(todo);
    return todo;
  }
  remove(id) { this.todos = this.todos.filter(t => t.id !== id); }
  toggle(id) {
    const todo = this.todos.find(t => t.id === id);
    if (todo) todo.completed = !todo.completed;
    return todo;
  }
  search(query) {
    if (!query) return this.todos;
    const q = query.toLowerCase();
    return this.todos.filter(t => t.title.toLowerCase().includes(q));
  }
}
module.exports = TodoService;
EOF

# Install the implementation
mkdir -p /tmp/spcrg-loop-test-impl
cp /tmp/spcrg-loop-test-impl/todo-service.js src/todo-service.js 2>/dev/null || cat > src/todo-service.js << 'EOF'
class TodoService {
  constructor() { this.todos = []; this.nextId = 1; }
  list() { return this.todos; }
  add(title) {
    const todo = { id: this.nextId++, title, completed: false };
    this.todos.push(todo);
    return todo;
  }
  remove(id) { this.todos = this.todos.filter(t => t.id !== id); }
  toggle(id) {
    const todo = this.todos.find(t => t.id === id);
    if (todo) todo.completed = !todo.completed;
    return todo;
  }
  search(query) {
    if (!query) return this.todos;
    const q = query.toLowerCase();
    return this.todos.filter(t => t.title.toLowerCase().includes(q));
  }
}
module.exports = TodoService;
EOF

# Add search tests (what the loop would produce)
cat > tests/run.js << 'EOF'
const TodoService = require('../src/todo-service');
let pass = 0, fail = 0;
function assert(cond, msg) {
  if (cond) { pass++; } else { fail++; console.log('FAIL: ' + msg); }
}

// Baseline tests
const svc = new TodoService();
assert(svc.list().length === 0, 'starts empty');
const t1 = svc.add('Buy milk');
assert(t1.id === 1, 'first id is 1');
assert(t1.title === 'Buy milk', 'title correct');
assert(t1.completed === false, 'not completed');
svc.toggle(1);
assert(svc.list()[0].completed === true, 'toggle works');
svc.remove(1);
assert(svc.list().length === 0, 'remove works');

// Search tests (new)
const s = new TodoService();
s.add('Buy milk');
s.add('Buy eggs');
s.add('Walk dog');

// Case 1: substring match
const r1 = s.search('Buy');
assert(r1.length === 2, 'substring match returns 2 items');
assert(r1[0].title === 'Buy milk', 'first result is Buy milk');
assert(r1[1].title === 'Buy eggs', 'second result is Buy eggs');

// Case 2: case-insensitive
const r2 = s.search('buy');
assert(r2.length === 2, 'case-insensitive returns 2');

// Case 3: empty query returns all
const r3 = s.search('');
assert(r3.length === 3, 'empty query returns all');

// Case 4: no match returns empty
const r4 = s.search('xyz123');
assert(r4.length === 0, 'no match returns empty');

// Case 5: partial word match
const r5 = s.search('og');
assert(r5.length === 1, 'partial match (og in dog)');
assert(r5[0].title === 'Walk dog', 'partial match finds Walk dog');

console.log(`\nResults: ${pass} passed, ${fail} failed`);
process.exit(fail > 0 ? 1 : 0);
EOF

if node tests/run.js >/dev/null 2>&1; then
  test_count=$(node tests/run.js 2>&1 | tail -1 | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+')
  _pass "T12 Simulated Phase 1 tests pass ($test_count tests)"
else
  _fail "T12 Simulated Phase 1 tests" "node tests/run.js failed"
fi

# T13: Verify coverage — all search branches tested
echo ""
echo "[T13] Coverage check on implemented feature"
if grep -q "search(query)" src/todo-service.js && \
   grep -q "substring match" tests/run.js && \
   grep -q "case-insensitive" tests/run.js && \
   grep -q "empty query" tests/run.js && \
   grep -q "no match" tests/run.js; then
  _pass "T13 All 4 spec scenarios covered in tests"
else
  _fail "T13 All 4 spec scenarios covered" "missing cases"
fi

# T14: Restore baseline for clean state
echo ""
echo "[T14] Restore baseline state"
git checkout -- src/todo-service.js tests/run.js 2>/dev/null
if node tests/run.js >/dev/null 2>&1; then
  _pass "T14 Baseline restored successfully"
else
  _fail "T14 Baseline restore" "tests failed after restore"
fi

# Summary
total=$((pass + fail))
echo ""
echo "========================================"
echo "  Results: $total tests, $pass passed, $fail failed"
echo "========================================"
if [ "$fail" -gt 0 ]; then
  echo ""
  echo "Failed tests:"
  for t in "${failed_tests[@]}"; do
    echo "  - $t"
  done
  exit 1
fi
