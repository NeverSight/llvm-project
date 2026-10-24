Native x86 MPX intrinsics
========================

This fork exposes architectural bounds-register operations through LLVM IR.
The bounds bank stays in BND0--BND3. It never becomes a vector SSA value or an
ordinary load/store replacement. The native instruction owns MPX enable checks,
bounds-table translation, exceptions and partial completion. The APIs remain
ordered unknown memory effects, including unused and repeated checks.

All operations return ``void``. ``bank`` and ``source`` are constant ``i32``
indices in [0, 3]. ``bits`` and ``segment`` are constant ``i32`` controls.
``word`` is ``i64`` for the following long-mode APIs:

.. list-table::
   :header-rows: 1

   * - IR name
     - Arguments
     - Native effect
   * - ``llvm.x86.bndmov.reg``
     - ``i32 bank, i32 source``
     - Copy a bounds register; available in both code modes.
   * - ``llvm.x86.bnd{cl,cu,cn}.reg``
     - ``i32 bank, word value``
     - Check a register value against the lower, complemented upper, or raw upper bound.
   * - ``llvm.x86.bndmov.{load,store,store.lock}``
     - ``i32 bank, word offset, i32 bits, i32 segment``
     - Native bounds memory access, including the explicit LOCK store form.
   * - ``llvm.x86.bnd{cl,cu,cn}.address``
     - ``i32 bank, word address, i32 bits, i32 segment``
     - Check the effective address without reading memory.
   * - ``llvm.x86.bndmk``
     - ``i32 bank, word lower, word inclusive_upper, i32 bits, i32 segment``
     - Establish bounds from a base and effective upper address.
   * - ``llvm.x86.bnd{ldx,stx}``
     - ``i32 bank, word translation_base, word pointer_value, i32 bits, i32 segment``
     - Access a bounds table using base+displacement and an unscaled pointer comparison value.

Append ``32`` to each name except ``bndmov.reg`` for i386, replacing ``word``
with ``i32``. The code modes must match the API; code16 is rejected.
The allowed address encodings are 32 or 64 in long mode, and 32 in i386.
Segment controls are 0, 0x26, 0x2e, 0x36, 0x3e, 0x64 or 0x65.
These are prefix bytes, not LLVM address spaces. The base uses BX/EBX/RBX so
the default memory segment is DS. Register-only APIs have no memory controls.

Intel specifies that MPX ignores 67H in long mode. Thus ``bits=32`` retains
the prefix while still consuming the full 64-bit register values. BNDMK and
the effective-address checks ignore segment bases; bounds memory/table accesses
retain native segmentation. BNDLDX/STX use zero for an absent base or index;
the caller supplies zero rather than folding a displacement into an absent base.

Compiler-created near branches, calls and returns in functions with MPX state
receive the BND/F2 prefix, preserving bounds when BNDPRESERVE=0. Callees and
inline assembly still own their architectural side effects. This is an ambient
state interface, not an ABI for passing bounds through arbitrary callees. XRay
sleds are rejected because their runtime byte-patching contract cannot accept
the added prefixes. Software lifting must separately model original branches'
BNDINIT effects; preserving compiler-created branches does not supply that model.

Qualification
-------------

``CodeGen/X86/mpx-state-intrinsics.ll`` checks both modes, ordering, controls,
object formats and the XRay boundary. ``MC/X86/mpx-native-encoding.s`` checks
native bytes and disassembly. NeverC's ``tests/verify-mpx-encoding.py`` adds
independent opcode/prefix checks and controlled GPR/ABI transport, including
high address bits with 67H, over 520 long-mode or 268 i386 combinations at
O0/O2 for ELF, COFF and Mach-O. It does not execute MPX semantics.

NeverC's ``tests/verify-mpx-state.py`` executes an isolated supervisor guest.
It tests enable/disable state, all banks, bounds checks, table hit/miss/fault,
repeated faults and conditional control flow. Its explicit QEMU limitation
option skips 180 of 520 combinations on QEMU 10.2; skipped cases are not passes.
The remaining 340 pass at O0/O2. Tables use a zero directory base, so nonzero
BNDCFG directory-base translation is not qualified. These are processor-model
tests; successful execution on physical MPX hardware remains unqualified.

Architectural reference: `Intel SDM Volume 1, Appendix E
<https://cdrdv2-public.intel.com/671436/253665-sdm-vol-1.pdf>`_.
The instruction definitions were restored from LLVM before
``c2d4fe51bb4f98870a2358a32809f849b0751d7c`` and adapted for architectural state.
