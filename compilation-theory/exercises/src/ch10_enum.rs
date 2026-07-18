use std::ffi::c_void;

pub struct VTable {
    pub draw: unsafe fn(*const c_void),
}
pub struct FatPointer {
    pub data: *const c_void,
    pub vtable: *const VTable,
}

pub unsafe fn call_draw(_fp: &FatPointer) {
    todo!("call draw through vtable")
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;
    #[test]
    fn test_vtable_dispatch() {
        static CALL_COUNT: Mutex<u32> = Mutex::new(0);
        struct Counter {
            count: u32,
        }
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
        unsafe {
            call_draw(&fp);
        }
        unsafe {
            call_draw(&fp);
        }
        assert_eq!(*CALL_COUNT.lock().unwrap(), 2);
    }
}
