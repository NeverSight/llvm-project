X86 KVM hypercall intrinsics
===========================

``llvm.x86.vmcall.kvm`` and ``llvm.x86.vmmcall.kvm`` return ``i64`` and take
five ``i64`` arguments in 64-bit code. Their ``kvm32`` variants return ``i32``
and take five ``i32`` arguments in 32-bit code. A mismatched code mode is an
error. The first argument is the hypercall number in rAX; the remaining
arguments use rBX, rCX, rDX and rSI. The result is the returned rAX.

This interface explicitly binds the `Linux KVM hypercall ABI
<https://docs.kernel.org/virt/kvm/x86/hypercalls.html>`_. The caller supplies a
returning hypervisor environment that preserves the other registers, flags,
extended state and compiler execution environment. Calls whose documented
contract changes additional registers or transfers execution are excluded.
These APIs do not infer a hypervisor or generic machine-state ABI from the
VMCALL/VMMCALL opcode and do not implement the Hyper-V convention.

The intrinsics are convergent and cannot be duplicated. They may read or write
arbitrary guest memory; even an unused result retains the instruction and
memory ordering. Physical-register uses and definitions remain on dedicated
machine pseudos through scheduling and allocation. MC lowering emits exactly
``0F 01 C1`` or ``0F 01 D9``, with no inline assembly or external helper.
Ordinary compiler callee-save rules preserve rBX/rSI as required by the target
ABI. Declaring a native interface does not provide a hypervisor, suppress
architectural faults, or qualify every hypercall service.
