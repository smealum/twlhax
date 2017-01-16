import sys
import math
import struct

header_fn = sys.argv[1]
exheader_fn = sys.argv[2]
exefs_fn = sys.argv[3]
out_fn = sys.argv[4]

header = bytearray(open(header_fn, "rb").read())
exheader = bytearray(open(exheader_fn, "rb").read())
exefs = bytearray(open(exefs_fn, "rb").read())

exefs_size = int(math.ceil(float(len(exefs))/0x200)) # in media units

exefs += bytearray([0] * (exefs_size*0x200 - len(exefs)))

header[0x1a4:0x1a4+4] = struct.pack("I", exefs_size)

data = header + exheader + exefs

open(out_fn, "wb").write(data)
