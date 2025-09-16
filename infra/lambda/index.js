import { DynamoDBClient, PutItemCommand, GetItemCommand, QueryCommand, ScanCommand, UpdateItemCommand } from '@aws-sdk/client-dynamodb';
import { marshall, unmarshall } from '@aws-sdk/util-dynamodb';
import { v4 as uuidv4 } from 'uuid';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';

const ddb = new DynamoDBClient({});
const DEVICES_TABLE = process.env.DEVICES_TABLE;
const ALLOWLIST_TABLE = process.env.ALLOWLIST_TABLE;
const USERS_TABLE = process.env.USERS_TABLE;
const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-change-me';

const json = (statusCode, body) => ({
  statusCode,
  headers: {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': '*',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
  },
  body: JSON.stringify(body),
});

function getMethod(event) {
  return event.httpMethod || event.requestContext?.http?.method || event.requestContext?.httpMethod || 'GET';
}

function getPath(event) {
  return event.path || event.requestContext?.http?.path || event.rawPath || '/';
}

function normalizePath(p, event) {
  if (!p) return '/';
  const stage = event?.requestContext?.stage;
  if (stage && p.startsWith(`/${stage}`)) {
    const trimmed = p.slice(stage.length + 1);
    return trimmed.startsWith('/') ? trimmed : `/${trimmed}`;
  }
  return p;
}

export const handler = async (event) => {
  const method = getMethod(event).toUpperCase();
  const path = normalizePath(getPath(event), event);
  const body = event.body ? (typeof event.body === 'string' ? JSON.parse(event.body) : event.body) : {};

  try {
    // CORS preflight
    if (method === 'OPTIONS') {
      return json(200, { ok: true });
    }
    if (method === 'GET' && path.match(/^\/device\/status\//)) {
      const deviceId = decodeURIComponent(path.split('/').pop());
      // 1) Check by id
      let device = await getDeviceById(deviceId);
      if (device) return json(200, { approved: !!device.approved, status: device.status, id: device.id });
      // 2) If not found, treat path param as mac and check allowlist
      const allowed = await isAllowlisted(deviceId);
      if (allowed) return json(200, { approved: true, status: 'approved' });
      return json(200, { approved: false, status: 'pending' });
    }

    if (method === 'POST' && path === '/device/register') {
      const { mac, requesterEmail, platform, model = '', osVersion = '', reason = 'New device registration', role = 'user', appVersion = '' } = body;
      if (!mac || !requesterEmail || !platform) return json(400, { error: 'mac, requesterEmail, platform are required' });
      const id = uuidv4();
      const approved = await isAllowlisted(mac);
      // TTL: expire pending after 30 days by default; approved can live longer
      const nowSec = Math.floor(Date.now() / 1000);
      const ttl = approved ? nowSec + 180 * 24 * 60 * 60 : nowSec + 30 * 24 * 60 * 60; // 180d vs 30d
      const item = {
        id,
        mac,
        requesterEmail,
        platform,
        model,
        osVersion,
        reason,
        role,
        appVersion,
        createdAt: new Date().toISOString(),
        status: approved ? 'approved' : 'pending',
        approved,
        decidedBy: null,
        ttl,
      };
      await ddb.send(new PutItemCommand({ TableName: DEVICES_TABLE, Item: marshall(item) }));
      return json(200, { status: item.status, id });
    }

    if (method === 'GET' && path === '/device/pending') {
      const user = await requireAuth(event);
      if (!user || user.role !== 'admin') return json(403, { error: 'forbidden' });
      // Use GSI to list pending efficiently
      const resp = await ddb.send(new QueryCommand({
        TableName: DEVICES_TABLE,
        IndexName: 'status-index',
        KeyConditionExpression: '#s = :s',
        ExpressionAttributeNames: { '#s': 'status' },
        ExpressionAttributeValues: marshall({ ':s': 'pending' }),
        ScanIndexForward: false, // most recent first by createdAt
      }));
      const items = (resp.Items || []).map((i) => unmarshall(i));
      return json(200, items);
    }

    if (method === 'POST' && path === '/device/decide') {
      const user = await requireAuth(event);
      if (!user || user.role !== 'admin') return json(403, { success: false, error: 'forbidden' });
      const { requestId, approve, decidedBy } = body;
      if (!requestId || typeof approve !== 'boolean') return json(400, { success: false, error: 'requestId and approve required' });
      const nowSec = Math.floor(Date.now() / 1000);
      const ttl = approve ? nowSec + 180 * 24 * 60 * 60 : nowSec + 7 * 24 * 60 * 60; // keep approved 180d; purge denied in 7d
      await ddb.send(new UpdateItemCommand({
        TableName: DEVICES_TABLE,
        Key: marshall({ id: requestId }),
        UpdateExpression: 'SET approved = :a, #s = :s, decidedBy = :d, ttl = :t',
        ExpressionAttributeNames: { '#s': 'status' },
        ExpressionAttributeValues: marshall({ ':a': approve, ':s': approve ? 'approved' : 'denied', ':d': decidedBy || user.username || 'admin', ':t': ttl }),
      }));
      return json(200, { success: true });
    }

    if (method === 'POST' && path === '/allowlist/add') {
      const { mac } = body || {};
      if (!mac) return json(400, { success: false, error: 'mac required' });
      await ddb.send(new PutItemCommand({ TableName: ALLOWLIST_TABLE, Item: marshall({ mac }) }));
      return json(200, { success: true });
    }

    if (method === 'POST' && path === '/auth/register') {
      const { username, password, name } = body || {};
      if (!username || !password || !name) return json(400, { success: false, error: 'username, password, and name are required' });
      const hash = bcrypt.hashSync(password, 10);
      await ddb.send(new PutItemCommand({ TableName: USERS_TABLE, Item: marshall({ username, name, passwordHash: hash, role: 'user', createdAt: new Date().toISOString() }) }));
      return json(200, { success: true, user: { username, name, role: 'user' } });
    }

    if (method === 'POST' && path === '/auth/login') {
      const { username, password, mac } = body || {};
      if (!username || !password) return json(400, { success: false, error: 'username and password are required' });
      const user = await getUser(username);
      if (!user) return json(401, { success: false, error: 'invalid credentials' });
      const ok = bcrypt.compareSync(password, user.passwordHash);
      if (!ok) return json(401, { success: false, error: 'invalid credentials' });
      // If a mac is provided, ensure device is approved/allowlisted
      if (mac) {
        const approved = (await isAllowlisted(mac)) || (await isMacApproved(mac));
        if (!approved) return json(403, { success: false, error: 'device-not-approved' });
      }
      const token = jwt.sign({ sub: user.username, role: user.role, name: user.name }, JWT_SECRET, { expiresIn: '8h' });
      // Bind this user to the latest device record for this mac (best-effort)
      if (mac) {
        try {
          const latest = await getLatestDeviceByMac(mac);
          if (latest && latest.id) {
            await ddb.send(new UpdateItemCommand({
              TableName: DEVICES_TABLE,
              Key: marshall({ id: latest.id }),
              UpdateExpression: 'SET username = :u, lastLoginAt = :t',
              ExpressionAttributeValues: marshall({ ':u': user.username, ':t': new Date().toISOString() }),
            }));
          }
        } catch (e) {
          console.warn('Binding user to device failed:', e?.message || e);
        }
      }
      return json(200, { success: true, token, user: { username: user.username, name: user.name, role: user.role } });
    }

    // Public user lookup for display name on login screen (no auth required)
    if (method === 'GET' && path.startsWith('/auth/user/')) {
      const username = decodeURIComponent(path.split('/').pop());
      const mac = event.queryStringParameters?.mac;
      if (!username) return json(400, { user: null });
      const user = await getUser(username);
      if (!user) return json(200, { user: null, allowed: false, bound: false });
      let allowed = false;
      let bound = false;
      if (mac) {
        allowed = (await isAllowlisted(mac)) || (await isMacApproved(mac));
        try {
          const mostRecentBound = await getMostRecentlyBoundDeviceByMac(mac);
          bound = !!(mostRecentBound && mostRecentBound.username === user.username);
        } catch (_) {}
      }
      return json(200, { user: { username: user.username, name: user.name, role: user.role }, allowed, bound });
    }

    // Lookup linked user by device MAC
    if (method === 'GET' && path === '/auth/linked') {
      const mac = event.queryStringParameters?.mac;
      if (!mac) return json(400, { user: null, allowed: false, bound: false, error: 'mac-required' });
      const allowed = (await isAllowlisted(mac)) || (await isMacApproved(mac));
      try {
        const boundDevice = await getMostRecentlyBoundDeviceByMac(mac);
        if (boundDevice && boundDevice.username) {
          const user = await getUser(boundDevice.username);
          if (user) {
            return json(200, { user: { username: user.username, name: user.name, role: user.role }, allowed, bound: true, deviceId: boundDevice.id });
          }
        }
      } catch (_) {}
      return json(200, { user: null, allowed, bound: false });
    }

    // Public test endpoint to list users (limited fields)
    if (method === 'GET' && path === '/auth/users') {
      const resp = await ddb.send(new ScanCommand({
        TableName: USERS_TABLE,
        ProjectionExpression: 'username, #n, #r, createdAt',
        ExpressionAttributeNames: { '#n': 'name', '#r': 'role' },
        Limit: 50,
      }));
      const users = (resp.Items || []).map((i) => unmarshall(i));
      return json(200, { users });
    }

    // Bootstrap initial admin (idempotent). Creates 'admin' if not exists.
    if (method === 'POST' && path === '/auth/bootstrap') {
      const existing = await getUser('admin');
      if (existing) {
        return json(409, { success: false, error: 'admin-exists' });
      }
      const password = 'Admin@' + uuidv4().replace(/-/g, '').slice(0, 8);
      const hash = bcrypt.hashSync(password, 10);
      const item = { username: 'admin', name: 'Administrator', passwordHash: hash, role: 'admin', createdAt: new Date().toISOString() };
      await ddb.send(new PutItemCommand({ TableName: USERS_TABLE, Item: marshall(item) }));
      return json(200, { success: true, admin: { username: 'admin', password } });
    }

    if (method === 'POST' && path === '/auth/bootstrap') {
      // Create an admin user only if table is empty (first-run setup)
      const { username = 'admin', password = 'admin123', name = 'Administrator' } = body || {};
      const existing = await ddb.send(new ScanCommand({ TableName: USERS_TABLE, Limit: 1 }));
      if ((existing.Items || []).length > 0) {
        return json(200, { success: false, error: 'users-exist' });
      }
      const hash = bcrypt.hashSync(password, 10);
      await ddb.send(new PutItemCommand({ TableName: USERS_TABLE, Item: marshall({ username, name, passwordHash: hash, role: 'admin', createdAt: new Date().toISOString() }) }));
      return json(200, { success: true, user: { username, name, role: 'admin' } });
    }

    return json(404, { message: 'Not Found', method, path });
  } catch (e) {
    console.error('Error', e);
    return json(500, { error: 'Internal Server Error', details: String(e) });
  }
};

async function requireAuth(event) {
  const headers = event.headers || {};
  const auth = headers.Authorization || headers.authorization;
  if (!auth || !auth.startsWith('Bearer ')) return null;
  const token = auth.slice(7);
  try {
    const payload = jwt.verify(token, JWT_SECRET);
    return { username: payload.sub, role: payload.role, name: payload.name };
  } catch (e) {
    return null;
  }
}

async function isAllowlisted(mac) {
  const resp = await ddb.send(new GetItemCommand({ TableName: ALLOWLIST_TABLE, Key: marshall({ mac }) }));
  return !!resp.Item;
}

async function getDeviceById(id) {
  const resp = await ddb.send(new GetItemCommand({ TableName: DEVICES_TABLE, Key: marshall({ id }) }));
  return resp.Item ? unmarshall(resp.Item) : null;
}

async function getUser(username) {
  const resp = await ddb.send(new GetItemCommand({ TableName: USERS_TABLE, Key: marshall({ username }) }));
  return resp.Item ? unmarshall(resp.Item) : null;
}

// Determine whether a mac has any approved device record
async function isMacApproved(mac) {
  const resp = await ddb.send(new QueryCommand({
    TableName: DEVICES_TABLE,
    IndexName: 'mac-index',
    KeyConditionExpression: '#m = :m',
    ExpressionAttributeNames: { '#m': 'mac' },
    ExpressionAttributeValues: marshall({ ':m': mac }),
    ScanIndexForward: false,
    Limit: 1,
  }));
  const items = (resp.Items || []).map((i) => unmarshall(i));
  return items.some((d) => d.approved === true || d.status === 'approved');
}

// Get the most recent device record for a mac
async function getLatestDeviceByMac(mac) {
  const resp = await ddb.send(new QueryCommand({
    TableName: DEVICES_TABLE,
    IndexName: 'mac-index',
    KeyConditionExpression: '#m = :m',
    ExpressionAttributeNames: { '#m': 'mac' },
    ExpressionAttributeValues: marshall({ ':m': mac }),
    ScanIndexForward: false,
    Limit: 1,
  }));
  const items = (resp.Items || []).map((i) => unmarshall(i));
  return items[0] || null;
}

// Get recent device records for a mac (best-effort, limited set)
async function getRecentDevicesByMac(mac, limit = 25) {
  const resp = await ddb.send(new QueryCommand({
    TableName: DEVICES_TABLE,
    IndexName: 'mac-index',
    KeyConditionExpression: '#m = :m',
    ExpressionAttributeNames: { '#m': 'mac' },
    ExpressionAttributeValues: marshall({ ':m': mac }),
    ScanIndexForward: false,
    Limit: limit,
  }));
  const items = (resp.Items || []).map((i) => unmarshall(i));
  return items;
}

// Find the most recent device entry for this mac that has a username (i.e., bound)
async function getMostRecentlyBoundDeviceByMac(mac) {
  const items = await getRecentDevicesByMac(mac, 25);
  // Filter to those with a username set
  const boundItems = items.filter((d) => !!d.username);
  if (boundItems.length === 0) return null;
  // Prefer item with latest createdAt if available
  boundItems.sort((a, b) => {
    const ta = a.createdAt ? Date.parse(a.createdAt) : 0;
    const tb = b.createdAt ? Date.parse(b.createdAt) : 0;
    return tb - ta;
  });
  return boundItems[0];
}
