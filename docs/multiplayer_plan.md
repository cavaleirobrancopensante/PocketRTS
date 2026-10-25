# Multiplayer plan (online 1v1 and online 2v1 co-op vs the AI)

Status: feasibility only. Nothing online is built. Hot-seat was dropped by the owner.
Goals: web build (GitHub Pages) and Android APK playing together, 1v1 and two humans vs one AI,
for playtesting with a friend. No paid server.

## 1. How deterministic is the sim today? (measured)

`tools/test_determinism.gd` plays Hard Crown vs Hard Brood on a fixed map and seed and prints a state
hash (every unit's kind/team/position/hp, every building, gold) every 10 game seconds. Run twice,
same machine, same binary, same seed, `seed()` called on the global RNG too:

    t=10 s  identical     t=20 s  identical     t=30 s  DIVERGED (and stays diverged)

So the sim is **not deterministic now**, not even on one machine. Causes found by reading the code:

- **Unseeded global RNG, shared with cosmetics.** About 110 `randf()/randi()` calls in sim files
  (game.gd 43, ai.gd 40, unit.gd 33, building.gd 24, building_life.gd). Only `Game.rng` is seeded
  (map, props); the rest use the global generator. Hit rolls (`randf() < 0.85` in game.gd), horse
  bolting, musket cooldown jitter, scatter of orders, AI choices and purely visual jitter (smoke,
  float text) all draw from the same stream. Anything drawn only on screen (culled by
  `view_rect`, `visible`) shifts the stream differently on each device.
- **Wall-clock in the sim.** The path queue (game.gd, `_tick_game`) stops after 6 ms of real time
  once 18 paths are done, so which unit gets its path on which tick depends on CPU speed. Fatal
  for lockstep on a phone vs a browser.
- **Per-node processing order.** Units, buildings, projectiles and AIs each run their own
  `_physics_process`; order is scene-tree order. Fine if spawn order is identical, but there are no
  stable entity ids (only `get_instance_id()`, which differs per process) and several `Callable`
  orders (`{"o":"act","fn":...}`) that cannot be serialised.
- **Cross-platform floats.** All maths is 32-bit float (`Vector2`) with heavy `sin/cos/atan2/
  from_angle/rotated`. Web (emscripten libm), Android ARM64 (bionic) and x86 desktop (glibc) can
  differ in the last bit, and a 1-ulp difference grows into a desync within minutes. This cannot be
  tested from this machine.
- Good news: physics is a fixed 30 Hz (`project.godot`), game logic is mostly independent of the
  camera and fog (those only gate visuals), `AStarGrid2D` is deterministic for equal inputs, the AI
  does not read the wall clock except for profiling.

## 2. Options

### A. Deterministic lockstep (send only commands)
Pros: tiny traffic, host has no advantage, same code path on every peer.
Cons, in this code base:
1. Make every sim `randf` go through a seeded sim RNG and every cosmetic one through a separate one
   (about 110 sites across game/unit/ai/building files that other agents are editing: constant merge
   conflicts).
2. Remove wall-clock budgets, add entity ids, make all orders serialisable, fix every ordering and
   hidden state leak. The only tool for that is the hash test above, run until it stays identical,
   then run again on web vs Android vs desktop where float differences may appear that cannot be
   fixed without replacing trig calls (large).
3. Run the AI on every peer (it must be deterministic too: 5,300 lines, 40 random calls) or stream its commands.
4. Lag: lockstep stalls everyone to the slowest device; a phone in a 300-unit late game that already
   spends 360 ms/s in unit updates (see CLAUDE.md backlog) would stall the browser.
Estimate: 3 to 5 weeks, with an open-ended tail (desync hunting) and a real chance that web vs
Android never stays in sync. **Not feasible with modest changes. Not recommended.**

### B. Host-authoritative state streaming (recommended)
The host runs the real game exactly as today (sim, AI, economy). The guest runs the game as a
"puppet": same rendering, HUD, fog, input, but no sim; it sends commands to the host and receives
snapshots. Determinism and float differences stop mattering, platforms mix freely.
- Host has zero input lag, guest has one round trip (about 50 to 150 ms). Acceptable for
  playtesting; say so in the menu ("host advantage").
- Traffic: ~250 entities x ~12 bytes (id, position, hp, facing, order/animation code) at 10 Hz is
  ~30 KB/s down per guest, fine over WebSocket. Delta-compress later if needed. Commands up are tiny.
- 2v1 co-op falls out of it: three slots with sides [0,0,1] (the lobby already supports up to 8 slots
  and sides). Host plays slot 0, guest slot 1, the AI plays slot 2 on the host only. `game.human` is
  a per-process variable, so each peer simply has its own.
- Cost: the work is in the puppet mode (Units and Buildings mix sim and visuals in 6.8k and 1.5k
  line files) and in replicating one-off events (shots, explosions, sounds, alerts such as "under
  attack") that the host raises for `team == game.human`.

### C. Rejected
- Serving a video stream of the host: needs a media server and ruins the touch UI.
- WebRTC peer-to-peer: built into the web export, but Android needs the `webrtc-native` GDExtension,
  and mobile NAT without a TURN server (paid) often fails. WebSocket through a relay always works.

## 3. Transport and the free relay

Web builds cannot open raw sockets; Godot's `WebSocketPeer` works on web (needs `wss://`, the Pages
site is https) and on Android with the same code. So both platforms connect **outbound** to one
relay that pairs two players by room code and forwards bytes. Options:

1. **Cloudflare Workers + one Durable Object (recommended).** A ~40 line worker; a Durable Object
   holds the two sockets of a room and forwards messages. Free plan: SQLite-backed Durable Objects
   get 100,000 requests/day, WebSocket messages count 20:1 (so ~2 million incoming messages/day),
   outgoing free, and 13,000 GB-s/day. A 1v1 at 10 Hz snapshots + commands is roughly 25 msgs/s,
   ~90,000 per hour, i.e. about 4,500 billed requests. Plenty for playtests. Needs a free Cloudflare
   account and one `wrangler deploy`; gives a `wss://...workers.dev` URL. Source: Cloudflare
   Durable Objects pricing page (checked in this session).
2. Public MQTT-over-WebSocket brokers (e.g. HiveMQ public, `wss`): zero setup, but public topics
   (anyone can read or spoof), best-effort, and needs a small MQTT client in GDScript. Good only as a
   fallback for a first test.
3. A headless Godot relay on a free host (Render etc.): sleeps when idle, 30 to 60 s cold start.

What the owner must do (once): create a free Cloudflare account, run `npx wrangler deploy` in
`tools/relay/` (to be written, about 40 lines), paste the resulting `wss://` URL into the game
(Settings, or a constant). Nothing else; GitHub Pages and the APK stay as they are. Web build is
already single-threaded (`thread_support=false`), so no special headers are needed.

## 4. Plan and estimate (host-authoritative)

| Phase | Work | Days |
|---|---|---|
| 0 | Relay worker + `NetLink` (WebSocketPeer wrapper: create/join room code, ping, reconnect message) + MULTIPLAYER menu page and lobby (host picks map/faction/mode, guest joins by code) | 2 |
| 1 | Stable entity ids (`net_id` set in `_add_unit`/`place_building`, deterministic counter); command funnel: wrap the ~30 player commands in `Game` (`smart_command`, `group_move`, `command_all`, `set_rally`, `place_building`, `place_line`, `train_any`, `cancel_train`, `start_research`, `start_hall_upgrade`, `demolish`, `abandon`, `set_gate_locked`, `refit_order`, `mount_order`, `unload_order`, `player_surrender`, plus the ~25 direct `cmd_*` calls in hud.gd/controls.gd) so a guest turns them into messages and the host applies them for the guest's team, rejecting commands for units it does not own | 4 |
| 2 | Puppet mode for Unit/Building/Projectile: no sim in `_physics_process`, state applied from snapshots (position, hp, facing, animation/order code, carrying, build progress, queues, gold/supply per team), spawn/despawn by id, interpolation between snapshots | 8 to 10 |
| 3 | Events channel: shots, impacts, deaths, sounds, "under attack"/"ready" alerts, pings, chat; guest-side fog from its own side's entities | 4 |
| 4 | 2v1 co-op lobby (3 slots, sides 0,0,1), disconnect handling (AI takes over the lost seat or pause), end screen, match log tag, playtests on web+APK | 3 |
| 5 | Snapshot tuning (delta, priority by view), cheat-proofing is out of scope | 2 |

Total about 3.5 to 4 weeks of focused work; a thin first playable (Phases 0 to 2 with units,
buildings, resources and orders; no events or sounds) at about 2 weeks. Edits to hud.gd/unit.gd/
game.gd are unavoidable in phase 1 and 2; to limit conflicts, put new code in new files
(`scripts/net/net_link.gd`, `net_commands.gd`, `net_snapshot.gd`, `ui/multiplayer_menu.gd`) and keep
the changes in existing files to one-line hooks (`if Net.active: return Net.send(...)`).

Cheaper partial alternative if the owner mostly wants to watch a friend play: spectator-only guest
(Phase 0, 2, 3 without Phase 1) at about 1.5 weeks.

## 5. Decision for this task
Step 3 (build the online command layer) was **not started**, because lockstep is the layer that
would be built and it is not feasible with modest changes (section 1). What is delivered:
this plan and `tools/test_determinism.gd` (also the tool to prove determinism if lockstep is ever
retried). Awaiting the owner's go-ahead on option B (phase 0 to 2 first).
