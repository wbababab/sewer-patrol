// Sewer Patrol WebRTC signaling server
// Purely a relay — no game logic. Run locally or deploy to Railway/Fly.io.
// Usage: node server.js [port]   (default 8765)

const { WebSocketServer } = require("ws");

const PORT = parseInt(process.env.PORT ?? process.argv[2] ?? "8765", 10);
const MAX_ROOM_SIZE = 4;

const wss = new WebSocketServer({ port: PORT });
// rooms: Map<roomCode, Map<peerId, ws>>
const rooms = new Map();
let nextPeerId = 1;

function generateCode() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let code = "";
  for (let i = 0; i < 4; i++) code += chars[Math.floor(Math.random() * chars.length)];
  return rooms.has(code) ? generateCode() : code;
}

function send(ws, obj) {
  if (ws.readyState === ws.OPEN) ws.send(JSON.stringify(obj));
}

function broadcast(room, obj, excludeId = null) {
  for (const [id, peer] of room) {
    if (id !== excludeId) send(peer, obj);
  }
}

wss.on("connection", (ws) => {
  ws.peerId = null;
  ws.roomCode = null;

  ws.on("message", (raw) => {
    let msg;
    try { msg = JSON.parse(raw); } catch { return; }

    switch (msg.type) {
      case "create_room": {
        const code = generateCode();
        ws.peerId = nextPeerId++;
        ws.roomCode = code;
        rooms.set(code, new Map([[ws.peerId, ws]]));
        send(ws, { type: "room_created", room: code, your_id: ws.peerId });
        console.log(`Room ${code} created by peer ${ws.peerId}`);
        break;
      }
      case "join_room": {
        const room = rooms.get(msg.room);
        if (!room) { send(ws, { type: "error", message: "Room not found" }); return; }
        if (room.size >= MAX_ROOM_SIZE) { send(ws, { type: "room_full" }); return; }
        ws.peerId = nextPeerId++;
        ws.roomCode = msg.room;
        const existingIds = [...room.keys()];
        room.set(ws.peerId, ws);
        send(ws, { type: "room_joined", room: msg.room, your_id: ws.peerId, peers: existingIds });
        broadcast(room, { type: "peer_joined", peer_id: ws.peerId }, ws.peerId);
        console.log(`Peer ${ws.peerId} joined room ${msg.room}`);
        break;
      }
      // Relay: offer, answer, ice — forward to named recipient
      case "offer":
      case "answer":
      case "ice": {
        const room = rooms.get(ws.roomCode);
        if (!room || msg.to == null) return;
        const target = room.get(msg.to);
        if (target) send(target, { ...msg, from: ws.peerId });
        break;
      }
      case "ready": {
        const room = rooms.get(ws.roomCode);
        if (room) broadcast(room, { type: "peer_ready", peer_id: ws.peerId }, ws.peerId);
        break;
      }
    }
  });

  ws.on("close", () => {
    if (!ws.roomCode) return;
    const room = rooms.get(ws.roomCode);
    if (!room) return;
    room.delete(ws.peerId);
    broadcast(room, { type: "peer_left", peer_id: ws.peerId });
    if (room.size === 0) { rooms.delete(ws.roomCode); console.log(`Room ${ws.roomCode} closed`); }
  });

  ws.on("error", (err) => console.error(`Peer ${ws.peerId} error:`, err.message));
});

console.log(`Sewer Patrol signaling server listening on ws://localhost:${PORT}`);
