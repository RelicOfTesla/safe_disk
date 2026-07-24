#!/usr/bin/env python3
"""审计 Dart 代码中静默吞掉异常的 catch 块。

用法:
  python3 scripts/audit_silent_catch.py                 # 审计 lib/
  python3 scripts/audit_silent_catch.py --all           # 所有 .dart
  python3 scripts/audit_silent_catch.py --json          # JSON 输出
  python3 scripts/audit_silent_catch.py --severity high # 仅高严重度
"""

import argparse
import json
import re
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent

# === 放行模式: 匹配即视为有意义的异常处理 ===
SAFE_PATTERNS = [
    r'\brethrow\b',
    r'\bthrow\b',
    r'\bdebugPrint\b',
    r'\bprint\(',
    r'\.log\(',
    r'\.error\(',
    r'\.warning\(',
    r'\.severe\(',
    r'\.shout\(',
    r'_completer\.completeError\b',
    r'\.completeError\b',
    r'Isolate\.exit\b',
    r'FlutterError\.reportError\b',
    r'\.writeln\(',          # stderr.writeln / sink.writeln
    r'\bMessageManager\.(?:show|post|error|warning)',
    r'\bshowError\b',
    r'\bshowToast\b',
    r'\bshowSnackBar\b',
    r'\bshowDialog\b',
    r'\bemitError\b',
    r'\baddError\b',
    r'\bnotifyError\b',
    r'\bException\b',
    r'\bStackTrace\b',
    r'\bexit\(',             # 测试 exit(1)
]

# === 半放行: 有错误状态变量赋值/收集，暂降为中严重度 ===
PARTIAL_PATTERNS = [
    r'callbackError\s*=\s*error',
    r'_nativeError\s*=\s*error',
    r'_TechnicalError\s*=',
    r'TechnicalError\s*=',
    r'SecureNotepad\w*Error\s*=',
    r'AntiScreenshotApplyResult\b',
    r'DirectoryTransferResult\b',
    r'BatchOperationFailure\b',
    r'\.add\(.*error',
    r'\.add\(.*fail',
    r'failedCount\+\+',
    r'failCount\+\+',
    r'processedCount\+\+',
    r'Keep the worker callback alive',
    r'await _cancelRootLockPreparation',
    r'return _cancelLockPreparation\b',
    r'if \(mounted\) setState',
]

# === 可接受的忽略注释 ===
# 注意：使用 .* 宽松匹配，因为注释开头可能包含额外上下文
IGNORE_COMMENTS = [
    # 明确的忽略意图
    r'intentionally|故意|expected|预期|ok\b|safe\b|ignored?|忽略|skip|跳过',
    # 非关键 / best-effort
    r'may\s*fail|可能失败|not\s*available|不可用|not\s*implemented|未实现|best.effort|非关键|non.critical',
    # 清理 / 取消
    r'cleanup|清理|cancel|取消|already|已经',
    # 不允许阻止
    r'must\s*not\s*prevent|不.*阻止|不.*妨碍',
    # 目录已不存在 / 配置无效
    r'no\s*longer\s*exists|config\s*is\s*invalid|invalid\s*config',
    # 无法清除 / VM 托管
    r'cannot\s*be\s*cleared|无法清除|can\'?t\s+be|VM.managed',
    # 尝试下一个 / 非有效编码
    r'Try\s+(?:the\s+)?next|尝试下|not\s+valid\s+(?:for|UTF)',
    r'Not\s+valid\s+UTF|无效\s*UTF',
    # 平台/进程生命周期
    r'platform\s+(?:can|may|will|has)\s+disappear|shut\w*\s*down|disappear',
    r'Go\s+remains\s+authoritative|switch\s+remains\s+disabled',
    r'child\s+cannot\s+retain|root\s+capability',
    # 通用: 有解释性长注释 (>= 40 个有效字符), 非 TODO/HACK/FIXME
    r'//.{40,}',
]


# 视为非解释性注释 (不应被放行)
NON_EXPLANATORY = [
    r'^\s*//\s*(?:TODO|HACK|FIXME|XXX|BUG)\b',
    r'^\s*//\s*$',   # 空注释行
    r'^\s*//\s*[a-z]{1,3}$',  # 超短注释
]

def find_dart_files(dirs: list[str]) -> list[Path]:
    out = []
    for d in dirs:
        target = PROJECT_ROOT / d
        if target.is_dir():
            for p in target.rglob('*.dart'):
                if p.is_file():
                    out.append(p)
    return sorted(out)


def extract_catch_body(lines: list[str], start: int) -> tuple[list[str], int]:
    """从 catch 起始行提取 body。返回 (body_lines, next_line_index)。"""
    # 找到 {
    line = lines[start]
    brace = line.find('{')
    if brace == -1:
        # { 在下一行
        i = start + 1
        while i < len(lines) and '{' not in lines[i]:
            i += 1
        if i >= len(lines):
            return [], start + 1
        start = i
        brace = lines[i].find('{')

    after = lines[start][brace + 1:]

    # 单行: catch (_) { body }
    if '}' in after:
        idx = after.index('}')
        body_text = after[:idx].strip()
        return [body_text], start + 1

    body = []
    rest = after.strip()
    if rest:
        body.append(rest)

    depth = 1
    i = start + 1
    while i < len(lines) and depth > 0:
        for ch in lines[i]:
            if ch == '{':
                depth += 1
            elif ch == '}':
                depth -= 1
        if depth > 0:
            body.append(lines[i])
        i += 1
    return body, i


def is_empty_code(body: list[str]) -> bool:
    code = [l.strip() for l in body if l.strip() and not l.strip().startswith('//')]
    return len(code) == 0


def has_ignore_comment(body: list[str]) -> bool:
    """检查 body 中是否有含可接受忽略关键词的注释。"""
    comments = [l.strip() for l in body if l.strip().startswith('//')]
    for c in comments:
        # 先排除非解释性注释
        if matches_any(c, NON_EXPLANATORY):
            continue
        for p in IGNORE_COMMENTS:
            if re.search(p, c, re.IGNORECASE):
                return True
    return False


def matches_any(text: str, patterns: list[str]) -> bool:
    for p in patterns:
        if re.search(p, text):
            return True
    return False


def classify(body: list[str]) -> tuple[str | None, str]:
    """返回 (severity, reason)。severity=None 表示放行。"""
    text = '\n'.join(body)
    code_lines = [l.strip() for l in body if l.strip() and not l.strip().startswith('//')]

    # 1. 有明确日志/传播 → 放行
    if matches_any(text, SAFE_PATTERNS):
        return None, ''

    # 2. 空体
    if not code_lines:
        if has_ignore_comment(body):
            return 'low', '空体但有明确忽略注释'
        return 'high', '空 catch 体，异常被静默吞掉'

    # 3. 有代码但无安全模式
    code_text = '\n'.join(code_lines)

    # 3a. 半放行: 有状态记录但非显式日志
    if matches_any(text, PARTIAL_PATTERNS):
        return 'medium', f'有状态记录/收集但无直接日志: {code_text[:80]}'

    # 3b. 仅 return 默认值
    only_return = all(
        re.match(r'^(return|await\s+return)\b', l) for l in code_lines
    )
    if only_return:
        return 'medium', f'仅返回默认值未记录异常: {code_text[:80]}'

    # 3c. 其他
    return 'medium', f'有代码但无日志/传播: {code_text[:80]}'


def audit(files: list[Path]) -> list[dict]:
    findings = []
    for fp in files:
        raw = fp.read_text(encoding='utf-8')
        lines = raw.split('\n')
        rel = str(fp.relative_to(PROJECT_ROOT))
        i = 0
        while i < len(lines):
            m = re.match(
                r'^(\s*)\}\s*(?:on\s+\S+\s+)?catch\s*\(([^)]*)\)',
                lines[i],
            )
            if m:
                cv = m.group(2).strip() if m.group(2) else '_'
                body, nxt = extract_catch_body(lines, i)
                sev, reason = classify(body)
                if sev:
                    findings.append({
                        'file': rel,
                        'line': i + 1,
                        'catch_var': cv,
                        'severity': sev,
                        'reason': reason,
                        'body_preview': '\n'.join(body[:3]).strip()[:120],
                    })
                i = nxt
            else:
                i += 1
    return findings


def print_report(findings: list[dict]) -> None:
    if not findings:
        print('未发现静默 catch 块。')
        return

    hh = [f for f in findings if f['severity'] == 'high']
    mm = [f for f in findings if f['severity'] == 'medium']
    ll = [f for f in findings if f['severity'] == 'low']

    print(f'\n静默 Catch 审计报告')
    print('=' * 60)
    print(f'总计: {len(findings)}  |  HIGH={len(hh)}  MED={len(mm)}  LOW={len(ll)}')

    by_file: dict[str, list[dict]] = {}
    for f in findings:
        by_file.setdefault(f['file'], []).append(f)

    print('\n--- 按文件 ---')
    for name in sorted(by_file):
        items = by_file[name]
        h = sum(1 for x in items if x['severity'] == 'high')
        m = sum(1 for x in items if x['severity'] == 'medium')
        l = sum(1 for x in items if x['severity'] == 'low')
        tags = '/'.join(
            t for t in [
                f'HIGH={h}' if h else '',
                f'MED={m}' if m else '',
                f'LOW={l}' if l else '',
            ] if t
        )
        print(f'  [{name}] ({tags})')

    if hh:
        print('\n--- HIGH: 空 catch 体 ---')
        for f in hh:
            print(f'  {f["file"]}:{f["line"]}  catch({f["catch_var"]})')

    if mm:
        print('\n--- MEDIUM: 有代码但无直接日志/传播 ---')
        for f in mm:
            print(f'  {f["file"]}:{f["line"]}  catch({f["catch_var"]})')
            print(f'    {f["reason"]}')

    if ll:
        print('\n--- LOW: 有注释说明 ---')
        for f in ll:
            print(f'  {f["file"]}:{f["line"]}  catch({f["catch_var"]})  {f["reason"]}')


def main() -> None:
    ap = argparse.ArgumentParser(description='审计 Dart catch 块沉默吞异常')
    ap.add_argument('--dir', nargs='+', default=['lib'],
                    help='审计目录 (default: lib)')
    ap.add_argument('--all', action='store_true',
                    help='审计所有 .dart 文件')
    ap.add_argument('--json', action='store_true', help='JSON 输出')
    ap.add_argument('--severity', choices=['high', 'medium', 'low', 'all'],
                    default='all')
    args = ap.parse_args()

    dirs = ['.'] if args.all else args.dir
    files = find_dart_files(dirs)
    results = audit(files)

    if args.severity != 'all':
        results = [r for r in results if r['severity'] == args.severity]

    if args.json:
        print(json.dumps(results, ensure_ascii=False, indent=2))
    else:
        print_report(results)

    h = sum(1 for r in results if r['severity'] == 'high')
    sys.exit(1 if h > 0 else 0)


if __name__ == '__main__':
    main()
