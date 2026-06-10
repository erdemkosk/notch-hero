#!/usr/bin/env python3
"""Generate data/weapons.json — 30 named weapons per type (150 total)."""

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "data" / "weapons.json"

RARITY_COUNTS = [("basic", 6), ("common", 9), ("rare", 9), ("unique", 6)]

# Weapon attack only (hero base_attack is separate). Unique cap = 50.
BASIC_ATK = [2, 3, 3, 4, 4, 5]
COMMON_ATK = [6, 7, 8, 8, 9, 9, 10, 7, 8]
RARE_ATK = [14, 15, 16, 17, 18, 19, 20, 14, 16]
UNIQUE_ATK = [32, 36, 38, 42, 46, 50]

ATK_BY_RARITY = {
    "basic": BASIC_ATK,
    "common": COMMON_ATK,
    "rare": RARE_ATK,
    "unique": UNIQUE_ATK,
}

SINGLE_SPRITES = {
    "axes": {
        "basic": "basic-axe-removebg-preview.png",
        "common": "common-axe-removebg-preview.png",
        "rare": "rare-axe-removebg-preview.png",
        "unique": "unique-axe-removebg-preview.png",
    },
    "sticks": {
        "basic": "basic-stick-removebg-preview.png",
        "common": "common-stick-removebg-preview.png",
        "rare": "rare-stick-removebg-preview.png",
        "unique": "unique-stick-removebg-preview.png",
    },
    "maces": {
        "basic": "basic-mace-removebg-preview.png",
        "common": "common-mace-removebg-preview.png",
        "rare": "rare-mace-removebg-preview.png",
        "unique": "unique-mace-removebg-preview.png",
    },
    "warhammers": {
        "basic": "basic-warhammer-removebg-preview.png",
        "common": "common-warhammer-removebg-preview.png",
        "rare": "rare-warhammer-removebg-preview.png",
        "unique": "unique-warhammer-removebg-preview.png",
    },
}

SWORD_SPRITES = {
    "basic": [
        "basic-sword1-removebg-preview.png",
        "basic-sword2-removebg-preview.png",
        "basic-sword3-removebg-preview.png",
    ],
    "common": [
        "common-sword1-removebg-preview.png",
        "common-sword2-removebg-preview.png",
        "common-sword3-removebg-preview.png",
    ],
    "rare": [
        "rare-sword-1-removebg-preview.png",
        "rare-sword2-removebg-preview.png",
        "rare-sword3-removebg-preview.png",
    ],
    "unique": [
        "unique-sword1-removebg-preview.png",
        "unique-sword2-removebg-preview.png",
        "unique-sword3-removebg-preview.png",
    ],
}

WEAPON_NAMES = {
    "axes": {
        "basic": [
            "Hand Axe",
            "Woodcutter",
            "Field Hatchet",
            "Lumber Axe",
            "Rusty Cleaver",
            "Camp Hatchet",
        ],
        "common": [
            "Iron Hatchet",
            "Battle Axe",
            "Cleaving Axe",
            "Hunter's Axe",
            "Raider's Hatchet",
            "Tomahawk",
            "Forester's Axe",
            "Woodsman's Tool",
            "Brigand Axe",
        ],
        "rare": [
            "Frost Hatchet",
            "Skullsplitter",
            "War Axe",
            "Bone Cleaver",
            "Storm Hatchet",
            "Berserker Axe",
            "Ogre Cleaver",
            "Warden's Axe",
            "Night Hatchet",
        ],
        "unique": [
            "Ragnarok",
            "Worldbreaker",
            "Apocalypse",
            "Doom Cleaver",
            "Titan's Fury",
            "Void Hatchet",
        ],
    },
    "swords": {
        "basic": [
            "Rusty Sword",
            "Training Blade",
            "Worn Saber",
            "Militia Sword",
            "Bent Falchion",
            "Scout Blade",
        ],
        "common": [
            "Iron Longsword",
            "Steel Saber",
            "Twin Fang",
            "Knight's Edge",
            "Silver Blade",
            "Raider's Sword",
            "Guard Longsword",
            "Crystal Shard",
            "Noble Saber",
        ],
        "rare": [
            "Crystal Edge",
            "Storm Rapier",
            "Whirling Blades",
            "Moonblade",
            "Sun Piercer",
            "Shadow Dancer",
            "Frost Sword",
            "Ember Edge",
            "Warden's Blade",
        ],
        "unique": [
            "Nightmare Blade",
            "Soulreaver",
            "Excalibur Echo",
            "Void Katana",
            "Dragon Fang",
            "Starfall",
        ],
    },
    "sticks": {
        "basic": [
            "Driftwood Staff",
            "Crooked Cane",
            "Birch Rod",
            "Worn Wand",
            "Pilgrim's Staff",
            "Twig Scepter",
        ],
        "common": [
            "Oak Cudgel",
            "Iron-shod Staff",
            "Walking Stick",
            "Elder Stick",
            "Runed Branch",
            "Ash Wand",
            "Willow Rod",
            "Mystic Cane",
            "Sage's Twig",
        ],
        "rare": [
            "Thunder Rod",
            "Sage's Staff",
            "Bone Wand",
            "Arcane Baton",
            "Stormcaller",
            "Moon Scepter",
            "Spirit Staff",
            "Hollow Wand",
            "Grovekeeper",
        ],
        "unique": [
            "Archmage Rod",
            "Void Scepter",
            "Eternity Staff",
            "Cosmos Wand",
            "Eldritch Rod",
            "World Tree Branch",
        ],
    },
    "maces": {
        "basic": [
            "Wooden Club",
            "Spiked Knuckle",
            "Stone Knuckle",
            "Bramble Mace",
            "Thump Club",
            "Rusty Flail",
        ],
        "common": [
            "Iron Mace",
            "Flanged Mace",
            "Morning Star",
            "Spiked Club",
            "Knight's Cudgel",
            "Bone Club",
            "Lead Pipe",
            "War Club",
            "Iron Star",
        ],
        "rare": [
            "Skull Crusher",
            "Dwarven Maul",
            "Blessed Censer",
            "Thunder Mace",
            "Ogre Club",
            "Warden's Gavel",
            "Sun Hammer",
            "Bone Flail",
            "Hex Mace",
        ],
        "unique": [
            "Doom Gavel",
            "Titan's Gavel",
            "Judgment",
            "Cataclysm Mace",
            "Void Crusher",
            "Rune Hammer",
        ],
    },
    "warhammers": {
        "basic": [
            "Rusty Hammer",
            "Mining Pick",
            "Forge Tongs",
            "Wooden Mallet",
            "Stone Hammer",
            "Bent Sledge",
        ],
        "common": [
            "Forge Hammer",
            "Sledgehammer",
            "War Hammer",
            "Iron Maul",
            "Blacksmith Hammer",
            "Mason's Hammer",
            "Rail Driver",
            "Heavy Maul",
            "Iron Sledge",
        ],
        "rare": [
            "Thunder Hammer",
            "Earthshaker",
            "Runic Iron Maul",
            "Meteor Hammer",
            "Titan's Hammer",
            "Storm Maul",
            "Siege Hammer",
            "Granite Breaker",
            "Warden's Maul",
        ],
        "unique": [
            "Molten Crusher",
            "Cataclysm",
            "World Cracker",
            "Doom Hammer",
            "Void Maul",
            "Starbreaker",
        ],
    },
}


def slugify(name: str) -> str:
    s = name.lower().replace("'", "")
    s = re.sub(r"[^a-z0-9]+", "-", s)
    return s.strip("-")


def weapon(folder: str, name: str, rarity: str, sprite_file: str, attack: int) -> dict:
    slug = slugify(name)
    return {
        "id": f"{folder}/{slug}",
        "name": name,
        "slot": "weapon",
        "rarity": rarity,
        "sprite": f"res://assets/items/{folder}/{sprite_file}",
        "folder": folder,
        "stats": {"attack": attack},
    }


def sprite_for(folder: str, rarity: str, index: int) -> str:
    if folder == "swords":
        return SWORD_SPRITES[rarity][index % len(SWORD_SPRITES[rarity])]
    return SINGLE_SPRITES[folder][rarity]


def build_type(folder: str) -> list:
    items = []
    for rarity, count in RARITY_COUNTS:
        names = WEAPON_NAMES[folder][rarity]
        attacks = ATK_BY_RARITY[rarity]
        assert len(names) == count
        for i, name in enumerate(names):
            items.append(
                weapon(folder, name, rarity, sprite_for(folder, rarity, i), attacks[i])
            )
    return items


def main() -> None:
    items = []
    for folder in ["axes", "swords", "sticks", "maces", "warhammers"]:
        items.extend(build_type(folder))

    OUT.write_text(json.dumps({"weapons": items}, indent=2) + "\n")
    print(f"Written {len(items)} weapons to {OUT}")


if __name__ == "__main__":
    main()
