# hook: pfd_sddrv_get_disk_info, `rlwinm. r0,r3,0,15,15` -- "card initialized?"
# r3 is the IOS status word.  The card is usable when IOS has finished
# initialising it (bit 16) -- or, for an SDHC card, when IOS flags it SDHC
# (bit 20).  Some IOS builds, and Dolphin, only ever report the latter, and the
# stock check then rejects the card as "not memory".
    rlwinm. 0, 3, 0, 15, 15     # displaced instruction
    bne     1f
    rlwinm. 0, 3, 0, 11, 11     # SDHC flag
1:
