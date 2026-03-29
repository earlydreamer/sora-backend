# gstack 도입 구현 계획

> **에이전트 작업자용:** REQUIRED SUB-SKILL: `superpowers:subagent-driven-development`(권장) 또는 `superpowers:executing-plans`를 사용해 이 계획을 작업 단위로 실행한다. 진행 추적은 체크박스(`- [ ]`) 문법을 사용한다.

**목표:** Claude와 Codex에서 공통으로 사용할 수 있는 전역 `gstack` 설치를 완료하고, 이 저장소의 운영 문서를 한국어 기준으로 정리한다.

**아키텍처:** 단일 기준 체크아웃은 `~/.claude/skills/gstack`에 두고, 같은 체크아웃에서 Claude와 Codex 등록을 모두 수행한다. Codex용 runtime root는 setup 과정에서 `~/.codex/skills`에 생성하고, 현재 저장소에는 repo-local skill 설치 대신 한국어 운영 문서만 추가한다.

**기술 스택:** Bash, git, gstack setup script, Markdown

---

## 파일 구조 및 책임

- 수정: `docs/superpowers/specs/2026-03-29-gstack-adoption-design.md`
  - 단일 기준 체크아웃 경로를 실제 `gstack` setup 동작에 맞게 `~/.claude/skills/gstack`으로 수정한다.
- 생성: `AGENTS.md`
  - 이 백엔드 저장소에서 Claude와 Codex를 어떻게 분담하는지, `gstack`을 어떤 흐름으로 쓰는지 기록한다.
- 수정: `README.md`
  - 저장소 소개에 에이전트 작업 가이드와 전역 `gstack` 운영 문서 위치를 연결한다.
- 생성: `docs/operations/gstack-global-setup.md`
  - 전역 설치, 검증, 업그레이드, 문제 해결 절차를 한국어로 정리한다.
- 생성: `docs/operations/gstack-repo-note-pattern.md`
  - 프론트엔드 저장소에 복사해 적용할 수 있는 운영 메모 패턴을 백엔드/프론트엔드 예시와 함께 제공한다.

### Task 1: 설치 경로 기준을 spec에 반영

**Files:**
- Modify: `docs/superpowers/specs/2026-03-29-gstack-adoption-design.md`
- Test: `docs/superpowers/specs/2026-03-29-gstack-adoption-design.md`

- [ ] **Step 1: 기존 spec이 잘못된 설치 기준을 포함하는지 확인**

```bash
rg -n "~/gstack|~/.claude/skills/gstack" docs/superpowers/specs/2026-03-29-gstack-adoption-design.md
```

Expected: `~/gstack` 기준 문장이 출력되어 현재 spec이 실제 setup 동작과 어긋나 있음을 확인한다.

- [ ] **Step 2: 단일 기준 체크아웃과 등록 문구를 교체**

다음 내용을 `docs/superpowers/specs/2026-03-29-gstack-adoption-design.md`의 설치 모델, 업그레이드 정책, 성공 기준 관련 문장에 반영한다.

```md
### 단일 기준 저장소

- 공통 `gstack` 체크아웃은 `~/.claude/skills/gstack` 하나만 유지한다.
- Claude 등록과 Codex 등록은 모두 이 체크아웃을 기준으로 수행한다.
- Codex용 runtime root는 setup 과정에서 `~/.codex/skills` 아래에 생성된다.

### 에이전트 등록

- Claude는 `cd ~/.claude/skills/gstack && ./setup --no-prefix`로 등록한다.
- Codex는 `cd ~/.claude/skills/gstack && ./setup --host codex --no-prefix`로 등록한다.
- 기본 운영 명령은 `/review`, `/qa`, `/office-hours`처럼 짧은 이름을 사용하기 위해 `--no-prefix`를 명시한다.

## 업그레이드 및 유지보수 정책

- 업그레이드는 `~/.claude/skills/gstack`에서만 수행한다.
- 공유 체크아웃에서 Claude와 Codex 등록을 다시 수행해 두 환경을 함께 갱신한다.
```

- [ ] **Step 3: 수정 후 잘못된 경로가 사라졌는지 검증**

```bash
rg -n "~/gstack" docs/superpowers/specs/2026-03-29-gstack-adoption-design.md
test $? -eq 1 && echo "OK: ~/gstack references removed"
rg -n "~/.claude/skills/gstack|--host codex --no-prefix|./setup --no-prefix" docs/superpowers/specs/2026-03-29-gstack-adoption-design.md
```

Expected: 첫 번째 `rg`는 결과 없이 종료하고, 두 번째 `rg`는 새 기준 문장을 출력한다.

- [ ] **Step 4: 변경 내용을 확인하고 커밋**

```bash
git add docs/superpowers/specs/2026-03-29-gstack-adoption-design.md
git commit -m "gstack 설치 기준 경로를 spec에 반영" -m " - Claude와 Codex가 함께 동작하는 실제 설치 기준을 spec에 반영함
 - 단일 기준 체크아웃 경로를 ~/.claude/skills/gstack으로 수정함
 - setup 실행 예시를 --no-prefix 기준으로 명시함"
```

Expected: 한국어 제목/본문을 가진 커밋 1개가 생성된다.

### Task 2: 전역 `gstack` 설치와 Claude/Codex 등록 수행

**Files:**
- Reference: `docs/superpowers/specs/2026-03-29-gstack-adoption-design.md`
- Reference: `docs/operations/gstack-global-setup.md`

- [ ] **Step 1: 설치 전 상태를 기록**

```bash
command -v bun
git --version
test -d "$HOME/.claude/skills/gstack" && echo "FOUND_CLAUDE_CHECKOUT" || echo "MISSING_CLAUDE_CHECKOUT"
test -d "$HOME/.codex/skills" && echo "FOUND_CODEX_DIR" || echo "MISSING_CODEX_DIR"
```

Expected: `bun`과 `git`이 확인되고, 기존 설치 여부가 `FOUND_*` 또는 `MISSING_*`로 출력된다.

- [ ] **Step 2: `gstack` 체크아웃을 준비**

```bash
mkdir -p "$HOME/.claude/skills"
if [ -d "$HOME/.claude/skills/gstack/.git" ]; then
  git -C "$HOME/.claude/skills/gstack" fetch --depth 1 origin main
  git -C "$HOME/.claude/skills/gstack" pull --ff-only
else
  git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git "$HOME/.claude/skills/gstack"
fi
```

Expected: 새로 복제되면 `Cloning into`가 출력되고, 기존 설치면 `Already up to date.` 또는 fast-forward 결과가 출력된다.

- [ ] **Step 3: Claude용 setup을 짧은 명령 이름 기준으로 실행**

```bash
cd "$HOME/.claude/skills/gstack"
./setup --no-prefix
```

Expected: `gstack ready (claude).`와 `browse:` 경로가 출력된다.

- [ ] **Step 4: 같은 체크아웃에서 Codex용 setup을 실행**

```bash
cd "$HOME/.claude/skills/gstack"
./setup --host codex --no-prefix
```

Expected: `gstack ready (codex).`와 `codex skills: /home/.../.codex/skills` 경로가 출력된다.

- [ ] **Step 5: Claude와 Codex 등록 결과를 검증**

```bash
test -f "$HOME/.claude/skills/gstack/SKILL.md"
test -f "$HOME/.codex/skills/gstack/SKILL.md"
test -f "$HOME/.codex/skills/gstack-review/SKILL.md"
test -f "$HOME/.codex/skills/gstack-qa/SKILL.md"
echo "OK: gstack installed for Claude and Codex"
```

Expected: 모든 `test`가 성공하고 마지막 줄에 `OK: gstack installed for Claude and Codex`가 출력된다.

### Task 3: 이 저장소용 에이전트 작업 가이드 추가

**Files:**
- Create: `AGENTS.md`
- Modify: `README.md`
- Test: `AGENTS.md`

- [ ] **Step 1: 가이드 파일이 아직 없는지 확인**

```bash
test -f AGENTS.md && echo "UNEXPECTED_AGENTS_EXISTS" || echo "AGENTS_MISSING"
```

Expected: `AGENTS_MISSING`

- [ ] **Step 2: `AGENTS.md`를 한국어 운영 가이드로 작성**

다음 내용을 새 파일 `AGENTS.md`에 그대로 작성한다.

```md
# 에이전트 작업 가이드

## 목적

이 저장소에서는 중요한 판단은 Claude에 맡기고, 주요 구현은 Codex가 담당한다. `gstack`은 전역 설치로만 운영하며, 이 저장소 안에는 repo-local skill 설치를 두지 않는다.

## 기본 원칙

- 큰 방향 결정, 범위 조정, 구조 검토는 Claude에서 먼저 수행한다.
- 구현, 반복 수정, 테스트 보강, 빠른 디버깅은 Codex에서 수행한다.
- 작업 마감 단계에서는 `gstack` review 및 QA 흐름을 기본 절차로 사용한다.
- 문서와 커밋 메시지는 특별한 사유가 없으면 한국어를 우선 사용한다.

## 전역 gstack 기준

- 기준 체크아웃: `~/.claude/skills/gstack`
- Claude 등록: `cd ~/.claude/skills/gstack && ./setup --no-prefix`
- Codex 등록: `cd ~/.claude/skills/gstack && ./setup --host codex --no-prefix`
- 업그레이드: `cd ~/.claude/skills/gstack && git pull --ff-only`

## 권장 작업 흐름

1. 변경이 모호하거나 영향 범위가 크면 Claude에서 `/office-hours`, `/plan-ceo-review`, `/plan-eng-review` 중 하나로 시작한다.
2. 방향이 정해지면 Codex에서 구현을 진행한다.
3. 구현 완료 전후에 `/review` 또는 `/qa`를 사용해 검토한다.
4. 배포 영향이나 계약 변경이 생기면 Claude로 다시 올라가 판단을 받는다.

## 저장소 경계

- 프론트엔드와 백엔드는 별도 저장소, 별도 배포 주기로 유지한다.
- 이 저장소는 백엔드 운영 원칙만 다룬다.
- 프론트엔드용 운영 메모는 별도 저장소에 동일한 패턴으로 적용한다.
```

- [ ] **Step 3: README에 작업 가이드와 전역 설치 문서 링크를 추가**

`README.md`를 아래 내용으로 교체한다.

```md
# sora-backend

sora 백엔드 프로젝트 저장소입니다.

## 작업 가이드

- 에이전트 작업 원칙은 [AGENTS.md](AGENTS.md)를 기준으로 유지합니다.
- 전역 `gstack` 설치와 검증 절차는 [docs/operations/gstack-global-setup.md](docs/operations/gstack-global-setup.md)를 참고합니다.
```

- [ ] **Step 4: 문서 연결이 올바른지 검증**

```bash
rg -n "Claude|Codex|gstack|한국어" AGENTS.md
rg -n "AGENTS.md|gstack-global-setup.md" README.md
```

Expected: 첫 번째 `rg`는 운영 원칙 핵심 문장을, 두 번째 `rg`는 README의 링크 문장을 출력한다.

- [ ] **Step 5: 문서 추가 내용을 커밋**

```bash
git add AGENTS.md README.md
git commit -m "백엔드 저장소용 에이전트 작업 가이드 추가" -m " - Claude와 Codex 역할 분리 기준을 AGENTS.md에 정리함
 - gstack 전역 설치와 작업 흐름을 한국어로 문서화함
 - README에서 운영 가이드 문서로 연결되도록 갱신함"
```

Expected: 한국어 제목/본문을 가진 커밋 1개가 생성된다.

### Task 4: 전역 설치 문서와 프론트엔드 적용 패턴 문서 추가

**Files:**
- Create: `docs/operations/gstack-global-setup.md`
- Create: `docs/operations/gstack-repo-note-pattern.md`
- Test: `docs/operations/gstack-global-setup.md`

- [ ] **Step 1: 운영 문서 파일이 비어 있는 상태인지 확인**

```bash
test -f docs/operations/gstack-global-setup.md && echo "UNEXPECTED_GLOBAL_DOC_EXISTS" || echo "GLOBAL_DOC_MISSING"
test -f docs/operations/gstack-repo-note-pattern.md && echo "UNEXPECTED_PATTERN_DOC_EXISTS" || echo "PATTERN_DOC_MISSING"
```

Expected: `GLOBAL_DOC_MISSING`와 `PATTERN_DOC_MISSING`

- [ ] **Step 2: 전역 설치/검증/업그레이드 문서를 작성**

다음 내용을 `docs/operations/gstack-global-setup.md`에 그대로 작성한다.

````md
# gstack 전역 설치 및 운영 가이드

## 목적

Claude와 Codex에서 공통으로 사용할 `gstack` 설치 기준과 검증 절차를 하나의 문서로 관리한다.

## 기준 경로

- 체크아웃: `~/.claude/skills/gstack`
- Codex runtime root: `~/.codex/skills`

## 최초 설치

```bash
mkdir -p "$HOME/.claude/skills"
git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git "$HOME/.claude/skills/gstack"
cd "$HOME/.claude/skills/gstack"
./setup --no-prefix
./setup --host codex --no-prefix
```

## 검증

```bash
test -f "$HOME/.claude/skills/gstack/SKILL.md"
test -f "$HOME/.codex/skills/gstack/SKILL.md"
test -f "$HOME/.codex/skills/gstack-review/SKILL.md"
test -f "$HOME/.codex/skills/gstack-qa/SKILL.md"
echo "OK: Claude와 Codex에서 gstack 사용 가능"
```

## 업그레이드

```bash
cd "$HOME/.claude/skills/gstack"
git pull --ff-only
./setup --no-prefix
./setup --host codex --no-prefix
```

## 문제 해결

- Claude에서 skill이 보이지 않으면 `cd ~/.claude/skills/gstack && ./setup --no-prefix`를 다시 실행한다.
- Codex에서 skill이 오래되었거나 invalid라고 나오면 `cd ~/.claude/skills/gstack && ./setup --host codex --no-prefix`를 다시 실행한다.
- `bun`이 없으면 먼저 `bun` 설치를 완료한 뒤 setup을 다시 실행한다.
````

- [ ] **Step 3: 프론트엔드 저장소에 복사할 운영 메모 패턴을 작성**

다음 내용을 `docs/operations/gstack-repo-note-pattern.md`에 그대로 작성한다.

````md
# gstack 저장소 운영 메모 패턴

## 사용 원칙

- 이 문서는 repo-local skill 설치를 만들기 위한 문서가 아니다.
- 전역 `gstack` 설치를 전제로 각 저장소에서 어떤 흐름으로 Claude와 Codex를 쓸지 정리하는 패턴이다.

## 백엔드 저장소용 문안

```md
# 에이전트 작업 가이드

- 방향 결정은 Claude에서 시작한다.
- 구현과 수정은 Codex에서 수행한다.
- API 경계, 도메인 모델, 배포 영향 검토는 Claude를 우선 사용한다.
- review와 QA는 마감 단계의 기본 절차로 포함한다.
```

## 프론트엔드 저장소용 문안

```md
# 에이전트 작업 가이드

- 방향 결정은 Claude에서 시작한다.
- 구현과 수정은 Codex에서 수행한다.
- UX 방향, 화면 구조, 기능 범위 결정은 Claude를 우선 사용한다.
- 화면 구현과 반복 수정은 Codex를 우선 사용한다.
- review와 QA는 마감 단계의 기본 절차로 포함한다.
```
````

- [ ] **Step 4: 운영 문서 핵심 문장을 검색으로 검증**

```bash
rg -n "체크아웃|Codex runtime root|최초 설치|업그레이드|문제 해결" docs/operations/gstack-global-setup.md
rg -n "백엔드 저장소용 문안|프론트엔드 저장소용 문안|repo-local skill 설치" docs/operations/gstack-repo-note-pattern.md
```

Expected: 두 문서 모두 핵심 섹션 제목이 출력된다.

- [ ] **Step 5: 운영 문서 추가 내용을 커밋**

```bash
git add docs/operations/gstack-global-setup.md docs/operations/gstack-repo-note-pattern.md
git commit -m "gstack 전역 운영 문서와 저장소 패턴 추가" -m " - 전역 설치, 검증, 업그레이드 절차를 한국어 문서로 정리함
 - 프론트엔드와 백엔드에 복사해 쓸 수 있는 운영 메모 패턴을 추가함
 - repo-local 설치 없이 전역 운영 원칙을 유지하도록 문서를 구성함"
```

Expected: 한국어 제목/본문을 가진 커밋 1개가 생성된다.
