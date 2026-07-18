use crate::LiveInterval;
use std::collections::{HashMap, HashSet};

pub type Graph = HashMap<String, HashSet<String>>;

pub fn build_interference_graph(_intervals: &[LiveInterval]) -> Graph {
    todo!("build interference graph from live intervals")
}

#[cfg(test)]
mod tests {
    use super::*;
    fn set(s: &[&str]) -> HashSet<String> {
        s.iter().map(|x| x.to_string()).collect()
    }

    #[test]
    fn test_no_overlap() {
        let intervals = vec![
            LiveInterval {
                var: "a".into(),
                start: 0,
                end: 1,
            },
            LiveInterval {
                var: "b".into(),
                start: 2,
                end: 3,
            },
        ];
        let g = build_interference_graph(&intervals);
        assert_eq!(g["a"], set(&[]));
        assert_eq!(g["b"], set(&[]));
    }
    #[test]
    fn test_overlapping_pair() {
        let intervals = vec![
            LiveInterval {
                var: "a".into(),
                start: 0,
                end: 2,
            },
            LiveInterval {
                var: "b".into(),
                start: 1,
                end: 3,
            },
        ];
        let g = build_interference_graph(&intervals);
        assert_eq!(g["a"], set(&["b"]));
        assert_eq!(g["b"], set(&["a"]));
    }
    #[test]
    fn test_chain() {
        let intervals = vec![
            LiveInterval {
                var: "a".into(),
                start: 0,
                end: 3,
            },
            LiveInterval {
                var: "b".into(),
                start: 2,
                end: 5,
            },
            LiveInterval {
                var: "c".into(),
                start: 4,
                end: 6,
            },
        ];
        let g = build_interference_graph(&intervals);
        assert_eq!(g["a"], set(&["b"]));
        assert_eq!(g["b"], set(&["a", "c"]));
        assert_eq!(g["c"], set(&["b"]));
    }
}
