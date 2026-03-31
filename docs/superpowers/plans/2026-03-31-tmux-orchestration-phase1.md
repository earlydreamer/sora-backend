# tmux 오케스트레이션 1단계 구현 계획

> **에이전트 작업자용:** REQUIRED SUB-SKILL: `superpowers:executing-plans` 또는 `superpowers:subagent-driven-development`를 사용해 이 계획을 task 단위로 실행한다. 진행 추적은 체크박스(`- [ ]`) 문법을 사용한다.

**목표:** 문서 계약(spec 정교화)과 운영 절차 문서를 추가해, 2단계(helper script 구현)로 진행할 수 있는 명확한 기초를 마련한다.

**아키텍처:** 기존 spec을 WSL/Tailscale/systemd 기반으로 정교화하고, `.orchestrator/` 파일 규약과 유지보수 정책을 운영 문서에 추가한다.

**기술 스택:** Bash, JSON, Markdown, WSL2 systemd

---

## Task 1: spec 최종 정교화

**Files:**
- Modify: `docs/superpowers/specs/2026-03-31-tmux-orchestration-design.md`
- Reference: `docs/current.md`, `AGENTS.md`

- [ ] **Step 1: WSL/Tailscale/systemd 섹션을 spec에 추가**

다음 내용을 spec의 "아키텍처" 섹션에 추가한다.

```md
### 실행 환경

#### WSL2 (Ubuntu 22.04+)

- Windows PC의 WSL2에서 tmux 세션을 운영한다
- systemd는 반드시 활성화 (`/etc/wsl.conf`에 `systemd=true`)
- 저장소 경로: `/mnt/d/Projects/sora/sora-backend`
- tmux 세션명: `sora-backend`

#### SSH 접근 (Tailscale VPN)

- WSL SSH 서버: `openssh-server` (기본 포트 22)
- Tailscale VPN으로 외부 접근을 암호화하고 공개 포트 노출을 피한다
- SSH 인증: 공개 키 인증만 사용 (비밀번호 인증 금지)

#### 제어 경로 (두 가지)

**경로 A: Windows Claude Code 앱 (대화형)**
- CLAUDE.md 규칙을 따라 모든 Bash 명령을 `wsl bash -lc "..."` 형태로 실행
- Windows에서 WSL 오케스트레이션 세션을 제어

**경로 B: SSH + tmux/WSL Claude Code (원격 관리)**
- Tailscale VPN으로 WSL SSH 접속
- `tmux attach -t sora-backend`로 실시간 모니터링
- WSL의 Claude Code CLI로 프로그래매틱 제어
```

- [ ] **Step 2: `.orchestrator/` git 관리 정책을 spec에 추가**

"파일 구조" 섹션을 다음과 같이 수정한다.

```md
## 파일 구조와 git 정책

### 저장소 추적 대상

- `scripts/orchestrator/*.sh` — helper script들 (커밋)
- `.orchestrator/scripts/` — 향후 추가 자동화 스크립트 (커밋)

### 저장소 제외 대상 (`.gitignore`)

- `.orchestrator/state.json` — 런타임 세션 상태 (휘발성)
- `.orchestrator/queue.json` — 런타임 작업 큐 (휘발성)
- `.orchestrator/workers/*.json` — 워커 인스턴스 상태 (휘발성)
- `.orchestrator/logs/` — 워커 실행 로그 (임시)

### 파일 사례

```text
.orchestrator/
  scripts/              ← git 추적
    orchestrator/
  state.json            ← .gitignore (runtime)
  queue.json            ← .gitignore (runtime)
  workers/              ← .gitignore (runtime)
    worker-001.json
  logs/                 ← .gitignore (temporary)
    worker-001.log
```
```

- [ ] **Step 3: 복구 규약에 WSL 경로 추가**

"복구 규약" → "복구 절차" 섹션의 4번 항목을 다음과 같이 수정한다.

```md
4. `.orchestrator/state.json` 읽기 (WSL 경로 기준: `/mnt/d/Projects/sora/sora-backend`)
```

- [ ] **Step 4: spec의 "다음 단계" 섹션을 2단계 계획으로 갱신**

```md
## 다음 단계

이 spec이 1단계 구현을 완료하면 2단계로 진행한다.

- 2단계: helper script 최소 구현
  - `spawn-worker`
  - `list-workers`
  - `capture-worker`
  - `mark-worker`
  - `recover-session`
- 3단계: `start-harness` 또는 별도 skill에 연결
- 4단계: 선택적 고도화 (TUI, pane 로그 뷰)
```

- [ ] **Step 5: 수정 완료 후 검증**

```bash
rg -n "WSL|Tailscale|systemd|/mnt/d" docs/superpowers/specs/2026-03-31-tmux-orchestration-design.md
```

Expected: WSL 환경, Tailscale, systemd, 경로 관련 문장이 모두 출력된다.

---

## Task 2: 운영 절차 문서 추가

**Files:**
- Create: `docs/operations/tmux-orchestration.md`
- Reference: `docs/operations/agent-handoff-harness.md`

- [ ] **Step 1: 운영 문서 디렉터리 확인**

```bash
ls docs/operations/
```

Expected: `gstack-global-setup.md`, `github-task-pipeline.md` 등이 있다.

- [ ] **Step 2: `tmux-orchestration.md` 파일 생성**

다음 내용으로 새 파일을 작성한다.

```md
# tmux 오케스트레이션 운영 가이드

## 개요

WSL2 Ubuntu 환경에서 tmux를 이용해 여러 Codex 워커를 동시에 관리하고, 외부에서 Tailscale VPN으로 SSH 접근해 모니터링한다.

## 전제 조건

- Windows PC에 WSL2 (Ubuntu 22.04+) 설치
- WSL2에서 systemd 활성화
- openssh-server 설치 (`sudo apt install openssh-server`)
- tmux 설치 (`sudo apt install tmux`)
- Tailscale 설치 및 VPN 연결

## WSL2 systemd 활성화

### 1. WSL 설정 확인

```bash
cat /etc/wsl.conf
```

`[boot]` 섹션에 `systemd=true`가 있는지 확인한다.

### 2. 없으면 추가

```bash
sudo tee -a /etc/wsl.conf > /dev/null <<EOF
[boot]
systemd=true
EOF
```

### 3. WSL 재시작

Windows PowerShell에서:

```powershell
wsl --shutdown
```

그 뒤 다시 WSL 터미널을 연다.

### 4. 확인

```bash
systemctl status
```

PID가 1인 systemd가 실행 중이어야 한다.

## SSH 서버 설정

### 1. openssh-server 설치

```bash
sudo apt update && sudo apt install openssh-server
```

### 2. SSH 포트 확인

```bash
sudo ss -tlnp | grep ssh
```

기본값: 포트 22

### 3. 공개 키 인증만 활성화 (선택)

```bash
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh
```

### 4. SSH 서비스 시작

```bash
sudo systemctl enable ssh
sudo systemctl start ssh
```

## Tailscale VPN 설정

### 1. Tailscale 설치

```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

### 2. Tailscale 활성화

```bash
sudo tailscale up
```

브라우저에서 인증 링크를 따라 로그인한다.

### 3. WSL2의 Tailscale IP 확인

```bash
sudo tailscale ip -4
```

이 IP 주소로 외부에서 SSH 접근한다.

## tmux 세션 자동시작

### 1. systemd user service 생성

```bash
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/tmux-orchestrator.service <<EOF
[Unit]
Description=tmux orchestrator session for sora-backend
After=network.target

[Service]
Type=forking
ExecStart=/usr/bin/tmux new-session -d -s sora-backend -c /mnt/d/Projects/sora/sora-backend
ExecStop=/usr/bin/tmux kill-session -t sora-backend
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF
```

### 2. 서비스 활성화

```bash
systemctl --user enable tmux-orchestrator.service
systemctl --user start tmux-orchestrator.service
```

### 3. 확인

```bash
systemctl --user status tmux-orchestrator.service
tmux list-sessions
```

## tmux 세션 접근

### Windows Claude Code 앱에서 (로컬 제어)

CLAUDE.md 규칙을 따라 모든 bash 명령을 `wsl bash -lc "..."` 형태로 실행한다.

```bash
wsl bash -lc "scripts/orchestrator/spawn-worker codex routes task-1"
```

### SSH로 원격 접근

```bash
# Tailscale IP를 이용한 접근
ssh tailscale-ip
tmux attach -t sora-backend

# 또는 직접 명령 실행
ssh tailscale-ip "tmux send-keys -t sora-backend:control 'list-workers' Enter"
```

### WSL 터미널에서 (로컬 직접 접근)

```bash
tmux attach -t sora-backend
```

## 상태 확인

### tmux window 목록

```bash
tmux list-windows -t sora-backend
```

### 특정 worker 출력 캡처 (이후 helper script 사용)

```bash
tmux capture-pane -t sora-backend:worker-001-codex-* -p
```

## 문제 해결

### tmux 세션이 시작되지 않음

```bash
systemctl --user status tmux-orchestrator.service
journalctl --user -u tmux-orchestrator.service -n 50
```

### SSH 접속 실패

```bash
# WSL SSH 서버 확인
sudo systemctl status ssh

# Tailscale 상태 확인
sudo tailscale status
```

### WSL2에서 systemd 미지원

Ubuntu 20.04 이하이거나 WSL1을 사용 중인 경우, 이 가이드를 따를 수 없습니다. WSL2 + Ubuntu 22.04+로 업그레이드하세요.

## 참고

- [Tailscale 공식 문서](https://tailscale.com/docs/)
- [tmux 공식 문서](https://github.com/tmux/tmux/wiki)
- [WSL systemd](https://devblogs.microsoft.com/commandline/systemd-support-is-now-available-in-wsl/)
```

- [ ] **Step 3: 파일 생성 후 검증**

```bash
test -f docs/operations/tmux-orchestration.md && echo "OK: 파일 생성됨"
rg -n "systemd|Tailscale|SSH" docs/operations/tmux-orchestration.md | head -5
```

Expected: 파일이 존재하고 핵심 섹션이 모두 있다.

---

## Task 3: `.gitignore` 업데이트

**Files:**
- Modify: `.gitignore`
- Reference: `.orchestrator/` 파일 정책

- [ ] **Step 1: 현재 `.gitignore` 확인**

```bash
cat .gitignore | tail -10
```

- [ ] **Step 2: orchestrator 항목 추가**

`.gitignore`의 끝에 다음 줄을 추가한다.

```
# orchestrator runtime state (volatile, machine-generated)
.orchestrator/state.json
.orchestrator/queue.json
.orchestrator/workers/
.orchestrator/logs/
```

- [ ] **Step 3: 검증**

```bash
git status .gitignore
```

Expected: `.gitignore`만 변경된 것으로 표시된다.

---

## Task 4: CLAUDE.md 업데이트 (Windows Claude Code 앱용)

**Files:**
- Modify: `CLAUDE.md` (없으면 생성)
- Reference: `AGENTS.md` (역할 정책)

- [ ] **Step 1: CLAUDE.md 파일 확인**

```bash
test -f CLAUDE.md && echo "EXISTS" || echo "MISSING"
```

- [ ] **Step 2: WSL bash 규칙 추가**

파일이 없으면 생성, 있으면 다음 섹션을 추가한다.

```md
# Claude Code 실행 환경 규칙

## WSL을 통한 명령 실행

Windows PC의 Claude Code 앱에서 실행되는 모든 Bash 명령은 WSL을 통해야 한다.

### 규칙

- 형식: `wsl bash -lc "<command>"`
- 경로: Windows 경로(`D:\...`) 대신 WSL 경로(`/mnt/d/...`) 사용
- 예시:

```bash
# ❌ 틀린 예
bash -c "cd D:\Projects\sora\sora-backend && npm run build"

# ✅ 올바른 예
wsl bash -lc "cd /mnt/d/Projects/sora/sora-backend && npm run build"
```

### tmux 오케스트레이션 명령

otel orchestrator helper script도 동일하게 `wsl bash -lc`를 통해 실행한다.

```bash
# worker 생성
wsl bash -lc "scripts/orchestrator/spawn-worker codex routes task-1"

# worker 목록 조회
wsl bash -lc "scripts/orchestrator/list-workers --json"

# worker 상태 확인
wsl bash -lc "scripts/orchestrator/capture-worker worker-001"
```

## WSL의 Claude Code 앱 (SSH + agentic)

SSH로 WSL에 접속한 뒤, WSL 터미널에서 `claude` CLI를 실행하면 이 규칙을 따를 필요 없다 (자연스럽게 WSL 명령으로 실행됨).
```

- [ ] **Step 3: 파일 생성/수정 확인**

```bash
test -f CLAUDE.md && rg -n "WSL|wsl bash" CLAUDE.md
```

Expected: CLAUDE.md가 존재하고 WSL 규칙이 포함되어 있다.

---

## Task 5: `docs/current.md` 업데이트

**Files:**
- Modify: `docs/current.md`

- [ ] **Step 1: 현재 상태 읽기**

```bash
head -20 docs/current.md
```

- [ ] **Step 2: 하네스 상태 갱신**

`## 하네스 상태` 섹션을 다음과 같이 갱신한다.

```md
## 하네스 상태
- 상태: codex-ready
- 현재 담당: Codex
- 활성 스펙: docs/superpowers/plans/2026-03-31-tmux-orchestration-phase1.md
- Claude 재판단 필요: 없음
```

- [ ] **Step 3: 작업 체크리스트 추가**

`## 작업 체크리스트` → `### 진행 중` 아래 다음을 추가한다.

```md
- [ ] tmux 오케스트레이션 1단계 구현 (담당: Codex)
  - spec 정교화
  - 운영 문서 추가
  - CLAUDE.md 규칙 반영
  - .gitignore 업데이트
```

---

## Task 6: 1단계 완료 후 검증

**Files:**
- Reference: `docs/superpowers/specs/2026-03-31-tmux-orchestration-design.md`
- Reference: `docs/operations/tmux-orchestration.md`
- Reference: `CLAUDE.md`
- Reference: `.gitignore`

- [ ] **Step 1: 핵심 파일 존재 확인**

```bash
test -f docs/superpowers/specs/2026-03-31-tmux-orchestration-design.md && echo "spec: OK"
test -f docs/operations/tmux-orchestration.md && echo "ops doc: OK"
test -f CLAUDE.md && echo "CLAUDE.md: OK"
```

Expected: 세 파일 모두 존재한다.

- [ ] **Step 2: 주요 내용 검증**

```bash
rg -n "WSL2|systemd|Tailscale" docs/superpowers/specs/2026-03-31-tmux-orchestration-design.md docs/operations/tmux-orchestration.md
rg -n "wsl bash -lc" CLAUDE.md
rg -n ".orchestrator/" .gitignore
```

Expected: 각각의 핵심 항목이 모두 문서에 반영되어 있다.

- [ ] **Step 3: 커밋**

```bash
git add docs/superpowers/specs/2026-03-31-tmux-orchestration-design.md \
        docs/operations/tmux-orchestration.md \
        docs/superpowers/plans/2026-03-31-tmux-orchestration-phase1.md \
        CLAUDE.md \
        .gitignore \
        docs/current.md

git commit -m "tmux 오케스트레이션 1단계: 문서 계약 및 운영 절차 추가" \
  -m "- spec을 WSL2/Tailscale/systemd 기반으로 정교화
 - tmux 오케스트레이션 운영 절차 문서 추가 (설치/설정/접근 방법)
 - CLAUDE.md에 WSL bash 규칙 추가 (Windows Claude Code app에서 WSL 명령 강제)
 - .gitignore에 .orchestrator 런타임 파일 제외 정책 추가
 - docs/current.md를 1단계 완료 상태로 갱신"
```

Expected: 한국어 제목/본문 커밋 1개가 생성된다.

---

## 완료 기준

1단계가 완료되려면 아래 모든 조건을 만족해야 한다.

- [ ] spec 파일이 WSL/Tailscale/systemd/CLAUDE.md 관련 내용으로 정교화됨
- [ ] `docs/operations/tmux-orchestration.md`가 완성되어 사람이 직접 따라 할 수 있음
- [ ] CLAUDE.md에 `wsl bash -lc` 규칙이 명확하게 기술됨
- [ ] `.gitignore`에 orchestrator 런타임 파일 정책이 추가됨
- [ ] 모든 변경이 한국어 커밋 1~2개로 정리됨
- [ ] `git log --oneline | head -5`에서 이번 커밋이 보임
- [ ] `docs/current.md`가 다음 단계(2단계 helper script)를 언급함

---

## 2단계로 진행하기

1단계 검증이 완료되면 다음 단계로:

```md
# Task: tmux 오케스트레이션 2단계 - helper script 구현

목표: 5개 helper script 구현 (`spawn-worker`, `list-workers`, `capture-worker`, `mark-worker`, `recover-session`)

시작: docs/superpowers/plans/2026-03-31-tmux-orchestration-phase2.md 작성 후 `/start-harness` 실행
```
