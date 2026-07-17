// 参考答案：TAC → MLOG 文本
use crate::{BinOp, Tac, Value};

pub fn tac_to_mlog(instrs: &[Tac]) -> Vec<String> {
    instrs.iter().map(|instr| match instr {
        Tac::BinOp { result, op, lhs, rhs } => {
            let opcode = match op {
                BinOp::Add => "add",
                BinOp::Sub => "sub",
                BinOp::Mul => "mul",
                BinOp::Div => "div",
            };
            format!("op {} {} {} {}", opcode, result, value_str(lhs), value_str(rhs))
        }
        Tac::Copy { result, value } => {
            format!("set {} {}", result, value_str(value))
        }
        Tac::Label(name) => {
            format!(":{}", name)
        }
        Tac::Jump(label) => {
            format!("jump {} always", label)
        }
        Tac::IfGoto { cond, label } => {
            format!("jump {} equal {} false", label, value_str(cond))
        }
    }).collect()
}

fn value_str(v: &Value) -> String {
    match v {
        Value::Int(n) => n.to_string(),
        Value::Var(s) => s.clone(),
    }
}
