// 练习 10：三地址码 → MLOG 文本
// ============================================================
//
// MLOG 的指令格式天然就是三地址码。
// 这个练习实现代码生成器的核心：把 TAC IR 翻译成 MLOG 文本输出。
//
// 映射规则：
//   Tac::BinOp { result, op, lhs, rhs }
//     → "op <opcode> <result> <lhs> <rhs>"
//
//   Tac::Copy { result, value }
//     → "set <result> <value>"
//
//   Tac::Label(name)
//     → ":<name>"
//
//   Tac::Jump(label)
//     → "jump <label> always"
//
//   Tac::IfGoto { cond, label }
//     → "jump <label> equal <cond> false"
//
// 提示：
//   1. 操作码映射：Add→"add", Sub→"sub", Mul→"mul", Div→"div"
//   2. Value 的显示：Int(n)→n.to_string(), Var(s)→s
//   3. 标签前面加冒号，跳转不带冒号
//
// ============================================================

use crate::{Tac, Value};

/// 将三地址码指令序列翻译为 MLOG 文本行。
pub fn tac_to_mlog(instrs: &[Tac]) -> Vec<String> {
    let _ = (instrs, opcode_str, value_str);
    // TODO: 对每条 TAC 指令生成对应的 MLOG 文本
    //
    // 对每条指令 pattern match：
    //   BinOp → format!("op {} {} {} {}", opcode, result, lhs_str, rhs_str)
    //   Copy  → format!("set {} {}", result, value_str)
    //   Label → format!(":{}", name)
    //   Jump  → format!("jump {} always", label)
    //   IfGoto → format!("jump {} equal {} false", label, cond_str)
    todo!("TAC → MLOG 文本")
}

fn opcode_str(op: crate::BinOp) -> &'static str {
    match op {
        crate::BinOp::Add => "add",
        crate::BinOp::Sub => "sub",
        crate::BinOp::Mul => "mul",
        crate::BinOp::Div => "div",
    }
}

fn value_str(v: &Value) -> String {
    match v {
        Value::Int(n) => n.to_string(),
        Value::Var(s) => s.clone(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::Tac::*;
    use crate::Value::*;

    #[test]
    fn test_binop() {
        let code = vec![
            BinOp { result: "t0".into(), op: crate::BinOp::Add, lhs: Int(1), rhs: Int(2) },
        ];
        let mlog = tac_to_mlog(&code);
        assert_eq!(mlog, vec!["op add t0 1 2"]);
    }

    #[test]
    fn test_copy() {
        let code = vec![
            Copy { result: "y".into(), value: Int(42) },
        ];
        let mlog = tac_to_mlog(&code);
        assert_eq!(mlog, vec!["set y 42"]);
    }

    #[test]
    fn test_if_else_pattern() {
        // if (x) { y = 1 } else { y = -1 } 的完整 TAC
        let code = vec![
            IfGoto { cond: Var("x".into()), label: "else".into() },
            Copy { result: "y".into(), value: Int(1) },
            Jump("end".into()),
            Label("else".into()),
            Copy { result: "y".into(), value: Int(-1) },
            Label("end".into()),
        ];
        let mlog = tac_to_mlog(&code);
        assert_eq!(mlog, vec![
            "jump else equal x false",
            "set y 1",
            "jump end always",
            ":else",
            "set y -1",
            ":end",
        ]);
    }
}
