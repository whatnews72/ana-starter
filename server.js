/* =========================================================================
   대시보드 + 채팅 브리지 서버 (Node 내장 모듈만, 의존성 0)
   ------------------------------------------------------------------------
   - 정적 대시보드 서빙 + 채팅 브리지 API + 데이터 상태(JSON 파일)
   - 사용자 채팅 → inbox(요청) → 릴레이가 fakechat 채널로 전달 → Claude 세션
   - Claude 가 POST /api/agent 로 리치 응답(텍스트/제안) → 대시보드 표시
   - 사용자가 승인하면 서버가 데이터에 적용(+version 증가) → 모든 기기 동기화
   실행: node server.js   (PORT 환경변수로 포트 변경)
   ========================================================================= */
const http = require("http");
const fs = require("fs");
const path = require("path");

const ROOT = __dirname;
const PORT = process.env.PORT ? +process.env.PORT : 8777;
const DATA = path.join(ROOT, "data", "state.json");   // { version, items: [...] }
const FEED = path.join(ROOT, "data", "feed.json");     // { messages, requests, nextMsg, nextReq }

const MIME = { ".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8", ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml", ".png": "image/png", ".ico": "image/x-icon",
  ".pdf": "application/pdf", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".gif": "image/gif", ".webp": "image/webp", ".txt": "text/plain; charset=utf-8" };

function loadFeed() { try { return JSON.parse(fs.readFileSync(FEED, "utf8")); } catch (e) { return { messages: [], requests: [], nextMsg: 1, nextReq: 1 }; } }
function saveFeed(s) { fs.writeFileSync(FEED, JSON.stringify(s, null, 2)); }
function loadData() { try { return JSON.parse(fs.readFileSync(DATA, "utf8")); } catch (e) { return { version: 1, items: [] }; } }
function saveData(s) { fs.writeFileSync(DATA, JSON.stringify(s, null, 2)); }

let state = loadFeed();
let sseClients = [], inboxWaiters = [];
let agentStatus = { text: "", ts: 0 };   // 비서 진행 상황(입력 중/처리 중)

// ---- Web Push (PWA 푸시 알림) ----
const SUBS = path.join(ROOT, "data", "push_subs.json");
let webpush = null, VAPID = null;
try {
  webpush = require("web-push");
  VAPID = JSON.parse(fs.readFileSync(path.join(ROOT, "data", "vapid.json"), "utf8"));
  webpush.setVapidDetails(VAPID.subject, VAPID.publicKey, VAPID.privateKey);
} catch (e) { console.log("web-push 비활성:", e.message); }
const SYNCF = path.join(ROOT, "data", "sync.json");
function loadSync() { try { return JSON.parse(fs.readFileSync(SYNCF, "utf8")); } catch (e) { return {}; } }
function liveCount() { try { return (JSON.parse(fs.readFileSync(path.join(ROOT, "data", "state.json"), "utf8")).items || []).filter(i => !i.done).length; } catch (e) { return 0; } }
function saveSync(o) { try { fs.writeFileSync(SYNCF, JSON.stringify(o)); } catch (e) {} }
function loadSubs() { try { return JSON.parse(fs.readFileSync(SUBS, "utf8")); } catch (e) { return []; } }
function saveSubs(s) { try { fs.writeFileSync(SUBS, JSON.stringify(s)); } catch (e) {} }
function sendPush(payload) {
  if (!webpush || !VAPID) return;
  const data = JSON.stringify(payload); let subs = loadSubs(); let changed = false;
  subs.forEach(sub => {
    webpush.sendNotification(sub, data).catch(err => {
      if (err && (err.statusCode === 410 || err.statusCode === 404)) {
        subs = subs.filter(x => x.endpoint !== sub.endpoint); changed = true; saveSubs(subs);
      }
    });
  });
}

// ---- 접근 인증(외부 공개 URL 보호) ----
const crypto = require("crypto");
const AUTHF = path.join(ROOT, "data", "auth.json");
let AUTH;
try { AUTH = JSON.parse(fs.readFileSync(AUTHF, "utf8")); }
catch (e) {
  AUTH = { password: crypto.randomBytes(4).toString("hex"), token: crypto.randomBytes(24).toString("hex") };
  try { fs.writeFileSync(AUTHF, JSON.stringify(AUTH, null, 2)); } catch (_) {}
}
function authed(req) {
  const m = (req.headers.cookie || "").match(/(?:^|;\s*)ana_auth=([^;]+)/);
  if (m && m[1] === AUTH.token) return true;
  if (req.headers["x-ana-token"] === AUTH.token) return true;               // 헤더 토큰
  try {                                                                      // iframe용 URL 토큰(?t=) / 키(?k=)
    const u = new URL(req.url, "http://x");
    if (u.searchParams.get("t") === AUTH.token) return true;
    if (u.searchParams.get("k") === AUTH.password) return true;
  } catch (e) {}
  return false;
}
function viaProxy(req) { return !!(req.headers["cf-connecting-ip"] || req.headers["x-forwarded-for"]); }  // 외부(터널)만 true
const OPEN_PATHS = new Set(["/api/login", "/manifest.json", "/service-worker.js", "/design-tokens.css", "/icon-192.png", "/icon-512.png", "/favicon.ico"]);
// 정적 리소스(이미지·CSS·폰트·JS 등)는 인증 없이 서빙 — iframe 임베드 시 <img src>·<link> 등이 토큰 없이 요청되어 깨지는 것 방지. (민감한 /api·data/*.json 은 그대로 보호)
const OPEN_EXT = /\.(png|jpe?g|gif|svg|webp|ico|css|js|mjs|woff2?|ttf|otf|mp4|webm|mp3|wav)$/i;
const LOGIN_HTML = '<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><title>비서 현황판 · 로그인</title><link rel="manifest" href="/manifest.json"><meta name="theme-color" content="#2F6BFF"><meta name="apple-mobile-web-app-capable" content="yes"><style>body{margin:0;min-height:100dvh;display:grid;place-items:center;font-family:-apple-system,BlinkMacSystemFont,"Apple SD Gothic Neo",sans-serif;background:#F2F4F6;color:#191F28}.card{width:300px;max-width:84vw;background:#fff;border-radius:18px;box-shadow:0 8px 30px rgba(0,0,0,.08);padding:28px 24px;text-align:center}h1{font-size:18px;margin:0 0 4px}p{font-size:13px;color:#8B95A1;margin:0 0 18px}input{width:100%;height:48px;border:1.5px solid #E5E8EB;border-radius:12px;padding:0 14px;font-size:16px;box-sizing:border-box;outline:none}input:focus{border-color:#2F6BFF}button{width:100%;height:48px;margin-top:12px;border:0;border-radius:12px;background:#2F6BFF;color:#fff;font-size:15px;font-weight:800}.err{color:#E0342B;font-size:12.5px;margin-top:10px;min-height:16px}</style></head><body><div class="card"><h1>비서 업무 현황판</h1><p>접근 키를 입력하세요</p><input id="k" type="password" placeholder="접근 키" autocomplete="current-password"><button id="b">들어가기</button><div class="err" id="e"></div></div><script>const k=document.getElementById("k"),b=document.getElementById("b"),e=document.getElementById("e");async function go(){e.textContent="";try{const r=await fetch("/api/login",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({key:k.value})});if(r.ok){location.href="/";}else{e.textContent="키가 올바르지 않습니다.";}}catch(x){e.textContent="오류: "+x.message;}}b.onclick=go;k.addEventListener("keydown",ev=>{if(ev.key==="Enter")go();});k.focus();</script></body></html>';

function now() { return Date.now(); }
function broadcast(msg) { const data = "data: " + JSON.stringify(msg) + "\n\n"; sseClients = sseClients.filter(c => { try { c.write(data); return true; } catch (e) { return false; } }); }
function wakeInbox() {
  const pend = state.requests.filter(r => r.status === "new");
  if (!pend.length || !inboxWaiters.length) return;
  inboxWaiters.forEach(w => { clearTimeout(w.timer); try { w.res.writeHead(200, { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" }); w.res.end(JSON.stringify({ requests: pend })); } catch (e) {} });
  inboxWaiters = [];
}
function addMsg(msg) { msg.id = state.nextMsg++; msg.ts = now(); state.messages.push(msg); broadcast(msg); return msg; }

/* ---- 데이터 변경 적용 (제안 diff 또는 수동 편집) ---- */
function applyDiff(diff) {
  const s = loadData(); const summary = { added: 0, updated: 0, removed: 0 }; diff = diff || {};
  (diff.remove || []).forEach(id => { const b = s.items.length; s.items = s.items.filter(it => it.id !== id); if (s.items.length < b) summary.removed++; });
  (diff.update || []).forEach(u => { const it = s.items.find(x => x.id === u.id); if (it) { Object.assign(it, u); summary.updated++; } });
  (diff.add || []).forEach(a => { s.items.push(Object.assign({ id: a.id || ("a" + Date.now().toString(36) + Math.floor(Math.random() * 1e4).toString(36)), done: false }, a)); summary.added++; });
  s.version = (s.version || 1) + 1; saveData(s);
  return { summary, version: s.version };
}

function sendJson(res, code, obj) { const b = JSON.stringify(obj); res.writeHead(code, { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" }); res.end(b); }
function readBody(req, cb) { let d = ""; req.on("data", c => { d += c; if (d.length > 1e6) req.destroy(); }); req.on("end", () => { try { cb(d ? JSON.parse(d) : {}); } catch (e) { cb({}); } }); }

function handleApi(req, res, url) {
  const p = url.pathname;

  // 대시보드 데이터
  if (p === "/api/state" && req.method === "GET") return sendJson(res, 200, loadData());

  // 채팅 피드(+version 동기화). 폴링이 항상 이걸로 데이터 변화도 감지한다.
  if (p === "/api/feed" && req.method === "GET") {
    const since = +(url.searchParams.get("since") || 0);
    let ver = 1; try { ver = loadData().version || 1; } catch (e) {}
    const st = (now() - agentStatus.ts < 60000) ? agentStatus : { text: "", ts: 0 };  // 60초 내만 유효
    return sendJson(res, 200, { messages: state.messages.filter(m => m.id > since), version: ver, status: st, sync: loadSync() });
  }

  // 사내 인원 명부(전달 추천용)
  if (p === "/api/people" && req.method === "GET") {
    try { return sendJson(res, 200, JSON.parse(fs.readFileSync(path.join(ROOT, "data", "people.json"), "utf8"))); }
    catch (e) { return sendJson(res, 200, []); }
  }
  // 채널별 동기화 시각
  if (p === "/api/sync" && req.method === "GET") return sendJson(res, 200, loadSync());
  if (p === "/api/sync" && req.method === "POST") return readBody(req, b => {
    const sy = loadSync(); (Array.isArray(b.channels) ? b.channels : [b.channel || "all"]).forEach(ch => { sy[ch] = { last: b.ts || now() }; });
    saveSync(sy); return sendJson(res, 200, { ok: true });
  });

  // 접근 키 로그인 → 쿠키 발급
  if (p === "/api/login" && req.method === "POST") return readBody(req, b => {
    if (b && b.key && b.key === AUTH.password) {
      res.writeHead(200, { "Content-Type": "application/json; charset=utf-8",
        "Set-Cookie": "ana_auth=" + AUTH.token + "; HttpOnly; Path=/; Max-Age=7776000; SameSite=Lax" });
      return res.end(JSON.stringify({ ok: true }));
    }
    return sendJson(res, 401, { error: "invalid key" });
  });

  // PWA 푸시: VAPID 공개키
  if (p === "/api/vapid-public" && req.method === "GET")
    return sendJson(res, 200, { publicKey: VAPID ? VAPID.publicKey : null });
  // PWA 푸시: 구독 등록
  if (p === "/api/push-subscribe" && req.method === "POST") return readBody(req, b => {
    if (!b || !b.endpoint) return sendJson(res, 400, { error: "no subscription" });
    let subs = loadSubs(); if (!subs.find(x => x.endpoint === b.endpoint)) { subs.push(b); saveSubs(subs); }
    return sendJson(res, 200, { ok: true, count: subs.length });
  });
  // PWA 푸시: 발송(비서/리포트가 호출)
  if (p === "/api/push" && req.method === "POST") return readBody(req, b => {
    sendPush({ title: b.title || "비서 업무 현황판", body: b.body || "", url: b.url || "/", tag: b.tag || "ana" });
    return sendJson(res, 200, { ok: true, subs: loadSubs().length });
  });

  // 비서 진행 상황 표시(입력 중/처리 중) — 훅이 POST
  if (p === "/api/status" && req.method === "POST") return readBody(req, b => {
    agentStatus = { text: (b.text || "").toString().slice(0, 140), ts: now() };
    return sendJson(res, 200, { ok: true });
  });

  // 세션 활동/응답 미러 — 훅이 도구 활동·응답을 피드에 남김
  if (p === "/api/activity" && req.method === "POST") return readBody(req, b => {
    const txt = (b.text || "").toString().slice(0, 3500);
    if (!txt) return sendJson(res, 200, { ok: true, skip: true });
    const m = addMsg({ role: b.role || "system", kind: b.kind || "activity", text: txt });
    saveFeed(state); return sendJson(res, 200, { ok: true, id: m.id });
  });

  // 저지연 실시간(SSE). 터널이 버퍼링할 수 있으니 프론트는 폴링도 함께 돌릴 것.
  if (p === "/api/stream" && req.method === "GET") {
    res.writeHead(200, { "Content-Type": "text/event-stream; charset=utf-8", "Cache-Control": "no-store", "Connection": "keep-alive", "X-Accel-Buffering": "no" });
    res.write("retry: 3000\n\n");
    const since = +(url.searchParams.get("since") || 0);
    state.messages.filter(m => m.id > since).forEach(m => res.write("data: " + JSON.stringify(m) + "\n\n"));
    sseClients.push(res); req.on("close", () => { sseClients = sseClients.filter(c => c !== res); });
    return;
  }

  // 사용자 채팅 → 요청 큐(릴레이가 fakechat 으로 전달)
  if (p === "/api/chat" && req.method === "POST") return readBody(req, b => {
    const text = (b.text || "").toString().trim(); if (!text) return sendJson(res, 400, { error: "empty" });
    const reqId = state.nextReq++;
    state.requests.push({ id: reqId, text, status: "new", ts: now() });   // 비서에겐 전체 텍스트 전달
    const msg = { role: "user", kind: b.ref ? "itemref" : "text", text: b.ref ? (b.displayText || "") : (b.displayText || text), reqId };
    if (b.ref) { msg.ref = b.ref; msg.action = b.action || ""; }            // 피드 표시는 칩(text=질문만)
    const m = addMsg(msg); saveFeed(state); wakeInbox();
    agentStatus = { text: "메시지 받음 · 비서가 확인 중…", ts: now() };   // 대화 시작 즉시 '처리 중' 표시(툴 호출 전부터)
    return sendJson(res, 200, { ok: true, msgId: m.id, reqId });
  });

  // 새로고침 트리거 — 비서를 깨우고, 채팅엔 '시스템 호출' 스타일 메시지로 표시(일반 텍스트 아님)
  if (p === "/api/refresh" && req.method === "POST") return readBody(req, b => {
    const text = (b.text || "").toString().trim(); if (!text) return sendJson(res, 400, { error: "empty" });
    const reqId = state.nextReq++;
    state.requests.push({ id: reqId, text, status: "new", ts: now() });
    const m = addMsg({ role: "system", kind: "syscall", text: b.label || "채널 새로고침 호출", reqId });
    saveFeed(state); wakeInbox();
    agentStatus = { text: "새로고침 — 비서가 점검 중…", ts: now() };
    return sendJson(res, 200, { ok: true, reqId, msgId: m.id });
  });

  // 파일 첨부 업로드 → 채팅 요청으로 전달(비서가 경로로 읽음)
  if (p === "/api/upload" && req.method === "POST") return readBody(req, b => {
    if (!b.data) return sendJson(res, 400, { error: "no data" });
    const name = (b.name || "file").toString().replace(/[^\w.\-가-힣 ]/g, "_").slice(0, 80);
    try {
      const dir = path.join(ROOT, "data", "uploads"); fs.mkdirSync(dir, { recursive: true });
      const fp = path.join(dir, now() + "_" + name);
      fs.writeFileSync(fp, Buffer.from(b.data, "base64"));
      const reqId = state.nextReq++;
      const userText = (b.text || "").toString().slice(0, 4000);
      state.requests.push({ id: reqId, text: "[파일 첨부] " + name + "\n경로: " + fp + (userText ? "\n\n" + userText : ""), status: "new", ts: now() });
      const m = addMsg({ role: "user", kind: "text", text: (userText ? userText + "\n" : "") + "📎 " + name, reqId }); saveFeed(state); wakeInbox();
      agentStatus = { text: "파일 받음 · 비서가 확인 중…", ts: now() };
      return sendJson(res, 200, { ok: true, path: fp, msgId: m.id });
    } catch (e) { return sendJson(res, 500, { error: String(e) }); }
  });

  // 릴레이 롱폴: 새 요청이 올 때까지 최대 25초 대기
  if (p === "/api/inbox-wait" && req.method === "GET") {
    const pend = state.requests.filter(r => r.status === "new");
    if (pend.length) return sendJson(res, 200, { requests: pend });
    const w = { res, timer: null };
    w.timer = setTimeout(() => { inboxWaiters = inboxWaiters.filter(x => x !== w); try { sendJson(res, 200, { requests: [] }); } catch (e) {} }, 25000);
    inboxWaiters.push(w); req.on("close", () => { clearTimeout(w.timer); inboxWaiters = inboxWaiters.filter(x => x !== w); });
    return;
  }

  // Claude(두뇌)의 리치 응답: 텍스트 또는 diff 제안
  if (p === "/api/agent" && req.method === "POST") return readBody(req, b => {
    const r = state.requests.find(x => x.id === b.reqId);
    const hasDiff = b.diff && ((b.diff.add || []).length || (b.diff.update || []).length || (b.diff.remove || []).length);
    const m = addMsg({ role: "assistant", kind: hasDiff ? "proposal" : "text", text: b.text || "", diff: hasDiff ? b.diff : null, status: hasDiff ? "pending" : "info", reqId: b.reqId || null });
    if (r) r.status = hasDiff ? "proposed" : "done";
    saveFeed(state); return sendJson(res, 200, { ok: true, msgId: m.id });
  });

  // 수동 편집 즉시 적용 (제안 없이)
  if (p === "/api/apply" && req.method === "POST") return readBody(req, b => {
    const result = applyDiff(b.diff || {});
    const adds = (b.diff && b.diff.add) || [];
    if (adds.length) sendPush({ title: "새 업무 " + adds.length + "건", body: adds.map(a => a.title || a.sender || "항목").join(" · ").slice(0, 120), url: "/", count: liveCount() });
    return sendJson(res, 200, { ok: true, version: result.version, summary: result.summary });
  });

  // 상태 토글(예: 완료) — 서버 저장으로 모든 기기 공유
  if (p === "/api/done" && req.method === "POST") return readBody(req, b => {
    const s = loadData(); const it = s.items.find(x => x.id === b.id); if (!it) return sendJson(res, 404, { error: "not found" });
    it.done = !!b.done; s.version = (s.version || 1) + 1; saveData(s);
    return sendJson(res, 200, { ok: true, version: s.version, id: b.id, done: it.done });
  });

  // 아이템 처리 상태 갱신(비서가 처리 중 상황을 아이템에 기록) — 모든 기기 공유
  if (p === "/api/itemstatus" && req.method === "POST") return readBody(req, b => {
    const s = loadData(); const it = s.items.find(x => x.id === b.id);
    if (!it) return sendJson(res, 404, { error: "not found" });
    it.status = (b.status || "").toString().slice(0, 200);
    it.statusState = b.state || "doing";   // doing | ok | fail | wait
    if (it.status) { it.statusLog = (it.statusLog || []); it.statusLog.push({ ts: now(), text: it.status, state: it.statusState });
      if (it.statusLog.length > 12) it.statusLog = it.statusLog.slice(-12); }
    if (b.done !== undefined) it.done = !!b.done;
    s.version = (s.version || 1) + 1; saveData(s);
    return sendJson(res, 200, { ok: true, version: s.version });
  });

  // 사용자가 제안 승인/거절
  if (p === "/api/approve" && req.method === "POST") return readBody(req, b => {
    const m = state.messages.find(x => x.id === b.msgId);
    if (!m || m.kind !== "proposal" || m.status !== "pending") return sendJson(res, 400, { error: "invalid" });
    if (b.decision === "approve") {
      const result = applyDiff(m.diff); m.status = "applied";
      if (m.reqId) { const r = state.requests.find(x => x.id === m.reqId); if (r) r.status = "applied"; }
      addMsg({ role: "system", kind: "applied", text: "변경 적용 완료", version: result.version }); saveFeed(state);
      return sendJson(res, 200, { ok: true, applied: true, version: result.version });
    } else {
      m.status = "rejected"; if (m.reqId) { const r = state.requests.find(x => x.id === m.reqId); if (r) r.status = "rejected"; }
      addMsg({ role: "system", kind: "text", text: "변경을 취소했어요." }); saveFeed(state);
      return sendJson(res, 200, { ok: true, applied: false });
    }
  });

  return sendJson(res, 404, { error: "not found" });
}

function serveStatic(req, res, url) {
  let rel = decodeURIComponent(url.pathname); if (rel === "/") rel = "/index.html";
  const fp = path.normalize(path.join(ROOT, rel));
  if (!fp.startsWith(ROOT)) { res.writeHead(403); return res.end("forbidden"); }
  fs.readFile(fp, (err, data) => {
    if (err) { res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" }); return res.end("404"); }
    res.writeHead(200, { "Content-Type": MIME[path.extname(fp).toLowerCase()] || "application/octet-stream", "Cache-Control": "no-store" });
    res.end(data);
  });
}

// 접근 키(로그인) 게이트는 기본 OFF — 스타터/개발에선 바로 열려야 자연스럽다.
// 외부 공개(터널/Codespaces 공개 URL)를 보호하려면 ANA_REQUIRE_AUTH=1 로 켠다.
const REQUIRE_AUTH = process.env.ANA_REQUIRE_AUTH === "1";

http.createServer((req, res) => {
  const url = new URL(req.url, "http://localhost");
  // 켜져 있을 때만: 외부(프록시) 접속에 접근 키 요구 — 로컬(브릿지·훅·curl)은 통과
  if (REQUIRE_AUTH && viaProxy(req) && !OPEN_PATHS.has(url.pathname) && !OPEN_EXT.test(url.pathname) && !authed(req)) {
    if (url.pathname.startsWith("/api/")) return sendJson(res, 401, { error: "auth required" });
    res.writeHead(200, { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store" });
    return res.end(LOGIN_HTML);
  }
  if (url.pathname.startsWith("/api/")) return handleApi(req, res, url);
  return serveStatic(req, res, url);
}).listen(PORT, () => console.log("dashboard+bridge server on http://localhost:" + PORT));

setInterval(() => { sseClients = sseClients.filter(c => { try { c.write(":ping\n\n"); return true; } catch (e) { return false; } }); }, 20000);
