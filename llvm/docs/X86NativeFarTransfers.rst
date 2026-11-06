Native x86 far CALL and JMP
==========================

These interfaces emit native far-transfer instructions with conservative
memory effects, ``convergent``, ``noduplicate`` and ``nounwind``. They neither
validate descriptors in software nor replace far control flow with near
calls or jumps. Selector, privilege, gate, task, paging and CET behavior at
the instruction remain hardware owned.

Returning far entries
---------------------

* ``i16 llvm.x86.lcall16(ptr target)``
* ``i32 llvm.x86.lcall32(ptr target)``
* ``i64 llvm.x86.lcall64(ptr target)``
* ``i16 llvm.x86.lcall16.imm(i16 offset, i16 selector)``
* ``i32 llvm.x86.lcall32.imm(i32 offset, i16 selector)``

``target`` addresses a packed offset followed immediately by a u16 selector.
The suffix selects the offset/operand width, independently of the current
code mode. Immediate offsets and selectors are ``immarg`` operands; these
forms retain the 9A encoding. Memory forms retain FF /3 and let the CPU read
the complete far pointer as part of that instruction.

The entry receives no C arguments and returns AX, EAX or RAX according to
the suffix. It must preserve the platform C callee-saved register banks,
restore the caller's CS, SS and exact SP with a matching far return, and
restore the ordinary ABI environment, including DF, segment bases and the
floating-point control state. A usual near-returning C function is not a
valid far entry. A call gate must copy zero parameters; its frame width
comes from the gate, so the entry's RETF width can differ from the intrinsic
suffix. No implicit original-image register inputs are promised.

Lowering installs the platform C call-preserved register mask and a real
call sequence. It disables leaf red-zone use and reserves Win64's 32-byte
outgoing home area after the native far return frame. Live integer/vector
values and dynamic compiler frames therefore survive an entry satisfying
that contract. The intrinsic can return normally and is neither ``noreturn``
nor ``willreturn``. It does not establish an asynchronous unwinding ABI.

The caller must place the entire returning continuation in the address range
representable by the actual native return frame, including direct code64
calls with a 16/32-bit operand width. Descriptor/task transitions that cannot
restore the compiler environment do not satisfy this returning interface.

Terminal jumps
--------------

* ``void llvm.x86.ljmp16/32/64(ptr target, ptr stack)``
* ``void llvm.x86.ljmp16.imm(i16 offset, i16 selector, ptr stack)``
* ``void llvm.x86.ljmp32.imm(i32 offset, i16 selector, ptr stack)``

These additionally have ``noreturn``. They abandon the compiler frame and
replace ESP/RSP with ``stack`` immediately before the native EA or FF /5
instruction. One terminal machine pseudo keeps the stack assignment and
jump adjacent through final MC emission. The target address cannot occupy
the stack-pointer register, including when it points into the old compiler
frame. An x32 pointer is zero-extended to the architectural RSP/address.
The CPU, rather than compiler loads, reads the far pointer after the switch.
Other register/flag values are compiler-selected. No ordinary epilogue or
continuation follows the jump, including on a hardware fault path.

Modes and qualification
-----------------------

The full backend supports code16/code32/code64 with its existing 32-bit
compiler stack ABI for code16. The 64-bit operand forms require code64;
immediate forms require code16/code32. Memory operand widths 16/32 also
remain available in code64. The current code mode and destination mode are
separate. NeverC exposes C23 ``__builtin_ia32_`` names with underscores in
place of intrinsic dots. Its embedded backend handles x64; Linux i386 source
uses its checked full-LLVM backend.

``native-far-transfers.ll`` checks O0/O2, ELF/COFF/Mach-O, x32 and code16,
exact native identities, immediate/mode/type rejection, terminal adjacency,
returning control and conservative attributes. NeverC's
``verify_far_transfers.py`` additionally executes direct LLVM, native NeverC
and NeverC IR through full LLVM in isolated KVM guests. Its far-entry code
clobbers caller-saved registers and mutates memory before RETF, checking live
values, returned values, callee-saved registers and exact stack restoration.
Independent native bytes compare GPRs, segment/system state, FPU/XMM state,
event state and RAM at the destination. Stack-local target copies check that
the target address survives the final SP assignment. The code16 and x32
profiles execute through the full LLVM backend.
This fixture does not qualify arbitrary original-image register contexts,
nonzero gate parameters, task switching, CET, fault recovery or asynchronous
unwinding.

The architectural instruction contracts are in the `Intel SDM, CALL and JMP
<https://cdrdv2-public.intel.com/835781/325462-sdm-vol-1-2abcd-3abcd-4.pdf>`_.
