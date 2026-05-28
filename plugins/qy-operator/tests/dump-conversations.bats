#!/usr/bin/env bats
# qy-operator plugin smoke tests
#
# 跑法：
#   bats plugins/qy-operator/tests/dump-conversations.bats
#
# 这些是 plugin 层 smoke test。完整集成 + 单元测试在
# miniapp/backend/tests/cli/operator/。

setup() {
    PLUGIN_DIR="$BATS_TEST_DIRNAME/.."
}

# ──────────────────────────────────────────────────────────────
# Group 1: 文件结构 / metadata
# ──────────────────────────────────────────────────────────────

@test "plugin.json exists and is valid JSON with required fields" {
    plugin_json="$PLUGIN_DIR/.claude-plugin/plugin.json"
    [ -f "$plugin_json" ]
    run python3 -c "
import json, sys
d = json.load(open('$plugin_json'))
assert d['name'] == 'qy-operator', f'name={d.get(\"name\")}'
assert 'description' in d and len(d['description']) > 10
assert 'version' in d and d['version'].count('.') == 2
print('ok')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok"* ]]
}

@test "SKILL.md exists with frontmatter name + description containing triggers" {
    skill_md="$PLUGIN_DIR/skills/dump-conversations/SKILL.md"
    [ -f "$skill_md" ]
    head -15 "$skill_md" | grep -q "^name: dump-conversations"
    head -15 "$skill_md" | grep -q "^description:"
    # 触发词必含
    grep -q "qy-dump" "$skill_md"
    grep -q "导出对话" "$skill_md"
}

@test "qy-dump command frontmatter exists and passes ARGUMENTS through" {
    cmd_md="$PLUGIN_DIR/commands/qy-dump.md"
    [ -f "$cmd_md" ]
    head -5 "$cmd_md" | grep -q "^description:"
    grep -q '\$ARGUMENTS' "$cmd_md"
}

@test "usage-examples.md covers 4 high-frequency scenarios" {
    examples="$PLUGIN_DIR/skills/dump-conversations/references/usage-examples.md"
    [ -f "$examples" ]
    grep -q "场景 1" "$examples"
    grep -q "场景 2" "$examples"
    grep -q "场景 3" "$examples"
    grep -q "场景 4" "$examples"
    grep -q "for-content" "$examples"
}

# ──────────────────────────────────────────────────────────────
# Group 2: scripts 合法性 + 行为
# ──────────────────────────────────────────────────────────────

@test "find-backend.sh is a valid bash script" {
    script="$PLUGIN_DIR/scripts/find-backend.sh"
    [ -f "$script" ]
    [ -x "$script" ]
    head -1 "$script" | grep -q "^#!/usr/bin/env bash"
    grep -q "set -euo pipefail" "$script"
    run bash -n "$script"
    [ "$status" -eq 0 ]
}

@test "ensure-pg.sh is a valid bash script" {
    script="$PLUGIN_DIR/scripts/ensure-pg.sh"
    [ -f "$script" ]
    [ -x "$script" ]
    head -1 "$script" | grep -q "^#!/usr/bin/env bash"
    grep -q "set -euo pipefail" "$script"
    run bash -n "$script"
    [ "$status" -eq 0 ]
}

@test "find-backend.sh locates miniapp backend path" {
    run "$PLUGIN_DIR/scripts/find-backend.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == */miniapp/backend ]]
    # 进一步校验：路径下确实有 operator 包
    [ -f "$output/app/cli/operator/dump.py" ]
}

@test "ensure-pg.sh exits 0 when postgres is running" {
    # 假设环境中 postgres 在跑（实际跑测试时确认过 deploy-postgres-1）。
    # 如果不跑，本测试会失败 + 提示用户启 postgres。
    run "$PLUGIN_DIR/scripts/ensure-pg.sh"
    if [ "$status" -ne 0 ]; then
        skip "postgres 未运行 (cd deploy && sudo docker compose up -d postgres 后重试)"
    fi
    [[ "$output" == *"运行中"* ]]
}

# ──────────────────────────────────────────────────────────────
# Group 3: backend 端模块可探测（不真跑 dump）
# ──────────────────────────────────────────────────────────────

@test "backend operator package can be imported" {
    backend=$("$PLUGIN_DIR/scripts/find-backend.sh")
    cd "$backend"
    # 仅探测 import 是否成功，不实际执行 dump 命令（避免 DB 连接副作用）
    run uv run python -c "from app.cli.operator import dump; print('ok:' + dump.__name__)"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok:"* ]]
}

@test "dump --help runs without DB connection" {
    backend=$("$PLUGIN_DIR/scripts/find-backend.sh")
    cd "$backend"
    run uv run python -m app.cli.operator dump --help
    [ "$status" -eq 0 ]
    # spec §6.1 的关键参数必须在 help 里出现
    [[ "$output" == *"--user"* ]]
    [[ "$output" == *"--since"* ]]
    [[ "$output" == *"--for-content"* ]]
    [[ "$output" == *"--dry-run"* ]]
    [[ "$output" == *"--anonymize"* ]]
}
