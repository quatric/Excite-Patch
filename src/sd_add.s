# hook: pfd_sddrv_physical_read/write loop, `add r25,r25,r23` (advance one sector's bytes).
# SDHC: advance one block.
    lis     12, FLAG@ha
    lwz     12, FLAG@l(12)
    cmpwi   12, 0
    beq     1f
    addi    25, 25, 1
    b       2f
1:  add     25, 25, 23              # displaced instruction
2:
