; RUN: llc -mtriple=thumbv7-apple-macosx -relocation-model=pic < %s | FileCheck %s

; Forge the metadata used by NeverD's authenticated final-image path. Ordinary
; object emission must still retain Darwin's non-lazy pointer ABI; metadata is
; a selector inside binary-rewrite mode, not authority to enter that mode.

@__nd_data_1000 = external dso_local global i8, !neverd.final_image_direct_symbol !0

define i32 @address() {
; CHECK-LABEL: _address:
; CHECK: L___nd_data_1000$non_lazy_ptr
  ret i32 ptrtoint (ptr @__nd_data_1000 to i32)
}

!0 = !{}
