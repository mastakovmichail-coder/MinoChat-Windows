// MinoChat для Windows: настоящее приложение (Electron). Интерфейс лежит внутри, в папке www.
const { app, BrowserWindow, Tray, Menu, shell, session, desktopCapturer, nativeImage, net } = require('electron');
const http = require('http');
const fs = require('fs');
const path = require('path');

// Web client ID из Firebase Console -> Authentication -> Sign-in method -> Google -> Web SDK configuration
const GOOGLE_WEB_CLIENT_ID = '269701754688-abe1ph77iv160q0ogk7886vmfnmh2qkk.apps.googleusercontent.com';
const crypto = require('crypto');
const pending = {}; // state -> { nonce, token, exp }
let curPort = 47831;
const PORT = 47831; // фиксированный порт, чтобы вход в аккаунт не сбрасывался
const WWW = path.join(__dirname, 'www');
const UPD_BASE = 'https://speeky-a0653.web.app';
const UI_DIR = () => path.join(app.getPath('userData'), 'ui'); // сюда скачиваются обновления интерфейса
const MIME = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml', '.ico': 'image/x-icon', '.webmanifest': 'application/manifest+json' };

let win = null, tray = null, quitting = false, baseUrl = '';

if (!app.requestSingleInstanceLock()) { app.quit(); }
app.on('second-instance', () => showWin());

// ---------- автообновление интерфейса ----------
const verNum = (v) => String(v).split('.').reduce((a, x) => a * 1000 + (parseInt(x, 10) || 0), 0);
function readVer(dir) {
  try { const m = /<meta name="ui-version" content="([\d.]+)"/.exec(fs.readFileSync(path.join(dir, 'index.html'), 'utf8')); return m ? m[1] : '0.0.0'; } catch { return '0.0.0'; }
}
function activeRoot() { const u = UI_DIR(); return verNum(readVer(u)) > verNum(readVer(WWW)) ? u : WWW; }
let updating = false;
async function checkUpdate() {
  if (updating) return; updating = true;
  try {
    const r = await net.fetch(UPD_BASE + '/update/version.json?t=' + Date.now(), { cache: 'no-store' });
    if (!r.ok) return;
    const j = await r.json();
    if (verNum(j.version) <= verNum(readVer(activeRoot())) || !Array.isArray(j.files)) return;
    const tmp = UI_DIR() + '_new'; fs.rmSync(tmp, { recursive: true, force: true });
    for (const rel of j.files) {
      if (/\.\.|^\//.test(rel)) continue; // защита от выхода из папки
      const rr = await net.fetch(UPD_BASE + '/update/ui/' + rel + '?t=' + j.version, { cache: 'no-store' });
      if (!rr.ok) throw new Error('download ' + rel);
      const out = path.join(tmp, rel); fs.mkdirSync(path.dirname(out), { recursive: true });
      fs.writeFileSync(out, Buffer.from(await rr.arrayBuffer()));
    }
    if (readVer(tmp) !== j.version) throw new Error('bad version');
    fs.rmSync(UI_DIR(), { recursive: true, force: true }); fs.renameSync(tmp, UI_DIR());
    if (win) {
      win.webContents.executeJavaScript("typeof toast==='function'&&toast('Интерфейс обновлён до версии " + j.version + ", перезагружаю…')").catch(() => {});
      setTimeout(() => { if (win) win.webContents.reloadIgnoringCache(); }, 2000);
    }
  } catch (e) { /* нет сети или сервер недоступен - попробуем позже */ } finally { updating = false; }
}

function startServer() {
  return new Promise((resolve) => {
    const srv = http.createServer((req, res) => {
      const u = new URL(req.url || '/', 'http://localhost');
      const send = (code, obj) => { res.writeHead(code, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' }); res.end(JSON.stringify(obj)); };
      // ---- вход через Google (через обычный браузер) ----
      if (u.pathname === '/auth/begin' && req.method === 'POST') {
        if (!GOOGLE_WEB_CLIENT_ID || GOOGLE_WEB_CLIENT_ID.startsWith('__')) return send(200, { error: 'Вход через Google не настроен' });
        const state = crypto.randomBytes(16).toString('hex'), nonce = crypto.randomBytes(16).toString('hex');
        pending[state] = { nonce, token: null, exp: Date.now() + 5 * 60000 };
        const redirect = 'http://localhost:' + curPort + '/auth/google';
        const url = 'https://accounts.google.com/o/oauth2/v2/auth?client_id=' + encodeURIComponent(GOOGLE_WEB_CLIENT_ID) + '&redirect_uri=' + encodeURIComponent(redirect) + '&response_type=id_token&scope=' + encodeURIComponent('openid email profile') + '&nonce=' + nonce + '&state=' + state + '&prompt=select_account';
        return send(200, { url, state });
      }
      if (u.pathname === '/auth/google') {
        res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' });
        return res.end('<!doctype html><meta charset="utf-8"><title>MinoChat</title><body style="font-family:sans-serif;background:#050814;color:#fff;text-align:center;padding-top:20vh"><h2 id="m">Входим…</h2><script>var p=new URLSearchParams(location.hash.slice(1));fetch("/auth/done",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({state:p.get("state"),id_token:p.get("id_token")})}).then(function(r){return r.json()}).then(function(j){document.getElementById("m").textContent=j.ok?"Готово! Вернитесь в MinoChat. Это окно можно закрыть.":"Не удалось войти: "+(j.error||"")}).catch(function(){document.getElementById("m").textContent="Ошибка"});history.replaceState(null,"","/auth/google")</script>');
      }
      if (u.pathname === '/auth/done' && req.method === 'POST') {
        let body = ''; req.on('data', (c) => { body += c; if (body.length > 20000) req.destroy(); });
        return req.on('end', () => {
          try {
            const j = JSON.parse(body), pd = pending[j.state];
            if (!pd || pd.exp < Date.now() || !j.id_token) return send(200, { error: 'сессия входа не найдена' });
            const pl = JSON.parse(Buffer.from(j.id_token.split('.')[1], 'base64url').toString('utf8'));
            if (pl.nonce !== pd.nonce || pl.aud !== GOOGLE_WEB_CLIENT_ID) return send(200, { error: 'неверный токен' });
            pd.token = j.id_token; send(200, { ok: true });
          } catch { send(200, { error: 'ошибка разбора' }); }
        });
      }
      if (u.pathname === '/auth/poll') {
        const st = u.searchParams.get('state'), pd = pending[st];
        if (!pd || pd.exp < Date.now()) return send(200, { error: 'Время входа истекло' });
        if (pd.token) { const t = pd.token; delete pending[st]; return send(200, { token: t }); }
        return send(200, {});
      }
      let p = decodeURIComponent((req.url || '/').split('?')[0]);
      if (p === '/' || p === '') p = '/index.html';
      const root = activeRoot();
      let f = path.normalize(path.join(root, p));
      if (!f.startsWith(root)) { res.writeHead(403); return res.end(); }
      if (!fs.existsSync(f)) f = path.normalize(path.join(WWW, p));
      fs.readFile(f, (err, data) => {
        if (err) { res.writeHead(404); return res.end('not found'); }
        res.writeHead(200, { 'Content-Type': MIME[path.extname(f).toLowerCase()] || 'application/octet-stream', 'Cache-Control': 'no-cache' });
        res.end(data);
      });
    });
    const listen = (port) => srv.listen(port, '127.0.0.1');
    srv.once('listening', () => { curPort = srv.address().port; resolve('http://localhost:' + curPort); });
    srv.on('error', (e) => { if (e.code === 'EADDRINUSE') { srv.removeAllListeners('listening'); srv.once('listening', () => { curPort = srv.address().port; resolve('http://localhost:' + curPort); }); listen(0); } });
    listen(PORT);
  });
}

function showWin() { if (!win) return createWin(); if (win.isMinimized()) win.restore(); win.show(); win.focus(); }

function createWin() {
  win = new BrowserWindow({
    width: 1180, height: 760, minWidth: 380, minHeight: 520, backgroundColor: '#050814', title: 'MinoChat',
    icon: path.join(__dirname, 'build', 'icon.png'), autoHideMenuBar: true,
    webPreferences: { contextIsolation: true, nodeIntegration: false, sandbox: true, spellcheck: true },
  });
  win.setMenuBarVisibility(false);
  win.loadURL(baseUrl + '/');
  // внешние ссылки открываем в обычном браузере
  win.webContents.setWindowOpenHandler(({ url }) => { if (/^https?:/.test(url)) shell.openExternal(url); return { action: 'deny' }; });
  win.webContents.on('will-navigate', (e, url) => { if (!url.startsWith(baseUrl)) { e.preventDefault(); if (/^https?:/.test(url)) shell.openExternal(url); } });
  // число непрочитанных из заголовка "(3) MinoChat" -> подсказка в трее и мигание в панели задач
  win.on('page-title-updated', (e, title) => {
    e.preventDefault(); win.setTitle(title);
    const m = /^\((\d+)\)/.exec(title), n = m ? +m[1] : 0;
    if (tray) tray.setToolTip(n ? 'MinoChat: непрочитанных ' + n : 'MinoChat');
    if (n && !win.isFocused()) win.flashFrame(true);
  });
  win.on('focus', () => win.flashFrame(false));
  win.on('close', (e) => { if (!quitting) { e.preventDefault(); win.hide(); } }); // крестик сворачивает в трей
  win.on('closed', () => { win = null; });
}

function createTray() {
  tray = new Tray(nativeImage.createFromPath(path.join(__dirname, 'build', 'icon.png')).resize({ width: 20, height: 20 }));
  tray.setToolTip('MinoChat');
  const autoOn = () => app.getLoginItemSettings().openAtLogin;
  const menu = () => Menu.buildFromTemplate([
    { label: 'Открыть MinoChat', click: showWin },
    { label: 'Проверить обновления', click: checkUpdate },
    { label: 'Запускать вместе с Windows', type: 'checkbox', checked: autoOn(), click: (i) => app.setLoginItemSettings({ openAtLogin: i.checked }) },
    { type: 'separator' },
    { label: 'Выход', click: () => { quitting = true; app.quit(); } },
  ]);
  tray.setContextMenu(menu());
  tray.on('click', showWin);
}

app.whenReady().then(async () => {
  app.setAppUserModelId('app.minochat.desktop');
  // микрофон, камера, уведомления, буфер обмена разрешаем только нашему интерфейсу
  session.defaultSession.setPermissionRequestHandler((wc, perm, cb) => cb(['media', 'notifications', 'clipboard-sanitized-write', 'fullscreen', 'display-capture'].includes(perm)));
  // показ экрана в звонках: берём главный экран
  session.defaultSession.setDisplayMediaRequestHandler(async (req, cb) => {
    try { const s = await desktopCapturer.getSources({ types: ['screen'] }); cb(s.length ? { video: s[0] } : {}); } catch { cb({}); }
  });
  baseUrl = await startServer();
  createWin(); createTray();
  setTimeout(checkUpdate, 5000); setInterval(checkUpdate, 30 * 60 * 1000);
  app.on('activate', showWin);
});
app.on('before-quit', () => { quitting = true; });
app.on('window-all-closed', () => { /* остаёмся в трее */ });
