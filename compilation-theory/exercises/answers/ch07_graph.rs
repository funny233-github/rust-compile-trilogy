// Reference answer: build interference graph
use crate::LiveInterval;
use std::collections::{HashMap, HashSet};

pub type Graph = HashMap<String, HashSet<String>>;

pub fn build_interference_graph(intervals: &[LiveInterval]) -> Graph {
    let mut graph: Graph = HashMap::new();
    for i in intervals {
        graph.entry(i.var.clone()).or_default();
    }
    for i in 0..intervals.len() {
        for j in (i + 1)..intervals.len() {
            let a = &intervals[i];
            let b = &intervals[j];
            if a.end >= b.start && b.end >= a.start {
                graph.get_mut(&a.var).unwrap().insert(b.var.clone());
                graph.get_mut(&b.var).unwrap().insert(a.var.clone());
            }
        }
    }
    graph
}
