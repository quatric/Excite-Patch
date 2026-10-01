# hook: read_kpad_button, the merge point every extension type reaches --
# `lwz r0,0(r3)` (r3 = the channel's KPAD struct, r7 = the previous buttons).
#
# The SI hardware polls the pads and mirrors the answer into SICnINBUFH
# (0xCD006404 + 12*chan): [31] error, [23] always 1 on a real pad response,
# [29:16] the PAD button word (A 0x100 B 0x200 X 0x400 Y 0x800 Start 0x1000
# L 0x40 R 0x20 Z 0x10 Up 8 Down 4 Right 2 Left 1).  Map that onto the Wii
# Remote bits the game expects with the remote held sideways, exactly as the
# Classic Controller patch does, and OR it in before the edge detection runs.
    lwz     0, 0(3)                     # displaced instruction
    lis     4, KBASE@ha
    addi    4, 4, KBASE@l               # KPAD channel 0 struct
    subf    4, 4, 3
    srwi    5, 4, 10                    # channel = offset / 0x400
    cmplwi  5, 3
    bgt     9f
    mulli   5, 5, 12
    lis     6, 0xCD00
    add     6, 6, 5
    lwz     8, 0x6404(6)                # INBUFH
    cmpwi   8, 0
    blt     9f                          # error / no pad
    andis.  9, 8, 0x0080
    beq     9f                          # not a pad response
    srwi    9, 8, 16                    # PAD buttons
    andi.   10, 9, 0x0300               # A -> 2, B -> 1
    rlwinm  11, 9, 1, 20, 20            # X -> A
    or      10, 10, 11
    rlwinm  11, 9, 31, 21, 21           # Y -> B
    or      10, 10, 11
    rlwinm  11, 9, 24, 27, 27           # Start -> +
    or      10, 10, 11
    rlwinm  11, 9, 29, 28, 28           # L -> left   (turbo)
    or      10, 10, 11
    rlwinm  11, 9, 29, 29, 29           # R -> right  (turbo)
    or      10, 10, 11
    rlwinm  11, 9, 30, 30, 30           # D-Up    -> bit 2 (sideways: up)
    or      10, 10, 11
    rlwinm  11, 9, 30, 31, 31           # D-Down  -> bit 1
    or      10, 10, 11
    rlwinm  11, 9, 3, 28, 28            # D-Left  -> bit 8
    or      10, 10, 11
    rlwinm  11, 9, 1, 29, 29            # D-Right -> bit 4
    or      10, 10, 11
    rlwinm  11, 9, 11, 16, 16           # Z -> HOME
    or      10, 10, 11
    or      0, 0, 10
    stw     0, 0(3)
9:
