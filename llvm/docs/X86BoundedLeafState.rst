Bounded x86 SGX/SMX completion with explicit flags
================================================

The existing bounded ENCLU and GETSEC interfaces retain their contracts.
Four additional interfaces transport incoming and outgoing arithmetic flags:

* ``llvm.x86.enclu.bounded.state``
* ``llvm.x86.enclu.bounded.state32``
* ``llvm.x86.getsec.bounded.state``
* ``llvm.x86.getsec.bounded.state32``

Each takes ``(word ax, word bx, word cx, word dx, i16 flags)`` and returns
``{word ax, word bx, word cx, word dx, i16 flags}``. ``word`` is i64 in the
unsuffixed interfaces and i32 in the suffixed interfaces; the target code
mode must match. Code16 is rejected. The complete first argument is constant.
Its low EAX selects ENCLU leaves 0, 1, 5..11 or GETSEC leaves 0, 6..8.
Unknown and transferring leaves are rejected.

``X86NativeArithmeticFlags.h`` owns the status representation shared with
explicit REP completion: LAHF's CF/PF/AF/ZF/SF occupy bits 8/10/12/14/15 and
OF occupies bit zero, for a combined mask of 0xd501. Other input bits are
ignored and other result bits are zero. Native flag effects are observed
directly; no leaf-specific arithmetic-flag summary substitutes for execution.
ENCLU requires SGX. Both interfaces require LAHF/SAHF support in long mode;
the 32-bit interfaces do not require that feature bit.

One machine pseudo owns flag restoration, the original instruction and flag
capture. It declares all four full-width register uses/definitions, SI scratch,
DI flag transport, EFLAGS clobber and unknown memory effects. MC emission keeps
the window outside stackmap shadows and automatic assembler padding. No
compiler spill, ordinary operand preload or arithmetic is inserted between
restoring the six flags and issuing the instruction. The native instruction
owns implicit memory, feature/privilege checks, faults and partial effects.
Host arithmetic flags following the C/LLVM call are not an additional result.

These are normal-completion APIs for the issuing processor. They do not
transport a VM exit, AEX, enclave entry/exit/resume, a measured-environment
entry/exit or another processor's continuation. A software lifter must prove
the selected bounded leaf from the incoming control-flow state and retain
leaf-specific register dependencies. A byte pattern preceding the instruction
does not establish that proof.

``CodeGen/X86/bounded-leaf-state.ll`` exercises both modes, all admitted leaves,
upper RAX bits, dead/repeated calls, optimization, object formats, assembly
roundtrips and feature boundaries. Its companion invalid-input test rejects
dynamic selectors and non-returning/unknown leaves. NeverC's
``verify-sgx-supervisor-completion.py --explicit-state`` checks register and
six-flag transport at controlled instruction boundaries; those injections
do not qualify successful SGX/SMX execution. Separate Linux x64 CPL3 checks
compare all four registers and six flags in native fault contexts or normal
query results against independent instruction bytes with POPFQ/PUSHFQ flag
transport. They cover all 64 flag combinations and three full-register input
patterns at O0/O2 through LLVM, NeverC and the NeverC-to-LLVM bridge. A fault
before the original instruction boundary fails the check.

The recorded matrix passes 133,744 encoding/controlled-completion checks for
the full LLVM fork and 66,872 for each of NeverC and its LLVM bridge. Each
route compares 9,984 physical CPL3 boundaries. On the qualification host all
of those observations were faults; no successful enclave or SMX completion
was observed. ``--keep`` retains per-leaf fault/normal-completion counts in
``native-observations.json``. The independently encoded reference rejects a
deliberately corrupted incoming OF bit, so matching faults alone cannot hide
a broken flag-transport sequence.

Architectural references: Intel SDM Volume 3D chapter 41, Volume 2D chapter 7,
and the Intel ISA extensions reference for EREPORT2/EGETKEY256.
