// 参考答案：if-else → 跳转指令
use crate::{Tac, Value};

pub struct IfElse {
    pub cond: String,
    pub then_body: Vec<Tac>,
    pub else_body: Option<Vec<Tac>>,
}

pub fn compile_if_else(ir: IfElse, label_base: &str) -> Vec<Tac> {
    let mut code = Vec::new();
    let label_else = format!("L_{}_else", label_base);
    let label_end = format!("L_{}_end", label_base);

    match ir.else_body {
        None => {
            code.push(Tac::IfGoto {
                cond: Value::Var(ir.cond),
                label: label_end.clone(),
            });
            code.extend(ir.then_body);
            code.push(Tac::Label(label_end));
        }
        Some(else_body) => {
            code.push(Tac::IfGoto {
                cond: Value::Var(ir.cond),
                label: label_else.clone(),
            });
            code.extend(ir.then_body);
            code.push(Tac::Jump(label_end.clone()));
            code.push(Tac::Label(label_else));
            code.extend(else_body);
            code.push(Tac::Label(label_end));
        }
    }

    code
}
