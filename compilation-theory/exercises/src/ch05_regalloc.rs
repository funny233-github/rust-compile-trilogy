// 练习 5：线性扫描寄存器分配
// ============================================================
//
// 用线性扫描算法把无限虚拟寄存器映射到 K 个物理寄存器。
//
// 算法：按 start 排序后逐个处理，维护 active 列表和 free_regs 池。
// 寄存器用完时，溢出 end 较小的那个区间。
//
// ============================================================

use crate::LiveInterval;
use std::collections::HashMap;

pub fn linear_scan(_intervals: &[LiveInterval], _k: usize) -> HashMap<String, Option<usize>> {
    todo!("实现线性扫描寄存器分配")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_no_overlap() {
        let intervals = vec![
            LiveInterval { var: "a".into(), start: 0, end: 1 },
            LiveInterval { var: "b".into(), start: 2, end: 3 },
        ];
        let result = linear_scan(&intervals, 1);
        assert_eq!(result["a"], Some(0));
        assert_eq!(result["b"], Some(0));
    }

    #[test]
    fn test_overlap_2regs() {
        let intervals = vec![
            LiveInterval { var: "a".into(), start: 0, end: 2 },
            LiveInterval { var: "b".into(), start: 1, end: 3 },
        ];
        let result = linear_scan(&intervals, 2);
        assert_eq!(result["a"], Some(0));
        assert_eq!(result["b"], Some(1));
    }

    #[test]
    fn test_spill() {
        let intervals = vec![
            LiveInterval { var: "a".into(), start: 0, end: 5 },
            LiveInterval { var: "b".into(), start: 1, end: 4 },
            LiveInterval { var: "c".into(), start: 2, end: 3 },
        ];
        let result = linear_scan(&intervals, 2);
        assert!(result["a"].is_some());
        assert!(result["b"].is_some());
        assert_eq!(result["c"], None);
    }
}
