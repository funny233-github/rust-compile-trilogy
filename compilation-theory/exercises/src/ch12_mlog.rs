use crate::{Tac, Value};

pub fn tac_to_mlog(instrs: &[Tac]) -> Vec<String> {
    let _ = (instrs, opcode_str, value_str);
    todo!("translate TAC to MLOG text")
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
        let code = vec![BinOp {
            result: "t0".into(),
            op: crate::BinOp::Add,
            lhs: Int(1),
            rhs: Int(2),
        }];
        let mlog = tac_to_mlog(&code);
        assert_eq!(mlog, vec!["op add t0 1 2"]);
    }
    #[test]
    fn test_copy() {
        let code = vec![Copy {
            result: "y".into(),
            value: Int(42),
        }];
        let mlog = tac_to_mlog(&code);
        assert_eq!(mlog, vec!["set y 42"]);
    }
    #[test]
    fn test_if_else_pattern() {
        let code = vec![
            IfGoto {
                cond: Var("x".into()),
                label: "else".into(),
            },
            Copy {
                result: "y".into(),
                value: Int(1),
            },
            Jump("end".into()),
            Label("else".into()),
            Copy {
                result: "y".into(),
                value: Int(-1),
            },
            Label("end".into()),
        ];
        let mlog = tac_to_mlog(&code);
        assert_eq!(
            mlog,
            vec![
                "jump else equal x false",
                "set y 1",
                "jump end always",
                ":else",
                "set y -1",
                ":end",
            ]
        );
    }
}
