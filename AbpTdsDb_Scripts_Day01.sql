--Gün 1

CREATE DATABASE AbpTdsDb;
GO

USE AbpTdsDb;
GO

CREATE TABLE URUNLER
(
	URUN_ID int PRIMARY KEY IDENTITY,
	URUN_ADI nvarchar(50) NOT NULL UNIQUE,
	URUN_KODU nvarchar(50) NOT NULL UNIQUE,
	ANA_URUN_ID int NULL FOREIGN KEY REFERENCES URUNLER(URUN_ID),	
	STOK_MIKTARI int NOT NULL DEFAULT (0) CHECK (STOK_MIKTARI >= 0),
	LISTE_FIYATI decimal(10, 2) CHECK (LISTE_FIYATI >= 0)
);

DROP TABLE URUNLER;
GO

CREATE SCHEMA URETIM;
GO
CREATE SCHEMA SATIS;
GO
CREATE SCHEMA IK;
GO

CREATE TABLE URETIM.URUNLER
(
	URUN_ID int PRIMARY KEY IDENTITY,
	URUN_ADI nvarchar(50) NOT NULL UNIQUE,
	URUN_KODU nvarchar(50) NOT NULL UNIQUE,
	ANA_URUN_ID int NULL FOREIGN KEY REFERENCES URETIM.URUNLER(URUN_ID),	
	STOK_MIKTARI int NOT NULL DEFAULT (0) CHECK (STOK_MIKTARI >= 0),
	LISTE_FIYATI decimal(10, 2) CHECK (LISTE_FIYATI >= 0)
);
GO

CREATE TABLE URETIM.URUN_KATEGORILERI
(
	URUN_KATEGORI_ID int PRIMARY KEY IDENTITY(1000, 10),
	URUN_KATEGORI_ADI nvarchar(100) NOT NULL UNIQUE
);
GO

ALTER TABLE URETIM.URUNLER
	ADD URUN_KATEGORI_ID int NOT NULL
		REFERENCES URETIM.URUN_KATEGORILERI(URUN_KATEGORI_ID);

INSERT INTO URETIM.URUN_KATEGORILERI(URUN_KATEGORI_ADI)
VALUES ('Enerji'), ('TDS');
GO

--INSERT URETIM.URUN_KATEGORILERI(URUN_KATEGORI_ADI)
--VALUES ('Enerji');

--INSERT URETIM.URUN_KATEGORILERI(URUN_KATEGORI_ADI)
--VALUES (NULL);

INSERT URETIM.URUNLER(URUN_ADI, URUN_KODU, LISTE_FIYATI, URUN_KATEGORI_ID)
VALUES ('Korkuluk', '3589466', 100, 1000);

ALTER TABLE URETIM.URUNLER
	ADD PASIF bit NOT NULL DEFAULT (0);
GO

SELECT *
FROM URETIM.URUNLER;

CREATE TABLE IK.PERSONELLER
(
	PERSONEL_ID int PRIMARY KEY IDENTITY,
	DEPARTMAN_ID int, --sonradan departmanlara baðlayacaðýz
	AD_SOYAD nvarchar(100) NOT NULL,
	TC_NO char(11) UNIQUE CHECK(LEN(TC_NO) = 11),
	DOGUM_TARIHI date,
	ISE_GIRIS_TARIHI date NOT NULL DEFAULT(GETDATE()),
	PASIF bit NOT NULL DEFAULT(0)
);

CREATE TABLE IK.DEPARTMANLAR
(
	DEPARTMAN_ID int PRIMARY KEY IDENTITY,
	DEPARTMAN_ADI nvarchar(100) NOT NULL,
	CONSTRAINT UQ_DEPARTMANLAR_DEPARTMAN_ADI UNIQUE(DEPARTMAN_ADI)
);

ALTER TABLE IK.PERSONELLER
	ADD CONSTRAINT FK_PERSONELLER_DEPARTMANLAR
		FOREIGN KEY(DEPARTMAN_ID) REFERENCES IK.DEPARTMANLAR;
GO

CREATE TABLE SATIS.MUSTERILER
(
	MUSTERI_ID int PRIMARY KEY IDENTITY,
	MUSTERI_ADI nvarchar(140) NOT NULL UNIQUE,
	SEHIR nvarchar(50),
	ULKE nvarchar(50),
	ADRES nvarchar(100),
	PASIF bit NOT NULL DEFAULT(0)
);

CREATE TABLE SATIS.SIPARISLER
(
	SIPARIS_ID int PRIMARY KEY IDENTITY,
	SIPARIS_TARIHI datetime NOT NULL DEFAULT(GETDATE()),
	PLANLANAN_SEVK_TARIHI datetime,
	GERCEKLESEN_SEVK_TARIHI datetime,
	PLANLANAN_TESLIM_TARIHI datetime,
	GERCEKLESEN_TESLIM_TARIHI datetime,
	PERSONEL_ID int NOT NULL REFERENCES IK.PERSONELLER,
	MUSTERI_ID int NOT NULL REFERENCES SATIS.MUSTERILER,
	TESLIMAT_SEHIR nvarchar(50),
	TESLIMAT_ULKE nvarchar(50),
	TESLIMAT_ADRES nvarchar(100),
	DURUM nvarchar(15) NOT NULL
	CHECK(DURUM IN ('Beklemede', 'Onaylandý', 'Hazýrlanýyor', 'Sevk Edildi', 'Teslim Edildi', 'Ýptal', 'Ýade'))
	DEFAULT('Beklemede')
);

CREATE TABLE SATIS.SIPARIS_DETAY
(
	SIPARIS_ID int NOT NULL,
	URUN_ID int NOT NULL,
	ADET int NOT NULL DEFAULT(1) CHECK(ADET > 0),
	BIRIM_FIYAT decimal(10, 2) NOT NULL CHECK (BIRIM_FIYAT > 0),
	INDIRIM_ORANI decimal(5, 4) DEFAULT(0) CHECK(INDIRIM_ORANI BETWEEN 0 AND 1),
	CONSTRAINT PK_SIPARIS_DETAY PRIMARY KEY(SIPARIS_ID, URUN_ID)
);

ALTER TABLE SATIS.SIPARIS_DETAY
	ADD CONSTRAINT FK_SIPARIS_DETAY_SIPARISLER FOREIGN KEY (SIPARIS_ID) REFERENCES SATIS.SIPARISLER(SIPARIS_ID),
		CONSTRAINT FK_SIPARIS_DETAY_URUNLER FOREIGN KEY (URUN_ID) REFERENCES URETIM.URUNLER(URUN_ID);

/* =====================================================================
   ABP TDS - ÖRNEK VERÝ SETÝ (AbpTdsDb)
   ---------------------------------------------------------------------
   * Gün 1 betiðindeki tablolar oluþturulduktan sonra çalýþtýrýn.
   * Dosyanýn TAMAMINI tek seferde çalýþtýrýn (F5). Geçici tablolar
     ayný oturumda kullanýlýyor.
   * 22.10.2021 - 22.10.2026 arasý yaklaþýk 5 yýllýk sipariþ üretir
     (~2.800 sipariþ, ~6.500 sipariþ satýrý).
   * RAND(seed) kullanýldýðý için her çalýþtýrmada AYNI veri oluþur.

   Filtreleme / sorgu çalýþmalarý için veride bilerek bulunanlar:
   - Yýllýk büyüme ve mevsimsellik (Nisan-Haziran yoðun, Ocak-Þubat sakin)
   - Türkiye enflasyonu: ayný ürünün birim fiyatý yýllar içinde artar
   - Geciken sevkiyatlar / teslimatlar, planlanan vs gerçekleþen tarihler
   - Tüm DURUM deðerleri (Beklemede, Onaylandý, Hazýrlanýyor, Sevk Edildi,
     Teslim Edildi, Ýptal, Ýade)
   - NULL deðerler: liste fiyatý olmayan ana ürünler, adresi olmayan
     müþteri, departmaný/TC'si/doðum tarihi olmayan personel,
     planlanan teslim tarihi girilmemiþ sipariþler
   - Hiç sipariþ vermemiþ müþteriler, hiç satýlmamýþ ürünler,
     personeli olmayan departman
   - Pasif ürünler (sadece eski yýllarda satýlmýþ), pasif müþteriler,
     iþten ayrýlmýþ satýþ personeli
   - Yurt dýþý müþteriler (Mersin Limaný FOB teslimatlarý dahil)
   - Þantiye teslimatlarý (müþteri adresinden farklý teslimat þehri)
   - Segmente göre deðiþen indirim oranlarý
   ===================================================================== */

USE AbpTdsDb;
GO

DELETE SATIS.SIPARIS_DETAY;
DELETE SATIS.SIPARISLER;
DELETE SATIS.MUSTERILER;
DELETE IK.PERSONELLER;
DELETE IK.DEPARTMANLAR;
UPDATE URETIM.URUNLER SET ANA_URUN_ID = NULL;
DELETE URETIM.URUNLER WHERE URUN_KODU <> '3589466';
DBCC CHECKIDENT('SATIS.SIPARISLER', RESEED, 0);
DBCC CHECKIDENT('SATIS.MUSTERILER', RESEED, 0);
DBCC CHECKIDENT('IK.PERSONELLER', RESEED, 0);
DBCC CHECKIDENT('IK.DEPARTMANLAR', RESEED, 0);
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF EXISTS (SELECT 1 FROM SATIS.SIPARISLER)
BEGIN
	RAISERROR('SATIS.SIPARISLER tablosunda zaten kayit var. Once temizlik blogunu calistirin.', 16, 1);
	RETURN;
END;

DECLARE @SEED float = RAND(20261022);   -- tekrarlanabilir rastgelelik

BEGIN TRAN;

/* =====================================================================
   1. ÜRÜN KATEGORÝLERÝ
   ===================================================================== */
INSERT URETIM.URUN_KATEGORILERI(URUN_KATEGORI_ADI)
SELECT K.AD
FROM (VALUES
	(N'Enerji'),
	(N'TDS'),
	(N'Çelik Otoyol Bariyerleri'),
	(N'Yaya ve Köprü Korkuluklarý'),
	(N'Trafik Ýþaret Levhalarý'),
	(N'Yol Güvenlik Ekipmanlarý'),
	(N'Aydýnlatma Direkleri'),
	(N'Enerji Nakil Direkleri'),
	(N'Güneþ Enerjisi Sistemleri'),
	(N'Baðlantý Elemanlarý'),
	(N'Montaj ve Hizmet'),
	(N'Kent Mobilyalarý')          -- hiç ürünü olmayan kategori (LEFT JOIN alýþtýrmasý)
) K(AD)
WHERE NOT EXISTS (SELECT 1 FROM URETIM.URUN_KATEGORILERI C WHERE C.URUN_KATEGORI_ADI = K.AD);

/* =====================================================================
   2. ÜRÜNLER
   FIYAT  : 2026 Ekim liste fiyatý (TL)
   AGIRLIK: satýþ sýklýðý (0 = satýlmaz / ana grup)
   TIPIK  : bir sipariþteki tipik miktar
   BAS/BIT: ürünün satýþta olduðu tarih aralýðý
   ===================================================================== */
CREATE TABLE #U
(
	KOD        nvarchar(50)  COLLATE DATABASE_DEFAULT PRIMARY KEY,
	AD         nvarchar(50)  COLLATE DATABASE_DEFAULT,
	UST_KOD    nvarchar(50)  COLLATE DATABASE_DEFAULT NULL,
	KATEGORI   nvarchar(100) COLLATE DATABASE_DEFAULT,
	FIYAT      decimal(10,2) NULL,
	STOK       int,
	PASIF      bit,
	AGIRLIK    int,
	TIPIK      int,
	GRUP       varchar(5),
	BAS        date,
	BIT        date NULL
);

INSERT #U VALUES
-- Çelik Otoyol Bariyerleri
(N'BAR-1000', N'Çelik Bariyer Sistemleri',           NULL,       N'Çelik Otoyol Bariyerleri', NULL,       0,    0, 0,  0,   'YOL', '2020-01-01', NULL),
(N'BAR-1001', N'W Profil Bariyer H1 4m',             N'BAR-1000', N'Çelik Otoyol Bariyerleri', 4850.00,   1200, 0, 10, 150, 'YOL', '2020-01-01', NULL),
(N'BAR-1002', N'W Profil Bariyer H2 4m',             N'BAR-1000', N'Çelik Otoyol Bariyerleri', 5650.00,   900,  0, 8,  120, 'YOL', '2020-01-01', NULL),
(N'BAR-1003', N'Thrie Beam Bariyer H4b 4m',          N'BAR-1000', N'Çelik Otoyol Bariyerleri', 9800.00,   300,  0, 4,  60,  'YOL', '2020-01-01', NULL),
(N'BAR-1004', N'Bariyer Dikmesi C Profil 1,9m',      N'BAR-1000', N'Çelik Otoyol Bariyerleri', 1450.00,   5000, 0, 9,  300, 'YOL', '2020-01-01', NULL),
(N'BAR-1005', N'Bariyer Dikmesi Sigma 2,2m',         N'BAR-1000', N'Çelik Otoyol Bariyerleri', 1780.00,   2400, 0, 5,  200, 'YOL', '2020-01-01', NULL),
(N'BAR-1006', N'Bariyer Uç Elemaný Balýk Kuyruðu',   N'BAR-1000', N'Çelik Otoyol Bariyerleri', 2250.00,   400,  0, 4,  20,  'YOL', '2020-01-01', NULL),
(N'BAR-1007', N'Bariyer Ayýrýcý (Spacer)',           N'BAR-1000', N'Çelik Otoyol Bariyerleri', 690.00,    3000, 0, 6,  300, 'YOL', '2020-01-01', NULL),
(N'BAR-1008', N'Enerji Sönümleyici Terminal',        N'BAR-1000', N'Çelik Otoyol Bariyerleri', 185000.00, 12,   0, 1,  2,   'YOL', '2020-01-01', NULL),
(N'BAR-1009', N'Yastýk Tipi Çarpma Yastýðý',         N'BAR-1000', N'Çelik Otoyol Bariyerleri', 245000.00, 6,    0, 1,  1,   'YOL', '2023-06-01', NULL),
(N'BAR-1010', N'Eski Tip W Bariyer 3m',              N'BAR-1000', N'Çelik Otoyol Bariyerleri', 2900.00,   0,    1, 5,  100, 'YOL', '2020-01-01', '2023-03-31'),
-- Yaya ve Köprü Korkuluklarý (ana ürün: mevcut 'Korkuluk' kaydý)
(N'3589466',  N'Korkuluk',                           NULL,       N'Yaya ve Köprü Korkuluklarý', NULL,     0,    0, 0,  0,   'YOL', '2020-01-01', NULL),
(N'KRK-2001', N'Köprü Korkuluðu Galvaniz 2m',        N'3589466',  N'Yaya ve Köprü Korkuluklarý', 7400.00,  250,  0, 4,  40,  'YOL', '2020-01-01', NULL),
(N'KRK-2002', N'Yaya Korkuluðu Boyalý 2m',           N'3589466',  N'Yaya ve Köprü Korkuluklarý', 3150.00,  600,  0, 6,  80,  'YOL', '2020-01-01', NULL),
(N'KRK-2003', N'Yaya Korkuluðu Paslanmaz 2m',        N'3589466',  N'Yaya ve Köprü Korkuluklarý', 9900.00,  80,   0, 2,  20,  'YOL', '2020-01-01', NULL),
(N'KRK-2004', N'Refüj Korkuluðu 2,5m',               N'3589466',  N'Yaya ve Köprü Korkuluklarý', 3600.00,  400,  0, 4,  60,  'YOL', '2020-01-01', NULL),
(N'KRK-2005', N'Okul Önü Korkuluðu Desenli 2m',      N'3589466',  N'Yaya ve Köprü Korkuluklarý', 4250.00,  150,  0, 3,  30,  'YOL', '2022-09-01', NULL),
(N'KRK-2006', N'Korkuluk Baðlantý Kelepçesi',        N'3589466',  N'Yaya ve Köprü Korkuluklarý', 145.00,   8000, 0, 5,  400, 'YOL', '2020-01-01', NULL),
-- Trafik Ýþaret Levhalarý
(N'LEV-3000', N'Trafik Levhalarý',                   NULL,       N'Trafik Ýþaret Levhalarý', NULL,        0,    0, 0,  0,   'YOL', '2020-01-01', NULL),
(N'LEV-3001', N'Üçgen Uyarý Levhasý 90cm',           N'LEV-3000', N'Trafik Ýþaret Levhalarý', 1850.00,    700,  0, 7,  50,  'YOL', '2020-01-01', NULL),
(N'LEV-3002', N'Daire Yasak Levhasý 60cm',           N'LEV-3000', N'Trafik Ýþaret Levhalarý', 1350.00,    900,  0, 7,  60,  'YOL', '2020-01-01', NULL),
(N'LEV-3003', N'Daire Yasak Levhasý 80cm',           N'LEV-3000', N'Trafik Ýþaret Levhalarý', 1690.00,    500,  0, 5,  40,  'YOL', '2020-01-01', NULL),
(N'LEV-3004', N'Kare Bilgi Levhasý 60x60',           N'LEV-3000', N'Trafik Ýþaret Levhalarý', 1250.00,    800,  0, 5,  50,  'YOL', '2020-01-01', NULL),
(N'LEV-3005', N'Yön Levhasý Diamond Grade (m2)',     N'LEV-3000', N'Trafik Ýþaret Levhalarý', 6200.00,    300,  0, 4,  25,  'YOL', '2020-01-01', NULL),
(N'LEV-3006', N'Portal Yön Levhasý (m2)',            N'LEV-3000', N'Trafik Ýþaret Levhalarý', 7800.00,    120,  0, 2,  30,  'YOL', '2020-01-01', NULL),
(N'LEV-3007', N'Levha Direði Galvaniz 3,5m',         N'LEV-3000', N'Trafik Ýþaret Levhalarý', 980.00,     2500, 0, 8,  80,  'YOL', '2020-01-01', NULL),
(N'LEV-3008', N'Levha Montaj Kelepçesi',             N'LEV-3000', N'Trafik Ýþaret Levhalarý', 95.00,      10000,0, 6,  200, 'YOL', '2020-01-01', NULL),
(N'LEV-3009', N'Engineer Grade Üçgen Levha 70cm',    N'LEV-3000', N'Trafik Ýþaret Levhalarý', 950.00,     0,    1, 4,  50,  'YOL', '2020-01-01', '2022-12-31'),
-- Yol Güvenlik Ekipmanlarý
(N'YGE-4001', N'Delineatör Direði Reflektörlü',      NULL, N'Yol Güvenlik Ekipmanlarý', 410.00,   6000,  0, 6, 400,  'YOL', '2020-01-01', NULL),
(N'YGE-4002', N'Yol Butonu Alüminyum Çift Yönlü',    NULL, N'Yol Güvenlik Ekipmanlarý', 85.00,    20000, 0, 7, 2000, 'YOL', '2020-01-01', NULL),
(N'YGE-4003', N'Solar Yol Butonu',                   NULL, N'Yol Güvenlik Ekipmanlarý', 690.00,   1500,  0, 3, 300,  'YOL', '2022-04-01', NULL),
(N'YGE-4004', N'Trafik Konisi 75cm Reflektörlü',     NULL, N'Yol Güvenlik Ekipmanlarý', 520.00,   3000,  0, 6, 200,  'YOL', '2020-01-01', NULL),
(N'YGE-4005', N'New Jersey Plastik Bariyer',         NULL, N'Yol Güvenlik Ekipmanlarý', 3900.00,  500,   0, 5, 50,   'YOL', '2020-01-01', NULL),
(N'YGE-4006', N'New Jersey Beton Bariyer',           NULL, N'Yol Güvenlik Ekipmanlarý', 8900.00,  150,   0, 3, 40,   'YOL', '2020-01-01', NULL),
(N'YGE-4007', N'Hýz Kesici Kauçuk 50cm',             NULL, N'Yol Güvenlik Ekipmanlarý', 1150.00,  1200,  0, 5, 60,   'YOL', '2020-01-01', NULL),
(N'YGE-4008', N'Panoramik Yol Aynasý 80cm',          NULL, N'Yol Güvenlik Ekipmanlarý', 2650.00,  220,   0, 3, 10,   'YOL', '2020-01-01', NULL),
(N'YGE-4009', N'Esnek Dikmeli Ayýrýcý',              NULL, N'Yol Güvenlik Ekipmanlarý', 640.00,   2500,  0, 4, 150,  'YOL', '2020-01-01', NULL),
(N'YGE-4010', N'Termoplastik Yol Çizgi Boyasý 25kg', NULL, N'Yol Güvenlik Ekipmanlarý', 2150.00,  1800,  0, 6, 100,  'YOL', '2020-01-01', NULL),
(N'YGE-4011', N'Akýllý Yaya Geçidi Uyarý Seti',      NULL, N'Yol Güvenlik Ekipmanlarý', 56000.00, 8,     0, 0, 0,    'YOL', '2026-09-01', NULL), -- yeni ürün, hiç satýlmadý
-- Aydýnlatma Direkleri
(N'AYD-5000', N'Aydýnlatma Direkleri',               NULL,       N'Aydýnlatma Direkleri', NULL,     0,   0, 0, 0,  'AYD', '2020-01-01', NULL),
(N'AYD-5001', N'Konik Aydýnlatma Direði 8m',         N'AYD-5000', N'Aydýnlatma Direkleri', 21500.00, 90,  0, 5, 20, 'AYD', '2020-01-01', NULL),
(N'AYD-5002', N'Konik Aydýnlatma Direði 10m',        N'AYD-5000', N'Aydýnlatma Direkleri', 27800.00, 70,  0, 4, 15, 'AYD', '2020-01-01', NULL),
(N'AYD-5003', N'Konik Aydýnlatma Direði 12m',        N'AYD-5000', N'Aydýnlatma Direkleri', 35400.00, 40,  0, 3, 10, 'AYD', '2020-01-01', NULL),
(N'AYD-5004', N'Dekoratif Park Direði 4m',           N'AYD-5000', N'Aydýnlatma Direkleri', 12900.00, 110, 0, 3, 15, 'AYD', '2020-01-01', NULL),
(N'AYD-5005', N'Çift Kollu Aplik',                   N'AYD-5000', N'Aydýnlatma Direkleri', 4600.00,  300, 0, 4, 20, 'AYD', '2020-01-01', NULL),
(N'AYD-5006', N'LED Yol Armatürü 120W',              N'AYD-5000', N'Aydýnlatma Direkleri', 8900.00,  400, 0, 5, 30, 'AYD', '2022-01-01', NULL),
(N'AYD-5007', N'LED Yol Armatürü 200W',              N'AYD-5000', N'Aydýnlatma Direkleri', 12400.00, 200, 0, 3, 20, 'AYD', '2023-03-01', NULL),
(N'AYD-5008', N'Sodyum Buharlý Armatür 250W',        N'AYD-5000', N'Aydýnlatma Direkleri', 3900.00,  35,  1, 4, 30, 'AYD', '2020-01-01', '2022-06-30'),
(N'AYD-5009', N'Ankraj Seti M24',                    N'AYD-5000', N'Aydýnlatma Direkleri', 1650.00,  600, 0, 4, 20, 'AYD', '2020-01-01', NULL),
-- Enerji Nakil Direkleri
(N'END-6000', N'Enerji Nakil Direkleri',             NULL,       N'Enerji Nakil Direkleri', NULL,      0,    0, 0, 0,   'ENR', '2020-01-01', NULL),
(N'END-6001', N'Kafes Tipi Direk 154kV (ton)',       N'END-6000', N'Enerji Nakil Direkleri', 98000.00,  35,   0, 3, 12,  'ENR', '2020-01-01', NULL),
(N'END-6002', N'Kafes Tipi Direk 380kV (ton)',       N'END-6000', N'Enerji Nakil Direkleri', 104000.00, 20,   0, 2, 20,  'ENR', '2020-01-01', NULL),
(N'END-6003', N'Çelik Boru Direk OG 12m',            N'END-6000', N'Enerji Nakil Direkleri', 64000.00,  25,   0, 3, 8,   'ENR', '2020-01-01', NULL),
(N'END-6004', N'Travers Galvaniz 2,4m',              N'END-6000', N'Enerji Nakil Direkleri', 3400.00,   900,  0, 4, 60,  'ENR', '2020-01-01', NULL),
(N'END-6005', N'Ýzolatör Baðlantý Seti',             N'END-6000', N'Enerji Nakil Direkleri', 780.00,    3000, 0, 3, 150, 'ENR', '2020-01-01', NULL),
-- Güneþ Enerjisi Sistemleri
(N'GES-7000', N'GES Konstrüksiyonlarý',              NULL,       N'Güneþ Enerjisi Sistemleri', NULL,    0,    0, 0, 0,    'GES', '2020-01-01', NULL),
(N'GES-7001', N'GES Konstrüksiyon Sabit Tip (kWp)',  N'GES-7000', N'Güneþ Enerjisi Sistemleri', 2950.00, 4000, 0, 4, 500,  'GES', '2020-01-01', NULL),
(N'GES-7002', N'GES Tracker Konstrüksiyon (kWp)',    N'GES-7000', N'Güneþ Enerjisi Sistemleri', 4750.00, 1500, 0, 2, 1000, 'GES', '2023-09-01', NULL),
(N'GES-7003', N'Çatý Tipi GES Rayý 4,2m',            N'GES-7000', N'Güneþ Enerjisi Sistemleri', 690.00,  6000, 0, 4, 400,  'GES', '2020-01-01', NULL),
(N'GES-7004', N'GES Kazýk Profili 2,5m',             N'GES-7000', N'Güneþ Enerjisi Sistemleri', 1350.00, 4000, 0, 3, 500,  'GES', '2020-01-01', NULL),
-- Enerji (mevcut kategori)
(N'ENJ-8001', N'Kompakt Trafo Köþkü',                NULL, N'Enerji', 685000.00, 4,   0, 1, 1,  'ENR', '2020-01-01', NULL),
(N'ENJ-8002', N'Aydýnlatma Kumanda Panosu',          NULL, N'Enerji', 46500.00,  30,  0, 3, 3,  'ENR', '2020-01-01', NULL),
(N'ENJ-8003', N'Topraklama Seti',                    NULL, N'Enerji', 2350.00,   500, 0, 3, 20, 'ENR', '2020-01-01', NULL),
-- TDS (Trafik Denetim / Sinyalizasyon)
(N'TDS-9000', N'Sinyalizasyon Sistemleri',           NULL,       N'TDS', NULL,       0,   0, 0, 0,  'TDS', '2020-01-01', NULL),
(N'TDS-9001', N'Deðiþken Mesaj Panosu (VMS)',        NULL,       N'TDS', 1250000.00, 3,   0, 1, 1,  'TDS', '2022-10-01', NULL),
(N'TDS-9002', N'Sinyalizasyon Direði 4m',            N'TDS-9000', N'TDS', 15800.00,   60,  0, 3, 8,  'TDS', '2020-01-01', NULL),
(N'TDS-9003', N'LED Trafik Lambasý 3lü 300mm',       N'TDS-9000', N'TDS', 13900.00,   120, 0, 3, 10, 'TDS', '2020-01-01', NULL),
(N'TDS-9004', N'Yaya Geri Sayým Sayacý',             N'TDS-9000', N'TDS', 9600.00,    80,  0, 2, 8,  'TDS', '2020-01-01', NULL),
(N'TDS-9005', N'Radar Hýz Göstergesi Solar',         NULL,       N'TDS', 74000.00,   15,  0, 2, 2,  'TDS', '2024-02-01', NULL),
(N'TDS-9006', N'Trafik Sayým Sensörü',               NULL,       N'TDS', 98000.00,   0,   0, 1, 2,  'TDS', '2025-05-01', NULL),
-- Baðlantý Elemanlarý
(N'BGL-1101', N'Bariyer Cývatasý M16x45 Galvaniz',   NULL, N'Baðlantý Elemanlarý', 18.50,  120000, 0, 8, 3000, 'YOL', '2020-01-01', NULL),
(N'BGL-1102', N'Bariyer Cývatasý M16x180 Galvaniz',  NULL, N'Baðlantý Elemanlarý', 42.00,  40000,  0, 6, 800,  'YOL', '2020-01-01', NULL),
(N'BGL-1103', N'Kimyasal Dübel M16',                 NULL, N'Baðlantý Elemanlarý', 165.00, 5000,   0, 3, 200,  'YOL', '2020-01-01', NULL),
-- Montaj ve Hizmet (stoksuz)
(N'HZM-1201', N'Bariyer Montaj Hizmeti (m)',         NULL, N'Montaj ve Hizmet', 420.00,   0, 0, 6, 400,  'HZM', '2020-01-01', NULL),
(N'HZM-1202', N'Levha Montaj Hizmeti (adet)',        NULL, N'Montaj ve Hizmet', 650.00,   0, 0, 4, 40,   'HZM', '2020-01-01', NULL),
(N'HZM-1203', N'Sýcak Daldýrma Galvaniz (kg)',       NULL, N'Montaj ve Hizmet', 38.00,    0, 0, 4, 5000, 'HZM', '2020-01-01', NULL),
(N'HZM-1204', N'Nakliye Hizmeti (sefer)',            NULL, N'Montaj ve Hizmet', 18500.00, 0, 0, 3, 2,    'HZM', '2020-01-01', NULL);

-- Ürünleri ekle (mevcut 'Korkuluk' kaydý atlanýr)
INSERT URETIM.URUNLER(URUN_ADI, URUN_KODU, STOK_MIKTARI, LISTE_FIYATI, URUN_KATEGORI_ID, PASIF)
SELECT U.AD, U.KOD, U.STOK, U.FIYAT, K.URUN_KATEGORI_ID, U.PASIF
FROM #U U
JOIN URETIM.URUN_KATEGORILERI K ON K.URUN_KATEGORI_ADI = U.KATEGORI
WHERE NOT EXISTS (SELECT 1 FROM URETIM.URUNLER X WHERE X.URUN_KODU = U.KOD OR X.URUN_ADI = U.AD)
ORDER BY U.KOD;

-- Gün 1'de 'Enerji' kategorisine eklenen Korkuluk'u doðru kategorisine taþý
UPDATE P SET URUN_KATEGORI_ID = K.URUN_KATEGORI_ID
FROM URETIM.URUNLER P
JOIN URETIM.URUN_KATEGORILERI K ON K.URUN_KATEGORI_ADI = N'Yaya ve Köprü Korkuluklarý'
WHERE P.URUN_KODU = '3589466';

-- Ana ürün (hiyerarþi) baðlantýlarý
UPDATE C SET ANA_URUN_ID = P.URUN_ID
FROM URETIM.URUNLER C
JOIN #U U ON U.KOD = C.URUN_KODU
JOIN URETIM.URUNLER P ON P.URUN_KODU = U.UST_KOD;

-- Satýþ havuzu (aðýrlýk kadar tekrarlanan satýrlar)
CREATE TABLE #UX (URUN_ID int PRIMARY KEY, LISTE decimal(10,2), TIPIK int, GRUP varchar(5), BAS date, BIT date NULL);
INSERT #UX
SELECT P.URUN_ID, U.FIYAT, U.TIPIK, U.GRUP, U.BAS, U.BIT
FROM #U U JOIN URETIM.URUNLER P ON P.URUN_KODU = U.KOD
WHERE U.AGIRLIK > 0 AND U.FIYAT IS NOT NULL;

CREATE TABLE #N (N int PRIMARY KEY);
INSERT #N VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10);

CREATE TABLE #UH (RN int IDENTITY PRIMARY KEY, URUN_ID int, GRUP varchar(5), BAS date, BIT date NULL);
INSERT #UH(URUN_ID, GRUP, BAS, BIT)
SELECT X.URUN_ID, X.GRUP, X.BAS, X.BIT
FROM #UX X
JOIN #U U ON U.KOD = (SELECT URUN_KODU FROM URETIM.URUNLER WHERE URUN_ID = X.URUN_ID)
JOIN #N N ON N.N <= U.AGIRLIK
ORDER BY X.URUN_ID, N.N;

/* =====================================================================
   3. DEPARTMANLAR VE PERSONEL
   ===================================================================== */
INSERT IK.DEPARTMANLAR(DEPARTMAN_ADI)
SELECT D.AD
FROM (VALUES
	(N'Genel Müdürlük'), (N'Yurt Ýçi Satýþ'), (N'Yurt Dýþý Satýþ'), (N'Üretim'),
	(N'Kalite Kontrol'), (N'Lojistik'), (N'Muhasebe ve Finans'), (N'Ýnsan Kaynaklarý'),
	(N'Ar-Ge'), (N'Satýn Alma'), (N'Bilgi Teknolojileri'), (N'Proje ve Montaj'),
	(N'Ýç Denetim')               -- personeli olmayan departman
) D(AD)
WHERE NOT EXISTS (SELECT 1 FROM IK.DEPARTMANLAR X WHERE X.DEPARTMAN_ADI = D.AD);

CREATE TABLE #P
(
	AD_SOYAD nvarchar(100) COLLATE DATABASE_DEFAULT,
	DEPT     nvarchar(100) COLLATE DATABASE_DEFAULT NULL,
	TC       char(11) NULL,
	DOGUM    date NULL,
	GIRIS    date,
	PASIF    bit,
	CIKIS    date NULL      -- sadece sipariþ atamasýnda kullanýlýr
);

INSERT #P VALUES
(N'Mehmet Ali Bozkurt', N'Genel Müdürlük',      '18234567012', '1968-03-14', '2009-02-02', 0, NULL),
(N'Ayþe Demir',         N'Yurt Ýçi Satýþ',      '23456789014', '1985-07-21', '2012-05-14', 0, NULL),
(N'Burak Yýlmaz',       N'Yurt Ýçi Satýþ',      '34567890126', '1988-11-03', '2015-09-01', 0, NULL),
(N'Elif Kaya',          N'Yurt Ýçi Satýþ',      '45678901238', '1991-02-17', '2018-03-12', 0, NULL),
(N'Serkan Aydýn',       N'Yurt Ýçi Satýþ',      '56789012340', '1983-06-09', '2011-01-10', 1, '2023-04-28'),
(N'Gizem Öztürk',       N'Yurt Ýçi Satýþ',      '67890123452', '1994-09-25', '2021-06-01', 0, NULL),
(N'Murat Çelik',        N'Yurt Ýçi Satýþ',      '78901234564', '1987-12-30', '2023-05-02', 0, NULL),
(N'Zeynep Arslan',      N'Yurt Ýçi Satýþ',      '89012345676', '1996-04-11', '2024-09-16', 0, NULL),
(N'Oðuz Þahin',         N'Yurt Ýçi Satýþ',      '90123456788', '1990-08-08', '2019-02-04', 1, '2025-11-28'),
(N'Deniz Koç',          N'Yurt Ýçi Satýþ',      '12345098762', '1998-01-19', '2026-02-02', 0, NULL),
(N'Can Erdoðan',        N'Yurt Dýþý Satýþ',     '23409876544', '1984-10-05', '2013-04-01', 0, NULL),
(N'Selin Aksoy',        N'Yurt Dýþý Satýþ',     '34510987656', '1992-05-28', '2020-11-02', 0, NULL),
(N'Kerem Tuncer',       N'Yurt Dýþý Satýþ',     '45621098768', '1989-03-15', '2022-04-18', 0, NULL),
(N'Nazlý Polat',        N'Yurt Dýþý Satýþ',     '56732109870', '1995-12-02', '2025-01-06', 0, NULL),
(N'Hasan Kurt',         N'Üretim',              '67843210982', '1975-04-12', '2008-06-16', 0, NULL),
(N'Ýbrahim Doðan',      N'Üretim',              '78954321094', '1980-01-25', '2010-03-01', 0, NULL),
(N'Yusuf Kýlýç',        N'Üretim',              '89065432106', '1993-07-07', '2017-08-14', 0, NULL),
(N'Ramazan Güneþ',      N'Üretim',              '90176543218', '1986-09-19', '2014-10-06', 0, NULL),
(N'Emre Yýldýz',        N'Üretim',              '10287654320', '1999-05-05', '2022-07-11', 0, NULL),
(N'Ali Rýza Kara',      N'Üretim',              '21398765432', '1978-11-11', '2009-09-07', 1, NULL),
(N'Furkan Özdemir',     N'Üretim',              '32409876546', '2001-02-28', '2024-03-04', 0, NULL),
(N'Seda Yalçýn',        N'Kalite Kontrol',      '43510987658', '1989-06-14', '2016-01-18', 0, NULL),
(N'Tolga Er',           N'Kalite Kontrol',      '54621098760', '1992-10-30', '2021-09-13', 0, NULL),
(N'Volkan Avcý',        N'Lojistik',            '65732109872', '1982-08-22', '2012-11-05', 0, NULL),
(N'Onur Taþ',           N'Lojistik',            '76843210984', '1994-03-03', '2019-06-17', 0, NULL),
(N'Kemal Uçar',         N'Lojistik',            '87954321096', '1979-12-12', '2015-04-20', 1, NULL),
(N'Fatma Þen',          N'Muhasebe ve Finans',  '98065432108', '1981-05-16', '2010-08-02', 0, NULL),
(N'Merve Acar',         N'Muhasebe ve Finans',  '19176543210', '1993-11-24', '2020-02-10', 0, NULL),
(N'Esra Yavuz',         N'Ýnsan Kaynaklarý',    '29287654324', '1987-02-09', '2014-02-03', 0, NULL),
(N'Hakan Ekinci',       N'Ar-Ge',               '39398765436', '1980-07-01', '2016-09-05', 0, NULL),
(N'Büþra Çakýr',        N'Ar-Ge',               '49409876548', '1997-08-18', '2023-10-02', 0, NULL),
(N'Cem Bulut',          N'Satýn Alma',          '59510987650', '1985-01-27', '2013-07-15', 0, NULL),
(N'Barýþ Güler',        N'Bilgi Teknolojileri', '69621098762', '1990-04-04', '2018-10-01', 0, NULL),
(N'Ece Sarý',           N'Bilgi Teknolojileri', '79732109874', '2000-06-06', '2025-07-07', 0, NULL),
(N'Sinan Karaca',       N'Proje ve Montaj',     '89843210986', '1983-09-09', '2011-05-23', 0, NULL),
(N'Umut Ateþ',          N'Proje ve Montaj',     '99954321098', '1995-01-14', '2020-08-03', 0, NULL),
(N'Cengiz Duman',       N'Proje ve Montaj',     '11065432102', '1976-10-20', '2008-04-14', 0, NULL),
(N'Mert Altun',         NULL,                   NULL,          '2004-03-30', '2026-07-01', 0, NULL),  -- stajyer: departman ve TC yok
(N'Leyla Tekin',        NULL,                   '22176543214', NULL,         '2026-09-21', 0, NULL);  -- yeni baþladý: departman ve doðum tarihi yok

INSERT IK.PERSONELLER(DEPARTMAN_ID, AD_SOYAD, TC_NO, DOGUM_TARIHI, ISE_GIRIS_TARIHI, PASIF)
SELECT D.DEPARTMAN_ID, P.AD_SOYAD, P.TC, P.DOGUM, P.GIRIS, P.PASIF
FROM #P P
LEFT JOIN IK.DEPARTMANLAR D ON D.DEPARTMAN_ADI = P.DEPT
WHERE NOT EXISTS (SELECT 1 FROM IK.PERSONELLER X WHERE X.AD_SOYAD = P.AD_SOYAD)
ORDER BY P.GIRIS;

-- Satýþ personeli havuzu
CREATE TABLE #S (PERSONEL_ID int PRIMARY KEY, TIP varchar(2), GIRIS date, CIKIS date NULL);
INSERT #S
SELECT E.PERSONEL_ID, CASE WHEN P.DEPT = N'Yurt Dýþý Satýþ' THEN 'YD' ELSE 'YI' END, P.GIRIS, P.CIKIS
FROM #P P JOIN IK.PERSONELLER E ON E.AD_SOYAD = P.AD_SOYAD
WHERE P.DEPT IN (N'Yurt Ýçi Satýþ', N'Yurt Dýþý Satýþ');

/* =====================================================================
   4. MÜÞTERÝLER
   SEGMENT: KAMU, BELEDIYE, MUTEAHHIT, BAYI, ENERJI, GES, YURTDISI, PERAKENDE
   AGIRLIK: sipariþ sýklýðý (0 = hiç sipariþ vermez)
   BAS/BIT: sipariþ verdiði dönem
   ===================================================================== */
CREATE TABLE #M
(
	AD      nvarchar(140) COLLATE DATABASE_DEFAULT,
	SEHIR   nvarchar(50)  COLLATE DATABASE_DEFAULT NULL,
	ULKE    nvarchar(50)  COLLATE DATABASE_DEFAULT NULL,
	ADRES   nvarchar(100) COLLATE DATABASE_DEFAULT NULL,
	PASIF   bit,
	AGIRLIK int,
	SEGMENT varchar(10),
	BAS     date,
	BIT     date NULL
);

INSERT #M VALUES
(N'T.C. Karayollarý 4. Bölge Müdürlüðü',           N'Ankara',    N'Türkiye', N'Yenimahalle, Ýstanbul Yolu Cd. No:12',     0, 10, 'KAMU',      '2020-01-01', NULL),
(N'T.C. Karayollarý 1. Bölge Müdürlüðü',           N'Ýstanbul',  N'Türkiye', N'Kaðýthane, Hamidiye Mah. No:4',            0, 8,  'KAMU',      '2020-01-01', NULL),
(N'T.C. Karayollarý 2. Bölge Müdürlüðü',           N'Ýzmir',     N'Türkiye', N'Bornova, Kazýmdirik Mah. No:30',           0, 6,  'KAMU',      '2020-01-01', NULL),
(N'T.C. Karayollarý 3. Bölge Müdürlüðü',           N'Konya',     N'Türkiye', N'Selçuklu, Ankara Cd. No:88',               0, 5,  'KAMU',      '2020-01-01', NULL),
(N'T.C. Karayollarý 6. Bölge Müdürlüðü',           N'Kayseri',   N'Türkiye', N'Kocasinan, Sivas Cd. No:15',               0, 4,  'KAMU',      '2020-01-01', NULL),
(N'Ankara Büyükþehir Belediyesi',                  N'Ankara',    N'Türkiye', N'Altýndað, Hipodrom Cd. No:5',              0, 7,  'BELEDIYE',  '2020-01-01', NULL),
(N'Ýstanbul Büyükþehir Belediyesi',                N'Ýstanbul',  N'Türkiye', N'Fatih, Kemalpaþa Mah.',                    0, 6,  'BELEDIYE',  '2020-01-01', NULL),
(N'Bursa Büyükþehir Belediyesi',                   N'Bursa',     N'Türkiye', N'Osmangazi, Kültürpark Yaný',               0, 4,  'BELEDIYE',  '2020-01-01', NULL),
(N'Antalya Büyükþehir Belediyesi',                 N'Antalya',   N'Türkiye', N'Muratpaþa, Yüksekalan Mah.',               0, 4,  'BELEDIYE',  '2020-01-01', NULL),
(N'Konya Büyükþehir Belediyesi',                   N'Konya',     N'Türkiye', N'Selçuklu, Feritpaþa Mah.',                 0, 4,  'BELEDIYE',  '2020-01-01', NULL),
(N'Kayseri Büyükþehir Belediyesi',                 N'Kayseri',   N'Türkiye', N'Kocasinan, Sahabiye Mah.',                 0, 3,  'BELEDIYE',  '2020-01-01', NULL),
(N'Gaziantep Büyükþehir Belediyesi',               N'Gaziantep', N'Türkiye', N'Þahinbey, Ýncilipýnar Mah.',               0, 3,  'BELEDIYE',  '2022-01-01', NULL),
(N'Nevþehir Belediyesi',                           N'Nevþehir',  N'Türkiye', N'Merkez, Atatürk Bulvarý',                  0, 1,  'BELEDIYE',  '2020-01-01', NULL),
(N'Anadolu Yol Yapý Ýnþaat A.Þ.',                  N'Ankara',    N'Türkiye', N'Çankaya, Oðuzlar Mah. 1374. Sk. No:9',     0, 9,  'MUTEAHHIT', '2020-01-01', NULL),
(N'Karadeniz Altyapý Taahhüt Ltd. Þti.',           N'Samsun',    N'Türkiye', N'Ýlkadým, Liman Mah. No:22',                0, 5,  'MUTEAHHIT', '2020-01-01', NULL),
(N'Ege Otoyol Müteahhitlik A.Þ.',                  N'Ýzmir',     N'Türkiye', N'Çiðli AOSB 10003 Sk. No:7',                0, 6,  'MUTEAHHIT', '2020-01-01', NULL),
(N'Marmara Köprü ve Yol Ýnþaat A.Þ.',              N'Kocaeli',   N'Türkiye', N'Gebze OSB 1600. Sk. No:3',                 0, 7,  'MUTEAHHIT', '2020-01-01', NULL),
(N'Toros Mühendislik Ýnþaat Ltd. Þti.',            N'Mersin',    N'Türkiye', N'Akdeniz, Kazanlý Yolu No:41',              0, 3,  'MUTEAHHIT', '2020-01-01', NULL),
(N'Fýrat Yol Asfalt Ltd. Þti.',                    N'Elazýð',    N'Türkiye', N'Merkez, OSB 3. Cd. No:2',                  1, 3,  'MUTEAHHIT', '2020-01-01', '2023-08-31'),
(N'Kapadokya Altyapý Ýnþaat Ltd. Þti.',            N'Nevþehir',  N'Türkiye', N'Merkez, Sanayi Sitesi 4. Blok',            0, 2,  'MUTEAHHIT', '2021-01-01', NULL),
(N'Birlik Proje Taahhüt Ltd. Þti.',                N'Ankara',    N'Türkiye', NULL,                                        0, 2,  'MUTEAHHIT', '2022-06-01', NULL),
(N'Mavi Otoyol Ýþletme A.Þ.',                      N'Bursa',     N'Türkiye', N'Nilüfer, Otoyol Bakým Merkezi',            0, 4,  'MUTEAHHIT', '2020-01-01', NULL),
(N'Baþkent Trafik Malzemeleri Tic. Ltd. Þti.',     N'Ankara',    N'Türkiye', N'Ostim OSB 1203. Cd. No:18',                0, 6,  'BAYI',      '2020-01-01', NULL),
(N'Ýstanbul Trafik Ekipmanlarý A.Þ.',              N'Ýstanbul',  N'Türkiye', N'Baþakþehir, Ýkitelli OSB No:55',           0, 6,  'BAYI',      '2020-01-01', NULL),
(N'Akdeniz Yol Çizgi Ltd. Þti.',                   N'Antalya',   N'Türkiye', N'Kepez, Sanayi Mah. No:61',                 0, 3,  'BAYI',      '2020-01-01', NULL),
(N'Kuzey Trafik Güvenlik Sistemleri Ltd.',         N'Trabzon',   N'Türkiye', N'Ortahisar, Deðirmendere Mah.',             0, 3,  'BAYI',      '2020-01-01', NULL),
(N'Trakya Yol Güvenlik Ltd. Þti.',                 N'Tekirdað',  N'Türkiye', N'Çorlu, Velimeþe OSB',                      0, 2,  'BAYI',      '2021-03-01', NULL),
(N'Selçuklu Yapý Market Ltd.',                     N'Konya',     N'Türkiye', N'Karatay, Büsan OSB',                       1, 1,  'BAYI',      '2020-01-01', '2022-12-31'),
(N'Orta Anadolu Enerji Taahhüt A.Þ.',              N'Kayseri',   N'Türkiye', N'Melikgazi, Kayseri OSB 12. Cd.',           0, 4,  'ENERJI',    '2020-01-01', NULL),
(N'Güneyhan Elektrik Mühendislik Ltd.',            N'Adana',     N'Türkiye', N'Seyhan, Hacý Sabancý OSB',                 0, 3,  'ENERJI',    '2020-01-01', NULL),
(N'Ilgaz Enerji Nakil Hatlarý A.Þ.',               N'Çankýrý',   N'Türkiye', N'Merkez, Organize Sanayi Bölgesi',          0, 3,  'ENERJI',    '2020-01-01', NULL),
(N'Doðu Elektrik Daðýtým Taahhüt Ltd.',            N'Erzurum',   N'Türkiye', N'Yakutiye, Þükrüpaþa Mah.',                 0, 2,  'ENERJI',    '2020-01-01', NULL),
(N'Yeþilvadi GES Enerji Yatýrýmlarý A.Þ.',         N'Konya',     N'Türkiye', N'Karatay, Fetih Cd. No:120',                0, 5,  'GES',       '2022-03-01', NULL),
(N'Güneþpark Yenilenebilir Enerji A.Þ.',           N'Karaman',   N'Türkiye', N'Merkez, OSB 2. Cd.',                       0, 4,  'GES',       '2023-01-01', NULL),
(N'Bodrum Peyzaj ve Kent Mobilyalarý Ltd.',        N'Muðla',     N'Türkiye', N'Bodrum, Konacýk Mah.',                     0, 1,  'BAYI',      '2020-01-01', NULL),
(N'Atlas Liman Ýþletmeleri A.Þ.',                  N'Mersin',    N'Türkiye', N'Yeniþehir, Liman Yolu',                    0, 1,  'MUTEAHHIT', '2024-01-01', NULL),
(N'Perakende Satýþ Müþterisi',                     NULL,         NULL,       NULL,                                        0, 2,  'PERAKENDE', '2020-01-01', NULL),
(N'Van Gölü Altyapý Ltd. Þti.',                    N'Van',       N'Türkiye', N'Ýpekyolu, Sanayi Sitesi',                  0, 0,  'MUTEAHHIT', '2020-01-01', NULL),  -- hiç sipariþ yok
(N'Ordu Kent Mobilyalarý Ltd.',                    N'Ordu',      N'Türkiye', N'Altýnordu, Sanayi Mah.',                   1, 0,  'BAYI',      '2020-01-01', NULL),  -- pasif, hiç sipariþ yok
(N'Baku Road Construction LLC',                    N'Bakü',      N'Azerbaycan', N'Nasimi District, 28 May St. 14',         0, 4,  'YURTDISI',  '2022-05-01', NULL),
(N'Caspian Infrastructure Group',                  N'Sumgayýt',  N'Azerbaycan', N'Industrial Park Block C',               0, 2,  'YURTDISI',  '2020-01-01', NULL),
(N'Tbilisi Highway Solutions Ltd.',                N'Tiflis',    N'Gürcistan', N'Didube, Tsereteli Ave. 112',             0, 3,  'YURTDISI',  '2020-01-01', NULL),
(N'Erbil Construction Company',                    N'Erbil',     N'Irak',     N'100m Road, Ankawa',                       0, 3,  'YURTDISI',  '2020-01-01', NULL),
(N'Basra Energy Projects',                         N'Basra',     N'Irak',     N'Al Jazair St. 7',                         0, 2,  'YURTDISI',  '2024-03-01', NULL),
(N'Drum Construct SRL',                            N'Bükreþ',    N'Romanya',  N'Sector 6, Bd. Iuliu Maniu 220',           0, 2,  'YURTDISI',  '2020-01-01', NULL),
(N'Balkan Road Safety DOO',                        N'Belgrad',   N'Sýrbistan', N'Novi Beograd, Omladinskih Brigada 90',   0, 2,  'YURTDISI',  '2020-01-01', NULL),
(N'Skopje Infra DOOEL',                            N'Üsküp',     N'Kuzey Makedonya', N'Gazi Baba Industrial Zone',        1, 1,  'YURTDISI',  '2020-01-01', '2024-06-30'),
(N'Doha Traffic Systems WLL',                      N'Doha',      N'Katar',    N'Industrial Area, St. 43',                 0, 2,  'YURTDISI',  '2023-01-01', NULL),
(N'Al Riyadh Roads Contracting',                   N'Riyad',     N'Suudi Arabistan', N'Al Sulay District',                0, 2,  'YURTDISI',  '2025-01-01', NULL),
(N'Tashkent Yo''l Qurilish',                       N'Taþkent',   N'Özbekistan', N'Chilonzor, Bunyodkor Ave. 5',           0, 2,  'YURTDISI',  '2023-06-01', NULL),
(N'Almaty Energy Build LLP',                       N'Almatý',    N'Kazakistan', N'Alatau District, Industrial Zone',      0, 2,  'YURTDISI',  '2020-01-01', NULL),
(N'Berlin Strassenbau GmbH',                       N'Berlin',    N'Almanya',  N'Marzahn, Rhinstrasse 140',                0, 1,  'YURTDISI',  '2025-03-01', NULL),
(N'Libya Al Jadida Contracting',                   N'Trablus',   N'Libya',    N'Gargaresh Rd.',                           0, 1,  'YURTDISI',  '2020-01-01', NULL),
(N'Nicosia Road Works Ltd.',                       N'Lefkoþa',   N'KKTC',     N'Organize Sanayi Bölgesi No:14',           0, 2,  'YURTDISI',  '2020-01-01', NULL),
(N'Yeni Kayýt Örnek Mühendislik A.Þ.',             N'Eskiþehir', N'Türkiye', N'Odunpazarý, OSB 22. Cd.',                  0, 0,  'MUTEAHHIT', '2026-10-01', NULL);  -- yeni kayýt, sipariþ yok

INSERT SATIS.MUSTERILER(MUSTERI_ADI, SEHIR, ULKE, ADRES, PASIF)
SELECT M.AD, M.SEHIR, M.ULKE, M.ADRES, M.PASIF
FROM #M M
WHERE NOT EXISTS (SELECT 1 FROM SATIS.MUSTERILER X WHERE X.MUSTERI_ADI = M.AD);

CREATE TABLE #MX
(
	MUSTERI_ID int PRIMARY KEY, SEGMENT varchar(10), YURTDISI bit,
	SEHIR nvarchar(50) COLLATE DATABASE_DEFAULT NULL,
	ULKE  nvarchar(50) COLLATE DATABASE_DEFAULT NULL,
	ADRES nvarchar(100) COLLATE DATABASE_DEFAULT NULL,
	BAS date, BIT date NULL, AGIRLIK int
);
INSERT #MX
SELECT C.MUSTERI_ID, M.SEGMENT,
	   CASE WHEN M.ULKE IS NOT NULL AND M.ULKE <> N'Türkiye' THEN 1 ELSE 0 END,
	   M.SEHIR, M.ULKE, M.ADRES, M.BAS, M.BIT, M.AGIRLIK
FROM #M M JOIN SATIS.MUSTERILER C ON C.MUSTERI_ADI = M.AD;

CREATE TABLE #MH (RN int IDENTITY PRIMARY KEY, MUSTERI_ID int, BAS date, BIT date NULL);
INSERT #MH(MUSTERI_ID, BAS, BIT)
SELECT X.MUSTERI_ID, X.BAS, X.BIT
FROM #MX X JOIN #N N ON N.N <= X.AGIRLIK
ORDER BY X.MUSTERI_ID, N.N;

-- Segmentlerin tercih ettiði ürün gruplarý
CREATE TABLE #TERCIH (SEGMENT varchar(10), GRUP varchar(5));
INSERT #TERCIH VALUES
('KAMU','YOL'),('KAMU','TDS'),('KAMU','AYD'),('KAMU','HZM'),
('BELEDIYE','YOL'),('BELEDIYE','AYD'),('BELEDIYE','TDS'),('BELEDIYE','HZM'),
('MUTEAHHIT','YOL'),('MUTEAHHIT','AYD'),('MUTEAHHIT','HZM'),
('BAYI','YOL'),
('ENERJI','ENR'),('ENERJI','AYD'),
('GES','GES'),('GES','ENR'),
('YURTDISI','YOL'),('YURTDISI','ENR'),('YURTDISI','GES'),('YURTDISI','AYD'),
('PERAKENDE','YOL');

-- Þantiye teslimatlarý için þehirler
CREATE TABLE #SEHIR (RN int IDENTITY PRIMARY KEY, SEHIR nvarchar(50) COLLATE DATABASE_DEFAULT);
INSERT #SEHIR(SEHIR) VALUES
(N'Ankara'),(N'Ýstanbul'),(N'Ýzmir'),(N'Bursa'),(N'Antalya'),(N'Konya'),(N'Kayseri'),(N'Samsun'),
(N'Trabzon'),(N'Erzurum'),(N'Diyarbakýr'),(N'Gaziantep'),(N'Adana'),(N'Mersin'),(N'Eskiþehir'),
(N'Sivas'),(N'Malatya'),(N'Van'),(N'Denizli'),(N'Kocaeli'),(N'Sakarya'),(N'Tekirdað'),(N'Bolu'),
(N'Afyonkarahisar'),(N'Aksaray'),(N'Nevþehir'),(N'Yozgat'),(N'Çorum'),(N'Kastamonu'),(N'Muðla');

/* =====================================================================
   5. ENFLASYON ÇARPANI (Ekim 2026 = 1.0, geriye doðru aylýk)
   ===================================================================== */
CREATE TABLE #ENF (YIL int, AY int, CARPAN float, PRIMARY KEY (YIL, AY));
DECLARE @AYT date = '2026-10-01', @C float = 1.0;
WHILE @AYT >= '2021-01-01'
BEGIN
	INSERT #ENF VALUES (YEAR(@AYT), MONTH(@AYT), @C);
	SET @C = @C / (1 + CASE YEAR(@AYT)
						WHEN 2021 THEN 0.028 WHEN 2022 THEN 0.045 WHEN 2023 THEN 0.040
						WHEN 2024 THEN 0.030 WHEN 2025 THEN 0.022 ELSE 0.017 END);
	SET @AYT = DATEADD(MONTH, -1, @AYT);
END;

/* =====================================================================
   6. SÝPARÝÞLER VE SÝPARÝÞ DETAYLARI
   ===================================================================== */
DECLARE
	@BAS date = '2021-10-22',
	@BUGUN date = '2026-10-22',
	@BUGUN_DT datetime = '2026-10-22 15:00',
	@GUN date, @HG int, @LAMBDA float, @SIP_SAYISI int, @I int,
	@CNT int, @K int, @R float, @ENFC float,
	@MUSTERI_ID int, @SEGMENT varchar(10), @YURTDISI bit,
	@M_SEHIR nvarchar(50), @M_ULKE nvarchar(50), @M_ADRES nvarchar(100),
	@TIPF varchar(2), @PERSONEL_ID int,
	@SIP datetime, @PL_SEVK datetime, @GS_SEVK datetime, @PL_TES datetime, @GS_TES datetime,
	@GECIKME int, @TRANSIT int, @DURUM nvarchar(15), @IPTAL bit,
	@T_SEHIR nvarchar(50), @T_ULKE nvarchar(50), @T_ADRES nvarchar(100),
	@SID int, @SATIR int, @J int, @DENEME int, @FILTRE bit,
	@URUN_ID int, @LISTE decimal(10,2), @TIPIK int, @ADET int, @FIYAT decimal(10,2),
	@IND decimal(5,4), @SEGC float, @SEHIR_CNT int;

SELECT @SEHIR_CNT = COUNT(*) FROM #SEHIR;
SET @GUN = @BAS;

WHILE @GUN <= @BUGUN
BEGIN
	SET @HG = DATEDIFF(DAY, '19000101', @GUN) % 7;     -- 0=Pazartesi ... 5=Cumartesi, 6=Pazar
	IF @HG = 6
	BEGIN
		SET @GUN = DATEADD(DAY, 1, @GUN);
		CONTINUE;
	END;

	-- Yýllýk büyüme x mevsimsellik
	SET @LAMBDA = CASE YEAR(@GUN) WHEN 2021 THEN 1.3 WHEN 2022 THEN 1.5 WHEN 2023 THEN 1.6
								  WHEN 2024 THEN 1.9 WHEN 2025 THEN 2.2 ELSE 2.5 END
				* CHOOSE(MONTH(@GUN), 0.6, 0.7, 1.0, 1.25, 1.35, 1.35, 1.2, 1.0, 1.15, 1.1, 0.9, 1.0);
	IF @HG = 5 SET @LAMBDA = @LAMBDA * 0.15;   -- cumartesi
	IF MONTH(@GUN) * 100 + DAY(@GUN) IN (101, 423, 501, 519, 715, 830, 1029) SET @LAMBDA = @LAMBDA * 0.1;  -- resmi tatiller

	SET @SIP_SAYISI = FLOOR(RAND() * (2 * @LAMBDA + 1));
	SELECT @ENFC = CARPAN FROM #ENF WHERE YIL = YEAR(@GUN) AND AY = MONTH(@GUN);

	SET @I = 1;
	WHILE @I <= @SIP_SAYISI
	BEGIN
		---------------- Müþteri seçimi ----------------
		SELECT @CNT = COUNT(*) FROM #MH WHERE BAS <= @GUN AND (BIT IS NULL OR BIT >= @GUN);
		SET @K = FLOOR(RAND() * @CNT) + 1;
		SELECT @MUSTERI_ID = X.MUSTERI_ID
		FROM (SELECT MUSTERI_ID, ROW_NUMBER() OVER (ORDER BY RN) AS R
			  FROM #MH WHERE BAS <= @GUN AND (BIT IS NULL OR BIT >= @GUN)) X
		WHERE X.R = @K;

		SELECT @SEGMENT = SEGMENT, @YURTDISI = YURTDISI, @M_SEHIR = SEHIR, @M_ULKE = ULKE, @M_ADRES = ADRES
		FROM #MX WHERE MUSTERI_ID = @MUSTERI_ID;

		---------------- Satýþ personeli seçimi ----------------
		SET @TIPF = CASE WHEN @YURTDISI = 1 THEN 'YD' ELSE 'YI' END;
		SELECT @CNT = COUNT(*) FROM #S WHERE TIP = @TIPF AND GIRIS <= @GUN AND (CIKIS IS NULL OR CIKIS >= @GUN);
		IF @CNT = 0
		BEGIN
			SET @TIPF = NULL;
			SELECT @CNT = COUNT(*) FROM #S WHERE GIRIS <= @GUN AND (CIKIS IS NULL OR CIKIS >= @GUN);
		END;
		SET @K = FLOOR(RAND() * @CNT) + 1;
		SELECT @PERSONEL_ID = X.PERSONEL_ID
		FROM (SELECT PERSONEL_ID, ROW_NUMBER() OVER (ORDER BY PERSONEL_ID) AS R
			  FROM #S WHERE (TIP = @TIPF OR @TIPF IS NULL) AND GIRIS <= @GUN AND (CIKIS IS NULL OR CIKIS >= @GUN)) X
		WHERE X.R = @K;

		---------------- Tarihler ----------------
		IF @HG = 5
			SET @SIP = DATEADD(MINUTE, 540 + FLOOR(RAND() * 210), CAST(@GUN AS datetime));
		ELSE
			SET @SIP = DATEADD(MINUTE, 510 + FLOOR(RAND() * 570), CAST(@GUN AS datetime));

		SET @PL_SEVK = DATEADD(HOUR, 9, CAST(DATEADD(DAY, 3 + FLOOR(RAND() * 12) + CASE WHEN @YURTDISI = 1 THEN 5 ELSE 0 END, @GUN) AS datetime));

		-- Gecikme daðýlýmý (2023 sonrasý operasyon iyileþiyor)
		SET @R = RAND();
		IF YEAR(@GUN) <= 2023
			SET @GECIKME = CASE WHEN @R < 0.50 THEN -FLOOR(RAND() * 3)
								WHEN @R < 0.85 THEN 1 + FLOOR(RAND() * 5)
								ELSE 6 + FLOOR(RAND() * 15) END;
		ELSE
			SET @GECIKME = CASE WHEN @R < 0.65 THEN -FLOOR(RAND() * 3)
								WHEN @R < 0.93 THEN 1 + FLOOR(RAND() * 4)
								ELSE 5 + FLOOR(RAND() * 12) END;

		SET @GS_SEVK = DATEADD(MINUTE, 420 + FLOOR(RAND() * 600), CAST(DATEADD(DAY, @GECIKME, CAST(@PL_SEVK AS date)) AS datetime));
		IF @GS_SEVK < DATEADD(DAY, 1, @SIP) SET @GS_SEVK = DATEADD(DAY, 1, @SIP);

		SET @PL_TES = DATEADD(DAY, CASE WHEN @YURTDISI = 1 THEN 10 ELSE 2 END, @PL_SEVK);
		SET @TRANSIT = CASE WHEN @YURTDISI = 1 THEN 6 + FLOOR(RAND() * 13) ELSE 1 + FLOOR(RAND() * 4) END;
		SET @GS_TES = DATEADD(MINUTE, 540 + FLOOR(RAND() * 480), CAST(DATEADD(DAY, @TRANSIT, CAST(@GS_SEVK AS date)) AS datetime));

		---------------- Durum ----------------
		SET @IPTAL = CASE WHEN RAND() < CASE WHEN @SEGMENT IN ('KAMU', 'BELEDIYE') THEN 0.02 ELSE 0.05 END THEN 1 ELSE 0 END;

		IF @IPTAL = 1
		BEGIN
			SET @DURUM = 'Ýptal';
			SET @GS_SEVK = NULL; SET @GS_TES = NULL;
			IF RAND() < 0.5 BEGIN SET @PL_SEVK = NULL; SET @PL_TES = NULL; END;
		END
		ELSE IF @GS_TES <= @BUGUN_DT
		BEGIN
			SET @DURUM = CASE WHEN RAND() < 0.025 THEN 'Ýade' ELSE 'Teslim Edildi' END;
			IF @DURUM = 'Teslim Edildi' AND RAND() < 0.004
			BEGIN
				SET @DURUM = 'Sevk Edildi';    -- teslim bilgisi sisteme hiç girilmemiþ (veri kalitesi örneði)
				SET @GS_TES = NULL;
			END;
		END
		ELSE IF @GS_SEVK <= @BUGUN_DT
		BEGIN
			SET @DURUM = 'Sevk Edildi';
			SET @GS_TES = NULL;
		END
		ELSE
		BEGIN
			SET @GS_SEVK = NULL; SET @GS_TES = NULL;
			IF DATEDIFF(DAY, @SIP, @BUGUN_DT) <= 1 AND RAND() < 0.7
			BEGIN
				SET @DURUM = 'Beklemede';
				SET @PL_SEVK = NULL; SET @PL_TES = NULL;
			END
			ELSE IF @PL_SEVK <= DATEADD(DAY, 4, @BUGUN_DT)
				SET @DURUM = 'Hazýrlanýyor';
			ELSE
				SET @DURUM = 'Onaylandý';
		END;

		-- Planlanan teslim tarihi girilmemiþ kayýtlar
		IF @PL_TES IS NOT NULL AND RAND() < 0.03 SET @PL_TES = NULL;

		---------------- Teslimat adresi ----------------
		SET @T_SEHIR = @M_SEHIR; SET @T_ULKE = @M_ULKE; SET @T_ADRES = @M_ADRES;
		SET @R = RAND();
		IF @SEGMENT = 'PERAKENDE'
		BEGIN
			IF @R < 0.5 BEGIN SET @T_SEHIR = NULL; SET @T_ULKE = NULL; SET @T_ADRES = NULL; END
			ELSE
			BEGIN
				SET @K = FLOOR(RAND() * @SEHIR_CNT) + 1;
				SELECT @T_SEHIR = SEHIR FROM #SEHIR WHERE RN = @K;
				SET @T_ULKE = N'Türkiye';
				SET @T_ADRES = N'Fabrikadan teslim';
			END;
		END
		ELSE IF @YURTDISI = 1 AND @R < 0.12
		BEGIN
			SET @T_SEHIR = N'Mersin'; SET @T_ULKE = N'Türkiye';
			SET @T_ADRES = N'Mersin Limaný Gümrüklü Saha (FOB)';
		END
		ELSE IF @YURTDISI = 0 AND @R < 0.18
		BEGIN
			SET @K = FLOOR(RAND() * @SEHIR_CNT) + 1;
			SELECT @T_SEHIR = SEHIR FROM #SEHIR WHERE RN = @K;
			SET @T_ULKE = N'Türkiye';
			SET @T_ADRES = N'Þantiye: ' + @T_SEHIR + N' '
						 + CHOOSE(1 + FLOOR(RAND() * 4), N'Çevre Yolu Km ', N'Bölünmüþ Yol Km ', N'OSB Baðlantý Yolu Km ', N'Otoyol Kesimi Km ')
						 + CAST(5 + FLOOR(RAND() * 180) AS nvarchar(10));
		END;

		INSERT SATIS.SIPARISLER
			(SIPARIS_TARIHI, PLANLANAN_SEVK_TARIHI, GERCEKLESEN_SEVK_TARIHI, PLANLANAN_TESLIM_TARIHI, GERCEKLESEN_TESLIM_TARIHI,
			 PERSONEL_ID, MUSTERI_ID, TESLIMAT_SEHIR, TESLIMAT_ULKE, TESLIMAT_ADRES, DURUM)
		VALUES
			(@SIP, @PL_SEVK, @GS_SEVK, @PL_TES, @GS_TES,
			 @PERSONEL_ID, @MUSTERI_ID, @T_SEHIR, @T_ULKE, @T_ADRES, @DURUM);

		SET @SID = SCOPE_IDENTITY();

		---------------- Sipariþ satýrlarý ----------------
		SET @R = RAND();
		SET @SATIR = CASE WHEN @R < 0.35 THEN 1 WHEN @R < 0.60 THEN 2 WHEN @R < 0.78 THEN 3
						  WHEN @R < 0.90 THEN 4 WHEN @R < 0.96 THEN 5 ELSE 6 + FLOOR(RAND() * 3) END;
		SET @SEGC = CASE @SEGMENT WHEN 'KAMU' THEN 1.3 WHEN 'BELEDIYE' THEN 0.9 WHEN 'MUTEAHHIT' THEN 1.1
								  WHEN 'BAYI' THEN 0.6 WHEN 'ENERJI' THEN 1.0 WHEN 'GES' THEN 1.2
								  WHEN 'YURTDISI' THEN 1.5 ELSE 0.08 END;

		SET @J = 1; SET @DENEME = 0;
		WHILE @J <= @SATIR AND @DENEME < 25
		BEGIN
			SET @DENEME += 1;
			SET @FILTRE = CASE WHEN RAND() < 0.75 THEN 1 ELSE 0 END;

			SELECT @CNT = COUNT(*) FROM #UH H
			WHERE H.BAS <= @GUN AND (H.BIT IS NULL OR H.BIT >= @GUN)
			  AND (@FILTRE = 0 OR H.GRUP IN (SELECT T.GRUP FROM #TERCIH T WHERE T.SEGMENT = @SEGMENT));
			IF @CNT = 0
			BEGIN
				SET @FILTRE = 0;
				SELECT @CNT = COUNT(*) FROM #UH H WHERE H.BAS <= @GUN AND (H.BIT IS NULL OR H.BIT >= @GUN);
			END;

			SET @K = FLOOR(RAND() * @CNT) + 1;
			SELECT @URUN_ID = X.URUN_ID
			FROM (SELECT H.URUN_ID, ROW_NUMBER() OVER (ORDER BY H.RN) AS R
				  FROM #UH H
				  WHERE H.BAS <= @GUN AND (H.BIT IS NULL OR H.BIT >= @GUN)
					AND (@FILTRE = 0 OR H.GRUP IN (SELECT T.GRUP FROM #TERCIH T WHERE T.SEGMENT = @SEGMENT))) X
			WHERE X.R = @K;

			IF EXISTS (SELECT 1 FROM SATIS.SIPARIS_DETAY WHERE SIPARIS_ID = @SID AND URUN_ID = @URUN_ID)
				CONTINUE;

			SELECT @LISTE = LISTE, @TIPIK = TIPIK FROM #UX WHERE URUN_ID = @URUN_ID;

			-- Miktar
			SET @ADET = CEILING(@TIPIK * (0.3 + RAND() * 1.4) * @SEGC);
			IF @TIPIK >= 50 SET @ADET = CEILING(@ADET / 10.0) * 10;
			IF @ADET < 1 SET @ADET = 1;

			-- Fiyat (o ayýn fiyat seviyesi ± %4)
			SET @FIYAT = ROUND(@LISTE * @ENFC * (0.96 + RAND() * 0.08), 2);
			IF @FIYAT < 0.01 SET @FIYAT = 0.01;

			-- Ýndirim
			SET @R = RAND();
			SET @IND = CASE WHEN @R < 0.45 THEN 0 WHEN @R < 0.65 THEN 0.05 WHEN @R < 0.80 THEN 0.10
							WHEN @R < 0.92 THEN 0.15 ELSE 0.20 END;
			IF @SEGMENT IN ('KAMU', 'BELEDIYE') SET @IND = CASE WHEN @IND / 2 > 0.10 THEN 0.10 ELSE @IND / 2 END;
			IF @SEGMENT = 'BAYI' SET @IND = @IND + 0.05;
			IF @ADET >= 2 * @TIPIK AND @SEGMENT <> 'PERAKENDE' SET @IND = @IND + 0.025;
			IF @SEGMENT = 'PERAKENDE' SET @IND = 0;
			IF @IND > 0.30 SET @IND = 0.30;

			INSERT SATIS.SIPARIS_DETAY(SIPARIS_ID, URUN_ID, ADET, BIRIM_FIYAT, INDIRIM_ORANI)
			VALUES (@SID, @URUN_ID, @ADET, @FIYAT, @IND);

			SET @J += 1;
		END;

		SET @I += 1;
	END;

	SET @GUN = DATEADD(DAY, 1, @GUN);
END;

COMMIT;

/* =====================================================================
   7. KONTROL ÖZETÝ
   ===================================================================== */
SELECT YEAR(S.SIPARIS_TARIHI) AS YIL,
	   COUNT(DISTINCT S.SIPARIS_ID) AS SIPARIS_SAYISI,
	   COUNT(*) AS SATIR_SAYISI,
	   SUM(D.ADET * D.BIRIM_FIYAT * (1 - D.INDIRIM_ORANI)) AS NET_CIRO
FROM SATIS.SIPARISLER S
JOIN SATIS.SIPARIS_DETAY D ON D.SIPARIS_ID = S.SIPARIS_ID
GROUP BY YEAR(S.SIPARIS_TARIHI)
ORDER BY YIL;

SELECT DURUM, COUNT(*) AS ADET
FROM SATIS.SIPARISLER
GROUP BY DURUM
ORDER BY ADET DESC;

DROP TABLE #U, #UX, #UH, #N, #P, #S, #M, #MX, #MH, #TERCIH, #SEHIR, #ENF;
GO