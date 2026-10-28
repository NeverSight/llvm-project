===============================
X86 native x87 state intrinsics
===============================

These fixed interfaces execute their native instructions in i386 and x86-64
code. The pointer operands use address space zero and need only byte alignment.

.. code-block:: llvm

  declare void @llvm.x86.fnstcw(ptr)
  declare void @llvm.x86.fldcw(ptr)
  declare i16 @llvm.x86.fnstsw()
  declare void @llvm.x86.fnstsw.mem(ptr)
  declare void @llvm.x86.fnclex()
  declare void @llvm.x86.fninit()
  declare void @llvm.x86.fwait()

The two FNSTSW interfaces retain separate encodings: ``DF E0`` returns AX,
whereas ``DD /7`` writes exactly two bytes through the pointer. The latter does
not expand into a register read and a compiler-generated store. FNSTCW and FLDCW
also retain their two-byte memory operands. The DAG marks these accesses
volatile and aligned to one byte.

FNSTCW, FNSTSW, FNCLEX and FNINIT are nonwaiting operations. FLDCW and FWAIT
check pending unmasked exceptions. FNCLEX clears exception state while FNINIT
resets control/status/tags and the instruction/data pointers. FNINIT leaves
physical register payload bits intact. Undefined condition-code results are
not promised to survive. The architectural reference is the `Intel SDM
<https://cdrdv2-public.intel.com/835781/325462-sdm-vol-1-2abcd-3abcd-4.pdf>`_,
Volume 2A entries for FCLEX/FNCLEX, FINIT/FNINIT, FSTCW/FNSTCW and FSTSW/FNSTSW,
and the WAIT/FWAIT entry in Volume 2D.

The IR operations retain conservative memory effects and do not acquire
``willreturn`` or ``speculatable`` promises. Their machine instructions carry
FPCW/FPSW dependencies and side effects; unused reads and repeated waits remain
observable. FNINIT clobbers allocator FP, architectural ST and MMX registers
and is a scheduling boundary, so compiler-owned live values are spilled and
reloaded across the reset. Its payload clobbers describe value availability
for allocation, not architectural erasure of the physical payload bits.

Ordinary unconstrained floating-point IR retains its existing floating-point
environment assumptions. These operations do not supply an opaque complete
machine-state ABI, preserve the status of an unrelated earlier instruction
across compiler-generated FP operations, or make a group of calls atomic.
Code managing an owned x87 context must keep its context switch and operation
inside its existing atomic assembly boundary.

The ``ClangBuiltin`` metadata provides intrinsic-name mappings; this change
alone does not register new builtins in the Clang frontend. NeverC supplies
its own frontend registrations and the same native backend contracts. Tests
cover native encodings, effects, malformed signatures, ordering and live x87/
MMX values. Physical exception qualification is a separate Linux x64 harness
in NeverC and does not establish privileged #NM, alignment-check delivery,
i386 execution or behavior of historical x87 implementations.
