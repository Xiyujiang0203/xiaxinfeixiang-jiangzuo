import express from 'express';

const app = express();
app.use(express.text({ type: 'application/x-www-form-urlencoded' }));

app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,X-Cookie');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

const TARGET = 'http://unify.xmu.edu.cn';

app.post(['/api/*', '/mob/*'], async (req, res) => {
  const cookie = String(req.header('X-Cookie') || '').trim();
  if (!cookie) return res.status(400).send(JSON.stringify({ success: false, msg: 'missing_cookie' }));

  try {
    const upstream = await fetch(`${TARGET}${req.originalUrl}`, {
      method: 'POST',
      headers: {
        Host: 'unify.xmu.edu.cn',
        Cookie: cookie,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: req.body ?? '',
    });

    const text = await upstream.text();
    res.status(upstream.status);
    const ct = upstream.headers.get('content-type');
    if (ct) res.setHeader('content-type', ct);
    res.send(text);
  } catch (e) {
    res.status(502).send(JSON.stringify({ success: false, msg: 'proxy_error' }));
  }
});

app.listen(3000, '127.0.0.1', () => {
  console.log('proxy listening on http://127.0.0.1:3000');
});

