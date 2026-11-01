Native immediate-abort RTM pair
==============================

``llvm.x86.rtm.abort.pair(i32 immarg code) -> i32`` executes one native
XBEGIN immediately followed by XABORT. ``code`` must be in 0..255. The result
is the actual EAX abort status, including aborts that occur before XABORT.
The intrinsic does not synthesize ``(code << 24) | 1``.

Entry requires an RTM-capable processor outside RTM and HLE, in the caller's
nonfaulting, no-debug-trap environment. The API supports 32-bit and 64-bit code
modes. It leaves no active transaction on normal completion. It does not
represent a general transactional body, nesting or an external checkpoint.

One machine pseudo expands to both instructions and their local fallback
label. Register allocation, spills, padding and compiler-generated calls cannot
split the pair. EAX supplies the result; conservative memory effects,
convergence and no-duplication survive IR optimization. There are no willreturn
or nosync promises. The instruction semantics follow Intel SDM Volume 1,
sections 17.2.2 and 17.3.5, and the XBEGIN/XABORT entries in Volume 2.
