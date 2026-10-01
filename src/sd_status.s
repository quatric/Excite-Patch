# hook: ISD_GetDeviceStatus, `stw r3,0(r28)` -- r3 is the IOS status word.
# Bit 20 (0x00100000) is SDIO_STATUS_CARD_SDHC.  FLAG lives in the last word
# of the SD handle struct, which nothing in the driver touches.
    stw     3, 0(28)            # displaced instruction
    rlwinm  4, 3, 12, 31, 31    # (status >> 20) & 1
    lis     5, FLAG@ha
    stw     4, FLAG@l(5)
