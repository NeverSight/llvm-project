==================================
X86 secure-loader launch intrinsic
==================================

The ``llvm.x86.skinit`` intrinsic executes AMD SKINIT with one ``i32`` input
in EAX. The value is the physical address of a Secure Loader Block, not an
LLVM pointer. It is passed unchanged; the processor clears the low 16 bits
as part of the instruction, after its native admission checks.

.. code-block:: llvm

  declare void @llvm.x86.skinit(i32)

  define void @launch(i32 %physical_address) {
    call void @llvm.x86.skinit(i32 %physical_address)
    unreachable
  }

SKINIT reinitializes processor state and jumps to the secure-loader entry
specified by the SLB. The intrinsic has no normal return into the caller's
old ABI context. It is convergent, cannot be duplicated, and retains unknown
memory effects. It receives no ``willreturn``, ``nosync``, ``nofree`` or
``nocallback`` promise. A caller must not model launch as an ordinary void
operation followed by a continuation using its old processor state.

Instruction selection emits the native ``0f 01 de`` instruction with an
implicit EAX input in both 32-bit and 64-bit code. No external runtime call
or inline assembly is introduced. The CPU owns privilege and feature checks,
reset state, SLB accesses, attestation and control transfer; the compiler does
not replace these with software memory reads or synthetic success.

The contract follows `AMD64 APM Volume 3, revision 3.38
<https://docs.amd.com/v/u/en-US/24594_3.38_APM_Vol3_PUB>`_ (July 2026), printed
pages 472--473. Successful launch and processor faults require the appropriate
privileged machine environment; code-generation tests do not execute SKINIT
on the build host.
