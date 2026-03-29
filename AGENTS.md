# 에이전트 작업 가이드

이 저장소에서는 중요한 판단은 Claude가 담당하고, 주요 구현은 Codex가 담당한다.

## 역할 분리

- 큰 방향 결정, 범위 조정, 구조 검토는 Claude가 맡는다.
- 구현, 반복 수정, 테스트, 디버깅은 Codex가 맡는다.
- 작업 마감 단계에서는 `gstack review`와 `gstack qa`를 사용해 최종 점검한다.

## gstack 운영 원칙

- `gstack`은 전역 설치만 사용하고, repo-local 설치는 하지 않는다.
- 전역 gstack 기준 경로는 `~/.claude/skills/gstack`이다.
- Claude 설정 명령:

```bash
cd ~/.claude/skills/gstack && ./setup --no-prefix
```

- Codex 설정 명령:

```bash
cd ~/.claude/skills/gstack && ./setup --host codex --no-prefix
```

- 업그레이드 명령:

```bash
cd ~/.claude/skills/gstack && git pull --ff-only
```

## 문서와 커밋

- 문서와 커밋 메시지는 한국어를 우선한다.
- 커밋 메시지는 짧고 명확한 한국어 제목과 본문을 사용한다.

## 저장소 범위

- 이 가이드는 백엔드 저장소에만 적용한다.
- 프론트엔드용 메모는 별도 저장소에 적용한다.
