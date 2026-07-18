use crate::LiveInterval;
use std::collections::HashMap;

pub fn linear_scan(_intervals: &[LiveInterval], _k: usize) -> HashMap<String, Option<usize>> {
    todo!("implement linear scan register allocation")
}

#[cfg(test)]
mod tests {
    use super::*;

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
        let result = linear_scan(&intervals, 1);
        assert_eq!(result["a"], Some(0));
        assert_eq!(result["b"], Some(0));
    }

    #[test]
    fn test_overlap_2regs() {
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
        let result = linear_scan(&intervals, 2);
        assert_eq!(result["a"], Some(0));
        assert_eq!(result["b"], Some(1));
    }

    #[test]
    fn test_spill_shortest() {
        let intervals = vec![
            LiveInterval {
                var: "a".into(),
                start: 0,
                end: 5,
            },
            LiveInterval {
                var: "b".into(),
                start: 1,
                end: 4,
            },
            LiveInterval {
                var: "c".into(),
                start: 2,
                end: 3,
            },
        ];
        let result = linear_scan(&intervals, 2);
        assert!(result["a"].is_some());
        assert!(result["b"].is_some());
        assert_eq!(result["c"], None);
    }

    #[test]
    fn test_steal_register() {
        // a:[0,5], b:[1,4], c:[2,6] — c(6) lives longer than a(5).
        // c steals a's register. Result: a→None, b→reg1, c→reg0.
        let intervals = vec![
            LiveInterval {
                var: "a".into(),
                start: 0,
                end: 5,
            },
            LiveInterval {
                var: "b".into(),
                start: 1,
                end: 4,
            },
            LiveInterval {
                var: "c".into(),
                start: 2,
                end: 6,
            },
        ];
        let result = linear_scan(&intervals, 2);
        assert_eq!(result["a"], None);
        assert!(result["b"].is_some());
        assert!(result["c"].is_some());
    }
}
