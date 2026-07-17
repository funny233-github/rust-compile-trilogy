// 练习 8：Fat Pointer 与 vtable 分发
// ============================================================
//
// `&dyn Trait` 在内存中是 *胖指针*（fat pointer）：
//   16 字节 = 8 字节数据指针 + 8 字节 vtable 指针
//
// 这和 C++ 的虚函数使用完全相同的机制。
//
// 任务：实现通过 vtable 调用 trait 方法的逻辑——
// 这就是 `shape.draw()` 编译后的底层操作。
//
// 提示：
//   1. fat pointer 的前 8 字节指向实际数据
//   2. 后 8 字节指向 vtable（函数指针表）
//   3. vtable 的第一个槽位是第一个 trait 方法
//   4. 使用 unsafe { ... } 来调用原始函数指针
//
// ============================================================

use std::ffi::c_void;

/// vtable：每个 trait 方法占一个槽位
pub struct VTable {
    /// 第一个 trait 方法：fn draw(data_ptr: *const c_void)
    pub draw: unsafe fn(*const c_void),
}

/// Fat pointer：数据指针 + vtable 指针
pub struct FatPointer {
    pub data: *const c_void,
    pub vtable: *const VTable,
}

/// 通过 vtable 调用 trait 方法
///
/// 等价于 Rust 代码：`shape.draw()`  where shape: &dyn Drawable
///
/// # Safety
/// 调用者保证 data 指针指向有效的实现类型数据
pub unsafe fn call_draw(_fp: &FatPointer) {
    // TODO:
    // 1. 解引用 fp.vtable 获取 vtable
    // 2. 调用 vtable 中的 draw 方法，传入 fp.data
    //
    // unsafe {
    //     let vt = &*fp.vtable;
    //     (vt.draw)(fp.data);
    // }
    todo!("通过 vtable 调用方法")
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;

    #[test]
    fn test_vtable_dispatch() {
        // 创建一个"类型"：一个带 draw 方法的计数器
        static CALL_COUNT: Mutex<u32> = Mutex::new(0);

        struct Counter { count: u32 }
        let mut counter = Counter { count: 0 };

        unsafe fn draw_counter(data: *const c_void) {
            let _counter = &*(data as *const Counter);
            *CALL_COUNT.lock().unwrap() += 1;
        }

        let vtable = VTable { draw: draw_counter };
        let fp = FatPointer {
            data: &mut counter as *mut Counter as *const c_void,
            vtable: &vtable,
        };

        unsafe { call_draw(&fp); }
        unsafe { call_draw(&fp); }

        assert_eq!(*CALL_COUNT.lock().unwrap(), 2);
    }
}
