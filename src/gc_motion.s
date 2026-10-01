# hook: the per-sample `bl IR_FUNC` in the KPAD read loop (r3 = the channel's KPAD
# struct, r4/r5 = sample, extension type).  It runs after the accelerometer
# filter for every sample and every extension type.  Runs the original, then
# -- if a GameCube pad answers on this channel -- drives the accelerometer the
# same way the Classic Controller patch does: acc.x <- -stickY, acc.z <- -stickX,
# normalised to [-1, 1] with a dead zone.  A GameCube stick reads 128 +/- ~100.
#
# Self-contained: it carries its own helper routines and calls game code
# through absolute addresses, so it works wherever the code handler (or the
# patcher) puts it.
    stwu    1, -0x40(1)
    stw     3, 0x08(1)
    lis     12, IR_FUNC@ha
    addi    12, 12, IR_FUNC@l
    mtctr   12
    bctrl                               # displaced instruction: bl IR_FUNC
    lwz     3, 0x08(1)
    lis     4, KBASE@ha
    addi    4, 4, KBASE@l
    subf    4, 4, 3
    srwi    5, 4, 10
    cmplwi  5, 3
    bgt     out
    mulli   5, 5, 12
    lis     6, 0xCD00
    add     6, 6, 5
    lwz     8, 0x6404(6)
    cmpwi   8, 0
    blt     out
    andis.  9, 8, 0x0080
    beq     out
    rlwinm  9, 8, 24, 24, 31            # stick X (u8)
    addi    9, 9, -128
    rlwinm  10, 8, 0, 24, 31            # stick Y (u8)
    addi    10, 10, -128
    stw     10, 0x0c(1)

    mr      4, 9
    bl      axis                        # r4 = -(X) in 1/256ths
    bl      tofloat                     # f0
    stfs    0, 0x14(3)                  # acc.z

    lwz     4, 0x0c(1)
    bl      axis
    bl      tofloat
    stfs    0, 0x0c(3)                  # acc.x

    # Pointer for the HOME Menu: with no real IR pointer, steer one with the stick
    # (the Classic Controller patch does the same).  The remote's IR routine just
    # cleared dpd_valid, so this runs fresh every sample.
    lwz     0, 0x84(3)
    cmpwi   0, 0
    bne     out
    lwz     0, 4(3)                     # buttons pressed this sample
    andi.   0, 0, 0x8000                # HOME: recentre the pointer
    beq     1f
    li      0, 0
    stw     0, 0x20(3)
    stw     0, 0x24(3)
1:  li      6, 2
    stb     6, 0x84(3)                  # pointer valid
    lis     12, HBM_FN@ha
    addi    12, 12, HBM_FN@l
    mtctr   12
    bctrl                               # 1 while the HOME Menu is up
    cmpwi   3, 1
    lwz     3, 0x08(1)
    lis     0, 0x3faa
    ori     0, 0, 0xaaab
    stw     0, 0x30(1)
    lfs     2, 0x30(1)                  # 1.3333
    bne     2f
    fmuls   2, 2, 2                     # slower in the menu
2:  lis     0, 0x3c75
    ori     0, 0, 0xc28f
    stw     0, 0x34(1)
    lfs     3, 0x34(1)                  # 0.015 per sample
    lis     0, 0x3f80
    stw     0, 0x38(1)
    lfs     4, 0x38(1)                  # 1.0 (screen edge)
    lfs     0, 0x20(3)
    lfs     1, 0x14(3)
    fdiv    1, 1, 2
    fneg    1, 1
    bl      pstep
    stfs    0, 0x20(3)                  # pos.x
    lfs     0, 0x24(3)
    lfs     1, 0x0c(3)
    bl      pstep
    stfs    0, 0x24(3)                  # pos.y
out:
    addi    1, 1, 0x40
    b       end

# r4 = signed stick offset -> r4 = -(normalised value) * 256, clamped to +/-256.
# Dead zone DEAD, full scale at DEAD + 80 (KMUL = 256 * 64 / 80, rounded up).
axis:
    srawi   11, 4, 31                   # -1 if negative
    xor     12, 4, 11
    subf    12, 11, 12                  # |v|
    cmpwi   12, DEAD
    ble     zero
    addi    12, 12, -DEAD
    mulli   12, 12, KMUL
    srawi   12, 12, 6
    cmpwi   12, 256
    ble     1f
    li      12, 256
1:  xor     12, 12, 11
    subf    12, 11, 12                  # signed again
    neg     4, 12                       # the game wants it inverted
    blr
zero:
    li      4, 0
    blr

# r4 = int in 1/256ths -> f0 = r4 / 256.0 (clobbers r0, f1, f2)
tofloat:
    lis     0, 0x4330
    stw     0, 0x18(1)
    xoris   4, 4, 0x8000
    stw     4, 0x1c(1)
    lfd     0, 0x18(1)
    stw     0, 0x20(1)
    lis     0, 0x8000
    stw     0, 0x24(1)
    lfd     1, 0x20(1)
    fsub    0, 0, 1
    lis     0, 0x3b80
    stw     0, 0x28(1)
    lfs     2, 0x28(1)
    fmul    0, 0, 2
    blr

# f0 = clamp(f0 + f1 * f3, -f4, f4)   (clobbers f4's sign, so negate back)
pstep:
    fmadd   0, 1, 3, 0
    fcmpu   0, 0, 4
    blt     1f
    fmr     0, 4
    blr
1:  fneg    4, 4
    fcmpu   0, 0, 4
    bgt     2f
    fmr     0, 4
2:  fneg    4, 4
    blr

end:
