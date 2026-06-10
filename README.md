# NotchHero

MacBook çentik (notch) alanında çalışan, Godot 4.6 tabanlı bir idle/RPG oyunu. Pencere ekranın üst ortasına hizalanır; fare çentiğe gelince panel açılır ve savaş, büyü ve envanter arayüzü görünür.

## Gereksinimler

- macOS (çentik algılama için native bileşenler)
- [Godot 4.6](https://godotengine.org/)
- Xcode / Swift derleyicisi (native probe ve GDExtension için)

## Kurulum ve çalıştırma

```bash
cd /Users/mek/Desktop/Projects/notch-hero
chmod +x native/build_all.sh
./native/build_all.sh
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

`build_all.sh` Swift tabanlı çentik probunu ve Godot GDExtension köprüsünü derler. Ardından Godot projesini açarak veya yukarıdaki komutla doğrudan çalıştırabilirsiniz.

## Varlıklar (Assets)

Karakter sprite'ları [Medieval Fantasy Humans Bundle #1](https://itch.io/s/146626/medieval-fantasy-humans-bundle-1) paketinden (Elthen's Pixel Art Shop) kullanılmaktadır.

## Item katalogları (JSON üretimi)

Silah ve eşya tanımları elle `data/weapons.json` / `data/equipment.json` içine yazılmak yerine Python script'leriyle üretilir. Aynı sprite birden fazla özel isimle paylaşılabilir; statlar `stats` alanında ayrı ayrı tanımlanır.

**Gereksinim:** Python 3 (macOS’ta genelde `python3` olarak gelir; ek kurulum gerekmez).

Proje kök dizininden çalıştırın:

```bash
cd /Users/mek/Desktop/Projects/notch-hero

# 150 silah (5 tip × 30 isim) → data/weapons.json
python3 tools/generate_weapons.py

# 80 eşya (zırh, yüzük, küpe vb.) → data/equipment.json
python3 tools/generate_equipment.py
```

Başarılı çalıştırmada terminalde örneğin `Written 150 weapons to ...` mesajı görünür. Godot açıkken dosyalar değişirse projeyi yeniden yükle veya oyunu bir kez yeniden başlat; `item_data.gd` bu JSON dosyalarını otomatik okur.

**İsim veya stat değiştirmek için:**

1. `tools/generate_weapons.py` veya `tools/generate_equipment.py` içindeki isim listelerini / stat tablolarını düzenle.
2. Yukarıdaki komutu tekrar çalıştır.
3. Üretilen JSON commit’lenebilir; oyun runtime’da script çalıştırmaz.

| Script | Çıktı | İçerik |
|--------|-------|--------|
| `tools/generate_weapons.py` | `data/weapons.json` | axes, swords, sticks, maces, warhammers |
| `tools/generate_equipment.py` | `data/equipment.json` | chest, leggings, helmet, shoes, gloves, amulet, ring, earrings |

`data/items.json` boş tutulur; tüm loot havuzu `weapons.json` + `equipment.json` üzerinden gelir.

## Proje yapısı

| Dizin | Açıklama |
|-------|----------|
| `scenes/` | Ana sahne ve UI |
| `scripts/` | Oyun mantığı, çentik penceresi, UI |
| `data/` | `weapons.json`, `equipment.json`, `stages.json`, oyun config |
| `tools/` | Item katalog üretim script'leri |
| `assets/characters/` | Sprite sheet'ler |
| `native/` | Swift probe, GDExtension köprüsü ve derleme script'leri |
