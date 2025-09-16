import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { Low } from 'lowdb';
import { JSONFile } from 'lowdb/node';
import { v4 as uuidv4 } from 'uuid';
import path from 'path';
import { fileURLToPath } from 'url';
import bcrypt from 'bcryptjs';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
app.use(cors());
app.use(express.json());

const dbFile = path.join(__dirname, 'data', 'db.json');
const adapter = new JSONFile(dbFile);
const db = new Low(adapter, { devices: [], allowlist: [], users: [] });
await db.read();
db.data ||= { devices: [], allowlist: [], users: [] };
await db.write();

// Helper: find device by MAC/ID
const findDevice = (id) => db.data.devices.find((d) => d.mac === id || d.id === id);
const isAllowed = (id) => db.data.allowlist.includes(id);

// POST /device/register
app.post('/device/register', async (req, res) => {
  const { mac, requesterEmail, platform, model = '', osVersion = '', reason = 'New device registration', role = 'user', appVersion = '' } = req.body || {};
  if (!mac || !requesterEmail || !platform) {
    return res.status(400).json({ error: 'mac, requesterEmail, platform are required' });
  }
  let device = findDevice(mac);
  if (!device) {
    device = {
      id: uuidv4(),
      mac,
      requesterEmail,
      platform,
      model,
      osVersion,
      reason,
      role,
      appVersion,
      createdAt: new Date().toISOString(),
      status: isAllowed(mac) ? 'approved' : 'pending',
      approved: isAllowed(mac),
      decidedBy: null,
    };
    db.data.devices.push(device);
    await db.write();
  }
  return res.json({ status: device.status, id: device.id });
});

// GET /device/status/:deviceId
app.get('/device/status/:deviceId', async (req, res) => {
  const { deviceId } = req.params;
  const device = findDevice(deviceId);
  if (!device) {
    // If the device isn't registered but is on the allowlist, treat as approved
    if (isAllowed(deviceId)) {
      return res.json({ approved: true, status: 'approved' });
    }
    return res.json({ approved: false, status: 'pending' });
  }
  return res.json({ approved: !!device.approved, status: device.status, id: device.id });
});

// GET /device/pending
app.get('/device/pending', async (_req, res) => {
  const list = db.data.devices.filter((d) => !d.approved);
  return res.json(list);
});

// POST /device/decide { requestId, approve, decidedBy }
app.post('/device/decide', async (req, res) => {
  const { requestId, approve, decidedBy } = req.body || {};
  if (!requestId || typeof approve !== 'boolean') return res.status(400).json({ success: false, error: 'requestId and approve required' });
  const device = db.data.devices.find((d) => d.id === requestId);
  if (!device) return res.status(404).json({ success: false, error: 'not found' });
  device.approved = approve;
  device.status = approve ? 'approved' : 'denied';
  device.decidedBy = decidedBy || 'admin';
  await db.write();
  return res.json({ success: true });
});

// POST /allowlist/add { mac }
app.post('/allowlist/add', async (req, res) => {
  const { mac } = req.body || {};
  if (!mac) return res.status(400).json({ success: false, error: 'mac required' });
  if (!db.data.allowlist.includes(mac)) {
    db.data.allowlist.push(mac);
    await db.write();
  }
  return res.json({ success: true });
});

// --- Simple user authentication (local only) ---
// POST /auth/register { username, password, name }
app.post('/auth/register', async (req, res) => {
  const { username, password, name } = req.body || {};
  if (!username || !password || !name) {
    return res.status(400).json({ success: false, error: 'username, password, and name are required' });
  }
  const existing = db.data.users.find((u) => u.username.toLowerCase() === String(username).toLowerCase());
  if (existing) {
    return res.status(409).json({ success: false, error: 'username already exists' });
  }
  const hash = bcrypt.hashSync(password, 10);
  const user = {
    id: uuidv4(),
    username,
    name,
    passwordHash: hash,
    role: 'user',
    createdAt: new Date().toISOString(),
  };
  db.data.users.push(user);
  await db.write();
  return res.json({ success: true, user: { id: user.id, username: user.username, name: user.name, role: user.role } });
});

// POST /auth/login { username, password }
app.post('/auth/login', async (req, res) => {
  const { username, password } = req.body || {};
  if (!username || !password) {
    return res.status(400).json({ success: false, error: 'username and password are required' });
  }
  const user = db.data.users.find((u) => u.username.toLowerCase() === String(username).toLowerCase());
  if (!user) return res.status(401).json({ success: false, error: 'invalid credentials' });
  const ok = bcrypt.compareSync(password, user.passwordHash);
  if (!ok) return res.status(401).json({ success: false, error: 'invalid credentials' });
  return res.json({ success: true, user: { id: user.id, username: user.username, name: user.name, role: user.role } });
});

const port = process.env.PORT || 5174;
app.listen(port, () => {
  console.log(`Local API listening on http://localhost:${port}`);
});
