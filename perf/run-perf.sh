#!/bin/sh
# Re-run cloudnative-pg perf benchmarks and compare against perf/baseline.json
# regression >10% = warn, >25% = block. Requires a Go toolchain on PATH
# (GOTOOLCHAIN auto-downloads the go.mod toolchain). TMPDIR is kept inside
# the workspace because /tmp may be too small for Go build work.
set -e; cd "$(dirname "$0")/.."
export GOFLAGS=-p=2 GOMAXPROCS=2 CGO_ENABLED=0
export TMPDIR="${TMPDIR:-$PWD/perf/.tmp}"; mkdir -p "$TMPDIR"
OUT=$(mktemp "$TMPDIR/out.XXXXXX"); trap 'rm -f "$OUT"' EXIT
go test -vet=off ./pkg/utils/ -run '^$' -bench 'BenchmarkPerf' -benchtime=10000x -count=1 -benchmem 2>&1 | tee "$OUT"
python3 - "$OUT" <<'PY'
import json, re, sys
cur = {}
for line in open(sys.argv[1]):
    m = re.match(r'(BenchmarkPerf\w+)-\d+\s+10000\s+([\d.]+) ns/op\s+(\d+) B/op\s+(\d+) allocs/op', line)
    if m: cur[m.group(1)] = {"ns_per_op": float(m.group(2)), "bytes_per_op": int(m.group(3)), "allocs_per_op": int(m.group(4)), "unit": "ns/op"}
if not cur: print("VERDICT: block (no benchmark results parsed)"); sys.exit(1)
try: base = json.load(open("perf/baseline.json"))["benches"]
except FileNotFoundError: print("no baseline.json; current:", cur); sys.exit(0)
verdict = "pass"
for name, r in cur.items():
    b = base.get(name, {}).get("ns_per_op")
    if not b: print(f"{name}: no baseline"); continue
    d = (r["ns_per_op"]-b)/b*100; print(f"{name}: {r['ns_per_op']:.1f} ns/op, delta {d:+.2f}% vs baseline")
    if d > 25: verdict = "block"
    elif d > 10 and verdict == "pass": verdict = "warn"
print(f"VERDICT: {verdict}")
PY
