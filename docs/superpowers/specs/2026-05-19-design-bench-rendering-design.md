# design-bench: Rendering-based Mockup Output

> **Status:** Spec (pre-implementation)
> **Author:** zach@wrtn.io (with Claude Code)
> **Date:** 2026-05-19

## Problem

`design-bench` 플러그인은 추천 UI/UX를 ASCII 박스 와이어프레임(`┌─┐│└┘`)으로
가시화한다. ASCII는 텍스트라 어디서나 보이고 가볍지만, 실제 색·타이포·간격
같은 시각 정보가 빈약해서 보고서를 받은 사람이 "이게 진짜 어떻게 보이는지"
머릿속에 그리기 어렵다. 결과적으로 보고서의 설득력과 실행 트리거가 약하다.

## Goal

추천 UI/UX를 **프로젝트의 design system 토큰을 적용한 HTML/CSS mockup**으로
렌더링한다. `report.html`에는 인라인 HTML mockup을, `report.md`에는 동일
mockup을 헤드리스 브라우저로 PNG 캡처해 임베드한다. 둘 다 시각적이다.

## Non-Goals

- 인터랙티브 mockup (hover/click 동작 시뮬레이션) — 정적 렌더만.
- 픽셀-퍼펙트 시각 디자인 — 의도는 "권고안의 시각적 설득력 확보"이지
  Figma 대체가 아니다.
- ASCII 와이어프레임 완전 제거 — PNG 렌더 실패 시 `report.md`의 fallback
  으로 유지한다 (얇게).
- 새 도구·MCP 강제 도입 — 헤드리스 브라우저는 optional, puppeteer는 npx
  로 자동 설치.

## Decisions (확정)

| 영역 | 결정 |
|---|---|
| 렌더 모드 | HTML/CSS 실제 mockup |
| 포맷 | `report.html` 메인 + `report.md`는 PNG embed |
| Fidelity | 프로젝트 design system 토큰 적용 |
| 렌더 대상 | Recommendations(3개) + Patterns/Anti-patterns |
| Viewport | Mobile(375px) + Desktop(1280px) side-by-side |
| PNG fallback | gstack/browse 없으면 `npx puppeteer` |
| HTML embed | `<iframe srcdoc>` (스타일 격리) |
| Puppeteer 호출 | skill 동봉 `render.mjs` (third-party CLI 미사용) |

## Architecture

```
[Step 5: Map Internal Design System]
   │
   ├─→ 컴포넌트 인벤토리 (기존)
   └─→ ★ Step 5b: Extract Design Tokens (신규)
        │ tokens/ 또는 config.tokens 경로에서
        │ color/typography/spacing/radius를 파싱
        │ → CSS variables 형태로 변환
        ↓
      design-tokens.css (OUTPUT_DIR에 저장)

[Step 7: Generate Recommendations]
   │
   ├─→ 각 recommendation에 대해:
   │    ├─→ mobile mockup HTML 생성 (375px)
   │    └─→ desktop mockup HTML 생성 (1280px)
   ├─→ patterns/anti-patterns mini-mockup 생성
   ↓
   mockup HTML 조각들 → OUTPUT_DIR/mockups/_src/*.html

[Step 8.5: Render Mockups to PNG] (신규)
   │
   ├─→ headless browser 감지 ($LB 변수, 기존 로직 재사용)
   │     ├─ 있으면: $LB goto file:// + screenshot
   │     └─ 없으면: render.mjs (puppeteer npx)
   ↓
   {OUTPUT_DIR}/mockups/rec-{n}-{mobile|desktop}.png
   {OUTPUT_DIR}/mockups/pattern-{slug}.png

[Step 8: Write report.md]
   └─→ ![alt](mockups/rec-1-mobile.png) 형태로 embed

[Step 9: Generate report.html]
   └─→ HTML mockup 원본 <iframe srcdoc> 인라인 embed
        + design-tokens.css 인라인 포함
```

## Components

### A. Token Extractor — `scripts/extract-tokens.sh` (신규)

- **입력:** `design_system.tokens` 경로 (config). 없으면 fallback paths 시도.
- **Fallback 탐색 순서:**
  1. `config.tokens` (e.g. `ui/src/tokens`)
  2. `tailwind.config.{js,ts}` 의 `theme.extend`
  3. `**/tokens.{json,css,ts}` glob
  4. `**/globals.css`, `**/theme.css` 의 `:root` CSS variables grep
  5. 못 찾으면 → neutral default tokens. 보고서에 명시.
- **출력:** `{OUTPUT_DIR}/design-tokens.css`
  ```css
  :root {
    --color-primary: #...;
    --color-bg: #...;
    --color-fg: #...;
    --color-muted: #...;
    --color-border: #...;
    --radius-sm: ...; --radius-md: ...; --radius-lg: ...;
    --space-1: ...; --space-2: ...; --space-4: ...; --space-8: ...;
    --font-sans: ...;
    --text-sm: ...; --text-md: ...; --text-lg: ...;
  }
  ```
- **의존성:** bash + grep + jq (JSON tokens 파싱용).

### B. Mockup Generator (LLM, Step 7 안)

- **단위:** 각 recommendation 1개당 mockup 2개 (mobile/desktop), patterns/
  anti-patterns 각각 mini-mockup 1개.
- **Mockup Contract (LLM에 강제):**
  - 외부 CSS/JS/이미지 금지. 인라인 또는 `design-tokens.css`만.
  - 색·간격·radius·폰트 모두 `var(--token-name)` 사용. raw hex 금지.
  - 최상위 wrapper: `<div class="mockup-frame" data-platform="mobile|desktop">`
  - Mobile: 고정 width 375px. Desktop: 고정 width 1280px.
  - Semantic 태그 우선 (`<button>`, `<nav>`, `<section>`).
- **저장:** 한 mockup당 self-contained HTML 파일로 `mockups/_src/`에 저장.
- **검증:** Step 8.5 시작 전 grep:
  - raw `#[0-9a-fA-F]{3,8}\b` 발견 시 self-correct 1회 retry.
  - `src="http` 발견 시 동일.
  - 실패해도 진행하되 보고서에 경고 배지.

### C. Mockup Renderer — `scripts/render-mockups.sh` + `scripts/render.mjs` (신규)

`render-mockups.sh`:
```bash
# 1) $LB 감지 (기존 SKILL.md 로직 재사용)
# 2) 있으면: for f in mockups/_src/*.html; $LB goto file://$f; $LB screenshot ...
# 3) 없으면: node render.mjs mockups/_src/ mockups/
# 4) 완료 후 mockups/_src/ 삭제
```

`render.mjs` (~50줄):
- `import puppeteer from 'puppeteer'` — 없으면 npx가 자동 설치
- HTML 파일의 `data-platform` 속성으로 viewport 결정 (375 또는 1280)
- file:// URL load → `fullPage: false`, viewport 고정으로 screenshot
- 출력 파일명은 입력과 동일, 확장자만 `.png`

### D. Report Writer (변경)

- **`report.md`:** 각 Recommendation 안에 `![rec-1 mobile](mockups/rec-1-mobile.png) ![rec-1 desktop](mockups/rec-1-desktop.png)` side-by-side.
- **`report.html`:** mockup HTML을 `<iframe srcdoc="...">` 로 인라인 embed.
  iframe height는 mockup wrapper 높이에 맞게 inline style로 설정.
  `design-tokens.css`도 `<style>` 블록으로 인라인 포함.

## Data Flow

```
config + tokens 경로
   ↓ (extract-tokens.sh)
design-tokens.css
   ↓ (LLM at step 7, with token list as context)
mockup HTML strings (mobile + desktop per rec/pattern)
   ↓ (mockups/_src/*.html에 저장)
   ↓ (render-mockups.sh → $LB 또는 render.mjs)
mockup PNG files (mockups/*.png)
   ↓ (writer)
report.md (PNG embed) + report.html (iframe srcdoc inline)
```

## File Changes

전체 7개 (수정 3 + 신규 4).

### 수정
1. `skills/design-bench/SKILL.md`
   - `Workflow > Step 5` 끝에 Step 5b 추가
   - `Workflow > Step 7` 의 "ASCII wireframe" 항목 → "HTML Mockup" 교체 + 작성 규칙
   - **Step 8.5 (신규)** Render mockups to PNG
   - Step 8/9 embed 방식 명시
   - 신규 섹션 "Mockup Contract" (5–7줄)
   - "ASCII Wireframe Convention" 섹션은 fallback 한정으로 1문단으로 축소
   - "Common Mistakes" 에 "raw hex 사용", "외부 CDN 의존" 추가

2. `skills/design-bench/references/report-template.md`
   - Recommendation의 `Sketch:` ASCII 블록 → `Mockups:` (mobile/desktop PNG)
   - Patterns/Anti-Patterns 각 항목에 mini-mockup PNG 링크 추가 (옵션)
   - footer에 "Mockups rendered with project design tokens" 한 줄

3. `plugins/design-bench/README.md`
   - "Output" 디렉토리 트리에 `mockups/` 추가
   - "ASCII wireframes" 문구 → "HTML/CSS mockups"

### 신규
4. `skills/design-bench/scripts/extract-tokens.sh`
5. `skills/design-bench/scripts/render-mockups.sh`
6. `skills/design-bench/scripts/render.mjs`
7. `skills/design-bench/references/mockup-examples.md` — LLM 참고용 mockup HTML 예시 3–5개

### 변경 안 함
- `.claude-plugin/plugin.json`
- `competitors-kr.md`, `competitors-global.md`
- `scripts/load-config.sh`

## Edge Cases

| 케이스 | 처리 |
|---|---|
| tokens 디렉토리 없음 | neutral default + 보고서에 "프로젝트 토큰 미발견, 중립 팔레트" 명시 |
| `platforms`에 `mobile`만 | desktop mockup 생성 스킵, single layout |
| `platforms`에 `desktop`만 | mobile mockup 생성 스킵 |
| LLM이 raw hex 사용 | grep 검증 → self-correct 1회 retry → 실패 시 진행 + 경고 |
| LLM이 외부 src 사용 | 동일 |
| puppeteer 첫 실행 (Chrome 다운로드) | stderr에 "Chrome 다운로드 중 (1회만, ~200MB)" 안내 |
| 네트워크 차단 환경에서 puppeteer 실패 | PNG 생략, report.html만, report.md는 ASCII fallback |
| mockup HTML이 viewport보다 큼 | 고정 width clip — `body { width: 375/1280px; overflow: hidden }` |
| `mockups/_src/` 임시 폴더 | 렌더링 완료 후 자동 삭제 |
| 보고서 재생성 (같은 OUTPUT_DIR 재실행) | `mockups/` 비우고 시작 (stale PNG 방지) |

## Error Handling / UX

- 모든 비치명적 실패는 **degrade, 계속 진행** (기존 Graceful Degradation 정책 유지).
- 보고서 TL;DR 아래에 **렌더링 상태 배지** 1줄:
  - `✓ Mockups rendered with project tokens`
  - `⚠ Mockups rendered with neutral defaults (no tokens found)`
  - `⚠ Mockups available in report.html only (PNG generation failed)`
- 치명적 실패만 사용자에게 직접 알림.

## Testing

### 스크립트 단위 (자동화)
- `tests/fixtures/tokens-css-vars/` — CSS `:root` 형태 fixture
- `tests/fixtures/tokens-tailwind/` — tailwind.config.js fixture
- `tests/fixtures/tokens-empty/` — 토큰 없음 fixture
- `tests/extract-tokens.test.sh` — 3 fixture 모두에 대해 추출 결과 검증
- `tests/render.test.sh` — 작은 HTML 입력 → PNG 출력 존재 검증

### End-to-end (수동)
- 시나리오 1: 헤드리스 브라우저 있음 + tokens 있음 → full path
- 시나리오 2: 헤드리스 브라우저 없음 → puppeteer fallback
- 시나리오 3: tokens 없음 → neutral + 경고 배지
- 시나리오 4: `platforms: [mobile]` → desktop 생략, single layout

각 시나리오에서 `.bench/.../report.html`을 브라우저로 직접 열어 시각 검증.

## Success Criteria

- 7개 파일 변경 적용 후 실제 프로젝트에서 `/design-bench` 실행 →
  `.bench/.../report.html` 을 브라우저에서 열었을 때 mockup이 ASCII가 아닌
  시각적 UI 컴포넌트로 렌더링됨.
- `report.md` 를 GitHub/뷰어에서 열었을 때 PNG로 mockup 확인 가능.
- 토큰이 있는 프로젝트는 mockup이 해당 브랜드 색·타이포로 렌더링됨.
- 토큰·헤드리스 브라우저가 없는 환경에서도 보고서는 끝까지 생성됨
  (degrade하되 실패하지 않음).

## Open Questions

- `mockup-examples.md` 의 초기 예시 3–5개를 어떤 카테고리에서 가져올지
  (pricing, onboarding, dashboard, list, settings 중) — 구현 단계에서
  결정.
- `neutral default tokens` 의 구체 팔레트 — 구현 단계에서 결정
  (Tailwind neutral 기반 권장).
