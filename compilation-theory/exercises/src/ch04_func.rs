// 练习 4：栈帧布局
// ============================================================
//
// 计算函数局部变量在栈帧中的偏移量。
//
// 栈帧布局（从高地址到低地址）：
//
//   rbp+8:  返回地址
//   rbp+0:  旧 rbp
//   rbp-4:  第一个局部变量 (4 字节)
//   rbp-8:  第二个局部变量 (4 字节)
//   rbp-12: 第三个局部变量 ...
//   ...
//
// 每个局部变量紧挨着放在上一个变量的下方。
//
// 提示：
//   1. 偏移从 0 开始，每放一个变量就减去其大小
//   2. 不要考虑对齐（简化处理）
//
// ============================================================

/// 局部变量：(名称, 字节大小)
pub type Local = (String, usize);

/// 计算每个局部变量的栈偏移（rbp 相对偏移，负值）。
///
/// 返回：每个变量的 (名称, 偏移量)
///
/// 示例：
///   locals = [("a", 4), ("b", 8)]
///   → [("a", -4), ("b", -12)]
pub fn stack_offsets(_locals: &[Local]) -> Vec<(String, isize)> {
    // TODO: 遍历局部变量，逐个计算栈偏移
    //
    // let mut offset: isize = 0;
    // for (name, size) in locals {
    //     offset -= *size as isize;
    //     result.push((name.clone(), offset));
    // }
    todo!("计算栈帧偏移")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_single_var() {
        let locals = vec![("x".into(), 4)];
        let result = stack_offsets(&locals);
        assert_eq!(result, vec![("x".into(), -4)]);
    }

    #[test]
    fn test_two_vars() {
        // a: 4 字节 → rbp-4
        // b: 8 字节 → rbp-12
        let locals = vec![("a".into(), 4), ("b".into(), 8)];
        let result = stack_offsets(&locals);
        assert_eq!(result, vec![
            ("a".into(), -4),
            ("b".into(), -12),
        ]);
    }

    #[test]
    fn test_three_vars() {
        // x: 4 字节 → rbp-4
        // y: 4 字节 → rbp-8
        // z: 1 字节 → rbp-9  (char)
        let locals = vec![("x".into(), 4), ("y".into(), 4), ("z".into(), 1)];
        let result = stack_offsets(&locals);
        assert_eq!(result, vec![
            ("x".into(), -4),
            ("y".into(), -8),
            ("z".into(), -9),
        ]);
    }
}
