Explicit REP machine state
==========================

The ``llvm.x86.rep.*.state`` intrinsics execute one native string instruction
with explicit direction, address width and source segment. The ``state32``
variants are for 32-bit code; the unsuffixed variants are for 64-bit code,
including the x32 ABI. A code-mode mismatch is rejected. They complement the
older pointer-based ``llvm.x86.movs*``, ``stos*`` and string-port interfaces.

Inputs and results
------------------

``word`` below is i64 in 64-bit code and i32 in 32-bit code. All input registers
and returned registers are full code-mode width, even with an address override.
In order, each intrinsic takes the three initial operands in the table, an i8
direction (zero for forward, nonzero for backward), the incoming i16 flags for
comparisons only, and the constant controls described below.

.. list-table:: Register operands
   :header-rows: 1

   * - Operation
     - First three inputs
     - Aggregate result
   * - movs
     - word SI, word DI, word CX
     - { word SI, word DI, word CX }
   * - stos
     - word DI, word CX, word AX
     - { word DI, word CX }
   * - lods
     - word SI, word CX, word AX
     - { word SI, word CX, word AX }
   * - cmps
     - word SI, word DI, word CX
     - { word SI, word DI, word CX, i16 flags }
   * - scas
     - word DI, word CX, word AX
     - { word DI, word CX, i16 flags }
   * - ins
     - word DI, word CX, i16 port
     - { word DI, word CX }
   * - outs
     - word SI, word CX, i16 port
     - { word SI, word CX }

``SI`` means RSI or ESI, and similarly for DI, CX and AX. Pointers are segment
offsets represented as integers. Results are read from the actual hardware
registers. This matters for zero counts, partial-register LODS updates, and
address overrides; callers must not pre-truncate natural-width inputs.

Flags use the LAHF positions in the high byte (SF, ZF, AF, PF, CF) and OF in
bit zero. Only bits in ``0xd501`` are consumed or returned. Comparisons restore
these six input flags immediately before REP, so zero-count completion and
the architectural restoration of EFLAGS on a CMPS/SCAS fault use that input.
64-bit comparisons require the ``sahf`` target feature. This requirement does
not apply to 32-bit code.

Constant controls
-----------------

All controls are i32 ``immarg`` operands, in this order:

* Element bytes: 1, 2 or 4, also 8 for 64-bit memory operations. INS and OUTS
  have no 8-byte form.
* Address bits: 32 or 64 in 64-bit code, 16 or 32 in 32-bit code.
* Source segment prefix, only for MOVS, LODS, CMPS and OUTS: 0 for default DS,
  or 0x26/0x2e/0x36/0x3e/0x64/0x65 for ES/CS/SS/DS/FS/GS. The destination is
  always the architectural ES destination. Segment bases and access checks
  follow the processor's current mode. A redundant DS prefix may be omitted
  by the assembler; it has the same source-segment semantics as default DS.
* Repeat condition, only for CMPS and SCAS: 0 for REPE, 1 for REPNE. Incoming
  ZF does not suppress the first iteration when the count is nonzero.

For example::

  declare { i64, i64, i64, i16 } @llvm.x86.rep.cmps.state(
    i64, i64, i64, i8, i16, i32 immarg, i32 immarg, i32 immarg, i32 immarg)

  ; Backward REPE CMPSW with 32-bit offsets and a GS source.
  %r = call { i64, i64, i64, i16 } @llvm.x86.rep.cmps.state(
    i64 %rsi, i64 %rdi, i64 %rcx, i8 1, i16 %oldflags,
    i32 2, i32 32, i32 101, i32 0)

Execution boundary
------------------

These operations have unknown memory and processor side effects, even when
their results are unused. Hardware owns element order, overlapping accesses,
count termination, port permission checks and instruction restart. No bulk
memory operation or software loop substitutes for REP. In particular, string
port I/O is not split into separate memory and port accesses.

The backend keeps one pseudo through register allocation and emits direction
setup, the instruction, comparison-flag capture and CLD as one unit. There are
no inserted spills, calls or assembler padding inside this DF window. Normal
completion restores ABI DF=0. The compiler-created direction branch preserves
the MPX bank when the enclosing function uses native MPX state, and starts
after any pending stackmap shadow.

An exception context at the REP instruction contains its current hardware
string registers. Returning from a handler to that instruction resumes the
hardware operation. These intrinsics are not a complete guest-machine
continuation ABI: unrelated registers are compiler allocated, and AX/DX may
be scratch registers for comparison-flag transport. An exception handler that
abandons the operation must also satisfy its destination's DF and calling
convention requirements. Ordinary LLVM code cannot catch a partial completion
as an aggregate result; the aggregate is available only after normal return.
