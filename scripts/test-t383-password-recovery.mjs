import fs from 'node:fs';
import http from 'node:http';
import { randomBytes } from 'node:crypto';
import { parseEnv } from 'node:util';

// An opt-in, loopback-only bridge for the real SDK recovery test. Never logs credentials.
const ref = 'lqmasbuqzvcvtawonjlb';
const mailbox = process.env.T383_RECOVERY_MAILBOX;
if (!mailbox || !/^[^+@\s]+@gmail\.com$/.test(mailbox)) throw Error('Set T383_RECOVERY_MAILBOX to the authorized Gmail mailbox');
if (fs.readFileSync('supabase/.temp/project-ref', 'utf8').trim() !== ref) throw Error('Wrong project');
const env = parseEnv(fs.readFileSync('supabase_environment_variables', 'utf8'));
const base = `https://${ref}.supabase.co`;
if (env.SUPABASE_URL.replace(/\/$/, '') !== base) throw Error('Wrong URL');
const run = randomBytes(8).toString('hex');
const users = [];
let callback;
let cleanupStarted = false;
const admin = async (path, method = 'GET', body) => {
  const response = await fetch(`${base}/auth/v1/admin/users${path}`, {
    method, headers: { apikey: env.SUPABASE_SECRET_KEY, 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!response.ok) throw Error(`Admin ${method} HTTP ${response.status}`);
  return response.json();
};
const cleanup = async () => {
  if (cleanupStarted) return;
  cleanupStarted = true;
  for (const user of users) {
    const current = await admin(`/${user.id}`);
    if (current.email !== user.email || current.app_metadata?.t383_run !== run) throw Error('Cleanup ownership mismatch');
    await admin(`/${user.id}`, 'DELETE');
    const check = await fetch(`${base}/auth/v1/admin/users/${user.id}`, { headers: { apikey: env.SUPABASE_SECRET_KEY } });
    if (check.status !== 404) throw Error('Cleanup verification failed');
  }
  console.log(JSON.stringify({ cleanupVerified: true, temporaryAccounts: users.length }));
};
const create = async label => {
  const email = mailbox.replace('@', `+beckon-wp12-${run}-${label}@`);
  const password = `${randomBytes(24).toString('base64url')}aA1!`;
  const user = await admin('', 'POST', { email, password, email_confirm: true, app_metadata: { t383_run: run } });
  users.push({ id: user.id, email });
  return { id: user.id, email, password };
};
try {
  const normal = await create('normal');
  const recovery = await create('recovery');
  const fixture = { url: base, key: env.SUPABASE_PUBLISHABLE_KEY, normal, recovery,
    newPassword: `${randomBytes(24).toString('base64url')}aA1!` };
  const server = http.createServer(async (request, response) => {
    try {
      response.setHeader('Content-Type', 'application/json');
      if (request.method === 'GET' && request.url === '/fixture') response.end(JSON.stringify(fixture));
      else if (request.method === 'GET' && request.url === '/callback') {
        response.statusCode = callback ? 200 : 202;
        response.end(JSON.stringify({ callback: callback ?? null }));
      } else if (request.method === 'POST' && request.url === '/finish') {
        await cleanup();
        response.end('{}');
        server.close(() => process.exit(0));
      } else { response.statusCode = 404; response.end('{}'); }
    } catch { response.statusCode = 500; response.end('{}'); }
  });
  server.on('error', async () => { await cleanup(); process.exit(1); });
  server.listen(49383, '127.0.0.1', () => console.log(JSON.stringify({ ready: true, temporaryAccounts: 2 })));
  if (!process.stdin.isTTY) throw Error('Private terminal input required');
  process.stdin.setRawMode(true);
  let input = '';
  process.stdin.on('data', async chunk => {
    input += chunk.toString();
    if (!input.includes('\n')) return;
    const line = input.slice(0, input.indexOf('\n'));
    input = input.slice(input.indexOf('\n') + 1);
    try {
      const email = JSON.parse(line);
      if (!email.to?.includes(recovery.email) || email.last_event !== 'delivered') throw Error('Wrong delivery');
      const links = [...email.html.matchAll(/href=["']([^"']+)["']/g)].map(match => match[1].replaceAll('&amp;', '&'));
      const link = links.map(value => new URL(value)).find(url => url.origin === base && url.pathname === '/auth/v1/verify');
      if (!link || link.searchParams.get('type') !== 'recovery' || link.searchParams.get('redirect_to') !== 'com.hellobeckon.beckon://auth/recovery') throw Error('Wrong link');
      const result = await fetch(link, { redirect: 'manual' });
      const location = new URL(result.headers.get('location'));
      if (location.protocol !== 'com.hellobeckon.beckon:' || location.host !== 'auth' || location.pathname !== '/recovery' || !location.searchParams.has('code')) throw Error('Invalid callback');
      callback = location.toString();
      console.log(JSON.stringify({ providerDelivered: true, exactPKCECallback: true }));
    } catch { console.log(JSON.stringify({ deliveryRejected: true })); }
  });
  setTimeout(async () => { await cleanup(); server.close(); process.exit(1); }, 15 * 60 * 1000).unref();
  process.on('SIGTERM', async () => { await cleanup(); process.exit(1); });
} catch (error) {
  await cleanup();
  console.error(error.message);
  process.exit(1);
}
