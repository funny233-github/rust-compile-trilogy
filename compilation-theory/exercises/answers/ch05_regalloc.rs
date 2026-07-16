// 参考答案：线性扫描寄存器分配
use crate::LiveInterval;
use std::collections::HashMap;

pub fn linear_scan(intervals: &[LiveInterval], k: usize) -> HashMap<String, Option<usize>> {
    let mut sorted = intervals.to_vec();
    sorted.sort_by_key(|i| i.start);

    let mut active: Vec<(LiveInterval, usize)> = Vec::new(); // (区间, 分配的寄存器)
    let mut free_regs: Vec<usize> = (0..k).collect();
    let mut result = HashMap::new();

    for i in &sorted {
        // 释放已结束的区间
        active.retain(|(a, reg)| {
            if a.end < i.start {
                free_regs.push(*reg);
                false
            } else {
                true
            }
        });

        if let Some(reg) = free_regs.pop() {
            // 有空闲寄存器 → 直接分配
            result.insert(i.var.clone(), Some(reg));
            active.push((i.clone(), reg));
        } else {
            // 全部占用 → 找最晚结束者
            let (idx, &(ref furthest, _)) = active
                .iter()
                .enumerate()
                .max_by_key(|(_, (a, _))| a.end)
                .unwrap();

            if furthest.end > i.end {
                // 溢出最晚结束者，把它的寄存器给 i
                let stolen_reg = active[idx].1;
                result.insert(furthest.var.clone(), None);
                result.insert(i.var.clone(), Some(stolen_reg));
                active[idx] = (i.clone(), stolen_reg);
            } else {
                // 溢出当前区间
                result.insert(i.var.clone(), None);
            }
        }
    }

    result
}
