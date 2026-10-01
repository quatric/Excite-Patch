# hook: pfd_sddrv_get_total_sectors, `lwz r5,0xc(r1)`.
# The CSD register was just read into r1+8..r1+0x17 (word 0 first).  For CSD
# v2 (structure bits = 1) the card size is (C_SIZE + 1) * 512 KiB: set r0 to 9
# (the 512-byte read-block-length exponent the v1 code would have derived),
# r6 to the sector count, and rejoin the v1 path just after its own maths.
    lwz     3, 0x14(1)
    rlwinm. 3, 3, 0, 9, 9       # CSD_STRUCTURE == 1 ?
    beq     1f
    li      0, 9
    lwz     3, 0xc(1)
    rlwinm  3, 3, 24, 10, 31    # C_SIZE, 22 bits
    addi    3, 3, 1
    mulli   6, 3, 0x400         # sectors
    lis     3, CSD_TARGET@ha
    addi    3, 3, CSD_TARGET@l
    mtctr   3
    bctr
1:  lwz     5, 0xc(1)           # displaced instruction
