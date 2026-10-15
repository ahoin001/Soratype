"""Build lexicon.ltlex in the LTLEX1 layout the Swift reader expects."""

import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORD_LIST = ROOT / "App" / "Resources" / "english.txt"
OUTPUT = ROOT / "Extension" / "lexicon.ltlex"
HEADER = 64
NODE = 16
ENDPOINT = 32
MAGIC = b"LTLEX1\0\0"


def words_from(path: Path) -> list[str]:
    found = []
    seen = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        trimmed = line.strip()
        if not trimmed or trimmed.startswith("#"):
            continue
        word = trimmed.split()[0].lower()
        if word in seen:
            continue
        if not all(ch == "'" or "a" <= ch <= "z" for ch in word):
            continue
        seen.add(word)
        found.append(word)
    return found


def compile_words(words: list[str]) -> bytes:
    nodes = [{"char": 0, "rank": 0, "children": {}}]
    written = []
    for offset, word in enumerate(words):
        index = 0
        for char in word.encode("utf-8"):
            child = nodes[index]["children"].get(char)
            if child is None:
                child = len(nodes)
                nodes.append({"char": char, "rank": 0, "children": {}})
                nodes[index]["children"][char] = child
            index = child
        if nodes[index]["rank"] == 0:
            nodes[index]["rank"] = min(offset + 1, 65535)
            written.append(word)

    packed = [{"char": 0, "flags": 0, "rank": 0, "child_start": 0, "child_count": 0} for _ in nodes]
    next_index = 1

    def assign(source: int, index: int) -> None:
        nonlocal next_index
        children = sorted(nodes[source]["children"].items())
        start = next_index
        next_index += len(children)
        for offset, (char, child) in enumerate(children):
            packed[start + offset]["char"] = char
            assign(child, start + offset)
        packed[index]["char"] = 0 if index == 0 else nodes[source]["char"]
        packed[index]["child_start"] = start
        packed[index]["child_count"] = len(children)
        if nodes[source]["rank"] > 0:
            packed[index]["rank"] = nodes[source]["rank"]
            packed[index]["flags"] = 1

    assign(0, 0)

    endpoints = []
    buckets = {}
    for word in written:
        raw = word.encode("utf-8")
        if not raw or len(raw) > 24:
            continue
        key = (raw[0] << 8) | raw[-1]
        count = buckets.get(key, 0)
        if count >= 180:
            continue
        buckets[key] = count + 1
        endpoints.append((raw[0], raw[-1], min(len(endpoints) + 1, 65535), raw))

    nodes_offset = HEADER
    endpoint_offset = nodes_offset + len(packed) * NODE
    blob = bytearray(endpoint_offset + len(endpoints) * ENDPOINT)
    blob[0:8] = MAGIC
    struct.pack_into("<H", blob, 8, 1)
    struct.pack_into("<H", blob, 10, HEADER)
    struct.pack_into("<I", blob, 12, len(written))
    struct.pack_into("<I", blob, 16, len(packed))
    struct.pack_into("<I", blob, 20, nodes_offset)
    struct.pack_into("<I", blob, 24, endpoint_offset)
    struct.pack_into("<I", blob, 28, len(endpoints))
    for index, node in enumerate(packed):
        offset = nodes_offset + index * NODE
        blob[offset] = node["char"]
        blob[offset + 1] = node["flags"]
        struct.pack_into("<H", blob, offset + 2, node["rank"])
        struct.pack_into("<I", blob, offset + 4, node["child_start"])
        struct.pack_into("<H", blob, offset + 8, node["child_count"])
    for index, (first, last, rank, raw) in enumerate(endpoints):
        offset = endpoint_offset + index * ENDPOINT
        blob[offset] = first
        blob[offset + 1] = last
        struct.pack_into("<H", blob, offset + 2, rank)
        blob[offset + 4] = len(raw)
        blob[offset + 8 : offset + 8 + len(raw)] = raw
    return bytes(blob)


def contains(blob: bytes, word: str) -> bool:
    node_count = struct.unpack_from("<I", blob, 16)[0]
    nodes_offset = struct.unpack_from("<I", blob, 20)[0]

    def record(index: int):
        offset = nodes_offset + index * NODE
        char, flags, rank, start, count = struct.unpack_from("<BBH I H", blob, offset)
        return char, flags, rank, start, count

    index = 0
    for char in word.encode("utf-8"):
        _, _, _, start, count = record(index)
        low, high = 0, count
        found = None
        while low < high:
            mid = (low + high) // 2
            child = start + mid
            child_char = record(child)[0]
            if child_char == char:
                found = child
                break
            if child_char < char:
                low = mid + 1
            else:
                high = mid
        if found is None:
            return False
        index = found
    return record(index)[1] & 1 == 1


def main() -> None:
    words = words_from(WORD_LIST)
    blob = compile_words(words)
    OUTPUT.write_bytes(blob)
    for sample in ("the", "hey", "howdy", "don't", "walking", "estranged"):
        if not contains(blob, sample):
            raise SystemExit(f"missing {sample}")
    if contains(blob, "teh") or contains(blob, "dont"):
        raise SystemExit("a misspelling was stored as a word")
    print(f"{len(words)} words, {len(blob)} bytes -> {OUTPUT}")


if __name__ == "__main__":
    main()
