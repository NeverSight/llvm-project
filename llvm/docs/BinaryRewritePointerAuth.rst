Authenticated pointers in binary rewriting
=========================================

The NeverSight final-address MC emitter preserves an AArch64 authenticated
pointer's signing recipe in ``RewriteSymbolResolveRequest::PointerAuth`` and
``FixupCtx::PointerAuth``. ``MCPointerAuthInfo`` carries the IA/IB/DA/DB key,
16-bit discriminator and address-diversity flag. The target MC assembly-info
owner reads its private expression; clients do not decode target enum values
or infer a signing recipe from a symbol name.

The symbol resolver returns the unsigned target address. The per-fixup hook
receives the resolved address including its addend, the final storage address
and the complete recipe. A client must install a runtime signing relocation
(for example, a dyld authenticated chain entry) or supply a pointer signed for
that final storage location. Returning an unsigned address does not satisfy
the hook's contract. The emitter rejects authenticated pointer storage without
a hook, an unresolved target, a PC-relative/subtractive expression or a
non-64-bit field. ELF's object-relocation metadata cannot overwrite the hook's
installed word.

``BinaryRewriteRelocationTest`` checks Mach-O and ELF, all four keys, both
address-diversity settings, local and external targets, addends and aliases.
It also checks missing installers, unresolved symbols and incorrect widths.
These tests establish metadata delivery and byte installation. They do not
establish a dyld chain builder, runtime pointer signing, signed stack unwinding
or an executable Apple arm64e image. Clients and LLVM must be rebuilt together
after this public callback-context change.
