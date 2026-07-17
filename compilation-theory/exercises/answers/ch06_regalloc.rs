// Reference answer: linear scan register allocation
use crate::LiveInterval;
use std::collections::HashMap;

pub fn linear_scan(intervals: &[LiveInterval], k: usize) -> HashMap<String, Option<usize>> {
    let mut sorted = intervals.to_vec();
    sorted.sort_by_key(|i| i.start);

    let mut active: Vec<(LiveInterval, usize)> = Vec::new();
    let mut free_regs: Vec<usize> = (0..k).collect();
    let mut result = HashMap::new();

    for i in &sorted {
        // Expire dead intervals
        active.retain(|(a, reg)| {
            if a.end < i.start {
                free_regs.push(*reg);
                false
            } else {
                true
            }
        });

        if let Some(reg) = free_regs.pop() {
            result.insert(i.var.clone(), Some(reg));
            active.push((i.clone(), reg));
        } else {
            // All registers taken — find the furthest-ending active interval
            let furthest_idx = active
                .iter()
                .enumerate()
                .max_by_key(|(_, (a, _))| a.end)
                .map(|(idx, _)| idx)
                .unwrap();

            let (ref furthest_var, furthest_reg) = active[furthest_idx];

            if furthest_var.end > i.end {
                // Steal register from the longer-lived one
                result.insert(furthest_var.var.clone(), None);
                result.insert(i.var.clone(), Some(furthest_reg));
                active[furthest_idx] = (i.clone(), furthest_reg);
            } else {
                // Current interval lives longer → spill it
                result.insert(i.var.clone(), None);
            }
        }
    }

    result
}
