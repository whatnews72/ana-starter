# ANA Agent 자동화 설정 대화기록
**날짜:** 2026년 8월 29일  
**주제:** HuggingFace Daily Papers 영단어 자동 추출 및 GitHub 배포 자동화

---

## 📋 목표
매일 HuggingFace의 daily papers 페이지에서 AI/로봇 관련 영어 단어 10개를 자동으로 추출하여:
- ANA 대시보드의 vocab에 추가
- 각 단어마다 논문 제목, 논문 링크(arXiv), 초록 2-4문장 포함
- data/vocab.json 변경사항을 GitHub에 자동 커밋/푸시
- GitHub Pages에서 자동 배포

---

## 🔍 진단 및 원인 분석

### 초기 문제점
1. **서버 다운 문제**
   - `daily-paper-vocab.bat`가 05:45에 실행될 때 server.js가 항상 실행 중이 아님
   - 같은 날 05:45 task는 성공 (vocab.json v92→93)
   - 06:00 push task는 "curl error 7" (connection refused) 발생
   - 서버는 사용자가 `start-ana.bat` 실행할 때만 기동

2. **Git 동기화 미흡**
   - data/vocab.json이 로컬에서 수정되지만 자동 커밋/푸시 없음
   - `sync-deploy.ps1`은 수동 전용 스크립트 (Task Scheduler에 미등록)

3. **GitHub Actions 무용지물**
   - `.github/workflows/auto-deploy.yml`이 GitHub 클라우드에서 실행
   - 로컬 PC의 data/vocab.json 변경을 절대 볼 수 없음 (구조적 설계 오류)

---

## ✅ 구현된 해결책

### 1️⃣ 서버 자동 시작 (ensure-server.bat)
```batch
@echo off
rem 서버가 실행 중인지 확인 (http://127.0.0.1:8777/api/state 프로브)
rem 응답 없으면 node server.js 자동 시작
rem 최대 10초 대기 후 응답 확인
```
- `daily-paper-vocab.bat`와 `daily-vocab-push.bat` 시작 시 호출
- 서버가 다운되어도 자동으로 재시작

### 2️⃣ Windows Task Scheduler 자동화
**생성된 두 개의 새 Task:**

#### 📌 ANA Server Autostart
- **트리거:** 시스템 시작 시
- **작업:** `autostart-server.bat` 실행
- **목적:** 시스템 재부팅 시 자동으로 서버 시작

#### 📌 ANA Vocab Git Sync
- **트리거:** 매일 05:50 (UTC)
- **작업:** `powershell -File sync-deploy.ps1` 실행
- **목적:** 단어 추가 5분 후 git 커밋/푸시 (05:45 → 05:50)
- **로그:** `logs/sync-deploy.log`

### 3️⃣ 로깅 및 오류 추적 강화

**수정 파일들:**
- `daily-vocab-push.bat`: curl 응답을 `logs/daily-vocab-push.log`에 기록 (이전: `-o NUL`로 버림)
- `daily-paper-vocab-prompt.txt`: curl 응답 검증 강제 (HTTP 200 확인)
- `sync-deploy.ps1`: 파일 기반 로깅 추가 (Task Scheduler 비대화형 실행용)

### 4️⃣ GitHub Action 제거
- `.github/workflows/auto-deploy.yml` 삭제
- 로컬에서 생성된 데이터만 커밋/푸시하므로 필요 없음

---

## 🛠️ 신규 생성 파일

| 파일명 | 용도 |
|--------|------|
| `ensure-server.bat` | 서버 자동 시작/체크 로직 |
| `autostart-server.bat` | Task Scheduler 시스템 시작 트리거용 |
| `create-server-autostart-task.ps1` | PowerShell 스크립트: "ANA Server Autostart" Task 생성 |
| `create-vocab-sync-task.ps1` | PowerShell 스크립트: "ANA Vocab Git Sync" Task 생성 |
| `setup-automation-tasks.bat` | Task 생성 통합 배치 파일 |

---

## 🧪 테스트 및 검증 결과

### Test 1: ensure-server.bat 동작 확인 ✅
```
서버 체크 + 자동 시작 로직 작동 완료
현재 node 프로세스 확인됨 (PID: 23364, 메모리: 43MB)
```

### Test 2: daily-vocab-push.bat 로깅 ✅
```
[2026-08-29 15:57:57.38] Attempting vocab push...
{"ok":true,"due":107,"subs":3}
[HTTP Status: 200]
```

### Test 3: data/vocab.json 변경 ✅
```
변경사항: 142줄 추가 (새 단어 10개 포함)
마지막 커밋: 8115f8f (이전 상태)
```

### Test 4: daily-paper-vocab.bat 구조 검증 ✅
```
- ensure-server 호출 확인
- headless Claude 세션 설정 확인
- 새 단어 추가 완료
```

### Test 5: Scheduled Task 생성 ✅
```
PowerShell 스크립트 실행 (관리자 권한):
✓ ANA Server Autostart 생성 완료
✓ ANA Vocab Git Sync 생성 완료
```

### Test 6: End-to-End 자동화 체인 ✅
```
schtasks /run /tn "ANA Daily Paper Vocab"
  → 성공: HF papers에서 단어 10개 추출
  
schtasks /run /tn "ANA Vocab Git Sync"
  → 성공: git add/commit/push 완료
  → 커밋 ID: 2b4a0b2
  → 푸시 대상: https://github.com/whatnews72/ana-starter.git
  
schtasks /run /tn "ANA Vocab Daily Push"
  → 성공: HTTP 200 응답
```

### Test 7: GitHub 배포 ✅
```
✅ 새 단어들 GitHub에 표시됨
✅ 각 단어마다 논문 제목 표시
✅ 각 단어마다 arXiv 링크 표시
✅ 각 단어마다 초록 2-4문장 표시
✅ GitHub Pages에 실시간 배포됨
   https://whatnews72.github.io/ana-starter/
```

---

## 📊 최종 상태

### 등록된 Scheduled Task

| Task명 | 트리거 | 작업 | 상태 |
|--------|--------|------|------|
| ANA Server Autostart | 시스템 시작 | `autostart-server.bat` | ✅ 활성 |
| ANA Daily Paper Vocab | 매일 05:45 | `daily-paper-vocab.bat` | ✅ 활성 (기존) |
| ANA Vocab Git Sync | 매일 05:50 | `sync-deploy.ps1` | ✅ 활성 (신규) |
| ANA Vocab Daily Push | 매일 06:00 | `daily-vocab-push.bat` | ✅ 활성 (기존) |

### 로그 파일 위치

| 로그 | 경로 | 용도 |
|------|------|------|
| 서버 로그 | `logs/server.log` | node server.js 실행 로그 |
| 단어 추출 로그 | `logs/daily-paper-vocab.log` | headless Claude 세션 로그 |
| Git 동기화 로그 | `logs/sync-deploy.log` | git add/commit/push 로그 |
| 푸시 로그 | `logs/daily-vocab-push.log` | 외부 API 호출 로그 |

---

## 🚀 자동화 흐름

```
시간          작업                  담당 파일            결과
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[시스템 시작]  서버 자동 시작         autostart-server.bat  server.js 기동
                                                          (포트 8777)

05:45        영단어 추출             daily-paper-vocab.bat  data/vocab.json
             (HF papers)             + ensure-server.bat    수정 (+10개)
             + Claude headless       + daily-paper-vocab-   
             세션                    prompt.txt

05:50        Git 동기화              sync-deploy.ps1        GitHub에
             (커밋/푸시)             + ensure-server.bat    커밋/푸시

06:00        외부 알림               daily-vocab-push.bat   서버가
             (API POST)              + ensure-server.bat    HTTP 200 반환

[다음 날까지] GitHub Pages 배포                              웹사이트 업데이트
                                                          https://whatnews72.
                                                          github.io/ana-starter/
```

---

## 💡 주요 개선사항

### 이전
❌ 서버 다운 시 단어 추가 실패  
❌ 커밋/푸시 수동만 가능  
❌ GitHub Action이 로컬 변경 감지 불가  
❌ 오류 추적 어려움 (silent fail)

### 현재
✅ 서버 자동 시작/복구  
✅ 매일 자동 커밋/푸시 (05:50)  
✅ 로컬에서 생성된 데이터 즉시 GitHub에 반영  
✅ 상세한 로깅 (각 step별 기록)  
✅ 명확한 FAIL 메시지 (grep 검색 가능)

---

## 📝 사용자 피드백 이력

1. **PowerShell 권한 문제 해결**
   - 요청: "별도의 .ps1 파일로 저장한 뒤 그 파일을 실행하는 방식으로"
   - 구현: `create-server-autostart-task.ps1`, `create-vocab-sync-task.ps1` 생성
   - 실행: `powershell -ExecutionPolicy Bypass -File "path\script.ps1"`

2. **경로 문제 해결**
   - 문제: 한글 경로에 공백이 있어 직접 실행 시 오류
   - 해결: 모든 경로를 따옴표로 감싸기 `"경로"`

3. **테스트 완료**
   - 자동화 체인 end-to-end 검증 완료
   - 모든 로그 확인 완료
   - GitHub Pages 배포 확인 완료

---

## ✨ 결론

**ANA Agent의 영단어 자동화 시스템이 완벽하게 구축되었습니다!**

- ✅ 매일 자동으로 새로운 AI/로봇 관련 영단어 10개 추가
- ✅ 각 단어마다 논문 정보(제목, 링크, 초록) 포함
- ✅ GitHub에 자동 커밋/푸시
- ✅ GitHub Pages에 자동 배포
- ✅ 서버 자동 시작/복구
- ✅ 상세한 로깅 및 오류 추적

**내일부터는 특별한 조작 없이 매일 05:45에 자동으로 작동합니다!** 🚀

---

*작성자: Claude Code (claude.ai/code)*  
*최종 검증: 2026-08-29 16:35:51*
