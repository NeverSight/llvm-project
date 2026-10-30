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
  OR ``0x100`` with zero or CS/DS/ES/SS to retain an original stack-default
  reference in 64-bit addressing. FS/GS and address32 reject that bit.
* Encoding is zero for VEX or one for EVEX. EVEX requires ``egpr`` even when
  the chosen base and stride use ordinary GPRs. An encoding-preserving pseudo
  survives EVEX compression; MC emits a forced-encoding assembly annotation
  as well as the correct object bytes.
* ``amx-tile`` is required; the two MOVRS loads additionally require
  ``amx-movrs``. Configuration accesses and strided tile transfers own their
  memory, faults, TILECFG/TILEDATA and native restart progress. The compiler
  does not substitute an ordinary load/store or infer a fixed tile footprint.

``LLVM_X86_AMX_STACK_MEMORY == 1`` in ``llvm/IR/X86AMXNative.h`` advertises
stack-default tile transfers. Their index remains the complete stride. The
backend outlines an internal ``preserve_allcc`` leaf, uses BP as its full
address base, and lets normal frame lowering save BP and describe the frame
with RSP-based DWARF/SEH information. The caller may have a dynamically
realigned frame. The leaf's return retains live MPX bounds. Physical/managed
tile mixing remains rejected after outlining. No intrinsic or machine-opcode
identity changes, user inline assembly or external runtime are needed.

This adds a compiler-owned call and its ordinary host stack frame. It does
not probe the tile operand or change hardware partial-progress handling.
The private helper contract rejects a borrowed frame pointer; it is not an
attribute that authorizes arbitrary IR to overwrite BP.

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

The same verifier's ``--stack-memory`` mode covers all five operations, eight
tiles, five stack controls, both encodings, O0/O2 and three object formats.
``tests/verify-amx-stack-unwind.py`` replaces independently decoded AMX slots
with UD2 to exercise real signal delivery, DWARF unwinding and resumption
through dynamic callers. That test qualifies frame transport; it does not
execute AMX or establish physical AMX fault/restart behavior.
