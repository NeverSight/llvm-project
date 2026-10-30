Native x86 frame and system transfers
====================================

These intrinsics terminate the current LLVM function. They emit native
instructions without inline assembly or an ABI return epilogue. All have
``convergent``, ``noduplicate``, ``noreturn`` and ``nounwind`` attributes, with
unknown memory effects. They do not restore a complete machine context.

Interfaces
----------

* ``void llvm.x86.iret16/32/64(ptr frame)``
* ``void llvm.x86.retf16/32/64(ptr frame)``
* ``void llvm.x86.retf16/32/64.imm(ptr frame, i16 adjustment)``
* ``void llvm.x86.erets(ptr frame)``
* ``void llvm.x86.eretu(ptr frame)``
* ``void llvm.x86.uiret(ptr frame)``
* ``void llvm.x86.sysenter()``
* ``void llvm.x86.rsm()``

The slash notation denotes separate intrinsic names. The far-return adjustment
is an ``immarg``. The plain form emits CB; the immediate form always emits CA,
including when the adjustment is zero. The suffix selects operand size, not
the destination code segment or privilege level.

For the frame interfaces, ``frame`` replaces RSP in code64 or ESP in code32
immediately before the transfer. An x32 ABI pointer is zero-extended to RSP.
The backend retains the stack change and native operation as one terminal
pseudo until MC emission, after register allocation and machine scheduling.
The compiler does not load, validate, or synthesize fields in the frame. Supply
the exact stack image required by the selected instruction, including the
FRED error-code slot when applicable. ``SYSENTER`` uses the ambient entry MSRs;
``RSM`` uses the hardware SMM save state, without a compiler stack change.

The current compiler frame is abandoned. No compiler-generated code follows
the transfer on a successful path. Other registers and flags not supplied by
the interface are compiler-selected at the instruction boundary; they are not
promised to equal the values at C function entry. There is no asynchronous
unwind or saved-context ABI guarantee. In particular, callers must not use
IRET with a resumable NT/task-return context: an architecture path that later
resumes after this IRET is incompatible with the nonreturning interface.

CPU privilege, descriptor state, segment caches, NMI state, CET, FRED enable
state, user-interrupt state, MSRs, admission checks and faults remain hardware
owned. The pointer argument is not a promise that a return succeeds. A fault
does not become a normal return to the old LLVM continuation.

Code modes
----------

The frame interfaces support code32 and code64, but reject code16. The 64-bit
operand forms, ERETS, ERETU and UIRET require code64. UIRET additionally requires
the ``uintr`` target feature. ERETS and ERETU retain the native assembler's
code64 requirement; enabling FRED is the caller's hardware responsibility.
NeverC's pruned backend targets code64 only, including the narrow operand forms.

The CPU contracts are described by the `Intel SDM
<https://cdrdv2-public.intel.com/835781/325462-sdm-vol-1-2abcd-3abcd-4.pdf>`_
(IRET, RET, RSM, SYSENTER and UIRET) and the `FRED specification
<https://www.intel.com/content/www/us/en/content-details/795004/flexible-return-and-event-delivery-fred-specification.html>`_.

Regression coverage
-------------------

``native-frame-returns.ll`` checks O0/O2 ELF, COFF and Mach-O output, exact
native opcode bytes, immediate zero and 65535, frame-switch adjacency, x32
pointer widening, code32 forms, malformed signatures, dynamic immediates,
feature/mode rejection, attributes and the pre-existing system dispatcher.
These compiler checks alone do not qualify successful native transitions,
faults, asynchronous events or CPU feature implementations.
