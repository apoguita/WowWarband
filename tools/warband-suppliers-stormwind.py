import os
import subprocess

MYSQL = r"C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe"
INI = r"var\mysql-client.ini"
OUT = r"data\sql\custom\warband-suppliers"

MULT = {0: 2, 1: 3, 2: 4, 3: 5, 4: 6, 5: 7, 6: 8, 7: 9}
FLOOR = 10

# Stormwind's three auctioneers become the first category merchants, in place.
CONVERSIONS = [
    {"entry": 8670, "name": "Warband Supplies - Cloth Shoulders",
     "where": "class = 4 AND subclass = 1 AND InventoryType = 3"},
    {"entry": 8719, "name": "Warband Supplies - Herbs",
     "where": "class = 7 AND subclass = 9"},
    {"entry": 15659, "name": "Warband Supplies - Materials",
     "where": "class = 7 AND subclass NOT IN (9)"},
]


def query(sql):
    out = subprocess.run([MYSQL, "--defaults-file=" + INI, "-N", "-B", "-e", sql, "acore_world"],
                         capture_output=True, text=True)
    if out.returncode != 0:
        raise SystemExit(out.stderr)
    return [line.split("\t") for line in out.stdout.strip().split("\n") if line]


def main():
    os.makedirs(OUT, exist_ok=True)
    apply_sql = ["-- Warband suppliers: Stormwind auctioneers become category merchants", "START TRANSACTION;"]
    revert_sql = ["-- Reverts the Stormwind supplier conversion", "START TRANSACTION;"]

    for conv in CONVERSIONS:
        entry = conv["entry"]
        original = query("SELECT name, npcflag FROM creature_template WHERE entry = %d" % entry)
        if not original:
            raise SystemExit("missing creature_template %d" % entry)
        old_name, old_flag = original[0]

        rows = query(
            "SELECT entry, name, Quality, RequiredLevel, ItemLevel, SellPrice, BuyPrice "
            "FROM item_template WHERE %s AND SellPrice > 0 "
            "ORDER BY RequiredLevel, ItemLevel, entry LIMIT 150" % conv["where"])
        print("%-20s %d items" % (conv["name"], len(rows)))

        apply_sql.append("UPDATE creature_template SET npcflag = 128, name = '%s' WHERE entry = %d;" % (conv["name"], entry))
        revert_sql.append("UPDATE creature_template SET npcflag = %s, name = '%s' WHERE entry = %d;" % (old_flag, old_name, entry))

        for slot, row in enumerate(rows):
            item, name, quality, _req, _ilvl, sell, buy = row
            item, quality = int(item), int(quality)
            base = int(sell) if sell not in ("NULL", "") else 0
            price = max(FLOOR, int(round(base * MULT.get(quality, MULT[1]))))

            apply_sql.append(
                "INSERT INTO npc_vendor (entry, slot, item, maxcount, incrtime, ExtendedCost) VALUES (%d, %d, %d, 0, 0, 0);"
                % (entry, slot, item))
            revert_sql.append("DELETE FROM npc_vendor WHERE entry = %d AND item = %d;" % (entry, item))

            apply_sql.append("UPDATE item_template SET BuyPrice = %d, SellPrice = %d WHERE entry = %d;" % (price, price, item))
            old_buy = int(buy) if buy not in ("NULL", "") else base * 4
            revert_sql.append(
                "UPDATE item_template SET SellPrice = %d, BuyPrice = %d WHERE entry = %d;" % (base, old_buy, item))

    apply_sql.append("COMMIT;")
    revert_sql.append("COMMIT;")
    open(os.path.join(OUT, "apply_stormwind.sql"), "w", encoding="utf-8", newline="\n").write("\n".join(apply_sql) + "\n")
    open(os.path.join(OUT, "revert_stormwind.sql"), "w", encoding="utf-8", newline="\n").write("\n".join(revert_sql) + "\n")
    print("wrote Stormwind SQL")


if __name__ == "__main__":
    main()
