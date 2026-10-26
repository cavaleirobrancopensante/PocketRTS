class_name NetLink
extends Node
## One WebSocket to the relay (tools/relay): create a room (host) or join one (guest) by its code.
## Game data goes as binary frames (NetCodec); the relay's own notices come as text (JSON).
## Works the same on the web build (needs wss:// there) and on Android.

signal opened(my_id: int)               # the relay accepted us (host: id 0, guest: 1..7)
signal notice(d: Dictionary)            # {"t": "join"/"leave"/"closed"/"error", ...}
signal message(from: int, msg: Dictionary)
signal closed(reason: String)
signal polled                           # every message waiting this frame has been handed out (NetSession applies the newest snapshot then)

var is_host := false
var code := ""
var my_id := -1
var connected := false                  # accepted by the relay
var rtt_ms := 0.0
var sent_bytes := 0
var recv_bytes := 0
var sent_msgs := 0
var recv_msgs := 0
var _ws: WebSocketPeer
var _was := WebSocketPeer.STATE_CLOSED
var _ping_t := 0.0
var _ping_at := 0
var _timeout := 0.0
var _reason := ""


static func room_url(base: String, room_code: String, host: bool) -> String:
	var b := base.strip_edges().rstrip("/")
	if b.begins_with("https://"):
		b = "wss://" + b.substr(8)
	elif b.begins_with("http://"):
		b = "ws://" + b.substr(7)
	elif not b.begins_with("ws://") and not b.begins_with("wss://"):
		b = "wss://" + b
	return "%s/room/%s?role=%s" % [b, room_code.to_upper(), "host" if host else "guest"]


## A new random room code (no look-alike letters).
static func new_code() -> String:
	var abc := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
	var s := ""
	for i in 4:
		s += abc[randi() % abc.length()]
	return s


func open(base_url: String, room_code: String, host: bool) -> int:
	is_host = host
	code = room_code.to_upper()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = 4 * 1024 * 1024
	_ws.outbound_buffer_size = 4 * 1024 * 1024
	_ws.max_queued_packets = 4096
	var err := _ws.connect_to_url(room_url(base_url, code, host))
	_was = WebSocketPeer.STATE_CONNECTING
	_timeout = 12.0
	_reason = ""
	return err


func is_open() -> bool:
	return _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN


## Host: to one guest id (0 = every guest). Guest: to the host (`to` is ignored). Returns the bytes sent (0: not open).
func send(msg: Dictionary, to := 0) -> int:
	if not is_open():
		return 0
	var body := NetCodec.pack(msg)
	var out := PackedByteArray()
	if is_host:
		out.append(to)
	out.append_array(body)
	_ws.send(out, WebSocketPeer.WRITE_MODE_BINARY)
	sent_bytes += out.size()
	sent_msgs += 1
	return out.size()


## Push what was just sent onto the wire now (before the app goes to the background and stops running).
func flush() -> void:
	if _ws:
		_ws.poll()


## Bytes sent but still waiting to leave this device (a slow uplink makes them pile up).
func buffered() -> int:
	return _ws.get_current_outbound_buffered_amount() if is_open() else 0


func close(why := "") -> void:
	if _ws:
		_ws.close(1000, why)
	connected = false


func _process(delta: float) -> void:
	if _ws == null:
		return
	_ws.poll()
	var st := _ws.get_ready_state()
	if st == WebSocketPeer.STATE_CONNECTING:
		_timeout -= delta
		if _timeout <= 0.0:
			_ws.close()
			_finish("Could not reach the relay (timed out). Check its address in SETTINGS.")
		return
	if st == WebSocketPeer.STATE_OPEN:
		_was = st
		while _ws.get_available_packet_count() > 0:
			var pkt := _ws.get_packet()
			var is_text := _ws.was_string_packet()
			recv_bytes += pkt.size()
			recv_msgs += 1
			if is_text:
				_text(pkt.get_string_from_utf8())
			elif is_host:
				if pkt.size() > 1:
					var m := NetCodec.unpack(pkt.slice(1))
					if not m.is_empty():
						message.emit(int(pkt[0]), m)
			else:
				var m2 := NetCodec.unpack(pkt)
				if not m2.is_empty():
					message.emit(0, m2)
		polled.emit()
		_ping_t -= delta
		if _ping_t <= 0.0 and connected:
			_ping_t = 2.0
			_ping_at = Time.get_ticks_msec()
			_ws.send_text("ping")
	elif st == WebSocketPeer.STATE_CLOSED:
		if _was != WebSocketPeer.STATE_CLOSED:
			_finish(_reason if _reason != "" else ("Could not reach the relay. Check its address in SETTINGS." if not connected else "The connection to the other player was lost."))


func _text(s: String) -> void:
	if s == "pong":
		rtt_ms = float(Time.get_ticks_msec() - _ping_at)
		return
	var d = JSON.parse_string(s)
	if not (d is Dictionary):
		return
	match String(d.get("t", "")):
		"hello":
			my_id = int(d["id"])
			connected = true
			opened.emit(my_id)
		"error":
			_reason = String(d.get("m", "The relay refused the connection."))
			notice.emit(d)
		"closed":
			_reason = "The host left the game."
			notice.emit(d)
		_:
			notice.emit(d)


func _finish(why: String) -> void:
	_was = WebSocketPeer.STATE_CLOSED
	connected = false
	closed.emit(why)
