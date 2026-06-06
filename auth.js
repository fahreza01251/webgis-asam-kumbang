
const { createClient } = supabase;
const db = createClient(SUPABASE_URL, SUPABASE_KEY);

// ---- AMBIL SESSION ----
async function getSession() {
  const { data: { session } } = await db.auth.getSession();
  return session;
}

// ---- AMBIL PROFIL USER ----
async function getUserProfile(userId) {
  try {
    const { data, error } = await db
      .from('profiles')
      .select('id, email, nama, role')
      .eq('id', userId)
      .maybeSingle();

    if (data) return data;

    // Profil belum ada — buat dari data auth
    const { data: authData } = await db.auth.getUser();
    if (!authData?.user) return null;

    const profil = {
      id:    authData.user.id,
      email: authData.user.email,
      nama:  authData.user.user_metadata?.nama
             || authData.user.email.split('@')[0],
      role:  'user'
    };

    await db.from('profiles').upsert([profil], { onConflict: 'id' });
    return profil;

  } catch (e) {
    console.error('getUserProfile error:', e);
    return null;
  }
}

// ---- REQUIRE AUTH ----
async function requireAuth() {
  const session = await getSession();
  if (!session) {
    window.location.href = 'login.html';
    return null;
  }

  let profile = await getUserProfile(session.user.id);

  // Fallback darurat dari session
  if (!profile) {
    profile = {
      id:    session.user.id,
      email: session.user.email,
      nama:  session.user.user_metadata?.nama
             || session.user.email.split('@')[0],
      role:  'user'
    };
  }

  return { session, profile };
}

// ---- REQUIRE ADMIN ----
async function requireAdmin() {
  const auth = await requireAuth();
  if (!auth) return null;
  if (auth.profile?.role !== 'admin') {
    showAccessDenied();
    return null;
  }
  return auth;
}

// ---- RENDER HEADER ----
function renderHeaderUser(profile) {
  const navEl = document.getElementById('nav-right');
  if (!navEl) return;

  const isAdmin = profile?.role === 'admin';
  const nama    = profile?.nama
                  || profile?.email?.split('@')[0]
                  || 'Pengguna';

  navEl.innerHTML = `
    <span class="role-badge ${isAdmin ? 'role-admin' : 'role-user'}">
      ${isAdmin ? '👑 Admin' : '👤 User'}
    </span>
    <span style="font-size:12px;color:var(--text2);margin-left:4px;
      max-width:160px;overflow:hidden;text-overflow:ellipsis;
      white-space:nowrap;display:inline-block">
      ${nama}
    </span>
    <button class="logout-btn" onclick="logout()">Logout</button>
  `;
}

// ---- RENDER NAV ----
function renderNav(profile) {
  const navLinks = document.getElementById('nav-links');
  if (!navLinks) return;

  const role    = profile?.role || 'user';
  const current = window.location.pathname.split('/').pop() || 'index.html';

  const links = [
    { href: 'index.html',     label: 'Peta',       roles: ['admin','user'] },
    { href: 'form.html',      label: 'Input Data',  roles: ['admin','user'] },
    { href: 'dashboard.html', label: 'Dashboard',   roles: ['admin'] },
    { href: 'kelola.html',    label: 'Kelola Data', roles: ['admin'] },
    { href: 'users.html',     label: 'Pengguna',    roles: ['admin'] },
  ];

  navLinks.innerHTML = links
    .filter(l => l.roles.includes(role))
    .map(l => `
      <a href="${l.href}" class="${current === l.href ? 'active' : ''}">
        ${l.label}
      </a>
    `).join('');
}

// ---- ACCESS DENIED ----
function showAccessDenied() {
  document.body.innerHTML = `
    <header style="background:var(--bg2);border-bottom:1px solid var(--border);
      padding:0 1.5rem;height:56px;display:flex;align-items:center;">
      <div>
        <div class="logo-main">WebGIS Jalan Rawan</div>
        <div class="logo-sub">Asam Kumbang · Medan Selayang</div>
      </div>
    </header>
    <div class="denied-wrap">
      <div class="denied-icon">🚫</div>
      <div class="denied-title">Akses Ditolak</div>
      <div class="denied-sub">Halaman ini hanya bisa diakses oleh Admin.</div>
      <a href="index.html" style="color:var(--accent2);font-size:14px;margin-top:8px">
        ← Kembali ke Peta
      </a>
    </div>
  `;
}

// ---- LOGOUT ----
async function logout() {
  await db.auth.signOut();
  window.location.href = 'login.html';
}

// ---- TOAST ----
function toast(msg, type = 'ok') {
  let el = document.getElementById('toast');
  if (!el) {
    el = document.createElement('div');
    el.id = 'toast';
    el.className = 'toast';
    document.body.appendChild(el);
  }
  el.textContent = msg;
  el.style.borderColor = type === 'err' ? 'var(--danger)' : 'var(--success)';
  el.style.color       = type === 'err' ? 'var(--danger)' : 'var(--success)';
  el.classList.add('show');
  setTimeout(() => el.classList.remove('show'), 3000);
}
