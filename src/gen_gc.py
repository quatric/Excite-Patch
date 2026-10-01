"""Build the GameCube controller feature for one region from src/gc_*.s."""
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'tools'))
import asm
from layout import GC_BASE, GC_END
from ops import Feature, Hook
from sig import find_unique

# USA addresses of the sites (the others are found by signature search)
BUTTONS = (0x80045AF8, 5, 6)                  # read_kpad_button merge point
IR_CALLS = ((0x80047D94, 6, 4), (0x80047E38, 5, 4), (0x80047EE8, 5, 4))   # bl IR routine, one per loop
USA_DOL = None

HBM_FN = 0x800A4294                          # "is the HOME Menu up?" (same function the Classic Controller pointer asks)

DEAD = 10
KMUL = 205

PAD_NOTE = ('GameCube pad: needs the SI hardware to be polling the port (the game does this for '
            'a pad that is plugged in when it boots)')


def _read(name):
    return open(os.path.join(HERE, name)).read()


def _decode_bl(word, at):
    li = word & 0x03FFFFFC
    if li & 0x02000000:
        li -= 0x04000000
    return (at + li) & 0xFFFFFFFF


def build(region, dol):
    usa_dol = USA_DOL if region != 'REXE01' else dol
    btn = find_unique(usa_dol, dol, *BUTTONS) if region != 'REXE01' else BUTTONS[0]
    calls = [find_unique(usa_dol, dol, *c) if region != 'REXE01' else c[0] for c in IR_CALLS]
    words = [struct.unpack('>I', dol.read(a, 4))[0] for a in calls]
    for a, w in zip(calls, words):
        if (w >> 26) != 18 or not w & 1:
            raise SystemExit('%s: 0x%08X is not a bl' % (region, a))
    targets = {_decode_bl(w, a) for a, w in zip(calls, words)}
    if len(targets) != 1:
        raise SystemExit('%s: the three IR calls disagree: %s' % (region, targets))
    ir_func = targets.pop()

    # the channel-0 KPAD struct: `lis r6,hi ... addi r6,r6,lo` at the top of the read routine
    start = ir_func
    scan = min(calls)
    while struct.unpack('>I', dol.read(scan, 4))[0] != 0x9421FFC0:
        scan -= 4
    kbase = None
    for a in range(scan, scan + 0x40, 4):
        w = struct.unpack('>I', dol.read(a, 4))[0]
        if (w >> 16) == 0x3CC0:                       # lis r6,X
            nxt = [struct.unpack('>I', dol.read(a + 4 * k, 4))[0] for k in range(1, 6)]
            for n in nxt:
                if (n >> 16) == 0x38C6:               # addi r6,r6,Y
                    lo = n & 0xFFFF
                    kbase = ((w & 0xFFFF) << 16) + (lo - 0x10000 if lo & 0x8000 else lo)
                    kbase &= 0xFFFFFFFF
                    break
            if kbase:
                break
    if not kbase:
        raise SystemExit('%s: could not find the KPAD struct base' % region)

    hbm_fn = find_unique(usa_dol, dol, HBM_FN, 0, 8) if region != 'REXE01' else HBM_FN
    syms = {'KBASE': kbase, 'IR_FUNC': ir_func, 'HBM_FN': hbm_fn}
    consts = {'DEAD': DEAD, 'KMUL': KMUL}
    ops, cur = [], GC_BASE

    # one self-contained copy of the motion code per call site (position independent)
    motion = asm.words(asm.assemble(_read('gc_motion.s'), cur, syms, consts)) + [0]
    for a, w in zip(calls, words):
        ops.append(Hook(a, w, motion, cur, note='KPAD sample loop: GameCube stick -> accelerometer, pointer'))
        cur += (len(motion) * 4 + 15) & ~15

    body = asm.words(asm.assemble(_read('gc_buttons.s'), cur, syms, consts)) + [0]
    orig = struct.unpack('>I', dol.read(btn, 4))[0]
    if orig != 0x80030000:
        raise SystemExit('%s: button merge point is 0x%08X' % (region, orig))
    ops.append(Hook(btn, orig, body, cur, note='read_kpad_button: GameCube buttons -> Wii Remote bits'))
    cur += (len(body) * 4 + 15) & ~15
    if cur > GC_END:
        raise SystemExit('gc code overflows its window: 0x%X > 0x%X' % (cur, GC_END))
    return Feature('gc', 'GameCube controller', region, ops)
