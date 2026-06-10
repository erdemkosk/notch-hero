#!/usr/bin/env python3
"""Generate data/equipment.json with named gear variants."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "data" / "equipment.json"


def eq(folder, slug, name, slot, rarity, sprite_file, stats):
    return {
        "id": f"{folder}/{slug}",
        "name": name,
        "slot": slot,
        "rarity": rarity,
        "sprite": f"res://assets/items/{folder}/{sprite_file}",
        "folder": folder,
        "stats": stats,
    }


def main() -> None:
    items = []

    chest = [
        ("padded-vest", "Padded Vest", "basic", "basic-chest-removebg-preview.png", {"armor": 2, "max_hp": 6}),
        ("leather-jerkin", "Leather Jerkin", "basic", "basic-chest2.png", {"armor": 2, "max_hp": 7}),
        ("iron-breastplate", "Iron Breastplate", "common", "common-chest-removebg-preview.png", {"armor": 4, "max_hp": 12}),
        ("steel-cuirass", "Steel Cuirass", "common", "common-chest-removebg-preview.png", {"armor": 3, "max_hp": 10}),
        ("chain-hauberk", "Chain Hauberk", "common", "common-chest2.png", {"armor": 4, "max_hp": 11}),
        ("knights-plate", "Knight's Plate", "rare", "rare-chest-removebg-preview.png", {"armor": 6, "max_hp": 20}),
        ("wardens-mail", "Warden's Mail", "rare", "rare-chest2.png", {"armor": 5, "max_hp": 18}),
        ("dragonscale-vest", "Dragonscale Vest", "rare", "rare-chest-removebg-preview.png", {"armor": 7, "max_hp": 19}),
        ("aegis-of-kings", "Aegis of Kings", "unique", "unique-chest-removebg-preview.png", {"armor": 11, "max_hp": 34}),
        ("voidguard-mail", "Voidguard Mail", "unique", "unique-chest2.png", {"armor": 10, "max_hp": 32}),
    ]
    for slug, name, rarity, sprite, stats in chest:
        items.append(eq("chest", slug, name, "chest", rarity, sprite, stats))

    leggings = [
        ("cloth-pants", "Cloth Pants", "basic", "basic-leggings-removebg-preview.png", {"armor": 1}),
        ("chain-leggings", "Chain Leggings", "basic", "basic-leggings2.png", {"armor": 2}),
        ("iron-greaves", "Iron Greaves", "common", "common-leggings-removebg-preview.png", {"armor": 3}),
        ("steel-legguards", "Steel Legguards", "common", "common-leggings-removebg-preview.png", {"armor": 2}),
        ("mail-chausses", "Mail Chausses", "common", "common-leggings2.png", {"armor": 3}),
        ("knights-greaves", "Knight's Greaves", "rare", "rare-leggings-removebg-preview.png", {"armor": 5}),
        ("wardens-chausses", "Warden's Chausses", "rare", "rare-leggings2.png", {"armor": 4}),
        ("shadow-legguards", "Shadow Legguards", "rare", "rare-leggings-removebg-preview.png", {"armor": 5}),
        ("titans-stride", "Titan's Stride", "unique", "unique-leggings-removebg-preview.png", {"armor": 8}),
        ("nethermail-leggings", "Nethermail Leggings", "unique", "unique-leggings2.png", {"armor": 7}),
    ]
    for slug, name, rarity, sprite, stats in leggings:
        items.append(eq("leggings", slug, name, "legs", rarity, sprite, stats))

    helmet = [
        ("leather-cap", "Leather Cap", "basic", "basic-helmet-removebg-preview.png", {"armor": 1, "max_hp": 4}),
        ("horned-cap", "Horned Cap", "basic", "basic-helmet2.png", {"armor": 1, "max_hp": 5}),
        ("iron-helm", "Iron Helm", "common", "common-helmet-removebg-preview.png", {"armor": 3, "max_hp": 10}),
        ("steel-sallet", "Steel Sallet", "common", "common-helmet-removebg-preview.png", {"armor": 2, "max_hp": 8}),
        ("horned-guard", "Horned Guard", "common", "common-helmet2.png", {"armor": 3, "max_hp": 9}),
        ("knights-helm", "Knight's Helm", "rare", "rare-halmet-removebg-preview.png", {"armor": 5, "max_hp": 16}),
        ("berserker-horns", "Berserker Horns", "rare", "rare-helmet2.png", {"armor": 4, "max_hp": 14}),
        ("wardens-helm", "Warden's Helm", "rare", "rare-halmet-removebg-preview.png", {"armor": 5, "max_hp": 15}),
        ("crown-of-thorns", "Crown of Thorns", "unique", "unique-helmet-removebg-preview.png", {"armor": 7, "max_hp": 26}),
        ("doom-horns", "Doom Horns", "unique", "unique-helmet2.png", {"armor": 8, "max_hp": 24}),
    ]
    for slug, name, rarity, sprite, stats in helmet:
        items.append(eq("helmet", slug, name, "helmet", rarity, sprite, stats))

    shoes = [
        ("worn-sandals", "Worn Sandals", "basic", "basic-shoe-removebg-preview.png", {"armor": 1}),
        ("chain-boots", "Chain Boots", "basic", "basic-shoe2.png", {"armor": 1}),
        ("leather-boots", "Leather Boots", "common", "common-shoe-removebg-preview.png", {"armor": 2}),
        ("iron-sabatons", "Iron Sabatons", "common", "common-shoe-removebg-preview.png", {"armor": 1}),
        ("mail-boots", "Mail Boots", "common", "common-shoe2.png", {"armor": 2}),
        ("knights-treads", "Knight's Treads", "rare", "rare-shoe-removebg-preview.png", {"armor": 3}),
        ("plated-greaves", "Plated Greaves", "rare", "rare-shoe2.png", {"armor": 3}),
        ("shadow-steps", "Shadow Steps", "rare", "rare-shoe-removebg-preview.png", {"armor": 2}),
        ("windwalkers", "Windwalkers", "unique", "unique-shoe-removebg-preview.png", {"armor": 4}),
        ("titans-stomp", "Titan's Stomp", "unique", "unique-shoe2.png", {"armor": 4}),
    ]
    for slug, name, rarity, sprite, stats in shoes:
        items.append(eq("shoes", slug, name, "feet", rarity, sprite, stats))

    gloves = [
        ("cloth-wraps", "Cloth Wraps", "basic", "basic-glove.png", {"attack": 1}),
        ("leather-gauntlets", "Leather Gauntlets", "basic", "basic-glove.png", {"attack": 2}),
        ("iron-grips", "Iron Grips", "common", "common-glove.png", {"attack": 3}),
        ("steel-gauntlets", "Steel Gauntlets", "common", "common-glove.png", {"attack": 2}),
        ("bandit-claws", "Bandit Claws", "common", "common-glove.png", {"attack": 2}),
        ("knights-grips", "Knight's Grips", "rare", "rare-glove.png", {"attack": 5}),
        ("spellweave-gloves", "Spellweave Gloves", "rare", "rare-glove.png", {"attack": 4}),
        ("assassins-touch", "Assassin's Touch", "rare", "rare-glove.png", {"attack": 5}),
        ("hand-of-fury", "Hand of Fury", "unique", "unique-glove.png", {"attack": 8}),
        ("titans-grasp", "Titan's Grasp", "unique", "unique-glove.png", {"attack": 7}),
    ]
    for slug, name, rarity, sprite, stats in gloves:
        items.append(eq("gloves", slug, name, "gloves", rarity, sprite, stats))

    amulet = [
        ("wooden-charm", "Wooden Charm", "basic", "basic-amulet-removebg-preview.png", {"max_hp": 4, "max_mana": 2}),
        ("bone-talisman", "Bone Talisman", "basic", "basic-amulet-removebg-preview.png", {"max_hp": 5, "max_mana": 3}),
        ("silver-amulet", "Silver Amulet", "common", "common-amulet-removebg-preview.png", {"max_hp": 10, "max_mana": 5}),
        ("jade-pendant", "Jade Pendant", "common", "common-amulet-removebg-preview.png", {"max_hp": 8, "max_mana": 4}),
        ("copper-charm", "Copper Charm", "common", "common-amulet-removebg-preview.png", {"max_hp": 9, "max_mana": 5}),
        ("ruby-amulet", "Ruby Amulet", "rare", "rare-amulet-removebg-preview.png", {"max_hp": 16, "max_mana": 8}),
        ("moonstone-pendant", "Moonstone Pendant", "rare", "rare-amulet-removebg-preview.png", {"max_hp": 14, "max_mana": 7}),
        ("sun-talisman", "Sun Talisman", "rare", "rare-amulet-removebg-preview.png", {"max_hp": 15, "max_mana": 8}),
        ("heart-of-eternity", "Heart of Eternity", "unique", "unique-amulet-removebg-preview.png", {"max_hp": 28, "max_mana": 14}),
        ("soulbinder", "Soulbinder", "unique", "unique-amulet-removebg-preview.png", {"max_hp": 26, "max_mana": 13}),
    ]
    for slug, name, rarity, sprite, stats in amulet:
        items.append(eq("amulet", slug, name, "amulet", rarity, sprite, stats))

    ring = [
        ("copper-band", "Copper Band", "basic", "basic-ring-removebg-preview.png", {"attack": 1, "spell_power": 1}),
        ("tin-ring", "Tin Ring", "basic", "basic-ring-removebg-preview.png", {"attack": 1, "spell_power": 1}),
        ("silver-ring", "Silver Ring", "common", "common-ring-removebg-preview.png", {"attack": 2, "spell_power": 2}),
        ("iron-band", "Iron Band", "common", "common-ring-removebg-preview.png", {"attack": 1, "spell_power": 2}),
        ("bronze-signet", "Bronze Signet", "common", "common-ring-removebg-preview.png", {"attack": 2, "spell_power": 1}),
        ("ruby-ring", "Ruby Ring", "rare", "rare-ring-removebg-preview.png", {"attack": 3, "spell_power": 3}),
        ("sapphire-band", "Sapphire Band", "rare", "rare-ring-removebg-preview.png", {"attack": 2, "spell_power": 3}),
        ("emerald-signet", "Emerald Signet", "rare", "rare-ring-removebg-preview.png", {"attack": 3, "spell_power": 2}),
        ("ring-of-kings", "Ring of Kings", "unique", "unique-ring-removebg-preview.png", {"attack": 4, "spell_power": 4}),
        ("void-loop", "Void Loop", "unique", "unique-ring-removebg-preview.png", {"attack": 3, "spell_power": 4}),
    ]
    for slug, name, rarity, sprite, stats in ring:
        items.append(eq("ring", slug, name, "ring", rarity, sprite, stats))

    earrings = [
        ("bone-stud", "Bone Stud", "basic", "basic-earring.png", {"spell_power": 1}),
        ("copper-stud", "Copper Stud", "basic", "basic-earring.png", {"spell_power": 2}),
        ("silver-hoop", "Silver Hoop", "common", "common-earring.png", {"spell_power": 3}),
        ("iron-earring", "Iron Earring", "common", "common-earring.png", {"spell_power": 2}),
        ("glass-bead", "Glass Bead", "common", "common-earring.png", {"spell_power": 2}),
        ("sapphire-stud", "Sapphire Stud", "rare", "rare-earring.png", {"spell_power": 5}),
        ("moonlit-hoop", "Moonlit Hoop", "rare", "rare-earring.png", {"spell_power": 4}),
        ("arcane-stud", "Arcane Stud", "rare", "rare-earring.png", {"spell_power": 5}),
        ("starfire-earring", "Starfire Earring", "unique", "unique-earring.png", {"spell_power": 8}),
        ("void-whisper", "Void Whisper", "unique", "unique-earring.png", {"spell_power": 7}),
    ]
    for slug, name, rarity, sprite, stats in earrings:
        items.append(eq("earrings", slug, name, "earring", rarity, sprite, stats))

    OUT.write_text(json.dumps({"equipment": items}, indent=2) + "\n")
    print(f"Written {len(items)} equipment items to {OUT}")


if __name__ == "__main__":
    main()
