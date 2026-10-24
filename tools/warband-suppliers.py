"""Generate the Warband supplier merchants: creatures, menus, vendor lists and prices.

What it produces:

    data/sql/updates/pending_db_world/2026_10_19_00_warband_suppliers.sql
        every table row needed for the merchants to exist and work. This is the directory
        AzerothCore's DB updater reads (Updates.EnableDatabases), so a clone that starts the
        server once gets the shops installed with no manual step, and the file clears the rows it
        owns first so applying it twice is harmless.

    data/sql/warband/revert_warband_suppliers.sql
        the exact inverse, self-contained, kept outside the updater's directory as the recovery
        script.

The catalogue is what a profession can actually create, read from the client's Spell.dbc (an effect
of type 24 makes an item), plus every trade good, gem, recipe and glyph. Glyphs are included directly
from item_template so minor glyphs are not lost when their creation spell is absent from Spell.dbc.
The tree below decides how a player clicks through it; each leaf becomes one vendor list, split only
when it holds more than the 150 items a 3.3.5 merchant window can show.

The tree, in short:

    auctioneer
    |-- Armor ................ Cloth / Leather / Mail / Plate / Shields / Other armour /
    |                          Trinkets and jewellery, then the slot, then the level range
    |-- Weapons .............. by family (one- and two-handed kept apart), then the level range
    |-- Containers ........... bags: plain, soul, herb, enchanting, engineering, gem, mining,
    |                          leatherworking, other
    |-- Materials & Reagents . one list per kind (cloth, leather, herbs, metal, ...)
    |-- Consumables .......... one list per kind (potions, elixirs, flasks, ...)
    |-- Glyphs ............... one list per class, plus Misc for unclassified glyphs
    |-- Gems ................. one list per colour
    |-- Recipes .............. one list per profession
    |-- Ammunition ........... arrows, bullets
    |-- Keys and tools ....... one small list, straight off the root

The deepest level of the equipment categories is the level range a player expects to shop by:
1-10, 11-20, 21-30, 31-40, 41-50, 51-60, 61-70, 71-80, with an extra "Any level" list for items
that have no level requirement. A range that is empty is simply not shown. Reagents, consumables,
recipes and gems are not split by level - a herb has no level - they stay one list per kind and are
only cut into "1 of 2" parts when a kind exceeds the 150-item window.

Nothing here runs at server runtime. The prices are the only values the module owns: they are seeded
into warband_setting, and warband_supplier_price keeps each item's original price so the Supplier
prices page in the addon can re-price the catalogue without compounding anything.

What the merchant charges is not what it pays. The paid value stays the rarity formula
max(10 copper, shipped sell price x multiplier[quality]); the charge is that same price plus what the
item's materials cost, each material priced by this same rule. A material that has its own recipe (a
bolt of cloth) contributes its own charge, a gathered one (raw cloth) contributes only its own price,
so the charge resolves bottom-up. The gap between the two numbers is what keeps buying from the
merchants and selling straight back from paying more than it cost, once the gold multiplier is
applied to the payout. Stock with no recipe - the recipes themselves, raw trade goods, raw gems -
charges exactly the merchant price.
"""
import argparse
import math
import os
import struct
import subprocess
import sys
from collections import OrderedDict

MYSQL = r"C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe"
INI = r"var\mysql-client.ini"
DATABASE = "acore_world"
# The forward SQL lives where AzerothCore's DB updater looks for it (Updates.EnableDatabases in
# worldserver.conf), so a clone that starts the server once gets the shops installed with no manual
# step. The reverse lives beside it, outside the updater's directory, as the recovery script.
OUT = r"data\sql\updates\pending_db_world"
APPLY_NAME = "2026_10_19_00_warband_suppliers.sql"
# The material-cost pass runs against an install that already has the catalogue, so it ships as its
# own update file - the base file is never edited once it has been applied anywhere.
PRICES_APPLY_NAME = "2026_10_24_02_warband_supplier_material_prices.sql"
REVERT_DIR = r"data\sql\warband"
REVERT_NAME = "revert_warband_suppliers.sql"
PRICES_REVERT_NAME = "revert_warband_supplier_material_prices.sql"
UPDATE_CHUNK = 400              # entries per generated statement
SPELL_DBC = r"var\data\dbc\Spell.dbc"

SOURCE_TEMPLATE = 8671          # Auctioneer Buckler: a plain humanoid to copy the holder templates from
HOLDER_BASE = 910000            # creature_template entries that only carry a list
MENU_BASE = 90100               # gossip_menu ids (90000-90002 are taken by shipped content)
TEXT_BASE = 90050               # npc_text ids
MAX_VENDOR_ITEMS = 150
GOSSIP_OPTION_GOSSIP = 1
GOSSIP_OPTION_VENDOR = 3
NPCFLAG_GOSSIP = 1
NPCFLAG_VENDOR = 128

# The merchant price: max(floor, original sell price * multiplier[quality]). This is what a merchant
# pays for the item; what the suppliers charge is this price plus the cost of its materials.
MULTIPLIERS = [2.0, 1.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0]
FLOOR = 10

# Names of the qualities in the order the game numbers them, for the saved settings.
QUALITY_KEYS = ["poor", "normal", "uncommon", "rare", "epic", "legendary", "artifact", "heirloom"]

# The inventory slots that are actually jewellery: neck, finger, trinket.
JEWELLERY_SLOTS = {2, 11, 12}

ARMOR_SUBCLASSES = {
    1: "Cloth", 2: "Leather", 3: "Mail", 4: "Plate", 6: "Shields", 0: "Trinkets and jewellery",
    7: "Librams", 8: "Idols", 9: "Totems", 10: "Sigils",
}
SLOT_NAMES = {
    0: "Not equippable", 1: "Head", 2: "Neck", 3: "Shoulders", 4: "Shirts", 5: "Chest", 6: "Waist",
    7: "Legs", 8: "Feet", 9: "Wrists", 10: "Hands", 11: "Fingers", 12: "Trinkets", 13: "One hand",
    14: "Shields", 15: "Ranged", 16: "Back", 17: "Two hand", 18: "Bags", 19: "Tabards", 20: "Robes",
    21: "Main hand", 22: "Off hand", 23: "Held in off hand", 24: "Ammunition", 25: "Thrown",
    26: "Ranged", 27: "Relics", 28: "Profession tools",
}
# Weapon families: group the one- and two-handed versions under a family name.
WEAPON_FAMILIES = {
    0: ("Axes", "One-handed"),
    1: ("Axes", "Two-handed"),
    4: ("Maces", "One-handed"),
    5: ("Maces", "Two-handed"),
    7: ("Swords", "One-handed"),
    8: ("Swords", "Two-handed"),
    6: ("Polearms", None),
    10: ("Staves", None),
    15: ("Daggers", None),
    13: ("Fist weapons", None),
    19: ("Wands", None),
    2: ("Bows", None),
    18: ("Crossbows", None),
    3: ("Guns", None),
    16: ("Thrown", None),
    20: ("Fishing poles", None),
    14: ("Off-hand weapons", None),
    17: ("Spears", None),
    11: ("Exotic weapons", None),
}
TRADE_GOOD_SUBCLASSES = {
    0: "Trade goods", 1: "Parts", 2: "Explosives", 3: "Devices", 4: "Jewelcrafting",
    5: "Cloth", 6: "Leather", 7: "Metal and stone", 8: "Meat", 9: "Herbs", 10: "Elemental",
    11: "Other reagents", 12: "Enchanting", 13: "Primal materials",
}
CONSUMABLE_SUBCLASSES = {
    0: "Miscellaneous", 1: "Potions", 2: "Elixirs", 3: "Flasks", 4: "Scrolls", 5: "Food and drink",
    6: "Item enhancements", 7: "Bandages", 8: "Other consumables",
}
RECIPE_SUBCLASSES = {
    0: "Books", 1: "Leatherworking", 2: "Tailoring", 3: "Engineering", 4: "Blacksmithing",
    5: "Cooking", 6: "Alchemy", 7: "First aid", 8: "Enchanting", 9: "Fishing", 10: "Jewelcrafting",
}
GEM_SUBCLASSES = {
    0: "Red", 1: "Blue", 2: "Yellow", 3: "Purple", 4: "Green", 5: "Orange", 6: "Meta",
    7: "Uncut and simple", 8: "Prismatic",
}
CONTAINER_SUBCLASSES = {
    0: "Bags", 1: "Soul bags", 2: "Herb bags", 3: "Enchanting bags",
    4: "Engineering bags and toolboxes", 5: "Gem bags", 6: "Mining bags",
    7: "Leatherworking bags", 8: "Other containers",
}
AMMUNITION_SUBCLASSES = {2: "Arrows", 3: "Bullets"}
# Glyph subclasses are the class the glyph is for.
GLYPH_CLASSES = {
    1: "Warrior", 2: "Paladin", 3: "Hunter", 4: "Rogue", 5: "Priest", 6: "Death Knight",
    7: "Shaman", 8: "Mage", 9: "Warlock", 10: "Misc", 11: "Druid",
}


# --- talking to MySQL and to the client data ----------------------------------------------------

def query(sql):
    result = subprocess.run(
        [MYSQL, "--defaults-file=" + INI, "-N", "-B", "-e", sql, DATABASE],
        capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit(result.stderr)
    return [line.split("\t") for line in result.stdout.strip().split("\n") if line]


def sql_text(value):
    return "'" + str(value).replace("\\", "\\\\").replace("'", "''") + "'"


def read_spell_dbc(path):
    """Every item a spell creates, and the reagents each of those spells consumes.

    Field 71/72/73 are the three effect slots and 107/108/109 the item each one creates; a create-item
    effect is 24. The eight reagent entries are fields 52-59 and their counts 60-67, as declared in
    src/server/shared/DataStores/DBCStructure.h (SpellEntry, "m_reagent"/"m_reagentCount"). The indices
    were confirmed against known crafting spells (a tailoring bolt) before this file existed, and the
    script re-checks one of them on every run.

    The return value is the set of crafted items and a map from item to the reagents of the first
    spell that creates it - each item is priced from its own recipe, with no comparison between
    candidate recipes.
    """
    raw = open(path, "rb").read()
    magic, records, fields, record_size, _string_size = struct.unpack_from("<4sIIII", raw, 0)
    if magic != b"WDBC":
        raise SystemExit("not a DBC file: %r" % magic)
    if record_size != fields * 4:
        raise SystemExit("record size %d does not match %d fields" % (record_size, fields))

    base = 20
    created = set()
    recipes = {}
    effect_slots = (71, 72, 73)
    item_fields = (107, 108, 109)
    reagent_fields = 52
    reagent_count_fields = 60

    for index in range(records):
        record = struct.unpack_from("<%dI" % fields, raw, base + index * record_size)

        # Self check: Bolt of Linen must still be readable as creating Bolt of Linen.
        if record[0] == 2963 and record[107] != 2996:
            raise SystemExit("Spell.dbc layout check failed: spell 2963 does not create item 2996")

        made = [record[item_field]
                for slot, item_field in zip(effect_slots, item_fields)
                if record[slot] == 24 and record[item_field]]
        if not made:
            continue

        created.update(made)

        reagents = [(record[reagent_fields + offset], record[reagent_count_fields + offset])
                    for offset in range(8)
                    if record[reagent_fields + offset] and record[reagent_count_fields + offset]]
        if not reagents:
            continue

        for entry in made:
            recipes.setdefault(entry, reagents)

    return created, recipes


# --- pricing ------------------------------------------------------------------------------------

def rarity_price(sell, quality):
    """The merchant price: max(floor, shipped sell price * multiplier[quality])."""
    multiplier = MULTIPLIERS[quality] if 0 <= quality < len(MULTIPLIERS) else 1.0
    return max(FLOOR, int(math.floor(sell * multiplier + 0.5)))


class PriceBook:
    """The charge of every item: its own merchant price plus what the recipe's materials cost.

    A material is priced by the same rule, so the materials have to be resolved before the item that
    uses them; the memo makes that one pass per item. `materials()` reports the material sum alone,
    which is what warband_supplier_price stores - 0 means the item has no recipe and charges exactly
    its merchant price.
    """

    def __init__(self, items, recipes):
        self.items = items          # entry -> dict with "quality" and "sell" (the shipped price)
        self.recipes = recipes      # entry -> [(reagent entry, count)]
        self._charge = {}
        self._materials = {}
        self._busy = set()

    def rarity(self, entry):
        item = self.items.get(entry)
        if not item:
            return 0
        return rarity_price(item["sell"], item["quality"])

    def materials(self, entry):
        self.charge(entry)
        return self._materials.get(entry, 0)

    def charge(self, entry):
        if entry in self._charge:
            return self._charge[entry]

        if entry in self._busy:
            return self.rarity(entry)      # a cycle cannot exist in the game data; never recurse

        base = self.rarity(entry)
        if not base:
            return 0

        self._busy.add(entry)
        total = 0
        for reagent, count in self.recipes.get(entry, ()):
            total += count * self.charge(reagent)
        self._busy.discard(entry)

        self._charge[entry] = base + total
        self._materials[entry] = total

        return self._charge[entry]


# --- catalogue ----------------------------------------------------------------------------------

def load_catalogue():
    """Every item the suppliers stock, with the fields the tree routes on."""
    rows = query(
        "SELECT entry, name, class, subclass, InventoryType, Quality, RequiredLevel, ItemLevel, "
        "BuyPrice, SellPrice FROM item_template")

    items = []
    for row in rows:
        items.append({
            "entry": int(row[0]),
            "name": row[1],
            "class": int(row[2]),
            "subclass": int(row[3]),
            "slot": int(row[4]),
            "quality": int(row[5]),
            "req": int(row[6]),
            "ilvl": int(row[7]),
            "buy": int(row[8]),
            "sell": int(row[9]),
        })
    return items


DEV_NAME_MARKERS = (
    "Monster -", "Monster ", "Deprecated", "OLD", "Test ", "Creature -", "NPC Equip ", "UNUSED", "DND")

TRADE_GOODS = 7
CONSUMABLES = 0
GEMS = 3
ARMOR = 4
WEAPONS = 2
RECIPES = 9
CONTAINERS = 1
GLYPHS = 16
AMMUNITION = 6
KEYS = 13
SKIP_CLASSES = {12, 11, 15, 10}   # quest items, quivers, miscellaneous junk, PvP marks


def is_dev_item(item):
    upper = item["name"]
    return any(marker in upper for marker in DEV_NAME_MARKERS)


def build_catalogue(items, crafted):
    """Crafted items plus all trade goods, gems, recipes and glyphs; dev leftovers dropped."""
    by_entry = {item["entry"]: item for item in items}
    chosen = {}

    for entry in crafted:
        item = by_entry.get(entry)
        if not item or item["class"] in SKIP_CLASSES or is_dev_item(item):
            continue
        chosen[entry] = item

    for item in items:
        # Include every actual glyph item, even if its creation spell is absent from Spell.dbc.
        # Minor glyphs are valid catalogue stock but can be missed by the crafted-item scan.
        if item["class"] in (TRADE_GOODS, GEMS, RECIPES, GLYPHS) and not is_dev_item(item):
            chosen[item["entry"]] = item

    return sorted(chosen.values(), key=lambda item: item["entry"])


# --- the tree -----------------------------------------------------------------------------------

class Leaf:
    """One vendor list: a menu option pointing at an entry that carries npc_vendor rows."""

    def __init__(self, label, items):
        self.label = label
        self.items = items
        self.holder = None


class Menu:
    def __init__(self, title):
        self.title = title
        self.menu_id = None
        self.text_id = None
        self.options = []          # ("submenu", label, Menu) or ("vendor", label, Leaf)

    def add_menu(self, label, menu):
        self.options.append(("submenu", label, menu))
        return menu

    def add_leaf(self, label, items):
        leaf = Leaf(label, items)
        self.options.append(("vendor", label, leaf))
        return leaf


def bands(items, size=MAX_VENDOR_ITEMS):
    """Split a list into lists of at most `size` items, ordered by level."""
    ordered = sorted(items, key=lambda item: (item["req"], item["ilvl"], item["entry"]))
    for start in range(0, len(ordered), size):
        yield ordered[start:start + size]


# The ranges the deepest category level offers, as asked for: 1-10 through 71-80.
LEVEL_RANGES = [(1, 10), (11, 20), (21, 30), (31, 40), (41, 50), (51, 60), (61, 70), (71, 80)]


def level_band(required_level):
    """The range an item belongs to. None means no level requirement at all."""
    if required_level <= 0:
        return None

    for low, high in LEVEL_RANGES:
        if low <= required_level <= high:
            return (low, high)

    return LEVEL_RANGES[-1]


def add_leaf_chunks(parent, label, items):
    """Add one vendor leaf per 150 items, numbering the parts when a range needs more than one."""
    chunks = list(bands(items))

    for number, chunk in enumerate(chunks, start=1):
        if len(chunks) == 1:
            name = label
        else:
            name = "%s (%d of %d)" % (label, number, len(chunks))

        if len(name) > 60:
            name = name[:57] + "..."

        parent.add_leaf(name, chunk)


def add_range_leaves(menu, items):
    """The deepest level: one option per level range, in order, inside that category's own menu.

    Every range gets its own vendor list, so a category never reaches the 150-item window limit by
    itself. Items with no level requirement get their own "Any level" option.
    """
    groups = OrderedDict()

    for item in items:
        groups.setdefault(level_band(item["req"]), []).append(item)

    ordered = []
    if None in groups:
        ordered.append((None, groups[None]))
    for band in LEVEL_RANGES:
        if band in groups:
            ordered.append((band, groups[band]))

    for band, chunk in ordered:
        band_text = "Any level" if band is None else "Levels %d-%d" % band
        add_leaf_chunks(menu, band_text, chunk)


def build_tree(catalogue):
    root = Menu("Warband Supplier")

    armor = root.add_menu("Armor", Menu("Armor"))
    weapons = root.add_menu("Weapons", Menu("Weapons"))
    containers = root.add_menu("Containers", Menu("Containers"))
    materials = root.add_menu("Materials and reagents", Menu("Materials and reagents"))
    consumables = root.add_menu("Consumables", Menu("Consumables"))
    glyphs = root.add_menu("Glyphs", Menu("Glyphs"))
    gems = root.add_menu("Gems", Menu("Gems"))
    recipes = root.add_menu("Recipes", Menu("Recipes"))
    ammunition = root.add_menu("Ammunition", Menu("Ammunition"))

    groups = {
        "armor": {},
        "weapon": {},
        "containers": {},
        "materials": {},
        "consumables": {},
        "glyphs": {},
        "gems": {},
        "recipes": {},
        "ammo": {},
        "keys": {},
    }

    unrouted = []

    for item in catalogue:
        if item["class"] == ARMOR:
            # Armour subclass 0 is a grab bag: the game files put rings, necks and trinkets there
            # next to engineering goggles and shirts. Jewellery is what a player expects under that
            # name, so only the real trinket slots stay there and everything else gets its own type.
            if item["subclass"] == 0:
                name = "Trinkets and jewellery" if item["slot"] in JEWELLERY_SLOTS else "Other armour"
            else:
                name = ARMOR_SUBCLASSES.get(item["subclass"])

            if not name:
                unrouted.append(item)
                continue
            slot = SLOT_NAMES.get(item["slot"], "Slot %d" % item["slot"])
            groups["armor"].setdefault((name, slot), []).append(item)
        elif item["class"] == WEAPONS:
            family, handed = WEAPON_FAMILIES.get(item["subclass"], ("Other weapons", None))
            if family == "Other weapons":
                unrouted.append(item)
                continue
            groups["weapon"].setdefault((family, handed), []).append(item)
        elif item["class"] == TRADE_GOODS:
            name = TRADE_GOOD_SUBCLASSES.get(item["subclass"], "Other reagents")
            groups["materials"].setdefault((name,), []).append(item)
        elif item["class"] == CONSUMABLES:
            name = CONSUMABLE_SUBCLASSES.get(item["subclass"], "Other consumables")
            groups["consumables"].setdefault((name,), []).append(item)
        elif item["class"] == RECIPES:
            name = RECIPE_SUBCLASSES.get(item["subclass"], "Other recipes")
            groups["recipes"].setdefault((name,), []).append(item)
        elif item["class"] == GEMS:
            name = GEM_SUBCLASSES.get(item["subclass"], "Other gems")
            groups["gems"].setdefault((name,), []).append(item)
        elif item["class"] == CONTAINERS:
            name = CONTAINER_SUBCLASSES.get(item["subclass"], "Other containers")
            groups["containers"].setdefault((name,), []).append(item)
        elif item["class"] == GLYPHS:
            name = GLYPH_CLASSES.get(item["subclass"], "Misc")
            groups["glyphs"].setdefault((name,), []).append(item)
        elif item["class"] == AMMUNITION:
            name = AMMUNITION_SUBCLASSES.get(item["subclass"], "Other ammunition")
            groups["ammo"].setdefault((name,), []).append(item)
        elif item["class"] == KEYS:
            groups["keys"].setdefault(("Keys and tools",), []).append(item)
        else:
            unrouted.append(item)

    # Armor: type, then slot, then the level ranges. When a type only has one slot (Shields), the
    # slot level would just repeat the type name, so the ranges sit directly under the type.
    for type_name in OrderedDict.fromkeys(key[0] for key in groups["armor"]).keys():
        type_menu = armor.add_menu(type_name, Menu(type_name))

        for key in sorted(groups["armor"]):
            if key[0] != type_name:
                continue

            if key[1] == type_name:
                add_range_leaves(type_menu, groups["armor"][key])
                continue

            slot_menu = type_menu.add_menu(key[1], Menu(key[1]))
            add_range_leaves(slot_menu, groups["armor"][key])

    # Weapons: family, one- and two-handed when the family has both, then the level ranges.
    families = OrderedDict()
    for family, handed in sorted(groups["weapon"]):
        families.setdefault(family, []).append(handed)

    for family, handed_variants in families.items():
        family_menu = weapons.add_menu(family, Menu(family))
        variants = [variant for variant in handed_variants if variant]

        if len(handed_variants) > 1 and variants:
            for variant in variants:
                variant_menu = family_menu.add_menu(variant, Menu(variant))
                add_range_leaves(variant_menu, groups["weapon"][(family, variant)])
        else:
            add_range_leaves(family_menu, groups["weapon"][(family, None)])

    # Everything else: one list per kind. Level ranges only make sense for something you wear or
    # swing, so reagents, consumables, recipes, gems, bags and ammunition stay a single list each
    # (split only if a kind holds more than the 150 items a merchant window shows).
    for group_name, menu in (("containers", containers), ("materials", materials),
                             ("consumables", consumables), ("gems", gems),
                             ("recipes", recipes), ("ammo", ammunition)):
        for key in sorted(groups[group_name]):
            add_leaf_chunks(menu, key[0], groups[group_name][key])

    # Preserve the existing direct class categories; unclassified glyphs go under Misc.
    for key in sorted(groups["glyphs"]):
        add_leaf_chunks(glyphs, key[0], groups["glyphs"][key])

    # Keys and tools are one small list, so they hang straight off the root instead of a menu that
    # would hold a single option.
    for key in sorted(groups["keys"]):
        add_leaf_chunks(root, key[0], groups["keys"][key])

    if unrouted:
        by_kind = OrderedDict()
        for item in unrouted:
            by_kind.setdefault((item["class"], item["subclass"]), []).append(item)

        print("  not routed anywhere (%d items):" % len(unrouted))
        for (item_class, subclass), items in by_kind.items():
            samples = ", ".join(item["name"] for item in items[:3])
            print("    class %-2d subclass %-2d %4d items   e.g. %s"
                  % (item_class, subclass, len(items), samples))

    return root


def allocate_ids(root):
    """Number the menus and texts, and give every leaf its holder entry."""
    menus = []
    leaves = []

    def walk(menu):
        menus.append(menu)
        for kind, _label, payload in menu.options:
            if kind == "submenu":
                walk(payload)
            else:
                leaves.append(payload)

    walk(root)

    for index, menu in enumerate(menus):
        menu.menu_id = MENU_BASE + index
        menu.text_id = TEXT_BASE + index

    for index, leaf in enumerate(leaves):
        leaf.holder = HOLDER_BASE + index

    return menus, leaves


# --- SQL ----------------------------------------------------------------------------------------

def creature_template_copy(entry, overrides):
    """INSERT .. SELECT with an explicit column list, so a new template copies a known-good one."""
    columns = [row[0] for row in query(
        "SELECT COLUMN_NAME FROM information_schema.COLUMNS "
        "WHERE TABLE_SCHEMA = '%s' AND TABLE_NAME = 'creature_template' ORDER BY ORDINAL_POSITION"
        % DATABASE)]

    source_values = []
    for column in columns:
        if column in overrides:
            source_values.append(overrides[column])
        elif column.lower() == "entry":
            source_values.append(str(entry))
        else:
            source_values.append("`" + column + "`")

    return "INSERT INTO `creature_template` (%s) SELECT %s FROM `creature_template` WHERE `entry` = %d;" % (
        ", ".join("`" + column + "`" for column in columns),
        ", ".join(source_values),
        SOURCE_TEMPLATE)


def creature_model_copy(entry):
    """The model lives in its own table; without a row here the creature cannot load at all."""
    return (
        "INSERT INTO `creature_template_model` "
        "(`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) "
        "SELECT %d, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild` "
        "FROM `creature_template_model` WHERE `CreatureID` = %d;" % (entry, SOURCE_TEMPLATE))


def price_catalogue(book, catalogue):
    """Per catalogue item: its material cost, the merchant price it pays, and the charge."""
    priced = []

    for item in catalogue:
        entry = item["entry"]
        rarity = rarity_price(item["sell"], item["quality"])
        materials = book.materials(entry)
        priced.append({
            "entry": entry,
            "quality": item["quality"],
            "buy": item["buy"],
            "sell": item["sell"],
            "materials": materials,
            "rarity": rarity,
            "charge": rarity + materials,
        })

    return priced


def price_updates(priced):
    """`item_template` price statements, a few hundred entries per statement."""
    statements = []

    for start in range(0, len(priced), UPDATE_CHUNK):
        chunk = priced[start:start + UPDATE_CHUNK]
        buy_case = "".join(" WHEN %d THEN %d" % (item["entry"], item["charge"]) for item in chunk)
        sell_case = "".join(" WHEN %d THEN %d" % (item["entry"], item["rarity"]) for item in chunk)
        entries = ", ".join(str(item["entry"]) for item in chunk)
        statements.append(
            "UPDATE `item_template` SET "
            "`BuyPrice` = CASE `entry`" + buy_case + " ELSE `BuyPrice` END, "
            "`SellPrice` = CASE `entry`" + sell_case + " ELSE `SellPrice` END "
            "WHERE `entry` IN (" + entries + ");")

    return statements


def material_updates(priced):
    """`warband_supplier_price.material_cost` statements, a few hundred entries per statement."""
    statements = []

    for start in range(0, len(priced), UPDATE_CHUNK):
        chunk = priced[start:start + UPDATE_CHUNK]
        case = "".join(" WHEN %d THEN %d" % (item["entry"], item["materials"]) for item in chunk)
        entries = ", ".join(str(item["entry"]) for item in chunk)
        statements.append(
            "UPDATE `warband_supplier_price` SET `material_cost` = CASE `entry`"
            + case + " ELSE `material_cost` END WHERE `entry` IN (" + entries + ");")

    return statements


def generate(catalogue, root, menus, leaves, templates, spawns, book):
    priced = price_catalogue(book, catalogue)

    apply_lines = ["-- Warband suppliers: merchants, menus and prices. Generated by tools/warband-suppliers.py",
                   "-- Apply on a world with no supplier rows in place; revert.sql is the exact inverse.",
                   "START TRANSACTION;", ""]

    revert_lines = ["-- Warband suppliers: reverses apply.sql completely. Generated, do not edit by hand.",
                    "START TRANSACTION;", ""]

    # 1. The module's own tables, in case the module has never run. The settings table is shared with
    #    every other Warband feature, which is why its keys carry a "supplier." prefix here.
    apply_lines.append("-- module tables")
    apply_lines.append("CREATE TABLE IF NOT EXISTS `warband_setting` (")
    apply_lines.append("  `setting` VARCHAR(48) NOT NULL,")
    apply_lines.append("  `value` DOUBLE NOT NULL DEFAULT 0,")
    apply_lines.append("  PRIMARY KEY (`setting`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;")

    legacy = query("SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = '%s' "
                   "AND TABLE_NAME = 'warband_supplier_setting'" % DATABASE)[0][0]
    if legacy == "1":
        apply_lines.append("-- carry over values saved before the settings table was shared")
        apply_lines.append("INSERT IGNORE INTO `warband_setting` (`setting`, `value`)")
        apply_lines.append("  SELECT CONCAT('supplier.', `setting`), `value` FROM `warband_supplier_setting`;")
        apply_lines.append("DROP TABLE IF EXISTS `warband_supplier_setting`;")

    apply_lines.append("CREATE TABLE IF NOT EXISTS `warband_supplier_price` (")
    apply_lines.append("  `entry` INT UNSIGNED NOT NULL,")
    apply_lines.append("  `quality` TINYINT UNSIGNED NOT NULL DEFAULT 0,")
    apply_lines.append("  `base_buy` INT UNSIGNED NOT NULL DEFAULT 0,")
    apply_lines.append("  `base_sell` INT UNSIGNED NOT NULL DEFAULT 0,")
    apply_lines.append("  `material_cost` INT UNSIGNED NOT NULL DEFAULT 0,")
    apply_lines.append("  PRIMARY KEY (`entry`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;")
    apply_lines.append("")

    # 2. Everything this file owns is removed first, so it can be applied twice without errors. The
    #    DB updater applies a pending file once, but a clone may already have the data from an older
    #    copy, and a re-run has to be harmless.
    apply_lines.append("-- this file owns these rows; clear them so a second application is harmless")
    apply_lines.append("DELETE FROM `gossip_menu_option` WHERE `MenuID` BETWEEN %d AND %d;"
                       % (MENU_BASE, MENU_BASE + len(menus) - 1))
    apply_lines.append("DELETE FROM `gossip_menu` WHERE `MenuID` BETWEEN %d AND %d;"
                       % (MENU_BASE, MENU_BASE + len(menus) - 1))
    apply_lines.append("DELETE FROM `npc_text` WHERE `ID` BETWEEN %d AND %d;"
                       % (TEXT_BASE, TEXT_BASE + len(menus) - 1))
    apply_lines.append("DELETE FROM `npc_vendor` WHERE `entry` BETWEEN %d AND %d;"
                       % (HOLDER_BASE, HOLDER_BASE + len(leaves) - 1))
    apply_lines.append("DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN %d AND %d;"
                       % (HOLDER_BASE, HOLDER_BASE + len(leaves) - 1))
    apply_lines.append("DELETE FROM `creature_template` WHERE `entry` BETWEEN %d AND %d;"
                       % (HOLDER_BASE, HOLDER_BASE + len(leaves) - 1))
    apply_lines.append("")

    # 3. The original price of every catalogue item, so nothing has to be guessed later, and the
    #    material cost that decides what the merchant charges for it.
    apply_lines.append("-- original prices and material costs, kept for the Supplier prices page")
    apply_lines.append("INSERT IGNORE INTO `warband_supplier_price` "
                       "(`entry`, `quality`, `base_buy`, `base_sell`, `material_cost`) VALUES")
    price_rows = ["(%d, %d, %d, %d, %d)" % (item["entry"], item["quality"], item["buy"],
                                            item["sell"], item["materials"]) for item in priced]
    apply_lines.append(",\n".join(price_rows) + ";")
    apply_lines.append("")
    revert_lines.append("-- prices back to how they shipped")
    for item in priced:
        revert_lines.append("UPDATE `item_template` SET `BuyPrice` = %d, `SellPrice` = %d WHERE `entry` = %d;"
                            % (item["buy"], item["sell"], item["entry"]))
    revert_lines.append("DELETE FROM `warband_supplier_price`;")
    revert_lines.append("")

    # 3. The auctioneers themselves become the interface. Same creature, same name, same spot: only
    #    what a click on them does changes - a gossip menu instead of the auction house window.
    apply_lines.append("-- the auctioneers keep their name and their place; what they show changes")
    for entry, npcflag, menu_id in templates:
        apply_lines.append(
            "UPDATE `creature_template` SET `npcflag` = %d, `gossip_menu_id` = %d WHERE `entry` = %s;"
            % (NPCFLAG_GOSSIP | NPCFLAG_VENDOR, root.menu_id, entry))
        revert_lines.append(
            "UPDATE `creature_template` SET `npcflag` = %s, `gossip_menu_id` = %s WHERE `entry` = %s;"
            % (npcflag, menu_id, entry))
    apply_lines.append("")

    for guid, creature_id, npcflag in spawns:
        apply_lines.append(
            "UPDATE `creature` SET `npcflag` = 0 WHERE `guid` = %s AND `id` = %s;" % (guid, creature_id))
        revert_lines.append(
            "UPDATE `creature` SET `npcflag` = %s WHERE `guid` = %s AND `id` = %s;"
            % (npcflag, guid, creature_id))

    # 4. One holder template per leaf: never spawned, it only carries npc_vendor rows. A merchant
    #    window can show 150 items, so every leaf of the tree needs its own list - these rows are
    #    bookkeeping and no player ever sees them.
    apply_lines.append("-- vendor list holders (never spawned, they only carry the lists)")
    for leaf in leaves:
        apply_lines.append(creature_template_copy(leaf.holder, {
            "name": sql_text("Warband Supplier stock"),
            "subname": sql_text(""),
            "npcflag": str(NPCFLAG_VENDOR),
            "gossip_menu_id": "0",
            "IconName": "NULL",
        }))
        apply_lines.append(creature_model_copy(leaf.holder))
    apply_lines.append("")
    if leaves:
        revert_lines.append(
            "DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN %d AND %d;"
            % (HOLDER_BASE, HOLDER_BASE + len(leaves) - 1))
        revert_lines.append(
            "DELETE FROM `creature_template` WHERE `entry` BETWEEN %d AND %d;"
            % (HOLDER_BASE, HOLDER_BASE + len(leaves) - 1))
    revert_lines.append("")

    # 5. The vendor lists.
    apply_lines.append("-- the lists themselves, unlimited stock")
    for leaf in leaves:
        values = []
        for slot, item in enumerate(leaf.items):
            values.append("(%d, %d, %d, 0, 0, 0)" % (leaf.holder, slot, item["entry"]))
            revert_lines.append("DELETE FROM `npc_vendor` WHERE `entry` = %d AND `item` = %d;"
                                % (leaf.holder, item["entry"]))
        apply_lines.append(
            "INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`) VALUES")
        apply_lines.append(",\n".join(values) + ";")
    apply_lines.append("")

    # 6. The menu tree: title text, menu, and the options that link them.
    apply_lines.append("-- menu titles (the client asks for these by id, the server answers from this table)")
    for menu in menus:
        if menu is root:
            greeting = "Everything this Warband can make, in unlimited supply, and a price for " \
                       "anything you bring back. What do you need?"
        else:
            greeting = "%s." % menu.title

        apply_lines.append(
            "INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `Probability0`, `VerifiedBuild`) "
            "VALUES (%d, %s, %s, 1, 1);" % (menu.text_id, sql_text(greeting), sql_text(greeting)))
        revert_lines.append("DELETE FROM `npc_text` WHERE `ID` = %d;" % menu.text_id)
    apply_lines.append("")

    apply_lines.append("-- menus")
    for menu in menus:
        apply_lines.append("INSERT INTO `gossip_menu` (`MenuID`, `TextID`) VALUES (%d, %d);"
                           % (menu.menu_id, menu.text_id))
        revert_lines.append("DELETE FROM `gossip_menu` WHERE `MenuID` = %d;" % menu.menu_id)
    apply_lines.append("")

    apply_lines.append("-- menu options")
    for menu in menus:
        values = []

        for index, (kind, label, payload) in enumerate(menu.options):
            if kind == "submenu":
                option_type = GOSSIP_OPTION_GOSSIP
                npcflag = NPCFLAG_GOSSIP
                icon = 0
                action = payload.menu_id
            else:
                option_type = GOSSIP_OPTION_VENDOR
                npcflag = NPCFLAG_VENDOR
                icon = 1
                action = payload.holder

            values.append("(%d, %d, %d, %s, 0, %d, %d, %d, 0, 0, 0, '', 0, 1)" % (
                menu.menu_id, index, icon, sql_text(label), option_type, npcflag, action))

        if not values:
            continue

        apply_lines.append(
            "INSERT INTO `gossip_menu_option` (`MenuID`, `OptionID`, `OptionIcon`, `OptionText`, "
            "`OptionBroadcastTextID`, `OptionType`, `OptionNpcFlag`, `ActionMenuID`, `ActionPoiID`, "
            "`BoxCoded`, `BoxMoney`, `BoxText`, `BoxBroadcastTextID`, `VerifiedBuild`) VALUES")
        apply_lines.append(",\n".join(values) + ";")
        revert_lines.append("DELETE FROM `gossip_menu_option` WHERE `MenuID` = %d;" % menu.menu_id)
    apply_lines.append("")

    # 7. Prices, and the settings rows the panel reads back. What a supplier pays is the merchant
    #    price; what it charges is that price plus the cost of its materials.
    apply_lines.append("-- prices: what a supplier charges and what it pays")
    apply_lines.extend(price_updates(priced))
    apply_lines.append("")

    apply_lines.append("-- the values the panel shows as applied")

    # The multipliers and the floor belong to whoever tuned them in game, so they are only written
    # when nothing is saved yet. The applied markers describe what this run just did, so they are
    # always written.
    for tier, value in enumerate(MULTIPLIERS):
        apply_lines.append(
            "INSERT IGNORE INTO `warband_setting` (`setting`, `value`) VALUES (%s, %s);"
            % (sql_text("supplier.mult.%d" % tier), value))

    apply_lines.append(
        "INSERT IGNORE INTO `warband_setting` (`setting`, `value`) VALUES (%s, %s);"
        % (sql_text("supplier.floor"), float(FLOOR)))

    applied = [("supplier.applied.mult.%d" % tier, value) for tier, value in enumerate(MULTIPLIERS)]
    applied.append(("supplier.applied.floor", float(FLOOR)))
    applied.append(("supplier.applied.items", float(len(catalogue))))

    for key, value in applied:
        apply_lines.append(
            "INSERT INTO `warband_setting` (`setting`, `value`) VALUES (%s, %s) "
            "ON DUPLICATE KEY UPDATE `value` = %s;" % (sql_text(key), value, value))
    apply_lines.append("")

    apply_lines.append("COMMIT;")
    revert_lines.append("COMMIT;")

    return apply_lines, revert_lines, menus, leaves


def load_shop_originals():
    """The installed catalogue and its shipped prices, read from the world database.

    The shipped sell price comes from `warband_supplier_price.base_sell`, not from `item_template`,
    because that column now carries the supplier price after an apply and pricing from it would
    compound the multiplier on every run.
    """
    items = {}
    for row in query("SELECT entry, quality, SellPrice FROM item_template"):
        items[int(row[0])] = {"quality": int(row[1]), "sell": int(row[2])}

    catalogue = []
    for row in query("SELECT entry, quality, base_buy, base_sell FROM warband_supplier_price"):
        entry = int(row[0])
        quality = int(row[1])
        sell = int(row[3])
        catalogue.append({"entry": entry, "quality": quality, "buy": int(row[2]), "sell": sell})
        items[entry] = {"quality": quality, "sell": sell}

    return items, catalogue


def prices_only(priced):
    """The incremental update: the material_cost column and the charge of every catalogue item."""
    lines = [
        "-- Warband suppliers: what the merchants charge is the merchant price plus the cost of the",
        "-- materials. Generated by tools/warband-suppliers.py --prices-only; applying it twice writes",
        "-- the same values, and the shipped prices in warband_supplier_price are kept.",
        "START TRANSACTION;",
        "",
        "-- the material cost sits beside the shipped price; 0 means the item has no recipe",
        "SET @make_material_cost := IF((SELECT `COLUMN_NAME` FROM `information_schema`.`COLUMNS` "
        "WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'warband_supplier_price' "
        "AND `COLUMN_NAME` = 'material_cost') IS NULL, "
        "'ALTER TABLE `warband_supplier_price` ADD COLUMN `material_cost` INT UNSIGNED NOT NULL DEFAULT 0', "
        "'SELECT 1');",
        "PREPARE add_material_cost FROM @make_material_cost;",
        "EXECUTE add_material_cost;",
        "DEALLOCATE PREPARE add_material_cost;",
        "",
    ]

    lines.append("-- what the materials of each stock item cost")
    lines.extend(material_updates(priced))
    lines.append("")
    lines.append("-- what the merchants charge (merchant price + material cost) and pay (merchant price)")
    lines.extend(price_updates(priced))
    lines.append("")
    lines.append("COMMIT;")

    return lines


def prices_only_revert():
    """Back to one number per item: the shipped buy price, which equals the rarity value."""
    return [
        "-- Warband suppliers: back to a single price per item - BuyPrice = the shipped price, and no",
        "-- material cost is remembered. Generated; safe to apply twice.",
        "START TRANSACTION;",
        "",
        "UPDATE `item_template` AS `i`",
        "  JOIN `warband_supplier_price` AS `p` ON `p`.`entry` = `i`.`entry`",
        "  SET `i`.`BuyPrice` = `p`.`base_buy`;",
        "UPDATE `warband_supplier_price` SET `material_cost` = 0;",
        "",
        "COMMIT;",
    ]


def report(priced):
    """What the dry run says, before anything is written."""
    with_recipe = [item for item in priced if item["materials"]]
    dearer = [item for item in priced if item["charge"] > item["rarity"]]

    print("  %d catalogue items, %d have a recipe and charge their materials on top of the merchant "
          "price, %d charge the merchant price alone" % (len(priced), len(dearer), len(priced) - len(dearer)))

    if dearer:
        ratios = sorted(
            ((float(item["charge"]) / item["rarity"], item["entry"]) for item in dearer),
            reverse=True)
        top = ratios[0]
        print("  largest charge/merchant-price ratio: %.1fx on item %d" % (top[0], top[1]))

    names = {int(row[0]): row[1] for row in query("SELECT entry, name FROM item_template")}
    samples = [2996, 2589, 2592]      # Bolt of Linen Cloth, Linen Cloth, Wool Cloth
    for item in priced:
        if item["entry"] in samples:
            print("  %-24s pays %7d copper, materials %7d, charges %7d"
                  % (names.get(item["entry"], "?"), item["rarity"], item["materials"], item["charge"]))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--allow-existing", action="store_true",
                        help="generate the full update even if the catalogue table already has rows")
    parser.add_argument("--dry-run", action="store_true",
                        help="report what the tree would contain, write nothing")
    parser.add_argument("--prices-only", action="store_true",
                        help="write only the material-cost update and its revert, for an installed catalogue")
    arguments = parser.parse_args()

    print("reading %s ..." % SPELL_DBC)
    crafted, recipes = read_spell_dbc(SPELL_DBC)
    print("  %d items are created by a spell, %d of them have reagents" % (len(crafted), len(recipes)))

    if arguments.prices_only:
        items, catalogue = load_shop_originals()
        if not catalogue:
            raise SystemExit("warband_supplier_price is empty - install the catalogue first")

        priced = price_catalogue(PriceBook(items, recipes), catalogue)
        report(priced)

        if arguments.dry_run:
            print("dry run: nothing written")
            return

        write_lines(os.path.join(OUT, PRICES_APPLY_NAME), prices_only(priced))
        write_lines(os.path.join(REVERT_DIR, PRICES_REVERT_NAME), prices_only_revert())
        print("wrote %s\\%s and %s\\%s" % (OUT, PRICES_APPLY_NAME, REVERT_DIR, PRICES_REVERT_NAME))
        return

    existing = query("SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = '%s' "
                     "AND TABLE_NAME = 'warband_supplier_price'" % DATABASE)[0][0]
    if existing == "1" and not arguments.dry_run:
        rows = query("SELECT COUNT(*) FROM `warband_supplier_price`")[0][0]
        if rows != "0" and not arguments.allow_existing:
            raise SystemExit(
                "warband_supplier_price already holds %s original prices. Run revert.sql first, or pass "
                "--allow-existing if you know the prices in the world are the original ones." % rows)

    items = load_catalogue()
    catalogue = build_catalogue(items, crafted)
    print("  catalogue: %d items" % len(catalogue))

    book = PriceBook({item["entry"]: item for item in items}, recipes)
    priced = price_catalogue(book, catalogue)
    report(priced)

    root = build_tree(catalogue)
    menus, leaves = allocate_ids(root)
    print("  tree: %d menus, %d vendor lists" % (len(menus), len(leaves)))

    # A gossip menu shows at most 32 options; anything beyond that would silently be cut off.
    for menu in menus:
        if len(menu.options) > 32:
            print("  WARNING: menu %r has %d options (32 is the limit)" % (menu.title, len(menu.options)))

    spawns = query(
        "SELECT c.guid, c.id, c.npcflag FROM creature c "
        "JOIN creature_template ct ON ct.entry = c.id "
        "WHERE ct.name LIKE 'Auctioneer%%' ORDER BY c.guid")

    templates = query(
        "SELECT DISTINCT ct.entry, ct.npcflag, ct.gossip_menu_id FROM creature c "
        "JOIN creature_template ct ON ct.entry = c.id "
        "WHERE ct.name LIKE 'Auctioneer%%' ORDER BY ct.entry")

    print("  auctioneers to convert: %d templates, %d spawns" % (len(templates), len(spawns)))

    apply_lines, revert_lines, menus, leaves = generate(
        catalogue, root, menus, leaves, templates, spawns, book)

    total_rows = sum(len(leaf.items) for leaf in leaves)

    if arguments.dry_run:
        print("dry run: %d menus, %d lists, %d stocked items - nothing written"
              % (len(menus), len(leaves), total_rows))
        return

    write_lines(os.path.join(OUT, APPLY_NAME), apply_lines)
    write_lines(os.path.join(REVERT_DIR, REVERT_NAME), revert_lines)

    print("wrote %s\\%s (%d vendor rows) and %s\\%s"
          % (OUT, APPLY_NAME, total_rows, REVERT_DIR, REVERT_NAME))


def write_lines(path, lines):
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)

    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
