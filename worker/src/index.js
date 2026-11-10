import { eventPush, localTime, plan } from './rules.js';

const SCOPES = [
  'https://www.googleapis.com/auth/firebase.messaging',
  'https://www.googleapis.com/auth/firebase.database',
  'https://www.googleapis.com/auth/userinfo.email',
].join(' ');

const b64url = (bytes) =>
  btoa(String.fromCharCode(...new Uint8Array(bytes)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');

const b64urlText = (value) => b64url(new TextEncoder().encode(value));

let cachedToken;

async function accessToken(account) {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expires > now + 60) return cachedToken.value;
  const unsigned = `${b64urlText(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))}.${b64urlText(
    JSON.stringify({
      iss: account.client_email,
      scope: SCOPES,
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }),
  )}`;
  const pem = account.private_key.replace(/-----[^-]+-----|\s/g, '');
  const key = await crypto.subtle.importKey(
    'pkcs8',
    Uint8Array.from(atob(pem), (c) => c.charCodeAt(0)),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned));
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${unsigned}.${b64url(signature)}`,
  });
  if (!response.ok) throw new Error(`Google token request failed: ${response.status}`);
  const json = await response.json();
  cachedToken = { value: json.access_token, expires: now + json.expires_in };
  return cachedToken.value;
}

function connect(env) {
  const account = JSON.parse(env.SERVICE_ACCOUNT);
  const base = env.DB_URL.replace(/\/$/, '');
  const db = async (path, method = 'GET', body) => {
    const response = await fetch(`${base}/${env.DB_ROOT ?? 'pair'}/${path}.json`, {
      method,
      headers: { authorization: `Bearer ${await accessToken(account)}` },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    if (!response.ok) throw new Error(`Database ${method} ${path} failed: ${response.status}`);
    return response.json();
  };
  const send = async (push, token) => {
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
      {
        method: 'POST',
        headers: {
          authorization: `Bearer ${await accessToken(account)}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title: push.title, body: push.body },
            data: push.open,
            android: {
              priority: 'HIGH',
              notification: {
                channel_id: push.channel,
                icon: 'ic_notification',
                color: '#16587B',
                tag: push.tag ?? push.kind,
              },
            },
          },
        }),
      },
    );
    return response.status;
  };
  return { db, send };
}

async function load(db, nowMs, extraDays = []) {
  const [devices, streak, notified, nudges, countdowns] = await Promise.all(
    ['devices', 'streak', 'notified', 'nudges', 'countdowns'].map((path) => db(path)),
  );
  const days = new Set(extraDays.filter((day) => /^\d{4}-\d{2}-\d{2}$/.test(day)));
  for (const device of Object.values(devices ?? {})) days.add(localTime(nowMs, device?.tz).day);
  const daily = {};
  await Promise.all([...days].map(async (day) => (daily[day] = await db(`daily/${day}`))));
  return { devices: devices ?? {}, streak, notified, nudges, countdowns, daily };
}

async function deliver({ db, send }, data, pushes) {
  const marks = {};
  for (const push of pushes) {
    const status = await send(push, data.devices[push.uid].token);
    if (status === 404) await db(`devices/${push.uid}/token`, 'DELETE');
    // Marked even when the send fails, so a broken token cannot cause a retry storm.
    Object.assign(marks, push.marks);
  }
  if (Object.keys(marks).length > 0) await db('notified', 'PATCH', marks);
}

async function callerUid(env, idToken) {
  if (typeof idToken !== 'string' || idToken === '') return null;
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${env.WEB_API_KEY}`,
    { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ idToken }) },
  );
  if (!response.ok) return null;
  return (await response.json()).users?.[0]?.localId ?? null;
}

export default {
  async scheduled(controller, env) {
    const firebase = connect(env);
    const now = Date.now();
    const data = await load(firebase.db, now);
    await deliver(firebase, data, plan(data, now));
  },

  async fetch(request, env) {
    const url = new URL(request.url);
    const firebase = connect(env);

    if (request.method === 'GET' && url.pathname === '/') {
      await firebase.db('config/notifyUrl', 'PUT', url.origin);
      return new Response('Notifications are set up. You can close this tab.');
    }

    if (request.method === 'POST' && url.pathname === '/event') {
      const event = await request.json().catch(() => null);
      const uid = event && (await callerUid(env, event.idToken));
      if (!uid) return new Response('Not signed in', { status: 401 });
      const now = Date.now();
      const data = await load(firebase.db, now, [event.day]);
      // Only the two allowed accounts can write a device record.
      if (!data.devices[uid]) return new Response('Not allowed', { status: 403 });
      await deliver(firebase, data, eventPush(data, uid, event, now));
      return new Response('ok');
    }

    return new Response('Not found', { status: 404 });
  },
};
