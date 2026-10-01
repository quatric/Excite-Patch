# Sources

The PowerPC routines the patches inject, as `devkitPPC` assembly, and the
generators that place them.

| File | Hook |
| --- | --- |
| `sd_status.s` `sd_info.s` `sd_csd.s` `sd_chk.s` `sd_mul.s` `sd_add.s` | the SDHC hooks (see `gen_sd.py` for the sites) |
| `gc_buttons.s` | GameCube buttons -> Wii Remote bits (`read_kpad_button`) |
| `gc_motion.s` | GameCube stick -> accelerometer + HOME Menu pointer (KPAD sample loop) |
| `cc/<disc id>.txt` | Vague Rant's Classic Controller Gecko codes, as published |
| `gen_sd.py` `gen_gc.py` `gen_cc.py` | build one feature for one release from a retail `main.dol` |

`python3 tools/gen_prebuilt.py` assembles everything and writes
`tools/prebuilt/*.json`, which is what the patcher ships and reads. It needs
devkitPPC and your own `main.dol` dumps (see the top-level README); end users do
neither.

Symbols such as `KBASE`, `IR_FUNC`, `HBM_FN` and `FLAG` are filled in per release at
build time (`asm.py` passes them to the linker), and the generators check the
retail bytes at every site before emitting anything.
