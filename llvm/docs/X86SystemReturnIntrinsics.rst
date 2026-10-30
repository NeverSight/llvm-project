=====================================
X86 native system-return intrinsics
=====================================

These operations transfer control to a processor-selected user context and
abandon the current compiler frame. They return no value and have no normal
continuation in that frame.

.. code-block:: llvm

  declare void @llvm.x86.sysret32(i32 %pc, i32 %flags, i64 %stack)
  declare void @llvm.x86.sysret64(i64 %pc, i64 %flags, i64 %stack)
  declare void @llvm.x86.sysexit32(i32 %pc, i32 %stack)
  declare void @llvm.x86.sysexit64(i64 %pc, i64 %stack)

SYSRET copies the PC and flags inputs into ECX/R11D or RCX/R11. It installs
the supplied 64-bit stack value in RSP immediately before the native SYSRET
instruction. SYSEXIT copies PC and stack into EDX/ECX or RDX/RCX; the
instruction itself installs the destination stack. The 32-bit interfaces
guarantee the low 32 bits of their named inputs, without a promise about
unused high halves. The suffix denotes the instruction's operand size.
SYSRET and SYSEXIT64 require 64-bit code. SYSEXIT32 also supports protected
32-bit code. Code16 is rejected.

All four declarations are convergent, noduplicate, noreturn and nounwind,
with unknown memory effects. There is no willreturn, nosync, nofree or
nocallback promise. Put ``unreachable`` after the intrinsic call. Native
privilege/feature checks, MSR-derived selectors and segment caches, flag
filtering, CET behavior and processor faults remain instruction-owned.
SYSEXIT retains flags present at its instruction boundary; ordinary compiler
instructions used to evaluate its inputs can change flags before that point.

The APIs guarantee their named inputs. Other GPRs and vector registers remain
compiler-selected, and the old frame is abandoned without an ABI epilogue.
They do not restore an entire saved machine context, reconstruct an original
image continuation, or provide an asynchronous unwind contract for the stack
switch. MSRs, CPL, enabled processor features and CET configuration are ambient
state supplied by the execution environment. A compatibility transition also
leaves legacy GPR high halves architecturally undefined; it does not grant a
preservation or zero-extension guarantee for those outputs.

The SYSRET stack operand stays in a register carrier through allocation and
machine scheduling. Final MC emission expands that single terminal into
``movq carrier, %rsp`` and SYSRET, with padding disabled between them. An
earlier glued CopyToReg design allowed O2 to move the stack assignment ahead
of local frame reads and writes. The fixed/dynamic-frame regression retains
that counterexample. No compiler load, store, spill, reload, or ordinary
return may appear between the stack assignment and transfer.

``CodeGen/X86/system-return-intrinsics.ll`` checks all four operations at O0/O2
for ELF, COFF and Mach-O, protected-mode SYSEXIT32, binary encodings, effect
attributes, exact signatures and mode refusal. The NeverC companion native
fixture independently checks compiler input transport and compares generated
transfers with original instruction bytes on a second KVM vCPU. Native
execution qualification is environment-specific and does not extend to every
CPU model, CET, fault ordering or asynchronous events.

The contract follows `Intel SDM 325462-085US
<https://cdrdv2-public.intel.com/835781/325462-sdm-vol-1-2abcd-3abcd-4.pdf>`_,
Volume 2B SYSRET/SYSEXIT and Volume 1 section 3.4.1.1.
