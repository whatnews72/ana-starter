<div align="center">

# ANA Starter — 비서 · 메모

**A base [ANA](https://github.com/tykimos/agent-native-agent) app template.** Same look‑and‑feel and logo as the reference secretary dashboard — pre‑wired so you don't start from scratch.

Starts with a simple menu you can grow by talking:

</div>

```
비서 (Secretary)        메모 (Memo)
├─ 할일  (To-do)        ├─ 업무  (Work)
└─ 스케줄 (Schedule)     └─ 공부  (Study)
```

---

## What you get

- **Identical design system** — reuses `design-tokens.css`, the ANA logo, PWA icons, manifest, and service worker.
- **The ANA runtime bridge** — `server.js` (zero‑dependency Node) + `fakechat-bridge.js`: watch a dashboard, converse with a coding agent, approve changes, version‑synced across devices.
- **A clean starting board** — `데이터/state.json` seeded with a few items per category. Delete them and make it yours.

## Run

```bash
node server.js     # or: npm start   |   node start.js
# → http://localhost:8777   (override with PORT=)
```

No `npm install` needed — the server uses only Node built‑ins (web‑push is optional and stays disabled without `data/vapid.json`).

**GitHub Codespaces:** run `node server.js`, then open the auto‑forwarded **port 8777** (Ports tab → the 🌐 URL). The entry file is `server.js` — `node start.js` and `npm start` also work.

## Grow it by talking

This is an **agent‑native** app: the coding agent is the runtime. Open the chat (bottom‑right), and:

```
"할일에 '제안서 마감' 추가해줘"
"메모 > 공부에 오늘 읽은 논문 정리해줘"
"상단에 이번 주 완료 개수 배지 붙여줘"     # ← evolve the app itself, no deploy
```

Changes arrive as before/after proposals you approve; state bumps a `version` and every device syncs.

## Structure

```
ana-starter/
├── index.html          # the dashboard UI (비서·메모)  — edit the IA here
├── design-tokens.css   # design system (do not hardcode colors; use tokens)
├── server.js           # dashboard + chat bridge (Node built-ins only)
├── fakechat-bridge.js  # inbound relay to the coding-agent channel
├── logo.png · icon-*.png · manifest.json · service-worker.js   # PWA
└── data/state.json     # your items ({version, items:[...]})
```

Built with **[ANA — Agent‑Native Agent](https://github.com/tykimos/agent-native-agent)** · lifestyle cases in **[ANL](https://github.com/tykimos/agent-native-lifestyle)**.

## License

[MIT](LICENSE) © [tykimos](https://github.com/tykimos)
