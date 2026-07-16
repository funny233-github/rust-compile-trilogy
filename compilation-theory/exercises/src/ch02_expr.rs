// 练习 2：表达式树 → 三地址码
// ============================================================
//
// 把嵌套的表达式树拍平为三地址码指令序列。
//
// 示例：
//   Expr:  (1 + 2) * 3
//   树:    BinOp(BinOp(Int(1), Add, Int(2)), Mul, Int(3))
//   输出:
//     tmp0 = 1 + 2
//     tmp1 = tmp0 * 3
//
// 提示：
//   1. 为每个子表达式的结果分配一个唯一的临时变量名（如 "t0", "t1", ...）
//   2. 递归处理：先 lower 左子树，再 lower 右子树，最后 emit 当前运算
//   3. Int(x) 和 Var(name) 不需要生成指令，直接返回对应的 Value
//
// ============================================================

use crate::{Expr, Tac, Value};

/// 把表达式树转换为三地址码序列。
pub fn lower_expr(expr: &Expr) -> (Vec<Tac>, Value) {
    let mut instrs = Vec::new();
    let mut tmp_counter = 0u32;
    let result = lower_expr_impl(expr, &mut instrs, &mut tmp_counter);
    (instrs, result)
}

fn lower_expr_impl(_expr: &Expr, _instrs: &mut Vec<Tac>, _counter: &mut u32) -> Value {
    todo!("实现表达式树 → 三地址码")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::Expr::*;
    use crate::BinOp::*;

    #[test]
    fn test_simple_add() {
        let tree = Expr::BinOp(Box::new(Var("a".into())), Add, Box::new(Var("b".into())));
        let (code, result) = lower_expr(&tree);
        assert_eq!(code, vec![
            Tac::BinOp { result: "t0".into(), op: Add, lhs: Value::Var("a".into()), rhs: Value::Var("b".into()) }
        ]);
        assert_eq!(result, Value::Var("t0".into()));
    }

    #[test]
    fn test_nested_expr() {
        let tree = Expr::BinOp(
            Box::new(Expr::BinOp(Box::new(Int(1)), Add, Box::new(Int(2)))),
            Mul, Box::new(Int(3)),
        );
        let (code, result) = lower_expr(&tree);
        assert_eq!(code, vec![
            Tac::BinOp { result: "t0".into(), op: Add, lhs: Value::Int(1), rhs: Value::Int(2) },
            Tac::BinOp { result: "t1".into(), op: Mul, lhs: Value::Var("t0".into()), rhs: Value::Int(3) },
        ]);
        assert_eq!(result, Value::Var("t1".into()));
    }

    #[test]
    fn test_literal_only() {
        let tree = Int(42);
        let (code, result) = lower_expr(&tree);
        assert!(code.is_empty());
        assert_eq!(result, Value::Int(42));
    }
}
