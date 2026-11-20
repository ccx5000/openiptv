// OpenIPTV self-hosted sync server — plain Node.js, no framework.
// Endpoints:
//   POST /auth/register {username,password?} -> {token,userId}
//   POST /auth/login    {username,password?} -> {token,userId}
//   GET    /profiles                    -> [profile]
//   POST   /profiles    {name,is_kids}
//   DELETE /profiles/:id
//   GET    /sync/:profileId?since_favorites=&since_watch_progress=&since_views=
//   POST   /sync/:profileId {playlists?,favorites?,watch_progress?,views?}
const http = require('http');
const crypto = require('crypto');
const { Pool } = require('pg');
const jwt = require('jsonwebtoken');

const pool = new Pool({
  connectionString:
    process.env.DATABASE_URL ||
    'postgres://openiptv:openiptv@db:5432/openiptv',
});
const JWT_SECRET = process.env.JWT_SECRET || 'change-me-in-production';
const PORT = parseInt(process.env.PORT || '8080', 10);

function hashPassword(pw) {
  const salt = crypto.randomBytes(16).toString('hex');
  const hash = crypto.scryptSync(pw, salt, 64).toString('hex');
  return `${salt}:${hash}`;
}

function verifyPassword(pw, stored) {
  const [salt, hash] = String(stored).split(':');
  if (!salt || !hash) return false;
  const test = crypto.scryptSync(pw, salt, 64).toString('hex');
  return crypto.timingSafeEqual(Buffer.from(hash, 'hex'), Buffer.from(test, 'hex'));
}

function send(res, code, data) {
  const body = JSON.stringify(data);
  res.writeHead(code, {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(body),
  });
  res.end(body);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', (c) => {
      data += c;
      if (data.length > 5e6) reject(new Error('payload too large'));
    });
    req.on('end', () => {
      try {
        resolve(data ? JSON.parse(data) : {});
      } catch {
        reject(new Error('invalid json'));
      }
    });
    req.on('error', reject);
  });
}

function getAuth(req) {
  const h = req.headers.authorization || '';
  if (!h.startsWith('Bearer ')) return null;
  try {
    return jwt.verify(h.slice(7), JWT_SECRET);
  } catch {
    return null;
  }
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  const path = url.pathname;
  try {
    if (req.method === 'POST' && path === '/auth/register') {
      const { username, password } = await readBody(req);
      const name = String(username || '').trim().toLowerCase();
      if (name.length < 2 || name.length > 64) {
        return send(res, 400, { error: 'Benutzername: 2 bis 64 Zeichen' });
      }
      if (password && password.length < 6) {
        return send(res, 400, { error: 'Passwort zu kurz (min. 6 Zeichen)' });
      }
      const exists = await pool.query('select 1 from users where email = $1', [name]);
      if (exists.rowCount) return send(res, 409, { error: 'Benutzername bereits vergeben' });
      const id = crypto.randomUUID();
      const pwHash = password ? hashPassword(password) : '';
      await pool.query(
        'insert into users (id, email, password_hash) values ($1, $2, $3)',
        [id, name, pwHash]
      );
      const token = jwt.sign({ sub: id }, JWT_SECRET, { expiresIn: '365d' });
      return send(res, 201, { token, userId: id });
    }

    if (req.method === 'POST' && path === '/auth/login') {
      const { username, password } = await readBody(req);
      const r = await pool.query(
        'select id, password_hash from users where email = $1',
        [String(username || '').trim().toLowerCase()]
      );
      if (!r.rowCount) return send(res, 401, { error: 'Konto nicht gefunden' });
      const stored = r.rows[0].password_hash || '';
      if (stored) {
        if (!password || !verifyPassword(password, stored)) {
          return send(res, 401, { error: 'Falsches Passwort' });
        }
      }
      const token = jwt.sign({ sub: r.rows[0].id }, JWT_SECRET, { expiresIn: '365d' });
      return send(res, 200, { token, userId: r.rows[0].id });
    }

    const user = getAuth(req);
    if (!user) return send(res, 401, { error: 'Nicht angemeldet' });

    if (req.method === 'GET' && path === '/profiles') {
      const r = await pool.query(
        'select id, name, avatar_color, is_kids from profiles where user_id = $1 order by created_at',
        [user.sub]
      );
      return send(res, 200, r.rows);
    }

    if (req.method === 'POST' && path === '/profiles') {
      const { name, is_kids } = await readBody(req);
      if (!name) return send(res, 400, { error: 'Name fehlt' });
      const r = await pool.query(
        `insert into profiles (user_id, name, is_kids) values ($1, $2, $3)
         on conflict (user_id, name) do nothing
         returning id, name, avatar_color, is_kids`,
        [user.sub, name, !!is_kids]
      );
      return send(res, 201, r.rows[0] || { error: 'Profil existiert bereits' });
    }

    const profileMatch = path.match(/^\/profiles\/([0-9a-f-]{36})$/);
    if (req.method === 'DELETE' && profileMatch) {
      await pool.query('delete from profiles where id = $1 and user_id = $2', [
        profileMatch[1],
        user.sub,
      ]);
      return send(res, 204, {});
    }

    const syncMatch = path.match(/^\/sync\/([0-9a-f-]{36})$/);
    if (syncMatch) {
      const pid = syncMatch[1];
      const own = await pool.query(
        'select 1 from profiles where id = $1 and user_id = $2',
        [pid, user.sub]
      );
      if (!own.rowCount) return send(res, 403, { error: 'Profil gehört nicht zum Nutzer' });

      if (req.method === 'GET') {
        const sf = url.searchParams.get('since_favorites') || '1970-01-01T00:00:00Z';
        const sp = url.searchParams.get('since_watch_progress') || '1970-01-01T00:00:00Z';
        const sv = url.searchParams.get('since_views') || '1970-01-01T00:00:00Z';
        const favorites = await pool.query(
          'select * from favorites where profile_id = $1 and updated_at > $2',
          [pid, sf]
        );
        const progress = await pool.query(
          'select * from watch_progress where profile_id = $1 and updated_at > $2',
          [pid, sp]
        );
        const views = await pool.query(
          'select * from views where profile_id = $1 and updated_at > $2',
          [pid, sv]
        );
        return send(res, 200, {
          favorites: favorites.rows,
          watch_progress: progress.rows,
          views: views.rows,
        });
      }

      if (req.method === 'POST') {
        const payload = await readBody(req);
        for (const pl of payload.playlists || []) {
          await pool.query(
            `insert into playlists (profile_id, name, kind, host, m3u_url, epg_url, updated_at)
             values ($1, $2, $3, $4, $5, $6, $7)
             on conflict (profile_id, name) do update
               set kind = excluded.kind, host = excluded.host,
                   m3u_url = excluded.m3u_url, epg_url = excluded.epg_url,
                   updated_at = excluded.updated_at`,
            [pid, pl.name, pl.kind, pl.host, pl.m3u_url, pl.epg_url,
             pl.updated_at || new Date().toISOString()]
          );
        }
        for (const f of payload.favorites || []) {
          await pool.query(
            `insert into favorites
               (profile_id, playlist_id, item_kind, item_id, title, logo_url, state, updated_at)
             values ($1, $2, $3, $4, $5, $6, $7, $8)
             on conflict (profile_id, item_kind, item_id, state) do update
               set title = excluded.title, logo_url = excluded.logo_url,
                   updated_at = excluded.updated_at`,
            [pid, f.playlist_id, f.item_kind, f.item_id, f.title,
             f.logo_url, f.state, f.updated_at]
          );
        }
        for (const p of payload.watch_progress || []) {
          await pool.query(
            `insert into watch_progress
               (profile_id, playlist_id, item_kind, item_id, title, position_ms, duration_ms, updated_at)
             values ($1, $2, $3, $4, $5, $6, $7, $8)
             on conflict (profile_id, item_kind, item_id) do update
               set title = excluded.title, position_ms = excluded.position_ms,
                   duration_ms = excluded.duration_ms, updated_at = excluded.updated_at`,
            [pid, p.playlist_id, p.item_kind, p.item_id, p.title,
             p.position_ms || 0, p.duration_ms || 0, p.updated_at]
          );
        }
        for (const v of payload.views || []) {
          await pool.query(
            `insert into views (profile_id, item_kind, item_id, updated_at)
             values ($1, $2, $3, $4)
             on conflict (profile_id, item_kind, item_id) do update
               set updated_at = excluded.updated_at`,
            [pid, v.item_kind, v.item_id, v.updated_at]
          );
        }
        return send(res, 200, { ok: true });
      }
    }

    return send(res, 404, { error: 'not found' });
  } catch (e) {
    console.error(e);
    return send(res, 500, { error: 'server error', detail: String(e.message || e) });
  }
});

server.listen(PORT, () => console.log(`OpenIPTV sync server listening :${PORT}`));
