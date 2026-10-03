# CLAUDE.md

이 파일은 Claude Code가 이 저장소에서 작업할 때 참고하는 안내서입니다. (문서는 한국어로 작성)


### 빠른 시작 — 로컬에서 실행하기

```bash
node server.js        # 대시보드 실행 http://localhost:8777
npm start             # (위와 동일)
npm run dev           # (위와 동일)
PORT=9000 node server.js  # 포트 변경
```

**`npm install` 불필요** — 서버는 Node.js 내장 모듈만 사용(`http`, `fs`, `path`, `crypto`). `data/vapid.json`이 없으면 선택적 의존성 `web-push`는 로드되지 않습니다.

**GitHub Codespaces:** `node server.js` 실행 후 자동 포워딩된 포트 8777 열기(Ports 탭 → 🌐 URL). 로컬에서는 로그인 필요 없음; 대시보드 직접 오픈.

**Windows (권장):** `start-ana.bat` 실행. 전체 스택 처리:
- `server.js` 시작 (포트 8777 대시보드)
- `fakechat-bridge.js` 시작 (포트 8798 릴레이)
- Claude Code 백그라운드 세션 시작 + fakechat 채널 연결
- Cloudflare 빠른 터널 시작
- 팝업에 외부 URL + 접근 키 표시

### 고급 아키텍처

**Agent-Native App (ANA)** — Claude Code 세션이 대시보드의 "두뇌" 역할. 5단계 루프:

```
① 대시보드 (index.html)  →  ② 서버 (server.js:8777)  →  ③ 릴레이 (fakechat-bridge.js)
                                                      ↓
                          ⑤ Claude Code 세션  ←  ④ fakechat 채널
```

**①②③은 이 저장소** — 로컬에서 실행. **④⑤는 런타임 환경** — Claude Code 플러그인 시스템 + 활성 세션.

**작동 방식:**
1. 대시보드 채팅창에 메시지 입력 (① → ②)
2. 릴레이가 fakechat 채널로 전달 (③ → ④)
3. Claude 세션이 메시지 읽고 행동 (⑤)
4. Claude가 `POST /api/agent`로 서버에 직접 답변 (⑤ → ②)
5. 대시보드 실시간 업데이트; 승인/거절
6. 데이터 버전 증가 + 모든 기기 동기화

**전통적 백엔드 로직 없음** — 코딩 에이전트 *자체가* 백엔드. "상단에 배지 추가"는 `index.html` 또는 `server.js` 직접 편집 후 대시보드에 승인 메시지로 응답.

### 프로젝트 구조

```
ana-starter/
├── index.html                # 전체 프론트엔드 SPA (677줄, 바닐라JS, PWA)
│                             # 탭: 비서, 메모, 영단어, 진화
├── server.js                 # 백엔드 (426줄, Node http, 의존성 0, JSON 데이터베이스)
├── fakechat-bridge.js        # 릴레이: 대시보드 채팅 → fakechat 채널 (수신만)
├── design-tokens.css         # 디자인 시스템 (41KB CSS 커스텀 프로퍼티 & 컴포넌트)
├── DESIGN_SYSTEM.md          # 디자인 토큰 문서
├── service-worker.js         # PWA 서비스 워커
├── manifest.json             # PWA 매니페스트
├── icon-*.png                # PWA 아이콘 (180, 192, 512)
├── logo.png                  # ANA 로고
│
├── data/                     # 런타임 "데이터베이스" (JSON 파일)
│   ├── state.json            # 보드 아이템 (gitignored; 사용자 개인 데이터)
│   ├── feed.json             # 채팅 받은편지함/메시지 (gitignored)
│   ├── vocab.json            # 라이트너 박스 단어 (gitignored 아님; CI가 자동 커밋)
│   ├── evolve.json           # 자기개선 제안
│   ├── auth.json             # 로그인 게이트 비밀: {password, token} (자동생성, gitignored)
│   ├── vapid.json            # 웹푸시 VAPID 키쌍 (활성화시, gitignored)
│   └── push_subs.json        # 푸시 구독 (gitignored)
│
├── logs/                     # 런타임 로그 (gitignored, 모두 UTF-8)
│   ├── server.log            # start-ana.bat / ensure-server.bat이 기록하는 서버 로그
│   ├── server.out.log        # autostart-server.bat(로그온 자동 시작)이 기록하는 서버 로그
│   ├── bridge.log
│   ├── tunnel.log
│   ├── sync-deploy.log       # 05:50 git 동기화
│   ├── daily-paper-vocab.log # 05:45 단어 추가
│   ├── daily-vocab-push.log  # 06:00 푸시
│   └── ...
│
├── .devcontainer/
│   └── devcontainer.json     # GitHub Codespaces 설정 (Node 20, 포트 8777 포워딩)
│
├── Windows 자동화 스크립트:
│   ├── start-ana.bat         # 전체 스택 실행 (메인 진입점)
│   ├── ensure-channel.ps1    # Claude 백그라운드 세션 시작 + fakechat 채널
│   ├── start-tunnel.ps1      # Cloudflare 빠른 터널 시작
│   ├── daily-paper-vocab.bat # 예약 작업: HF 논문 가져오기, 단어 10개 추가
│   ├── daily-vocab-push.bat  # 예약 작업: POST /api/vocab/push-today
│   ├── sync-deploy.ps1       # 예약 작업(05:50): data/vocab.json을 git 커밋/푸시 (GitHub Pages 재배포)
│   ├── ensure-server.bat     # 서버가 꺼져 있으면 기동 (예약 작업 bat들이 호출)
│   ├── autostart-server.bat  # 로그온 시 서버 기동 (ANA Server Autostart 작업)
│   ├── create-*-task.ps1     # 작업 스케줄러 등록 스크립트 (관리자 권한 필요)
│   ├── setup-automation-tasks.bat # 위 등록 스크립트 일괄 실행 (관리자 권한)
│   └── show-tunnel-popup.ps1 # 외부 URL + 접근 키 팝업 표시
│
├── run-all.sh                # Bash: server.js + fakechat-bridge.js 함께 실행
├── start.js                  # Node 편의 래퍼 (server.js용)
├── package.json              # NPM 메타데이터 (스크립트, 선택적 web-push)
├── LICENSE                   # AGPL-3.0
├── COMMERCIAL.md             # 상업 라이선스 조건
├── README.md / README.ko.md   # 메인 프로젝트 문서
└── .claude/settings.json     # Claude Code 프로젝트 설정
```

### 데이터 모델

**보드 아이템** (`data/state.json`):
```json
{
  "version": 5,
  "items": [
    {
      "id": "sec-1",
      "board": "secretary",      // "secretary" 또는 "memo"
      "channel": "schedule",     // 소채널: "todo", "schedule", "work", "study"
      "title": "제안서 제출",
      "sender": "you",
      "priority": "high",        // "low", "normal", "high"
      "due": "2026-08-30",       // YYYY-MM-DD
      "done": false,
      "summary": "월말까지 Q3 제안서 완료"
    }
  ]
}
```

**채팅 피드** (`data/feed.json`):
```json
{
  "messages": [
    {"id": 1, "sender": "you", "text": "할일 추가해줘", "ts": 1693478400},
    {"id": 2, "sender": "agent", "text": "완료!", "ts": 1693478410}
  ],
  "requests": [
    {"id": "dash-1", "text": "할일에 제안서 마감 추가해줘", "status": "new", "ts": 1693478400}
  ],
  "nextMsg": 3,
  "nextReq": 2
}
```

**영단어** (`data/vocab.json`, 라이트너 박스 간격 반복):
```json
{
  "version": 12,
  "words": [
    {
      "id": "vocab-1",
      "word": "diligent",
      "meaning": "부지런한",
      "example": "She is diligent about her studies.",
      "exampleKo": "그녀는 공부에 부지런하다.",
      "box": 2,          // 라이트너 박스 단계 (1-6)
      "streak": 3,       // 연속 정답 횟수
      "nextReview": "2026-08-30",
      "paperTitle": "대규모 학습",
      "paperUrl": "https://arxiv.org/abs/2026.12345",
      "paperAbstract": "이 논문은..."
    }
  ]
}
```

**서버 API** (부분; 전체는 `server.js` 참조):

| 엔드포인트 | 메서드 | 목적 |
|-----------|--------|------|
| `/` | GET | 정적 `index.html` 서빙 |
| `/api/state` | GET | 보드 상태 (아이템, 버전) |
| `/api/feed` | GET | 채팅 피드 (메시지, 요청) |
| `/api/vocab` | GET | 단어 목록 (오늘 복습 대상) |
| `/api/agent` | POST | **에이전트 답변** `{reqId, text, diff?}` |
| `/api/apply` | POST | 승인된 변경사항 적용 |
| `/api/evolve` | POST | 자기개선 제안 등록 |
| `/api/vocab/add` | POST | 영단어 추가 (승인 불필요) |
| `/api/vocab/update` | POST | 기존 단어 뜻/예문 수정 |
| `/api/vocab/push-today` | POST | 오늘 복습 단어를 외부 서비스로 푸시 |
| `/api/inbox-wait` | GET | 새 메시지 대기 (릴레이용 롱폴) |
| `/api/stream` | GET | Server-Sent Events (SSE) 실시간 동기화 |
| `/api/login` | POST | 인증 게이트 (`ANA_REQUIRE_AUTH=1`시) |

### 개발 & 테스팅

**테스트 프레임워크 없음, 린터 없음, 빌드 단계 없음.**

- **프론트엔드**: `index.html` 편집, 브라우저 새로고침. 클라이언트 바닐라JS가 `/api/*` 엔드포인트 상태 모두 렌더링.
- **백엔드**: `server.js` 편집, 서버 재시작 (`npm start` 또는 `node server.js`).
- **통합 테스트**:
  1. `npm start` 실행 (또는 `npm run all` 전체 스택)
  2. 브라우저에서 `http://localhost:8777` 열기
  3. 대시보드 채팅창에 메시지 입력
  4. Claude Code의 fakechat 채널에서 도착한 메시지 확인
  5. 대시보드에서 결과 제안 승인/거절

**디자인 시스템**: `design-tokens.css` (CSS 커스텀 프로퍼티) 또는 `DESIGN_SYSTEM.md` 편집. 모든 UI는 토큰 참조 (`--bg`, `--surface`, `--blue-500` 등), 절대 하드코드 색상 금지.

### 배포 & CI/CD

**로컬 (주요 사용):**
- `start-ana.bat` (Windows) 또는 `npm run all` (모든 OS) 실행해 ②③ 시작
- Claude Code를 fakechat 채널 연결 후 실행해 ④⑤ 완료
- `http://localhost:8777` 또는 Cloudflare 빠른 터널 (run `start-tunnel.ps1` 외부 URL + 접근 키)

**일일 자동화 (Windows 작업 스케줄러, 로컬 시간):**
- 05:45 `ANA Daily Paper Vocab` — HF 논문에서 단어 10개 추출 → `/api/vocab/add` (서버가 중복 단어를 자동 skip)
- 05:50 `ANA Vocab Git Sync` — `sync-deploy.ps1`이 `data/vocab.json` 커밋/푸시 → GitHub Pages 반영 (로그: `logs/sync-deploy.log`)
- 06:00 `ANA Vocab Daily Push` — `/api/vocab/push-today` 푸시 알림
- `ANA Vocab Git Sync`는 `RunLevel Limited`로 등록해야 한다. `Highest`(관리자 토큰)면 Git Credential Manager가 일반 세션의 자격 증명을 읽지 못해 `git push`가 `Unable to persist credentials with the 'wincredman'`로 실패한다 (2026-10-04 05:50 사례). 기존 `Highest` 작업은 관리자 권한 PowerShell에서 `create-vocab-sync-task.ps1`을 다시 실행해야 바뀐다
- 작업 등록 시 반드시 `WorkingDirectory`를 지정할 것 (미지정 시 cwd=System32라 상대경로가 깨짐)
- 세 작업 모두 `StartWhenAvailable=True`, `DisallowStartIfOnBatteries=False`여야 한다. PC가 꺼져 있던 시각의 실행을 켠 직후 만회하고 배터리에서도 실행된다 (2026-10-03 전까지 Paper Vocab/Push는 꺼져 있어 PC가 꺼진 날 누락됨). 확인: `Get-ScheduledTask -TaskName 'ANA*' | Select TaskName,@{n='Catchup';e={$_.Settings.StartWhenAvailable}}`
- 로그는 UTF-8로 기록한다. PowerShell 5.1에서 `Tee-Object`/`Out-File`/`>`는 UTF-16이 되므로 `Add-Content -Encoding UTF8`을 쓰고, 읽을 때도 `Get-Content -Encoding UTF8`을 지정한다 (기본 인코딩으로 읽으면 정상 UTF-8 로그도 깨져 보임)
- git 네이티브 명령의 stderr(경고·진행 메시지)는 PS 5.1에서 `NativeCommandError`로 기록되므로 `2>&1 | ForEach-Object { "$_" }`로 문자열화하고 성공 여부는 `$LASTEXITCODE`로 판단한다 (`sync-deploy.ps1`의 `Invoke-Git`)
- 일일 페이로드 JSON은 `logs/vocab_payload_<날짜>.json`에 쓴다 (저장소 루트 금지)
- GitHub Pages `https://whatnews72.github.io/ana-starter/` 서빙 (`main` 루트). GitHub Actions 워크플로는 사용하지 않음(로컬 데이터는 클라우드에서 볼 수 없음).

**GitHub Codespaces:**
- `.devcontainer/devcontainer.json` Node 20 이미지, 포트 8777 포워딩 제공
- `node server.js` 실행 후 포워딩된 포트 URL 열기
- 전체 루프는 Codespace 외부의 Claude 세션 + fakechat 채널 필요 (로컬 Claude Code에 위치)

**공개 접근 (선택사항):**
- `ANA_REQUIRE_AUTH=1 node server.js` — `data/auth.json`의 비밀번호 로그인 게이트 필요 (자동생성)
- 외부 포워딩 트래픽만 적용 (`cf-connecting-ip` 또는 `x-forwarded-for` 헤더 감지); 로컬/LAN은 열린 상태

### 흔한 작업

**영단어 추가** (승인 불필요, 직접 적용):
```bash
# 먼저 JSON을 파일에 쓰기 (Windows 한글 인코딩 문제 방지)
# 그 후 POST
curl -s -X POST http://localhost:8777/api/vocab/add \
  -H 'Content-Type: application/json' \
  --data-binary @payload.json

# payload.json:
# {"words":[
#   {"word":"diligent","meaning":"부지런한",
#    "example":"She is diligent about her studies.",
#    "exampleKo":"그녀는 공부에 부지런하다.",
#    "paperTitle":"대규모 학습","paperUrl":"https://arxiv.org/abs/...",
#    "paperAbstract":"..."}
# ]}
```

**앱 UI/동작 수정** (예: "상단에 배지 추가"):
1. `index.html` (프론트엔드) 또는 `server.js` (백엔드) 편집
2. 로컬 테스트
3. `/api/agent`로 텍스트 확인 전송: `{"reqId": N, "text": "적용했습니다"}`

**보드 아이템 추가** (대시보드 승인 필요):
- `/api/agent`에 `diff` → `add` 배열로 전송:
  ```
  {"reqId": N, "text": "할일 추가할까요?", 
   "diff": {"add": [{"id":"sec-2","board":"secretary","channel":"todo","title":"새 할일",...}]}}
  ```
- 사용자가 대시보드에서 승인 → 서버 적용 + 버전 증가

**보드 아이템 변경** (승인 필요):
- `/api/agent`에 `diff` → `update`로 전송:
  ```
  {"reqId": N, "text": "완료할까요?",
   "diff": {"update": [{"id":"sec-1","done":true}]}}
  ```

**공개 터널에서 로그인 게이트 활성화:**
```bash
ANA_REQUIRE_AUTH=1 node server.js
# data/auth.json의 접근 키 → { password: "...", token: "..." }
```

### 알려진 문제 / 정리 필요한 것

- 루트의 `daily_vocab_*.json`, `vocab_*payload*.json`, `server.log`, 깨진 이름의 `D:AI_Agent...vocab_payload.json`은 과거 잔재 파일이며 `.gitignore`로 제외됨(삭제해도 무방).
- 과거 `Tee-Object`로 만든 `logs/server.log`·`bridge.log`는 UTF-16이었으나 현재는 UTF-8로 변환·수정됨. 서버 실행 중이면 `logs/server.out.log`는 잠겨 있어 UTF-16 잔재가 남을 수 있음(서버 재시작 후 삭제 가능). `sync-deploy.log` 2026-08-29 이전 4줄은 이미 글자가 깨진 상태로 저장됨.

### 관련 저장소

- **업스트림 ANA 프레임워크**: [tykimos/agent-native-agent](https://github.com/tykimos/agent-native-agent) — Claude Code 스킬, 디자인 시스템, 아키텍처 원칙
- **ANA 라이프스타일 사례**: [tykimos/agent-native-lifestyle](https://github.com/tykimos/agent-native-lifestyle) — 사용 예시 및 패턴

---

## 런타임 지시사항 (Runtime Instructions for Brain Sessions)

다음 섹션은 기존 CLAUDE.md 콘텐츠입니다. fakechat 채널로 대시보드와 연결된 Claude 세션이 메시지를 받을 때의 작동 방식을 설명합니다.

### ANA Starter — 이 세션의 역할 (두뇌)

이 프로젝트는 fakechat 채널로 대시보드(`http://127.0.0.1:8777`)와 연결된 에이전트 네이티브 앱(ANA)이다.
`--channels plugin:fakechat@claude-plugins-official`로 기동된 세션이 채널 메시지를 받으면 이 앱의 **두뇌** 역할을 한다.

### 메시지가 도착하면

채널 메시지는 `<channel source="fakechat" message_id="dash-N">[태그 #N] 사용자 텍스트` 형태로 온다.
`message_id`(예: `dash-4`) 또는 텍스트의 `#N`에서 **reqId = N**을 뽑아낸다.

### 응답은 반드시 대시보드 API로 — 채널의 reply 툴 쓰지 않기

fakechat의 `reply`/`edit_message` 툴로 답하면 대시보드에는 아무것도 안 뜬다(채널 UI 전용). 대신 curl/fetch로 아래를 호출한다.

- **단순 답변**: `POST http://127.0.0.1:8777/api/agent`  body `{"reqId": N, "text": "답변 내용"}`
- **데이터 변경 제안** (전/후 미리보기 승인 카드로 표시됨, 직접 데이터 파일을 고치지 말 것):
  `POST http://127.0.0.1:8777/api/agent` body `{"reqId": N, "text": "이렇게 바꿀까요?", "diff": {"add":[...], "update":[...], "remove":[...]}}`
  사용자가 대시보드에서 승인하면 서버가 알아서 적용(version++)한다.
- **앱 기능/코드 자체를 바꿔달라는 요청**(예: "상단에 배지 추가해줘")이면: `server.js` / `index.html` 등을 **직접 Edit로 수정**하고 나서, `/api/agent`로 "적용했습니다" 텍스트 응답을 보낸다.

**중요(Windows): curl의 `-d`에 한글을 직접 넣지 말 것.** Windows Bash 환경에서 `-d '{"text":"한글..."}'`처럼 명령줄 인자에 직접 한글을 넣으면 인코딩이 깨져서 대시보드에 깨진 글자로 저장된다. 반드시 Write 툴로 JSON을 **파일에 먼저 쓴 뒤**, `curl -d @파일`로 보낼 것.

예시:
```bash
# 1) Write 툴로 UTF-8 JSON 파일 작성 (예: /tmp/agent_payload.json)
#    {"reqId": 4, "text": "오늘 날짜는 2026년 8월 7일입니다."}
# 2) 그 파일을 @로 참조해서 전송(명령줄에 한글을 직접 쓰지 않는다)
curl -s -X POST http://127.0.0.1:8777/api/agent \
  -H 'Content-Type: application/json' \
  --data-binary @/tmp/agent_payload.json
```

### 참고

- 현재 대시보드 데이터 조회: `GET http://127.0.0.1:8777/api/state`
- 아이템 스키마(`data/state.json`): `board`(secretary|memo), `channel`, `title`, `sender`, `priority`, `due`, `done`, `summary`
- 진화(자기개선) 제안 등록: `POST http://127.0.0.1:8777/api/evolve` body `{"proposal":{"type":"improve","title":"...","desc":"..."}}`

### 영단어 학습(라이트너 박스 복습)

- 조회: `GET /api/vocab` → `{version, words, due}` (`due` = 오늘 복습 대상, `nextReview <= 오늘`).
- 사용자가 "영단어 ~개 추가해줘" 처럼 요청하면 **승인 없이 바로** 추가한다(단어 추가는 위험도가 낮아 diff 제안 대상이 아님). **`example`은 자연스러운 새 예문 한 문장, `exampleKo`는 그 예문의 한국어 번역을 반드시 함께 채운다** (원문 논문 문장을 그대로 넣지 말고, 학습하기 쉬운 짧고 자연스러운 문장으로 만들 것). **2026-08-28부터는 모든 신규 단어에 `paperTitle`, `paperUrl`, `paperAbstract`를 반드시 포함한다** (학습 효과 향상 목적):
  `POST /api/vocab/add` body `{"words":[{"word":"diligent","meaning":"부지런한","example":"She is diligent about her studies.","exampleKo":"그녀는 공부에 부지런하다.","paperTitle":"논문 제목","paperUrl":"https://arxiv.org/abs/...","paperAbstract":"초록 2~4문장..."}]}` (파일 기반 curl 규칙 동일 적용 — 한글은 명령줄에 직접 넣지 말 것).
- 논문 정보 필드: `paperTitle`(논문 제목), `paperUrl`(논문을 찾을 수 있는 링크, 가능하면 arXiv abstract 링크), `paperAbstract`(초록 2~4문장 발췌, 500자 이내).
- 기존 단어의 뜻/예문/예문 해석을 고칠 땐 `POST /api/vocab/update` body `{"id":"...", "example":"...", "exampleKo":"..."}` (복습 상태 box/streak/nextReview는 건드리지 않음); 논문 정보를 고칠 때도 동일하게 `"paperTitle"`, `"paperUrl"`, `"paperAbstract"` 필드를 포함해서 전송 가능.
- 복습 정답/오답 반영, 단어 삭제는 **대시보드 UI(플래시카드/×버튼)에서 사용자가 직접** 한다 — 세션이 대신 호출하지 않는다.
- 이 아이템들은 `data/state.json`의 `items`와 별개(`data/vocab.json`)이므로 `/api/agent`의 `diff`(add/update/remove)로 다루지 않는다.
