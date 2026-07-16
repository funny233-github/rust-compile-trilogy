// 参考答案：常量折叠
use crate::{BinOp, Tac, Value};

pub fn constant_fold(instrs: &[Tac]) -> Vec<Tac> {
    instrs
        .iter()
        .map(|instr| match instr {
            Tac::BinOp {
                result,
                op,
                lhs: Value::Int(l),
                rhs: Value::Int(r),
            } => {
                let folded = match op {
                    BinOp::Add => l + r,
                    BinOp::Sub => l - r,
                    BinOp::Mul => l * r,
                    BinOp::Div => l / r,
                };
                Tac::Copy {
                    result: result.clone(),
                    value: Value::Int(folded),
                }
            }
            other => other.clone(),
        })
        .collect()
}
