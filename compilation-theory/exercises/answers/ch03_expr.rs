// 参考答案：表达式树 → 三地址码
use crate::{Expr, Tac, Value};

pub fn lower_expr(expr: &Expr) -> (Vec<Tac>, Value) {
    let mut instrs = Vec::new();
    let mut tmp_counter = 0u32;
    let result = lower_expr_impl(expr, &mut instrs, &mut tmp_counter);
    (instrs, result)
}

fn lower_expr_impl(expr: &Expr, instrs: &mut Vec<Tac>, counter: &mut u32) -> Value {
    match expr {
        Expr::Int(n) => Value::Int(*n),
        Expr::Var(name) => Value::Var(name.clone()),
        Expr::BinOp(lhs, op, rhs) => {
            let lhs_val = lower_expr_impl(lhs, instrs, counter);
            let rhs_val = lower_expr_impl(rhs, instrs, counter);
            let tmp = format!("t{}", counter);
            *counter += 1;
            instrs.push(Tac::BinOp {
                result: tmp.clone(),
                op: *op,
                lhs: lhs_val,
                rhs: rhs_val,
            });
            Value::Var(tmp)
        }
    }
}
