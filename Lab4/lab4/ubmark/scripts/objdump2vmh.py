import fileinput
import re


LINE_RE = re.compile(
    r"^\s*(?P<addr>[0-9a-fA-F]+)"
    r"\s*(?P<v0>[0-9a-fA-F]{8})(?=\s)"
    r"\s*(?P<v1>[0-9a-fA-F]{8})?(?=\s)"
    r"\s*(?P<v2>[0-9a-fA-F]{8})?(?=\s)"
    r"\s*(?P<v3>[0-9a-fA-F]{8})?(?=\s)"
)

ENTRY_BYTES = 16

def main():
    """Convert objdump section bytes into a 128-bit little-endian VMH."""

    memory = {}

    for line in fileinput.input():
        match = LINE_RE.match(line.rstrip())
        if not match:
            continue

        line_addr = int(match.group("addr"), 16)
        for word_index, word in enumerate(match.group("v0", "v1", "v2", "v3")):
            if not word:
                continue

            # objdump -s prints bytes in increasing address order inside each
            # eight-digit group. The lowest byte address becomes the VMH LSB.
            for byte_index in range(4):
                address = line_addr + word_index * 4 + byte_index
                memory[address] = int(word[byte_index * 2:byte_index * 2 + 2], 16)

    block_addresses = sorted({address & ~(ENTRY_BYTES - 1) for address in memory})
    previous_block = None

    for block_address in block_addresses:
        if previous_block is None or block_address != previous_block + ENTRY_BYTES:
            if previous_block is not None:
                print("")
            print("@{0:x}".format(block_address // ENTRY_BYTES))

        value = 0
        for byte_index in range(ENTRY_BYTES):
            value |= memory.get(block_address + byte_index, 0) << (byte_index * 8)

        print("{0:032x}".format(value))
        previous_block = block_address

if __name__ == '__main__':
    main()
