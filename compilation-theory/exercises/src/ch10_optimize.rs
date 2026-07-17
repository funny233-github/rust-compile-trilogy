// 练习 9：常量折叠
// ============================================================
//
// 遍历三地址码指令，折叠所有常量运算。
//
//   输入:  t0 = 2 + 3
//          t1 = t0 * 4
//   输出:  t0 = 5
//          t1 = t0 * 4  (t0 是变量，不做传播)
//
// ============================================================

use crate::Tac;

pub fn constant_fold(_instrs: &[Tac]) -> Vec<Tac> {
    todo!("实现常量折叠")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::Tac::*;
    use crate::Value::*;

    #[test]
    fn test_fold_add() {
        let input = vec![BinOp { result: "t0".into(), op: crate::BinOp::Add, lhs: Int(2), rhs: Int(3) }];
        assert_eq!(constant_fold(&input), vec![Copy { result: "t0".into(), value: Int(5) }]);
    }

    #[test]
    fn test_fold_mixed() {
        let input = vec![
            BinOp { result: "t0".into(), op: crate::BinOp::Add, lhs: Int(2), rhs: Int(3) },
            BinOp { result: "t1".into(), op: crate::BinOp::Mul, lhs: Var("t0".into()), rhs: Int(4) },
            BinOp { result: "t2".into(), op: crate::BinOp::Sub, lhs: Int(10), rhs: Int(5) },
        ];
        assert_eq!(constant_fold(&input), vec![
            Copy { result: "t0".into(), value: Int(5) },
            BinOp { result: "t1".into(), op: crate::BinOp::Mul, lhs: Var("t0".into()), rhs: Int(4) },
            Copy { result: "t2".into(), value: Int(5) },
        ]);
    }

    #[test]
    fn test_fold_div() {
        let input = vec![BinOp { result: "t0".into(), op: crate::BinOp::Div, lhs: Int(100), rhs: Int(3) }];
        assert_eq!(constant_fold(&input), vec![Copy { result: "t0".into(), value: Int(33) }]);
    }
}
