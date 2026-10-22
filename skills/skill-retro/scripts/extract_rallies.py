#!/usr/bin/env python3
"""Claude Code の会話履歴（~/.claude/projects/*/*.jsonl）から、起点スキル以降のユーザーとのラリーを時系列で抽出する。

使い方:
  extract_rallies.py                                  # いまのセッション（CLAUDE_CODE_SESSION_ID）・起点は nonstop
  extract_rallies.py --branch fix/123-a --branch fix/123-b   # ブランチに乗った全セッション
  extract_rallies.py --pr 18672 --since-skill implement
  extract_rallies.py --session 316d306c-... --since-skill ''   # 起点なし（全件）
  extract_rallies.py --dump ~/.claude/projects/xxx/yyy.jsonl:120-180   # 指定範囲のツール呼び出しを確認
"""

import argparse
import collections
import glob
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone

JST = timezone(timedelta(hours=9))
SYSTEM_REMINDER = re.compile(r'<system-reminder>.*?</system-reminder>', re.S)
COMMAND_NAME = re.compile(r'<command-name>(.*?)</command-name>', re.S)
COMMAND_ARGS = re.compile(r'<command-args>(.*?)</command-args>', re.S)
BASH_INPUT = re.compile(r'<bash-input>(.*?)</bash-input>', re.S)
USER_SAID = re.compile(r'the user said:\s*(.*)', re.S)
REJECTED = "The user doesn't want to proceed with this tool use"
COMPACTION_PREFIX = 'This session is being continued from a previous conversation'
SKIP_PREFIXES = ('<task-notification>', '<local-command-stdout>', '<local-command-caveat>', 'Caveat:')
EDIT_TOOLS = {'Edit', 'Write', 'MultiEdit', 'NotebookEdit'}
SHARED_BRANCHES = {'develop', 'main', 'master', 'HEAD'}
HOME = os.path.expanduser('~')


def short_path(path):
    return path.replace(HOME, '~', 1) if path.startswith(HOME) else path


def jst(ts):
    if not ts:
        return '?'
    return datetime.fromisoformat(ts.replace('Z', '+00:00')).astimezone(JST).strftime('%Y-%m-%d %H:%M')


def quote(text):
    return '\n'.join(f'> {line}' if line else '>' for line in text.splitlines())


def clip_head(text, limit):
    return text if len(text) <= limit else text[:limit] + ' …（以下略）'


def clip_tail(text, limit):
    return text if len(text) <= limit else '（前略）… ' + text[-limit:]


def current_branch():
    result = subprocess.run(['git', 'rev-parse', '--abbrev-ref', 'HEAD'], capture_output=True, text=True)
    return result.stdout.strip() or None


def find_session_files(projects_dir, branches, session_ids, pr):
    needles = [f'"gitBranch":"{b}"'.encode() for b in branches]
    needles += [f'"sessionId":"{s}"'.encode() for s in session_ids]
    if pr:
        needles.append(f'"prNumber":{pr},'.encode())
    matched = []
    for path in glob.glob(os.path.join(projects_dir, '*', '*.jsonl')):
        with open(path, 'rb') as f:
            data = f.read()
        if any(n in data for n in needles):
            matched.append(path)
    return matched


def load_records(path):
    records = []
    with open(path, encoding='utf-8', errors='replace') as f:
        for lineno, line in enumerate(f, 1):
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue
            if record.get('isSidechain'):
                continue
            record['_line'] = lineno
            records.append(record)
    return records


def tool_result_text(block):
    content = block.get('content')
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return '\n'.join(b.get('text', '') for b in content if isinstance(b, dict))
    return ''


def classify_user_record(record):
    """ユーザー起点のイベントなら (種別, 本文) を返す。ツール結果・自動挿入メッセージは None。"""
    if record.get('type') != 'user' or record.get('isMeta'):
        return None
    content = record.get('message', {}).get('content')
    if isinstance(content, list):
        results = [b for b in content if isinstance(b, dict) and b.get('type') == 'tool_result']
        if results:
            rejected = [
                tool_result_text(b) for b in results
                if b.get('is_error') and tool_result_text(b).startswith(REJECTED)
            ]
            if not rejected:
                return None
            said = USER_SAID.search(rejected[0])
            return ('ツール拒否', said.group(1).strip() if said else '')
        raw = '\n'.join(b.get('text', '') for b in content if isinstance(b, dict) and b.get('type') == 'text')
    else:
        raw = content or ''
    text = SYSTEM_REMINDER.sub('', raw).strip()
    if not text or text.startswith(SKIP_PREFIXES):
        return None
    if text.startswith(COMPACTION_PREFIX):
        return ('compaction', '')
    if text.startswith('[Request interrupted'):
        return ('中断', '')
    command = COMMAND_NAME.search(text)
    if command:
        args = COMMAND_ARGS.search(text)
        return ('コマンド', f"{command.group(1).strip()} {args.group(1).strip() if args else ''}".strip())
    bash = BASH_INPUT.search(text)
    if bash:
        return ('シェル', bash.group(1).strip())
    return ('発話', text)


def skill_invoked(record, skill):
    """この記録が skill の起動（Skill ツール or スラッシュコマンド）なら True。"""
    if record.get('type') == 'assistant':
        return any(
            b.get('type') == 'tool_use' and b.get('name') == 'Skill' and b.get('input', {}).get('skill') == skill
            for b in record.get('message', {}).get('content', [])
        )
    event = classify_user_record(record)
    return bool(event and event[0] == 'コマンド' and event[1].split()[0] == f'/{skill}')


def extract_events(path):
    records = load_records(path)
    events = []
    last_text = ''
    current = None
    for record in records:
        if record.get('type') == 'assistant':
            for block in record.get('message', {}).get('content', []):
                if block.get('type') == 'text' and block.get('text', '').strip():
                    last_text = block['text']
                elif block.get('type') == 'tool_use' and current is not None:
                    name = block.get('name', '?')
                    tool_input = block.get('input', {})
                    current['tools'][name] += 1
                    if name == 'Skill':
                        current['skills'].append(tool_input.get('skill', '?'))
                    if name in EDIT_TOOLS and tool_input.get('file_path'):
                        current['edits'].setdefault(short_path(tool_input['file_path']), None)
            continue
        event = classify_user_record(record)
        if not event:
            continue
        kind, text = event
        if kind == '発話' and last_text.startswith('API Error'):
            kind = 'APIエラー後の再開'
        current = {
            'uuid': record.get('uuid'),
            'kind': kind,
            'text': text,
            'ts': record.get('timestamp'),
            'branch': record.get('gitBranch'),
            'session': record.get('sessionId', '')[:8],
            'ref': f'{short_path(path)}:{record["_line"]}',
            'before': last_text,
            'tools': collections.Counter(),
            'skills': [],
            'edits': {},
        }
        events.append(current)
    return records, events


def find_invocation(sessions, skill, after=''):
    """after より後で最初に skill が起動された (timestamp, 参照) を返す。"""
    found = []
    for path, records in sessions:
        for record in records:
            if (record.get('timestamp') or '') > after and skill_invoked(record, skill):
                found.append((record['timestamp'], f'{short_path(path)}:{record["_line"]}'))
                break
    return min(found) if found else None


def render_session_list(sessions):
    lines = []
    for path, records in sessions:
        stamps = [r['timestamp'] for r in records if r.get('timestamp')]
        branches = sorted({r['gitBranch'] for r in records if r.get('gitBranch')})
        session_id = next((r['sessionId'] for r in records if r.get('sessionId')), '?')
        span = f'{jst(min(stamps))} 〜 {jst(max(stamps))}' if stamps else '?'
        lines.append(f'  - `{session_id}` {span} ブランチ: {", ".join(branches)}  \n    `{short_path(path)}`')
    return lines


def render_event(number, event, context_chars):
    lines = [f'## R-{number} [{event["kind"]}] {jst(event["ts"])}  branch={event["branch"]}  (`{event["ref"]}`)', '']
    if event['before']:
        lines += ['**直前のClaude（末尾）**', '', quote(clip_tail(event['before'].strip(), context_chars)), '']
    lines += ['**ユーザー**', '', quote(clip_head(event['text'], 2000)) if event['text'] else '>（本文なし）', '']
    response = []
    if event['skills']:
        response.append('スキル: ' + ', '.join(event['skills']))
    if event['edits']:
        response.append('変更: ' + ', '.join(f'`{p}`' for p in event['edits']))
    if event['tools']:
        response.append('ツール: ' + ', '.join(f'{name}×{count}' for name, count in event['tools'].most_common()))
    lines += ['**その後の対応:** ' + (' / '.join(response) if response else 'なし'), '']
    return lines


def dump_range(spec):
    path, _, span = spec.rpartition(':')
    start, _, end = span.partition('-')
    start, end = int(start), int(end or start)
    for record in load_records(os.path.expanduser(path)):
        if not start <= record['_line'] <= end:
            continue
        head = f'{record["_line"]:>6} {jst(record.get("timestamp"))} {record.get("type")}'
        if record.get('type') == 'assistant':
            for block in record.get('message', {}).get('content', []):
                if block.get('type') == 'text':
                    print(f'{head} text: {clip_head(block["text"].strip(), 300)}')
                elif block.get('type') == 'tool_use':
                    detail = json.dumps(block.get('input', {}), ensure_ascii=False)
                    print(f'{head} {block.get("name")}: {clip_head(detail, 300)}')
        elif record.get('type') == 'user':
            event = classify_user_record(record)
            if event:
                print(f'{head} [{event[0]}] {clip_head(event[1], 300)}')
            else:
                content = record.get('message', {}).get('content')
                if isinstance(content, list):
                    for block in content:
                        if isinstance(block, dict) and block.get('type') == 'tool_result':
                            print(f'{head} tool_result: {clip_head(tool_result_text(block).strip(), 200)}')


def main():
    parser = argparse.ArgumentParser(description='会話履歴からユーザーとのラリーを抽出する')
    parser.add_argument('--branch', action='append', default=[], help='対象ブランチ（複数指定可）。そのブランチに一度でも乗った全セッションが対象')
    parser.add_argument('--session', action='append', default=[], help='対象セッションID（複数指定可）。条件をすべて省略すると、いまのセッション')
    parser.add_argument('--pr', type=int, help='対象PR番号（会話中で作成・紐付けされたPR）')
    parser.add_argument('--since-skill', default='nonstop', help="起点スキル。この起動より後のイベントだけ出す。'' で全件")
    parser.add_argument('--until-skill', default='skill-retro', help="このスキルの起動以降は出さない（振り返り中の会話を除くため）")
    parser.add_argument('--projects-dir', default=os.path.join(HOME, '.claude', 'projects'))
    parser.add_argument('--context-chars', type=int, default=800, help='直前のClaude応答を末尾から何文字出すか')
    parser.add_argument('--dump', help='PATH:START-END の範囲の記録（ツール呼び出し含む）を出力して終了する')
    args = parser.parse_args()

    if args.dump:
        dump_range(args.dump)
        return

    branches = args.branch
    session_ids = args.session
    if not (branches or session_ids or args.pr):
        current_session = os.environ.get('CLAUDE_CODE_SESSION_ID')
        if current_session:
            session_ids = [current_session]
        else:
            branch = current_branch()
            if not branch:
                sys.exit('対象を決められません。--branch / --session / --pr を指定してください')
            branches = [branch]

    paths = find_session_files(args.projects_dir, branches, session_ids, args.pr)
    if not paths:
        sys.exit(f'該当するセッションが見つかりません: branch={branches} session={session_ids} pr={args.pr}')

    sessions = []
    events = []
    for path in paths:
        records, session_events = extract_events(path)
        sessions.append((path, records))
        events += session_events
    sessions.sort(key=lambda s: min((r['timestamp'] for r in s[1] if r.get('timestamp')), default=''))

    touched = sorted({r['gitBranch'] for _, records in sessions for r in records if r.get('gitBranch')} - SHARED_BRANCHES)
    others = sorted(set(find_session_files(args.projects_dir, touched, [], None)) - set(paths)) if touched else []
    events.sort(key=lambda e: e['ts'] or '')
    seen = set()
    events = [e for e in events if not (e['uuid'] in seen or seen.add(e['uuid']))]

    origin = find_invocation(sessions, args.since_skill) if args.since_skill else None
    if origin:
        events = [e for e in events if (e['ts'] or '') > origin[0]]
    until = find_invocation(sessions, args.until_skill, origin[0] if origin else '') if args.until_skill else None
    if until:
        events = [e for e in events if (e['ts'] or '') < until[0]]

    rallies = [e for e in events if e['kind'] != 'compaction']
    counts = collections.Counter(e['kind'] for e in rallies)

    out = ['# ラリー抽出', '']
    out.append(f'- 条件: branch={branches} session={session_ids} pr={args.pr}')
    out.append('- セッション:')
    out += render_session_list(sessions)
    if others:
        out.append(f'- 同じブランチに乗った別セッション: {len(others)} 件（含めるなら ' + ' '.join(f'--branch {b}' for b in touched) + '）')
        out += render_session_list([(path, load_records(path)) for path in others])
    if origin:
        out.append(f'- 起点: `/{args.since_skill}` {jst(origin[0])}（`{origin[1]}`）')
    elif args.since_skill:
        out.append(f'- 起点: `{args.since_skill}` の起動が見つからないため、全イベントを出力')
    else:
        out.append('- 起点: 指定なし（全イベント）')
    if until:
        out.append(f'- 終点: `/{args.until_skill}` {jst(until[0])} より前まで')
    out.append(f'- ユーザーイベント: {len(rallies)} 件（' + ' / '.join(f'{k} {v}' for k, v in counts.most_common()) + '）')
    out.append('')

    number = 0
    for event in events:
        if event['kind'] == 'compaction':
            out += [f'--- compaction（会話の要約） {jst(event["ts"])} `{event["ref"]}` ---', '']
            continue
        number += 1
        out += render_event(number, event, args.context_chars)

    print('\n'.join(out))


if __name__ == '__main__':
    main()
