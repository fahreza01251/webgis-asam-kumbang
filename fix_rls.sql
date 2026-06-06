-- 1. Reset semua policy di titik_rawan
DROP POLICY IF EXISTS "publik_baca"        ON titik_rawan;
DROP POLICY IF EXISTS "publik_baca_titik"  ON titik_rawan;
DROP POLICY IF EXISTS "baca_semua"         ON titik_rawan;
DROP POLICY IF EXISTS "login_insert"       ON titik_rawan;
DROP POLICY IF EXISTS "login_bisa_insert"  ON titik_rawan;
DROP POLICY IF EXISTS "admin_update"       ON titik_rawan;
DROP POLICY IF EXISTS "admin_update_titik" ON titik_rawan;
DROP POLICY IF EXISTS "admin_delete"       ON titik_rawan;
DROP POLICY IF EXISTS "admin_delete_titik" ON titik_rawan;

-- 2. Buat ulang policy yang benar
CREATE POLICY "select_all"   ON titik_rawan FOR SELECT USING (true);
CREATE POLICY "insert_auth"  ON titik_rawan FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "update_admin" ON titik_rawan FOR UPDATE USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
CREATE POLICY "delete_admin" ON titik_rawan FOR DELETE USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- 3. Reset semua policy di profiles
DROP POLICY IF EXISTS "baca_sendiri"      ON profiles;
DROP POLICY IF EXISTS "admin_baca_semua"  ON profiles;
DROP POLICY IF EXISTS "update_sendiri"    ON profiles;
DROP POLICY IF EXISTS "admin_update_semua" ON profiles;
DROP POLICY IF EXISTS "insert_profil"     ON profiles;
DROP POLICY IF EXISTS "insert_profil_baru" ON profiles;
DROP POLICY IF EXISTS "user_baca_sendiri"  ON profiles;
DROP POLICY IF EXISTS "user_update_sendiri" ON profiles;

-- 4. Buat ulang policy profiles yang benar
CREATE POLICY "profiles_select" ON profiles FOR SELECT USING (true);
CREATE POLICY "profiles_insert" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "profiles_update" ON profiles FOR UPDATE USING (auth.uid() = id);

-- 5. Grant akses ke role anon dan authenticated
GRANT SELECT ON titik_rawan TO anon;
GRANT SELECT, INSERT ON titik_rawan TO authenticated;
GRANT UPDATE, DELETE ON titik_rawan TO authenticated;

GRANT SELECT ON profiles TO anon;
GRANT SELECT, INSERT, UPDATE ON profiles TO authenticated;

-- 6. Cek data ada
SELECT kategori, COUNT(*) FROM titik_rawan GROUP BY kategori;
