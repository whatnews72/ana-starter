<div align="center">

<img src="docs/assets/logo.png" width="88" alt="ANA Starter logo" />

# ANA Starter

### 말하는 것으로 키우는, 바로 실행 가능한 Agent‑Native App.

[![Use this template](https://img.shields.io/badge/use%20this%20template-ana--starter-2F6BFF?style=for-the-badge&logo=github)](https://github.com/tykimos/ana-starter/generate)
[![Stars](https://img.shields.io/github/stars/tykimos/ana-starter?style=for-the-badge&logo=github&color=2F6BFF)](https://github.com/tykimos/ana-starter/stargazers)
[![License: MIT](https://img.shields.io/badge/License-MIT-1f6feb?style=for-the-badge)](LICENSE)
[![Built for Claude Code](https://img.shields.io/badge/built%20for-Claude%20Code-CC785C?style=for-the-badge)](https://claude.com/claude-code)

[English](README.md) · **한국어**

<br/>

![ANA Starter — 비서 · 메모 dashboards](docs/assets/hero.gif)

</div>

[**ANA**](https://github.com/tykimos/agent-native-agent) 앱 기본 템플릿입니다 — 레퍼런스 대시보드와 **동일한 룩앤필·로고·런타임**을 갖췄고, 빈 화면부터 시작하지 않도록 미리 배선돼 있습니다. 말하는 것으로 키우는 간단한 메뉴로 시작합니다:

```
비서 (Secretary)        메모 (Memo)
├─ 할일  (To-do)        ├─ 업무  (Work)
└─ 스케줄 (Schedule)     └─ 공부  (Study)
```

---

## 무엇이 담겨 있나

- **동일한 디자인 시스템** — `design-tokens.css`, ANA 로고, PWA 아이콘·manifest·service worker를 그대로 재사용.
- **ANA 런타임 브리지** — `server.js`(의존성 0 Node) + `fakechat-bridge.js`: 대시보드를 보면서, 코딩 에이전트와 대화하고, 변경을 승인하며, version 기반으로 전 기기 동기화.
- **깨끗한 시작 보드** — `data/state.json`에 카테고리별로 몇 개의 항목이 시드돼 있습니다. 지우고 당신의 것으로 만드세요.

## 실행

```bash
node server.js     # or: npm start   |   node start.js
# → http://localhost:8777   (override with PORT=)
```

`npm install` 불필요 — 서버는 Node 내장 모듈만 사용합니다(web‑push는 선택이며 `data/vapid.json` 없으면 비활성).

**GitHub Codespaces:** `node server.js` 실행 후 자동 포워딩된 **포트 8777**을 엽니다(Ports 탭 → 🌐 URL). 진입 파일은 `server.js` — `node start.js`·`npm start`도 됩니다. 로그인 없이 바로 대시보드가 열립니다.

> **공개 URL 보호:** 로그인 게이트는 **기본 OFF**입니다(개발/Codespaces가 바로 열리도록). 외부로 포워딩되는 트래픽에 접근 키를 요구하려면 `ANA_REQUIRE_AUTH=1 node server.js`로 실행하세요 — 키는 `data/auth.json`의 `password`(자동 생성)입니다.

## 말하는 것으로 키우기

이것은 **agent‑native** 앱입니다: 코딩 에이전트가 런타임입니다. 우하단 채팅을 열고 말하세요:

```
"할일에 '제안서 마감' 추가해줘"
"메모 > 공부에 오늘 읽은 논문 정리해줘"
"상단에 이번 주 완료 개수 배지 붙여줘"     # ← 앱 자체를 진화, 배포 없이
```

변경은 전/후 제안으로 도착하고, 승인하면 `version`이 올라가며 모든 기기가 동기화됩니다.

## 코딩 에이전트 연결 (전체 루프)

`node server.js`만 실행하면 **대시보드 + 채팅 UI**만 뜹니다 — 입력한 메시지는 큐에 쌓이지만 아직 답할 주체가 없습니다. converse 루프는 네 조각으로 이뤄집니다:

```
Dashboard → ② server.js(:8777) → ③ fakechat-bridge.js → ④ fakechat channel(:8787) → ⑤ Claude Code session
            └──────── 이 레포에 포함 ────────┘             └──── 런타임 환경(미번들) ────┘
```

| 조각 | 무엇 | 어디에 |
|---|---|---|
| ② `server.js` | 대시보드 + 채팅 인박스/피드/승인 API | ✅ 이 레포 |
| ③ `fakechat-bridge.js` | 인박스를 fakechat 채널로 릴레이 | ✅ 이 레포(실행 필요) |
| ④ **fakechat channel** (`:8787`) | 메시지를 Claude 세션에 푸시(MCP) | ⛭ Claude Code 플러그인/채널 |
| ⑤ **Claude Code session** | 대시보드를 읽고, 행동하고, `POST /api/agent`로 응답 | ⛭ 실행 중인 세션 |

**② + ③ 함께 실행:**

```bash
npm run all        # = bash run-all.sh  → server.js + fakechat-bridge.js
```

그다음 이 대시보드에 연결된 **fakechat 채널을 가진 Claude Code 세션**을 실행하면 루프가 완성됩니다. 그 세션이 곧 코딩 에이전트입니다 — 메시지를 받고 승인 가능한 리치 제안으로 답합니다. 필요하면 릴레이를 환경변수로 설정하세요: `DASH_URL`(기본 `http://127.0.0.1:8777`), `FAKECHAT_WS`(기본 `ws://127.0.0.1:8787/ws`).

> **Codespaces 참고:** Codespace는 대시보드는 잘 돌지만 기본적으로 그 안에 Claude 세션·fakechat 채널이 없습니다 — 채팅은 큐에 머뭅니다. 전체 루프는 로컬(Claude Code + fakechat 채널이 있는 곳)에서 돌리거나, 그것들을 Codespace 안으로 가져오세요. [ANA 하네스](https://github.com/tykimos/agent-native-agent) + `fakechat-dashboard-agent` 빌딩블록이 ④/⑤를 구성합니다.

## 구조

```
ana-starter/
├── index.html          # 대시보드 UI (비서·메모)  — IA는 여기서 편집
├── design-tokens.css   # 디자인 시스템 (색상 하드코딩 금지, 토큰 사용)
├── server.js           # 대시보드 + 채팅 브리지 (Node 내장 모듈만)
├── fakechat-bridge.js  # 코딩 에이전트 채널로의 인바운드 릴레이
├── logo.png · icon-*.png · manifest.json · service-worker.js   # PWA
└── data/state.json     # 당신의 항목 ({version, items:[...]})
```

**[ANA — Agent‑Native Agent](https://github.com/tykimos/agent-native-agent)**로 제작 · 라이프스타일 사례는 **[ANL](https://github.com/tykimos/agent-native-lifestyle)**.

> 이 스타터가 빈 화면의 수고를 덜어줬다면, 다른 사람도 찾을 수 있도록 **⭐ 스타**를 눌러주세요.

## 라이선스(License)

[MIT](LICENSE) © [tykimos](https://github.com/tykimos)
