# ANA Design System

이 패키지는 비서 업무 현황판의 디자인 시스템입니다.

## Files

- `design-tokens.css`: 색상, 크기, 레이아웃, 버튼, 카드, 시트, 채팅, 그래프 등 UI 전체 스타일
- `DESIGN_SYSTEM.md`: 사용 안내

## Usage

HTML에서 아래처럼 불러옵니다.

```html
<link rel="stylesheet" href="design-tokens.css">
```

디자인 값은 `:root` CSS 변수에서 관리합니다. 색상, 라운드, 그림자, 채널 색상, 상태 색상, 레이아웃 상수를 바꾸면 전체 UI가 함께 반영됩니다.

## Main Token Groups

- Surface/Text: `--bg`, `--surface`, `--text`, `--line`
- Brand/State: `--blue`, `--green`, `--danger`, `--success`
- Channel: `--ch-hiworks-*`, `--ch-gmail-*`, `--ch-slack-*`
- Shape: `--r-xl`, `--r-lg`, `--r`, `--r-sm`, `--r-xs`
- Layout: `--header-h`, `--safe-b`
- Elevation: `--sh-card`, `--sh-fab`, `--sh-sheet`

## Notes

컴포넌트 스타일은 토큰을 우선 참조하도록 구성되어 있습니다. 새 UI를 추가할 때도 색상과 크기를 직접 하드코딩하기보다 기존 변수를 먼저 사용하세요.
