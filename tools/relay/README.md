# Holdfast online relay

A tiny server that pairs two (or three) players by a room code and forwards their game messages. It
does not know anything about the game. The match itself runs on the host's device; the guest sends
orders and receives pictures of the match (see `docs/multiplayer_plan.md`).

It runs for free on Cloudflare Workers (one Durable Object per room). A playtest of an hour is a
few thousand billed requests against a free allowance of 100,000 a day.

## What the owner does, once (about 10 minutes)

1. Make a free account at https://dash.cloudflare.com/sign-up (no card needed).
2. Install Node.js (https://nodejs.org, the LTS version) if it is not on your computer.
3. Open a terminal in this folder (`tools/relay/`) and run:

       npx wrangler login
       npx wrangler deploy

   `wrangler login` opens a browser tab: press Allow. `wrangler deploy` uploads `worker.js` and prints
   an address like `https://pocketrts-relay.<your-name>.workers.dev`.
4. In the game: main menu, ONLINE, RELAY ADDRESS (the same field is under SETTINGS): paste the address.
   `https://...` or `wss://...` both work. Do this on every device (computer, phone, web) once.
5. Test: on one device press HOST A GAME (it shows a 4-letter room code), on the other press JOIN and
   type the code. The host picks map and mode and presses START.

If you want a different name than `pocketrts-relay`, change `name` in `wrangler.toml` before deploying.
Check that it runs: open the address in a browser; it says "Holdfast relay is running."

Nothing else is needed: GitHub Pages and the APK stay as they are. Both players must run the same
game version (the lobby refuses a different one and says which versions).

## Trying it on one computer (no account)

    node tools/relay/local_relay.mjs 8787      # prints ws://127.0.0.1:8787, needs only node
    tools/test_online.sh                       # host and guest processes, plays a short match through it

Use `ws://127.0.0.1:8787` as the relay address in the game to test with two windows.
The web build can only reach `wss://` addresses (it is served over https), the desktop and Android
builds can use `ws://` too.

## The protocol (for whoever changes it)

`wss://<host>/room/<CODE>?role=host` creates the room, `?role=guest` joins it (up to 7 guests).
Binary frames carry the game. Host to relay: first byte = the guest to send to (0 = all guests), then
the payload. Guest to relay: the payload; the host receives it with the guest's id (1 to 7) as the
first byte. Text frames from the relay are notices: `{"t":"hello","id":n}`, `{"t":"join","id":n}` and
`{"t":"leave","id":n}` (to the host), `{"t":"closed"}` (the host left), `{"t":"error","m":...}`.
A client text `ping` is answered with `pong`. Payloads are `NetCodec` messages
(`scripts/net/net_codec.gd`).

Rooms are not protected beyond the code (4 letters and digits): fine for playtests with a friend, not
for anything public. Room codes are forgotten when the host leaves.
