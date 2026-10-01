# hook: pfd_sddrv_physical_read/write, `mullw r25,r5,r6` (sector index * sector size).
# SDHC addresses are block numbers, so keep the sector index.
    lis     12, FLAG@ha
    lwz     12, FLAG@l(12)
    cmpwi   12, 0
    beq     1f
    mr      25, 5
    b       2f
1:  mullw   25, 5, 6                # displaced instruction
2:  rlwinm. 0, 4, 0, 27, 31         # restore CR0 for the caller (clrlwi. r0,r4,0x1b)
