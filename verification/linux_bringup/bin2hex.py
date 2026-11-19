import sys
import struct

def bin_to_hex(bin_path, hex_path):
    with open(bin_path, 'rb') as f_in:
        data = f_in.read()

    # Pad with zeros to a multiple of 8 bytes
    if len(data) % 8 != 0:
        data += b'\x00' * (8 - (len(data) % 8))

    with open(hex_path, 'w') as f_out:
        for i in range(0, len(data), 8):
            # Read 8 bytes as a little-endian 64-bit integer
            word = struct.unpack('<Q', data[i:i+8])[0]
            # Write out as 16 hex characters
            f_out.write(f"{word:016x}\n")

if __name__ == '__main__':
    in_bin = sys.argv[1] if len(sys.argv) > 1 else 'titan_x_fw.bin'
    out_hex = sys.argv[2] if len(sys.argv) > 2 else 'firmware.hex'
    bin_to_hex(in_bin, out_hex)
    print(f"Generated {out_hex} from {in_bin}")
