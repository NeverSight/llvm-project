Explicit physical AMX controls
==============================

The fork adds thirteen fixed-signature interfaces for the architectural tile
bank. They do not construct ``x86_amx`` SSA values or ask the compiler to load a
configuration, allocate tiles, or save/restore tile contents. Mixing these
interfaces with compiler-managed AMX values in a function is rejected, including
in assertion-disabled builds.

Memory interfaces
-----------------

``llvm.x86.{ldtilecfg,sttilecfg}.address`` take ``(i64 offset, i32 address_bits,
i32 segment_prefix, i32 encoding)`` and return void. The five tile interfaces
``llvm.x86.{tileloadd64,tileloaddt164,tileloaddrs64,tileloaddrst164,tilestored64}.address``
take ``(i8 tile, i64 offset, i64 stride, i32 address_bits, i32 segment_prefix,
i32 encoding)`` and return void. The tile index and the final three controls
must be constants.

* Code mode is x86-64; address width is 32 or 64. Base and stride are truncated
  to that width before the hardware applies segment semantics. Address width
  remains part of the instruction, including native address-size override.
* Segment is zero for the DS default, or one of the actual override bytes
  ``26, 2e, 36, 3e, 64, 65`` (hexadecimal). An integer offset is not a linear
  pointer and the compiler does not synthesize a segment-base read.
* Encoding is zero for VEX or one for EVEX. EVEX requires ``egpr`` even when
  the chosen base and stride use ordinary GPRs. An encoding-preserving pseudo
  survives EVEX compression; MC emits a forced-encoding assembly annotation
  as well as the correct object bytes.
* ``amx-tile`` is required; the two MOVRS loads additionally require
  ``amx-movrs``. Configuration accesses and strided tile transfers own their
  memory, faults, TILECFG/TILEDATA and native restart progress. The compiler
  does not substitute an ordinary load/store or infer a fixed tile footprint.

Register-row interfaces
-----------------------

The six ``llvm.x86.{tcvtrowd2ps,tcvtrowps2bf16h,tcvtrowps2bf16l,tcvtrowps2phh,
tcvtrowps2phl,tilemovrow}.reg`` interfaces take ``(i8 tile, i32 row,
i32 extended)``. Tile and extended are constant; row preserves all 32 bits.
The result types match the existing row intrinsics: ``<16 x float>``,
``<32 x bfloat>``, ``<32 x half>``, or ``<16 x i32>`` as appropriate. Existing
immediate-row intrinsics continue to cover the imm8 encodings.

Extended zero forces a legacy GPR selector; one forces R16D and requires
``egpr``. Both forms require ``amx-avx512`` and ``avx10.2`` with 512-bit vectors.
A real EVEX row instruction produces the complete vector result even when
that result is dead. The physical bank remains ambient state; row extraction
must not turn it into compiler-managed tiles.

Effects and qualification
-------------------------

All thirteen interfaces have conservative unknown memory effects and ordered
native side effects. They cannot be commoned or discarded for unused results.
They neither check CPU/OS availability nor replace an unavailable instruction
with a no-op. Native exceptions remain native exceptions.

``CodeGen/X86/AMX/amx-explicit-controls.ll`` checks lowering and invalid controls,
features and programming-model mixing. NeverC's accompanying
``tests/verify-amx-explicit-controls.py`` independently decodes all physical
tiles, seven segment choices, both widths and both encoding/register classes
at O0/O2 in ELF, COFF and MachO, including ATT/Intel assembly round trips.
Controlled completions exercise 32-bit wrap, full-width strides and row
selectors, unknown-memory ordering, all 512 result bits and Win64 nonvolatile
GPR/XMM preservation under pressure. These checks do not establish physical
AMX arithmetic, exception or restart behavior.
