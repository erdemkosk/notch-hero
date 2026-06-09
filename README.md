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

## Proje yapısı

| Dizin | Açıklama |
|-------|----------|
| `scenes/` | Ana sahne ve UI |
| `scripts/` | Oyun mantığı, çentik penceresi, UI |
| `assets/characters/` | Sprite sheet'ler |
| `native/` | Swift probe, GDExtension köprüsü ve derleme script'leri |
