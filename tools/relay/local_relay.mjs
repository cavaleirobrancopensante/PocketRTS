// The same relay as worker.js, for testing on one computer (no packages, node 18+):
//   node tools/relay/local_relay.mjs [port]      then use  ws://127.0.0.1:<port>  as the relay URL.
// Protocol: see worker.js.
import http from "node:http";
import crypto from "node:crypto";

const port = Number(process.argv[2] || 8787);
const rooms = new Map(); // CODE -> Map(id -> socket)

function frame(op, payload) {
  const n = payload.length;
  const head = n < 126 ? Buffer.from([0x80 | op, n]) : n < 65536 ? Buffer.from([0x80 | op, 126, n >> 8, n & 255])
    : (() => { const h = Buffer.alloc(10); h[0] = 0x80 | op; h[1] = 127; h.writeBigUInt64BE(BigInt(n), 2); return h; })();
  return Buffer.concat([head, payload]);
}
const sendText = (s, o) => s.write(frame(1, Buffer.from(typeof o === "string" ? o : JSON.stringify(o))));
const sendBin = (s, b) => s.write(frame(2, b));

const server = http.createServer((req, res) => res.end("Holdfast local relay\n"));
server.on("upgrade", (req, sock) => {
  const url = new URL(req.url, "http://x");
  const m = url.pathname.match(/^\/room\/([A-Za-z0-9]{3,12})$/);
  if (!m) { sock.destroy(); return; }
  const key = req.headers["sec-websocket-key"];
  const acc = crypto.createHash("sha1").update(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").digest("base64");
  sock.write(`HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: ${acc}\r\n\r\n`);
  const code = m[1].toUpperCase(), role = url.searchParams.get("role");
  const room = rooms.get(code) || new Map();
  let id = 0, err = "";
  if (role === "host") { if (room.has(0)) err = "That room code is already in use."; }
  else if (!room.has(0)) err = "No room with that code.";
  else { for (id = 1; id < 8 && room.has(id); id++); if (id >= 8) err = "The room is full."; }
  if (err) { sendText(sock, { t: "error", m: err }); sock.write(frame(8, Buffer.from([3, 232]))); sock.end(); return; }
  room.set(id, sock); rooms.set(code, room);
  sendText(sock, { t: "hello", id });
  if (id > 0) sendText(room.get(0), { t: "join", id });
  console.log(`[relay] ${code}: ${id === 0 ? "host" : "guest " + id} connected`);

  let buf = Buffer.alloc(0), frag = [], fop = 0;
  const handle = (op, data) => {
    if (op === 8) { sock.end(); return; }
    if (op === 9) { sock.write(frame(10, data)); return; }
    if (op === 1) { if (data.toString() === "ping") sendText(sock, "pong"); return; }
    if (op !== 2) return;
    if (id > 0) { const h = room.get(0); if (h) sendBin(h, Buffer.concat([Buffer.from([id]), data])); }
    else if (data.length > 0) for (const [sid, s] of room) if (sid > 0 && (data[0] === 0 || data[0] === sid)) sendBin(s, data.subarray(1));
  };
  sock.on("data", (d) => {
    buf = Buffer.concat([buf, d]);
    for (;;) {
      if (buf.length < 2) return;
      const fin = buf[0] & 128, op = buf[0] & 15, masked = buf[1] & 128;
      let len = buf[1] & 127, off = 2;
      if (len === 126) { if (buf.length < 4) return; len = buf.readUInt16BE(2); off = 4; }
      else if (len === 127) { if (buf.length < 10) return; len = Number(buf.readBigUInt64BE(2)); off = 10; }
      if (buf.length < off + (masked ? 4 : 0) + len) return;
      const mask = masked ? buf.subarray(off, off + 4) : null;
      if (masked) off += 4;
      const data = Buffer.from(buf.subarray(off, off + len));
      if (mask) for (let i = 0; i < len; i++) data[i] ^= mask[i & 3];
      buf = buf.subarray(off + len);
      if (op === 0) { frag.push(data); if (fin) { handle(fop, Buffer.concat(frag)); frag = []; } }
      else if (!fin) { fop = op; frag = [data]; }
      else handle(op, data);
    }
  });
  const gone = () => {
    if (room.get(id) !== sock) return;
    room.delete(id);
    console.log(`[relay] ${code}: ${id === 0 ? "host" : "guest " + id} left`);
    if (id === 0) { for (const s of room.values()) { sendText(s, { t: "closed" }); s.end(); } rooms.delete(code); }
    else if (room.has(0)) sendText(room.get(0), { t: "leave", id });
  };
  sock.on("close", gone); sock.on("error", gone);
});
server.listen(port, () => console.log(`[relay] listening on ws://127.0.0.1:${port}`));
