# hook: ISD_{Read,Write}MultiBlockAsync, `cmplw r4,r0` (r0 = r4 & ~0x1ff just computed).
# On an SDHC card the "offset" argument is a block number, never byte-aligned,
# so make the alignment check pass.
    lis     12, FLAG@ha
    lwz     12, FLAG@l(12)
    cmpwi   12, 0
    beq     1f
    mr      0, 4
1:  cmplw   4, 0                    # displaced instruction
