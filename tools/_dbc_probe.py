"""Scratch probe 2: slot alignment, the created-item array, and the spell name field."""
import struct

DBC = r"var\data\dbc\Spell.dbc"


def load(path):
    raw = open(path, "rb").read()
    magic, records, fields, record_size, string_size = struct.unpack_from("<4sIIII", raw, 0)
    base = 20
    strings = base + records * record_size
    return raw, records, fields, record_size, base, strings


def read_string(raw, strings, offset):
    if offset == 0:
        return ""
    end = raw.find(b"\0", strings + offset)
    return raw[strings + offset:end].decode("utf-8", "replace")


def record_at(raw, base, record_size, fields, index):
    return struct.unpack_from("<%dI" % fields, raw, base + index * record_size)


def find(src, spell_id):
    raw, records, fields, record_size, base, strings = src
    low, high = 0, records - 1
    while low <= high:
        mid = (low + high) // 2
        value = struct.unpack_from("<I", raw, base + mid * record_size)[0]
        if value == spell_id:
            return record_at(raw, base, record_size, fields, mid)
        if value < spell_id:
            low = mid + 1
        else:
            high = mid - 1
    return None


def main():
    src = load(DBC)
    raw, records, fields, record_size, base, strings = src

    for spell_id in (2963, 3839):
        rec = find(src, spell_id)
        named = [(i, read_string(raw, strings, v)) for i, v in enumerate(rec)
                 if 0 < v < 200000 and read_string(raw, strings, v).isprintable()
                 and len(read_string(raw, strings, v)) > 4]
        print("spell %d string fields: %s" % (spell_id, named[:6]))
        print("  nonzero 100..115: %s" % [(i, rec[i]) for i in range(100, 116) if rec[i]])

    # Which slots carry the create-item effect, and which field carries its item?
    slot_counts = {71: 0, 72: 0, 73: 0}
    item_field_counts = {}
    multi = 0

    for index in range(records):
        rec = record_at(raw, base, record_size, fields, index)
        slots = [i for i in (71, 72, 73) if rec[i] == 24]
        if not slots:
            continue
        for slot in slots:
            slot_counts[slot] += 1
        hits = [i for i in range(104, 114) if rec[i]]
        for hit in hits:
            item_field_counts[hit] = item_field_counts.get(hit, 0) + 1
        if len(hits) > 1:
            multi += 1

    print("create-item effect by slot:", slot_counts)
    print("fields 104..113 holding a value, by frequency:", sorted(item_field_counts.items()))
    print("spells with more than one such value:", multi)


if __name__ == "__main__":
    main()
