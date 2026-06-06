-- ============================================================
-- SETUP LENGKAP DATABASE SUPABASE
-- WebGIS Jalan Rawan — Asam Kumbang, Medan Selayang
-- Jalankan di SQL Editor Supabase, urut dari atas ke bawah
-- ============================================================


-- ============================================================
-- LANGKAH 1: Aktifkan PostGIS (jika belum aktif)
-- ============================================================
CREATE EXTENSION IF NOT EXISTS postgis;


-- ============================================================
-- LANGKAH 2: Tabel PROFILES (data user & role)
-- ============================================================
CREATE TABLE profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email       TEXT NOT NULL,
  nama        TEXT,
  role        TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('admin','user')),
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- RLS untuk profiles
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- User bisa baca profilnya sendiri
CREATE POLICY "user_baca_sendiri" ON profiles
  FOR SELECT USING (auth.uid() = id);

-- Admin bisa baca semua profil
CREATE POLICY "admin_baca_semua" ON profiles
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- User bisa update profilnya sendiri
CREATE POLICY "user_update_sendiri" ON profiles
  FOR UPDATE USING (auth.uid() = id);

-- Admin bisa update semua profil (untuk ubah role)
CREATE POLICY "admin_update_semua" ON profiles
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Siapa saja bisa insert profil baru (diperlukan saat register)
CREATE POLICY "insert_profil_baru" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);


-- ============================================================
-- LANGKAH 3: Tabel TITIK_RAWAN (data spasial)
-- ============================================================
CREATE TABLE titik_rawan (
  id                BIGSERIAL PRIMARY KEY,
  nama              TEXT NOT NULL,
  kelurahan         TEXT NOT NULL DEFAULT 'Asam Kumbang',
  lat               DOUBLE PRECISION NOT NULL,
  lng               DOUBLE PRECISION NOT NULL,
  kategori          TEXT NOT NULL CHECK (kategori IN ('gelap','rusak','rawan')),
  deskripsi         TEXT,
  risiko            TEXT NOT NULL CHECK (risiko IN ('Rendah','Sedang','Tinggi')),
  geom              GEOMETRY(Point, 4326),
  dilaporkan_oleh   UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-isi kolom geom dari lat/lng
CREATE OR REPLACE FUNCTION fn_update_geom()
RETURNS TRIGGER AS $$
BEGIN
  NEW.geom = ST_SetSRID(ST_MakePoint(NEW.lng, NEW.lat), 4326);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_geom
BEFORE INSERT OR UPDATE ON titik_rawan
FOR EACH ROW EXECUTE FUNCTION fn_update_geom();

-- RLS untuk titik_rawan
ALTER TABLE titik_rawan ENABLE ROW LEVEL SECURITY;

-- Siapa saja (termasuk publik) bisa BACA data peta
CREATE POLICY "publik_baca_titik" ON titik_rawan
  FOR SELECT USING (true);

-- Hanya user yang login yang bisa INSERT
CREATE POLICY "login_bisa_insert" ON titik_rawan
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Hanya admin yang bisa UPDATE
CREATE POLICY "admin_update_titik" ON titik_rawan
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Hanya admin yang bisa DELETE
CREATE POLICY "admin_delete_titik" ON titik_rawan
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );


-- ============================================================
-- LANGKAH 4: Fungsi auto-buat profil saat user register
-- ============================================================
CREATE OR REPLACE FUNCTION fn_create_profile()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, email, nama, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'nama', split_part(NEW.email, '@', 1)),
    'user'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: jalankan setelah user baru dibuat di auth.users
CREATE TRIGGER trg_create_profile
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION fn_create_profile();


-- ============================================================
-- LANGKAH 5: Buat akun Admin pertama
-- Jalankan SETELAH daftar akun admin@asamkumbang.id di website
-- ============================================================
UPDATE profiles
SET role = 'admin'
WHERE email = 'admin@asamkumbang.id';


-- ============================================================
-- LANGKAH 6: Data contoh titik rawan Asam Kumbang
-- ============================================================
INSERT INTO titik_rawan (nama, kelurahan, lat, lng, kategori, deskripsi, risiko) VALUES
  ('Jl. Asam Kumbang Ujung',     'Asam Kumbang', 3.5718, 98.6408, 'gelap',
   'Lampu PJU mati, sangat gelap setelah pukul 21.00. Warga takut melintas.', 'Tinggi'),

  ('Jl. Bunga Raya Gg. 4',       'Asam Kumbang', 3.5732, 98.6425, 'rawan',
   'Terdapat 2 kasus jambret dalam 3 bulan terakhir. Area gelap, tidak ada pos ronda.', 'Tinggi'),

  ('Jl. Setia Budi Pasar VIII',  'Asam Kumbang', 3.5745, 98.6398, 'rusak',
   'Aspal berlubang besar sekitar 30cm, berbahaya untuk pengendara motor malam hari.', 'Sedang'),

  ('Jl. Asam Kumbang Gg. 7',    'Asam Kumbang', 3.5708, 98.6440, 'gelap',
   'Gang sempit tanpa penerangan sama sekali, hanya diterangi cahaya dari rumah warga.', 'Tinggi'),

  ('Jl. Bunga Aster Gg. 2',     'Asam Kumbang', 3.5755, 98.6415, 'rusak',
   'Jalan berlubang dan tergenang air saat hujan, pernah menyebabkan kecelakaan.', 'Sedang'),

  ('Jl. Pattimura Gg. Buntu',   'Asam Kumbang', 3.5695, 98.6430, 'rawan',
   'Jalan buntu yang gelap, sering digunakan pelaku kejahatan untuk bersembunyi.', 'Tinggi'),

  ('Jl. Setia Budi Pasar VI',   'Asam Kumbang', 3.5760, 98.6390, 'gelap',
   'Lampu PJU rusak sejak 4 bulan lalu, belum diperbaiki meski sudah dilaporkan.', 'Sedang'),

  ('Jl. Asam Kumbang Gg. 12',   'Asam Kumbang', 3.5725, 98.6455, 'rusak',
   'Kondisi jalan rusak parah, batu-batuan berserakan dan tidak rata.', 'Rendah');
