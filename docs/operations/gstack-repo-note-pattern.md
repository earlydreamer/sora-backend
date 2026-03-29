# gstack 저장소 안내 문안 패턴

이 문서는 repo-local skill 설치 문서가 아닙니다. 전역 `gstack` 설치를 전제로, 각 저장소의 README나 운영 메모에 짧게 넣을 수 있는 문안을 정리합니다.

## 전제
- `gstack`은 `~/.claude/skills/gstack`에 전역으로만 설치되어 있어야 합니다.
- 저장소 안에는 `.agents/skills/gstack` 같은 repo-local 설치를 두지 않습니다.
- 이 문안은 설치 절차가 아니라, 저장소별 운영 메모용입니다.

## 백엔드 저장소용 문안
```md
이 저장소는 전역 `gstack` 설치를 사용합니다. 설치와 업그레이드는 `~/.claude/skills/gstack`에서만 관리하고, repo-local skill 설치는 사용하지 않습니다. 전역 설치와 운영 절차는 [docs/operations/gstack-global-setup.md](/docs/operations/gstack-global-setup.md)를 참고하세요.
```

## 프론트엔드 저장소용 문안
```md
이 저장소도 전역 `gstack` 설치를 사용합니다. `bun`/`bunx` 래퍼와 user-space `gstack-libs`는 브라우저 런타임 안정성을 위해 전역 체크아웃 기준으로만 동작해야 하며, repo-local skill 설치는 사용하지 않습니다. 전역 설치와 운영 절차는 [docs/operations/gstack-global-setup.md](/docs/operations/gstack-global-setup.md)를 참고하세요.
```
