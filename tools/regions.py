"""The three retail releases of Excite Truck and where their pieces moved.

All three are disc version 0.  The Nintendo SD driver (PFD) is byte-identical
across them apart from a constant shift, which is what makes one site map cover
all three.
"""
REGIONS = {
    'REXE01': dict(label='Excite Truck (USA)', short='USA', version=0, sd_delta=0x000),
    'REXP01': dict(label='Excite Truck (Europe)', short='Europe', version=0, sd_delta=0x510),
    'REXJ01': dict(label='Excite Truck (Japan)', short='Japan', version=0, sd_delta=0x5BC),
}

# retail DOL sizes, to give a clear error on someone else's modified dump
DOL_SIZES = {'REXE01': 3491936, 'REXJ01': 3647424, 'REXP01': 3596736}
