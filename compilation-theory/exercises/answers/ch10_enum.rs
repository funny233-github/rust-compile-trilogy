// 参考答案：Fat Pointer 与 vtable 分发
use std::ffi::c_void;

pub struct VTable {
    pub draw: unsafe fn(*const c_void),
}

pub struct FatPointer {
    pub data: *const c_void,
    pub vtable: *const VTable,
}

pub unsafe fn call_draw(fp: &FatPointer) {
    let vt = &*fp.vtable;
    (vt.draw)(fp.data);
}
