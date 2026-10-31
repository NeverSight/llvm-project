:orphan:

Explicit AMD VMRUN context
=========================

The NeverSight extension ``llvm.x86.vmrun.context(ptr, i32 immarg)`` executes
one native VMRUN and returns after VMEXIT. It requires 64-bit code; the immediate
selects a 32- or 64-bit VMCB physical address. It is convergent, noduplicate and
has unknown memory effects. Guest code is not a C callee. A successful VMEXIT
does not restore the fourteen software-managed GPRs or the user xstate bank.

The pointer names a writable 144-byte context of eighteen consecutive u64
fields, aligned to eight bytes:

.. list-table:: Context layout
   :header-rows: 1

   * - Offset
     - Contents
   * - 0
     - VMCB physical address (truncated to 32 bits for address width 32)
   * - 8
     - Guest standard XSAVE buffer linear address, input and output
   * - 16
     - Host standard XSAVE scratch buffer linear address
   * - 24
     - XSAVE/XRSTOR mask
   * - 32..143
     - RBX, RCX, RDX, RSI, RDI, RBP, R8, R9, R10, R11, R12, R13, R14, R15

Guest RAX, RSP, RIP, RFLAGS and exit information belong to the VMCB. Invalid
VMCB exits can occur before guest state is installed; callers must interpret
the exit code before treating the save area as an executed guest's result.

The compiler outlines a local helper with an RSP-based frame and a dedicated
spill slot for the context pointer. VMEXIT restores this RSP even if the guest
changed every software-managed GPR, including RBP. The helper saves all guest
GPR outputs before borrowing registers to save guest xstate and restore host
xstate. The ordinary compiler epilogue restores host callee-saved GPRs. The
instruction sequence is emitted by the native X86 backend, without inline
assembly or an unresolved runtime helper. Legacy and new pass-manager codegen
both install the outlining pass. Operand bundles are rejected.

Caller responsibilities
-----------------------

* Supply valid CPL0 SVM setup, EFER.SVME, VM_HSAVE_PA, VMCB/intercepts and GIF
  policy. This intrinsic neither enables SVM nor implements a hypervisor.
* Enable XSAVE and provide two distinct, 64-byte-aligned, CPUID-sized standard
  XSAVE buffers. Initialize reserved header bytes to zero. The mask must cover
  all enabled XCR0 user components, and the guest must leave XCR0 unchanged.
* Keep the context, both buffers and compiler stack mapped and accessible in
  the returning host context, disjoint from guest-writable memory. Loaded
  xstate, including protection state, must permit the helper's memory accesses.
* Own software-managed supervisor state and any required VMLOAD/VMSAVE.
  Changes to FS/GS, MSRs, debug/control registers or supervisor xstate must
  preserve the returning host's software ABI. An arbitrary guest that violates
  this contract cannot be admitted merely because its VMCB is valid.

Processor faults are not caught; earlier save/restore effects can already have
occurred. This interface is not a full-machine emulator, a fault-recovery ABI,
or a certificate for nested SVM, SEV-ES, SMM, CET or arbitrary mode switches.
The ownership distinction follows AMD APM Volume 2, sections 15.5.1 and 15.5.2.

``test/CodeGen/X86/svm-context.ll`` checks native encodings, both codegen pass
managers, object formats, memory ordering and malformed widths/modes. NeverC's
``tests/neverc/X86/verify_vmrun_context.py`` executes the generated code in a
disposable QEMU TCG SVM guest, including invalid VMCBs, x87/XMM/YMM state and
callers with dynamic stacks. This is not physical AMD processor qualification.
