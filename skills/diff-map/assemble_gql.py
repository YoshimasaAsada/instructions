"""フロントの .gql から、指定した GraphQL 操作と、それが使うフラグメントだけを集めた1つのクエリ文書を作る。

実際の画面と同じクエリを rails runner で流すために使う。graphql-ruby は使われていないフラグメントを含む文書を
エラーにするので、操作から辿れるフラグメントだけを集める。

使い方（リポジトリルートで）:
    python3 ~/.claude/skills/diff-map/assemble_gql.py \
        <フロントのアプリのディレクトリ> \
        <Rails アプリのディレクトリ>/tmp \
        OrderDetail_getOrder OrderList_getOrders

出力は <出力先>/diff_map_<操作名>.graphql。Rails をコンテナで動かしている場合、コンテナから見えるのは Rails アプリの配下だけなので、
出力先はその tmp にする。
"""

import pathlib
import re
import sys

DEFINITION = re.compile(r'(?m)^(query|mutation|subscription|fragment)\s+(\w+)')
SPREAD = re.compile(r'\.\.\.\s*(\w+)')


def collect_definitions(app_dir: pathlib.Path) -> dict[str, str]:
    definitions = {}
    for path in app_dir.rglob('*.gql'):
        if 'node_modules' in path.parts:
            continue
        source = re.sub(r'#[^\n]*', '', path.read_text(encoding='utf-8'))
        for match in DEFINITION.finditer(source):
            start = source.index('{', match.end())
            depth = 0
            for end in range(start, len(source)):
                if source[end] == '{':
                    depth += 1
                elif source[end] == '}':
                    depth -= 1
                    if depth == 0:
                        break
            definitions[match.group(2)] = source[match.start():end + 1]
    return definitions


def assemble(definitions: dict[str, str], operation: str) -> str:
    needed: list[str] = []
    stack = [operation]
    while stack:
        name = stack.pop()
        if name in needed:
            continue
        if name not in definitions:
            raise SystemExit(f'定義が見つからない: {name}')
        needed.append(name)
        stack.extend(SPREAD.findall(definitions[name]))
    return '\n\n'.join(definitions[name] for name in needed)


def main() -> None:
    if len(sys.argv) < 4:
        raise SystemExit(__doc__)
    app_dir, out_dir, *operations = sys.argv[1:]
    definitions = collect_definitions(pathlib.Path(app_dir))
    for operation in operations:
        document = assemble(definitions, operation)
        out = pathlib.Path(out_dir) / f'diff_map_{operation}.graphql'
        out.write_text(document, encoding='utf-8')
        fragments = len(re.findall(r'(?m)^fragment', document))
        print(f'{out}: {len(document.splitlines())}行 / フラグメント {fragments}個')


if __name__ == '__main__':
    main()
