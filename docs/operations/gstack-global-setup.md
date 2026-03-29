# gstack 전역 설치 및 운영 가이드

## 목적
이 문서는 `gstack`을 저장소별로 다시 설치하지 않고, 사용자 전역 기준으로 한 번만 설치해 Claude와 Codex에서 공통으로 쓰기 위한 안내입니다. 백엔드와 프론트엔드 저장소는 이 체크아웃을 참조만 하고, repo-local 설치 산출물은 두지 않습니다.

## 기준 경로
- 전역 `gstack` 체크아웃: `~/.claude/skills/gstack`
- Codex가 참조하는 사용자 공간 경로: `~/.codex/skills`

## 최초 설치 명령
```bash
mkdir -p "$HOME/.claude/skills"
git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git "$HOME/.claude/skills/gstack"
cd ~/.claude/skills/gstack && ./setup --no-prefix
cd ~/.claude/skills/gstack && ./setup --host codex --no-prefix
```
`--no-prefix`를 사용하면 `/office-hours`, `/review`, `/qa`처럼 짧은 slash command 이름을 그대로 사용합니다.
이미 `~/.claude/skills/gstack` 체크아웃이 있다면 다시 clone하지 말고 아래 업그레이드 절차를 사용합니다.

## 검증 명령
```bash
test -f "$HOME/.claude/skills/gstack/SKILL.md"
test -f "$HOME/.codex/skills/gstack/SKILL.md"
test -f "$HOME/.codex/skills/gstack-review/SKILL.md"
test -f "$HOME/.codex/skills/gstack-qa/SKILL.md"
echo "OK: Claude와 Codex에서 gstack 사용 가능"
```
설치 후에는 `~/.claude/skills/gstack`와 `~/.codex/skills`가 기대한 기준 경로로 연결되는지 확인합니다.

## 업그레이드 명령
```bash
cd ~/.claude/skills/gstack && git pull --ff-only
cd ~/.claude/skills/gstack && ./setup --no-prefix
cd ~/.claude/skills/gstack && ./setup --host codex --no-prefix
```
업그레이드는 항상 단일 체크아웃에서만 수행합니다. 저장소 안의 복사본이나 별도 설치는 만들지 않습니다.

## 문제 해결
- 설치가 꼬였거나 경로가 어긋나면 `~/.claude/skills/gstack`를 기준으로 다시 설치하고, Codex 쪽 등록도 같은 체크아웃에서 재실행합니다.
- Claude에서 skill이 보이지 않으면 `cd ~/.claude/skills/gstack && ./setup --no-prefix`를 다시 실행합니다.
- Codex에서 skill이 오래되었거나 invalid라고 나오면 `cd ~/.claude/skills/gstack && ./setup --host codex --no-prefix`를 다시 실행합니다.
- `bun` 또는 `bunx`가 없으면 먼저 `bun` 설치를 완료한 뒤 setup을 다시 실행합니다.
- 브라우저 런타임에서 `bun`/`bunx` 래퍼와 user-space `gstack-libs`를 쓰는 이유는 실행 환경을 사용자 공간에 고정해 런타임 안정성을 높이기 위해서입니다. 관련 오류가 나면 이 래퍼와 라이브러리 경로가 실제로 같은 전역 체크아웃을 가리키는지 먼저 확인합니다.
- Codex runtime root에서 실행할 때만 실패한다면, 로컬 저장소 문제가 아니라 전역 체크아웃 또는 사용자 공간 의존성 문제인지 분리해서 봅니다.
