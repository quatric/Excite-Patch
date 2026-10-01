"""Build the SDHC feature for one region from src/sd*.s and a retail DOL."""
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'tools'))
import asm
from layout import SD_BASE, SD_END
from ops import Feature, Hook
from regions import REGIONS

# USA addresses; every region adds REGIONS[id]['sd_delta']
SITES = dict(
    info=0x800BA34C,        # pfd_sddrv_get_disk_info: rlwinm. r0,r3,0,15,15
    status=0x800BAE58,      # ISD_GetDeviceStatus: stw r3,0(r28)
    csd=0x800BA8DC,         # pfd_sddrv_get_total_sectors: lwz r5,0xc(r1)
    read_chk=0x800BB568,    # ISD_ReadMultiBlockAsync: cmplw r4,r0
    write_chk=0x800BB8A4,   # ISD_WriteMultiBlockAsync: cmplw r4,r0
    read_mul=0x800BA504,    # pfd_sddrv_physical_read: mullw r25,r5,r6
    write_mul=0x800BA6F0,   # pfd_sddrv_physical_write: mullw r25,r5,r6
    read_add=0x800BA658,    # physical_read loop: add r25,r25,r23
    write_add=0x800BA844,   # physical_write loop: add r25,r25,r23
)
EXPECT = dict(info=0x546003DF, read_chk=0x7C040040, write_chk=0x7C040040, read_mul=0x7F2531D6, write_mul=0x7F2531D6,
              read_add=0x7F39BA14, write_add=0x7F39BA14, csd=0x80A1000C, status=0x907C0000)


def _read(name):
    return open(os.path.join(HERE, name)).read()


def _flag_address(region, dol, delta):
    """The SD handle struct's last word.  The PFD device struct sits at a fixed
    address (`lis rX,hi ; lwz r0,lo(rX)` at the top of pfd_sddrv_physical_read);
    its handle struct follows at +0x20 and is 0x40 bytes long, with nothing in the
    driver touching +0x28..+0x3f."""
    lis = struct.unpack('>I', dol.read(0x800BA4B0 + delta, 4))[0]
    lwz = struct.unpack('>I', dol.read(0x800BA4B8 + delta, 4))[0]
    if (lis >> 16) != 0x3D00 or (lwz >> 16) != 0x8008:
        raise SystemExit('%s: unexpected device-struct load (%08X, %08X)' % (region, lis, lwz))
    lo = lwz & 0xFFFF
    base = (((lis & 0xFFFF) << 16) + (lo - 0x10000 if lo & 0x8000 else lo)) & 0xFFFFFFFF
    return base + 0x5C


def build(region, dol):
    d = REGIONS[region]['sd_delta']
    site = {k: v + d for k, v in SITES.items()}
    for k, want in EXPECT.items():
        got = struct.unpack('>I', dol.read(site[k], 4))[0]
        if got != want:
            raise SystemExit('%s: %s at 0x%08X is 0x%08X, expected 0x%08X' % (region, k, site[k], got, want))
    flag = _flag_address(region, dol, d)
    ops, cur = [], SD_BASE

    def hook(key, src, note, extra=None):
        nonlocal cur
        syms = {'FLAG': flag}
        syms.update(extra or {})
        body = asm.words(asm.assemble(_read(src), cur, syms)) + [0]
        ops.append(Hook(site[key], EXPECT[key], body, cur, note=note))
        cur += (len(body) * 4 + 15) & ~15

    hook('status', 'sd_status.s', 'ISD_GetDeviceStatus: remember whether the card is SDHC')
    hook('info', 'sd_info.s', 'get_disk_info: accept an SDHC card IOS has not marked initialized')
    hook('csd', 'sd_csd.s', 'get_total_sectors: CSD v2 capacity', {'CSD_TARGET': site['csd'] + 0x40})
    hook('read_chk', 'sd_chk.s', 'ISD_ReadMultiBlockAsync: block offsets are always aligned')
    hook('write_chk', 'sd_chk.s', 'ISD_WriteMultiBlockAsync: block offsets are always aligned')
    hook('read_mul', 'sd_mul.s', 'physical_read: sector -> block address')
    hook('write_mul', 'sd_mul.s', 'physical_write: sector -> block address')
    hook('read_add', 'sd_add.s', 'physical_read: advance one block')
    hook('write_add', 'sd_add.s', 'physical_write: advance one block')
    if cur > SD_END:
        raise SystemExit('sd code overflows its window: 0x%X > 0x%X' % (cur, SD_END))
    return Feature('sd', 'SDHC card support', region, ops)
