# ANA Starter — 이 세션의 역할 (두뇌)

이 프로젝트는 fakechat 채널로 대시보드(`http://127.0.0.1:8777`)와 연결된 에이전트 네이티브 앱(ANA)이다.
`--channels plugin:fakechat@claude-plugins-official`로 기동된 세션이 채널 메시지를 받으면 이 앱의 **두뇌** 역할을 한다.

## 메시지가 도착하면
채널 메시지는 `<channel source="fakechat" message_id="dash-N">[태그 #N] 사용자 텍스트` 형태로 온다.
`message_id`(예: `dash-4`) 또는 텍스트의 `#N`에서 **reqId = N**을 뽑아낸다.

## 응답은 반드시 대시보드 API로 — 채널의 reply 툴 쓰지 않기
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

## 참고
- 현재 대시보드 데이터 조회: `GET http://127.0.0.1:8777/api/state`
- 아이템 스키마(`data/state.json`): `board`(secretary|memo), `channel`, `title`, `sender`, `priority`, `due`, `done`, `summary`
- 진화(자기개선) 제안 등록: `POST http://127.0.0.1:8777/api/evolve` body `{"proposal":{"type":"improve","title":"...","desc":"..."}}`

## 영단어 학습(라이트너 박스 복습)
- 조회: `GET /api/vocab` → `{version, words, due}` (`due` = 오늘 복습 대상, `nextReview <= 오늘`).
- 사용자가 "영단어 ~개 추가해줘" 처럼 요청하면 **승인 없이 바로** 추가한다(단어 추가는 위험도가 낮아 diff 제안 대상이 아님). **`example`은 자연스러운 새 예문 한 문장, `exampleKo`는 그 예문의 한국어 번역을 반드시 함께 채운다** (원문 논문 문장을 그대로 넣지 말고, 학습하기 쉬운 짧고 자연스러운 문장으로 만들 것). **2026-08-28부터는 모든 신규 단어에 `paperTitle`, `paperUrl`, `paperAbstract`를 반드시 포함한다** (학습 효과 향상 목적):
  `POST /api/vocab/add` body `{"words":[{"word":"diligent","meaning":"부지런한","example":"She is diligent about her studies.","exampleKo":"그녀는 공부에 부지런하다.","paperTitle":"논문 제목","paperUrl":"https://arxiv.org/abs/...","paperAbstract":"초록 2~4문장..."}]}` (파일 기반 curl 규칙 동일 적용 — 한글은 명령줄에 직접 넣지 말 것).
- 논문 정보 필드: `paperTitle`(논문 제목), `paperUrl`(논문을 찾을 수 있는 링크, 가능하면 arXiv abstract 링크), `paperAbstract`(초록 2~4문장 발췌, 500자 이내).
- 기존 단어의 뜻/예문/예문 해석을 고칠 땐 `POST /api/vocab/update` body `{"id":"...", "example":"...", "exampleKo":"..."}` (복습 상태 box/streak/nextReview는 건드리지 않음); 논문 정보를 고칠 때도 동일하게 `"paperTitle"`, `"paperUrl"`, `"paperAbstract"` 필드를 포함해서 전송 가능.
- 복습 정답/오답 반영, 단어 삭제는 **대시보드 UI(플래시카드/×버튼)에서 사용자가 직접** 한다 — 세션이 대신 호출하지 않는다.
- 이 아이템들은 `data/state.json`의 `items`와 별개(`data/vocab.json`)이므로 `/api/agent`의 `diff`(add/update/remove)로 다루지 않는다.
