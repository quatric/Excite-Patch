"""Where the hook trampolines live in the injected low-memory section.

Every patch is a set of hooks: one instruction in the game is replaced by a
branch to a small self-contained routine that runs the displaced instruction
and branches back.  A Gecko code handler stores those routines itself (C2
codes); the patched DOL and the Riivolution patch need somewhere to put them,
so the patcher adds one text section at CAVE_BASE.

0x80001800-0x80003000 is the Wii's boot-time scratch area, which the game itself
never touches (every access to 0x8000xxxx in the retail DOLs is at 0x80003000 or
above).  The first 0x20 bytes are skipped: the word at 0x80001800 is overwritten
by the OS early on.  Each feature gets a fixed window so the three patches can be
combined freely.  The routines hold no variables of their own.
"""
CAVE_BASE = 0x80001820
CAVE_LIMIT = 0x80003000

SD_BASE = 0x80001820          # SDHC hook trampolines
SD_END = 0x80001A00
GC_BASE = 0x80001A00          # GameCube controller hook trampolines
GC_END = 0x80002500
CC_BASE = 0x80002500          # Classic Controller hook trampolines
CC_END = 0x80002A00

WINDOWS = {'sd': (SD_BASE, SD_END), 'gc': (GC_BASE, GC_END), 'cc': (CC_BASE, CC_END)}
