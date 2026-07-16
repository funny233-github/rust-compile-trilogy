// 练习 3：if-else → 跳转指令
// ============================================================
//
// 把 if-else 控制流翻译为带标签和条件跳转的三地址码。
//
// 模式：
//   if (cond) { then_body } else { else_body }
//   →  if cond == 0 goto L_else
//      then_body...
//      goto L_end
//   L_else:
//      else_body...
//   L_end:
//
// ============================================================

use crate::Tac;

pub struct IfElse {
    pub cond: String,
    pub then_body: Vec<Tac>,
    pub else_body: Option<Vec<Tac>>,
}

pub fn compile_if_else(_ir: IfElse, _label_base: &str) -> Vec<Tac> {
    todo!("实现 if-else → 跳转指令")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::Tac::*;
    use crate::Value;

    #[test]
    fn test_if_then() {
        let ir = IfElse {
            cond: "x".into(),
            then_body: vec![Copy { result: "y".into(), value: Value::Int(1) }],
            else_body: None,
        };
        let code = compile_if_else(ir, "test");
        assert_eq!(code, vec![
            IfGoto { cond: Value::Var("x".into()), label: "L_test_end".into() },
            Copy { result: "y".into(), value: Value::Int(1) },
            Label("L_test_end".into()),
        ]);
    }

    #[test]
    fn test_if_else() {
        let ir = IfElse {
            cond: "x".into(),
            then_body: vec![Copy { result: "y".into(), value: Value::Int(1) }],
            else_body: Some(vec![Copy { result: "y".into(), value: Value::Int(-1) }]),
        };
        let code = compile_if_else(ir, "test");
        assert_eq!(code, vec![
            IfGoto { cond: Value::Var("x".into()), label: "L_test_else".into() },
            Copy { result: "y".into(), value: Value::Int(1) },
            Jump("L_test_end".into()),
            Label("L_test_else".into()),
            Copy { result: "y".into(), value: Value::Int(-1) },
            Label("L_test_end".into()),
        ]);
    }
}
