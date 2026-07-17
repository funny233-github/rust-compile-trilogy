// Reference answer: linear scan register allocation
//
// Standard algorithm (Poletto 1999): spill whichever interval
// has the SMALLER end — shorter remaining life = cheaper spill.
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

            let furthest_end = active[furthest_idx].0.end;

            if furthest_end > i.end {
                // Current is shorter-lived → spill current (cheaper)
                result.insert(i.var.clone(), None);
            } else {
                // Current lives longer → steal register from the shorter-lived active
                let (ref stolen_var, stolen_reg) = active[furthest_idx];
                result.insert(stolen_var.var.clone(), None);
                result.insert(i.var.clone(), Some(stolen_reg));
                active[furthest_idx] = (i.clone(), stolen_reg);
            }
        }
    }

    result
}
