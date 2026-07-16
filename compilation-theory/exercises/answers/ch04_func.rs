// 参考答案：栈帧布局
pub type Local = (String, usize);

pub fn stack_offsets(locals: &[Local]) -> Vec<(String, isize)> {
    let mut offset: isize = 0;
    let mut result = Vec::new();
    for (name, size) in locals {
        offset -= *size as isize;
        result.push((name.clone(), offset));
    }
    result
}
