#!/usr/bin/env bash
# 采集 ConcordRTS 内核基线。可在 macOS / Linux / Windows(Git Bash) 上运行。
# 输出：单文件 JSON，用于跨平台逐字节对照。
#
# 用法：
#   ./capture-core-baseline.sh <build-dir> <output.json>
# 示例：
#   ./capture-core-baseline.sh ../ConcordRTS/build-core-mac \
#       baseline/core-macos-x86_64.json

set -u

BUILD_DIR="${1:-}"
OUT="${2:-}"

if [ -z "${BUILD_DIR}" ] || [ -z "${OUT}" ]; then
    echo "用法: $0 <build-dir> <output.json>" >&2
    exit 2
fi

if [ ! -d "${BUILD_DIR}" ]; then
    echo "构建目录不存在: ${BUILD_DIR}" >&2
    exit 2
fi

BUILD_DIR="$(cd "${BUILD_DIR}" && pwd)"
mkdir -p "$(dirname "${OUT}")"

json_escape() {
    printf '%s' "$1" | tr -d '\r' | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' '
}

# ---- 环境信息 ----
UNAME_S="$(uname -s 2>/dev/null || echo unknown)"
UNAME_M="$(uname -m 2>/dev/null || echo unknown)"
# MinGW/MSYS 下常没有 c++ 这个别名，退回 CXX / g++ / clang++ 逐个探测。
CXX_VERSION=""
for candidate in "${CXX:-}" c++ g++ clang++ cl; do
    [ -n "${candidate}" ] || continue
    command -v "${candidate}" >/dev/null 2>&1 || continue
    CXX_VERSION="$("${candidate}" --version 2>/dev/null | head -1)"
    [ -n "${CXX_VERSION}" ] || CXX_VERSION="$("${candidate}" 2>&1 | head -1)"
    [ -n "${CXX_VERSION}" ] && break
done
[ -n "${CXX_VERSION}" ] || CXX_VERSION="unknown"
CMAKE_VERSION="$(cmake --version 2>/dev/null | head -1 || echo unknown)"
GIT_COMMIT="$(git -C "${BUILD_DIR}/.." rev-parse --short HEAD 2>/dev/null || echo unknown)"
GIT_DIRTY=""
if ! git -C "${BUILD_DIR}/.." diff --quiet 2>/dev/null; then
    GIT_DIRTY=" (dirty)"
fi

# ---- 测试结果 ----
CTEST_LOG="$(mktemp)"
( cd "${BUILD_DIR}" && ctest --output-on-failure ) > "${CTEST_LOG}" 2>&1
CTEST_STATUS=$?
# 注意：不要用 grep -c，某些环境（含 WorkBuddy 的 brokered grep）会返回多行；
# 统一用 wc -l 保证输出是单个整数。
TEST_COUNT="$(grep -E '^[[:space:]]*[0-9]+/[0-9]+ Test' "${CTEST_LOG}" | wc -l | tr -d ' ')"
TEST_PASSED="$(grep -E 'Passed' "${CTEST_LOG}" | wc -l | tr -d ' ')"
TEST_FAILED="$(grep -E '\*\*\*Failed|\*\*\*Exception' "${CTEST_LOG}" | wc -l | tr -d ' ')"
SUMMARY="$(grep -E 'tests passed out of|tests failed out of' "${CTEST_LOG}" | tail -1)"

# ---- smoke 输出与哈希 ----
# 这些可执行文件会打印权威哈希；哈希值就是跨平台对照金标准。
SMOKES="
concord_game_world_deterministic_hash_smoke
concord_production_core_hash_smoke
concord_runtime_atomic_file_smoke
concord_lan_transport_smoke
concord_secure_bytes_contract
concord_multiplayer_lockstep_smoke
concord_multiplayer_snapshot_transfer_smoke
concord_multiplayer_compatibility_fingerprint_smoke
"

SMOKE_JSON=""
for s in ${SMOKES}; do
    exe="${BUILD_DIR}/${s}"
    [ -f "${exe}" ] || exe="${BUILD_DIR}/${s}.exe"
    if [ ! -f "${exe}" ]; then
        SMOKE_JSON="${SMOKE_JSON}{\"name\":\"${s}\",\"exit\":\"missing\",\"hash\":\"\",\"tail\":\"\"},"
        continue
    fi
    log="$(mktemp)"
    "${exe}" > "${log}" 2>&1
    code=$?
    hash="$(grep -oE 'hash=[0-9]+' "${log}" | head -1 | cut -d= -f2)"
    tail_line="$(tail -1 "${log}" | tr -d '\r')"
    SMOKE_JSON="${SMOKE_JSON}{\"name\":\"${s}\",\"exit\":${code},\"hash\":\"${hash}\",\"tail\":\"$(json_escape "${tail_line}")\"},"
    rm -f "${log}"
done
SMOKE_JSON="${SMOKE_JSON%,}"

cat > "${OUT}" <<EOF
{
  "schema": 1,
  "captured_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "os": "${UNAME_S}",
  "arch": "${UNAME_M}",
  "compiler": "$(json_escape "${CXX_VERSION}")",
  "cmake": "$(json_escape "${CMAKE_VERSION}")",
  "git_commit": "${GIT_COMMIT}${GIT_DIRTY}",
  "build_dir": "$(json_escape "${BUILD_DIR}")",
  "ctest": {
    "status": ${CTEST_STATUS},
    "registered": ${TEST_COUNT},
    "passed": ${TEST_PASSED},
    "failed": ${TEST_FAILED},
    "summary": "$(json_escape "${SUMMARY}")"
  },
  "smokes": [${SMOKE_JSON}]
}
EOF

rm -f "${CTEST_LOG}"
echo "基线已写入: ${OUT}"
echo "  OS=${UNAME_S}/${UNAME_M}  ctest=${SUMMARY}"
echo "  哈希: $(printf '%s' "${SMOKE_JSON}" | grep -oE '"hash":"[0-9]+"' | head -2 | tr '\n' ' ')"
