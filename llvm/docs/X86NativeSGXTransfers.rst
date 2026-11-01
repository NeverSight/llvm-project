Native terminal SGX input context
================================

``void llvm.x86.enclu.transfer.context(ptr)`` installs an explicit native input
bank and executes ENCLU with EAX equal to 2 (EENTER), 3 (ERESUME) or 4 (EEXIT).
It is convergent, nonduplicable and noreturn, with memory effects. It requires
SGX and XSAVE target features and code32 or code64. Code16 is rejected.

The context is a read-only array of natural code-mode words. Its GPR order is
AX, CX, DX, BX, SP, BP, SI, DI, followed by R8 through R15 in code64. The next
word holds RFLAGS and the final word holds a linear pointer to a standard
XSAVE image. Thus the structure is 40 bytes in code32 and 144 bytes in
code64, including the x32 ABI. An x32 *function argument pointer* follows the
ordinary ABI rule that bits 63:32 are zero; the explicit GPR bank still
contains complete 64-bit values.

The low EAX leaf is checked before importing xstate or installing the target
stack. Other leaves reach UD2. For admitted leaves the final emitter restores
x87, SSE and AVX with XRSTOR/XRSTOR64 and EDX:EAX=7, imports flags with POPF,
and restores every represented GPR, including the full input RAX. SP and AX
are the last loads, followed immediately by ENCLU and UD2. No compiler frame
access, epilogue or ordinary return can follow installation of the target SP.

Native environment and protocol
-------------------------------

These interfaces require a flat native C address space, live XCR0=7, a valid
64-byte-aligned standard XSAVE image, a context aligned to the code-mode word
size, and accessible, disjoint context, image and compiler stack storage.
They must not be concurrently mutated. The supplied flags must be realizable
by CPL3 POPF: IF and IOPL equal the ambient values, and TF, RF, NT and VM are
clear. CET is disabled. Hardware owns the enclave environment, including
EPC, TCS, SSA, FS/GS caches, debug state and SGX leaf checks.

Transport is not atomic. A fault or asynchronous event during the emitted
sequence observes that native instruction's partially installed state.
This API does not map that event to an original binary PC, roll back the
sequence, emulate an SGX transition, or supply an AEX handler.

EENTER exposes the address following the actual ENCLU instruction in RCX.
That address is deliberately UD2 because the old compiler frame has been
abandoned. The enclave/runtime must use an explicit native continuation and
AEP protocol; returning to that address is an invalid use of this terminal
interface. ERESUME with AEX notification also needs its native protocol.
This is not an ordinary returning enclave-call or Linux vDSO ABI, and it is
not transparent relocation of an original EENTER instruction. SGX hardware
performs ERESUME/SSA restoration and AEX; the compiler does not reproduce it.

Original instruction site
-------------------------

``void llvm.x86.enclu.transfer.at.context(ptr, i64 immarg)`` imports the same
bank, then jumps to the supplied original ENCLU address. The original three
bytes, native continuation code and AEP must retain their immutable executable
mapping. The address must fit in 32 bits in code32. In code64, including x32,
it is a complete 64-bit code address independent of the C pointer size.

The final indirect jump reads a code-local address literal: RIP-relative in
code64, absolute in code32. It consumes no input GPR and leaves flags intact.
The code32 literal-address relocation must be resolved by the final linker or
loader. This interface does not promise relocation-free position-independent
code32 text; the code64 RIP-relative form needs no such address relocation.
The literal is aligned to the code-mode word size, so restoring AC does not
introduce an alignment fault in this jump when CR0.AM is set at CPL3.
SP and AX are the last context loads; the AX load still uses the context
address, never the restored SP. No compiler-stack access or epilogue follows.
Thus the
processor executes the original ENCLU, and EENTER's observable next PC is
the original site plus three. The original native continuation, enclave and
AEP/runtime own subsequent execution, including AEX/ERESUME. This path does
not insert an ENCLU at a different address or synthesize its output RCX.

Input transport retains the non-atomic and native-environment requirements
above. In particular, it does not provide a software EPC/SSA implementation,
translate subsequent continuation code, or recover a fault midway through
the preparatory sequence.

Validation
----------

``native-sgx-transfer-context.ll`` and ``native-sgx-transfer-at-context.ll``
check code32/code64, x32, ELF/COFF/Mach-O,
O0/O2, both code-generation pass managers, feature refusals, and the terminal
instruction sequence, constant original-site width and argument constraints.
The NeverC companion KVM fixture compares every
represented input GPR, flags, x87/SSE/AVX state and unchanged memory at the
instruction boundary immediately before ENCLU, with CR0.AM enabled and both
values of AC. A deliberately omitted XRSTOR and a corrupted original-site
target must fail. It executes zero enclave
instructions and therefore does not qualify successful EENTER, EEXIT,
ERESUME, EPC/SSA processing or AEX. Those need a configured SGX platform and
an explicit enclave/runtime protocol.

The x32 pointer convention follows the `x86 psABI ILP32 supplement
<https://gitlab.com/x86-psABIs/x86-64-ABI/-/blob/d725a37222da8468dd37564f40005138449621d8/x86-64-ABI/x32.tex>`_.
SGX leaf effects follow the `Intel Software Developer's Manual
<https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html>`_,
ENCLU/EENTER/ERESUME/EEXIT and the SGX enclave entry/exit chapters.
