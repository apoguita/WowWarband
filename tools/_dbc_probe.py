"""Scratch probe: friendliness of the factions used by the shaman trainers."""
import struct

DBC = r"var\data\dbc\FactionTemplate.dbc"

WANTED = {35: "Shaman Trainer (generic)", 12: "Stormwind", 1638: "Draenei / Exodar", 1640: "draenei trainer 2",
          29: "Orgrimmar", 104: "Thunder Bluff", 55: "Ironforge"}


def main():
    raw = open(DBC, "rb").read()
    magic, records, fields, record_size, string_size = struct.unpack_from("<4sIIII", raw, 0)
    print("FactionTemplate.dbc records=%d fields=%d" % (records, fields))
    base = 20
    for index in range(records):
        rec = struct.unpack_from("<%dI" % fields, raw, base + index * record_size)
        if rec[0] not in WANTED:
            continue
        # 0 ID, 1 Faction, 2 Flags, 3 FactionGroup, 4 FriendGroup, 5 EnemyGroup, 6-9 Enemy, 10-13 Friend
        print("%-24s id=%-5d faction=%-4d group=%d friendGroup=%d enemyGroup=%d friends=%s enemies=%s" % (
            WANTED[rec[0]], rec[0], rec[1], rec[3], rec[4], rec[5], list(rec[10:14]), list(rec[6:10])))


if __name__ == "__main__":
    main()
