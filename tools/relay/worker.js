// PocketRTS relay: pairs players by room code and forwards bytes. It knows nothing about the game.
// Cloudflare Worker + one Durable Object per room (WebSocket hibernation API).
//
//   wss://<your-worker>.workers.dev/room/<CODE>?role=host    the host (one per room)
//   wss://<your-worker>.workers.dev/room/<CODE>?role=guest   a guest (up to 7)
//
// Binary frames carry the game. Host -> relay: [target byte, 0 = every guest] + payload.
// Guest -> relay: payload; the host receives [guest id byte] + payload. Text frames from the
// relay are small JSON notices ({"t":"hello"|"join"|"leave"|"closed"|"error"}); a client text
// "ping" is answered with "pong".
export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    const m = url.pathname.match(/^\/room\/([A-Za-z0-9]{3,12})$/);
    if (!m) return new Response("PocketRTS relay is running.\n");
    if (req.headers.get("Upgrade") !== "websocket") return new Response("WebSocket expected", { status: 426 });
    return env.ROOM.get(env.ROOM.idFromName(m[1].toUpperCase())).fetch(req);
  },
};

export class Room {
  constructor(state) { this.state = state; }

  async fetch(req) {
    const role = new URL(req.url).searchParams.get("role");
    const pair = new WebSocketPair();
    const [client, ws] = Object.values(pair);
    const all = this.state.getWebSockets();
    const idOf = (s) => (s.deserializeAttachment() || {}).id;
    const host = all.find((s) => idOf(s) === 0);
    let id = 0, err = "";
    if (role === "host") { if (host) err = "That room code is already in use."; }
    else if (!host) err = "No room with that code.";
    else {
      for (id = 1; id < 8 && all.some((s) => idOf(s) === id); id++);
      if (id >= 8) err = "The room is full.";
    }
    this.state.acceptWebSocket(ws);
    if (err) { ws.send(JSON.stringify({ t: "error", m: err })); ws.close(1000, err); return new Response(null, { status: 101, webSocket: client }); }
    ws.serializeAttachment({ id });
    ws.send(JSON.stringify({ t: "hello", id }));
    if (id > 0) host.send(JSON.stringify({ t: "join", id }));
    return new Response(null, { status: 101, webSocket: client });
  }

  webSocketMessage(ws, data) {
    if (typeof data === "string") { if (data === "ping") ws.send("pong"); return; }
    const id = (ws.deserializeAttachment() || {}).id;
    const socks = this.state.getWebSockets();
    const bytes = new Uint8Array(data);
    if (id > 0) {                                   // guest -> host, tagged with the guest's id
      const host = socks.find((s) => (s.deserializeAttachment() || {}).id === 0);
      if (host) { const out = new Uint8Array(bytes.length + 1); out[0] = id; out.set(bytes, 1); host.send(out); }
    } else if (bytes.length > 0) {                  // host -> one guest or all
      const out = bytes.slice(1);
      for (const s of socks) { const sid = (s.deserializeAttachment() || {}).id; if (sid > 0 && (bytes[0] === 0 || bytes[0] === sid)) s.send(out); }
    }
  }

  webSocketClose(ws) {
    const id = (ws.deserializeAttachment() || {}).id;
    const socks = this.state.getWebSockets().filter((s) => s !== ws);
    if (id === 0) socks.forEach((s) => { s.send(JSON.stringify({ t: "closed" })); s.close(1000, "host left"); });
    else if (id > 0) socks.filter((s) => (s.deserializeAttachment() || {}).id === 0).forEach((h) => h.send(JSON.stringify({ t: "leave", id })));
  }

  webSocketError(ws) { this.webSocketClose(ws); }
}
