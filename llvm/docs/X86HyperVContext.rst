Explicit x64 Hyper-V page calls
==============================

``llvm.x86.hyperv.call(ptr entry, ptr gprs, ptr xmm, i32 stride)`` is a
returning, convergent, nonduplicable operation with unknown memory effects.
``stride`` must be the constant 16, 32 or 64. Only x64 is supported.

``entry`` is the executable entry of the registered hypercall page. ``gprs``
addresses sixteen u64 cells in x86 encoding order (RAX, RCX, RDX, RBX, RSP,
RBP, RSI, RDI, R8..R15). ``xmm`` addresses six slots separated by ``stride``
bytes. The buffers may be unaligned. Each vector access is exactly 16 bytes.
RCX/RDX/R8 and XMM0..5 are supplied; RAX/RCX/RDX/R8 and XMM0..5 are published
after return. Other bytes remain untouched. The caller owns accessible,
mutually disjoint storage which is also disjoint from service writes.

This operation emits native register moves and a CALL to the page, with a
compiler-owned call frame. It does not relocate the page's instruction or use
inline assembly. The original page owns transparent hypercall restarts.
The service must preserve all other registers and the compiler's execution
environment. Replacing the calling processor's state is outside this API.
Features, privilege, faults and memory mappings belong to the caller.

See Microsoft's `TLFS hypercall interface
<https://learn.microsoft.com/en-us/virtualization/hyper-v-on-windows/tlfs/hypercall-interface>`_.
The tests qualify register transport, not every Hyper-V service.
