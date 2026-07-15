#import "../lib.typ": *
= 中间表示 — 三地址码
#labnote[ 第五站：从 AST 到三地址码 ]

AST 中的表达式可以是任意深度的树——`a + b * (c - d)` 在 AST 中是一个嵌套的 `BinaryOp` 结构。但 MLOG 的 `op` 指令一次只能做一次运算。

中间表示（IR）的作用就是把 AST 树拍平成 MLOG 能消费的三地址码序列。

== 什么是三地址码

#definition[
  *三地址码*（Three-Address Code, TAC）是一种中间表示，每条指令最多有三个操作数：

  ```
  result = operand1 操作符 operand2
  ```

  这恰好对应 MLOG 的 `op` 指令格式。

  复杂表达式 `a + b * c` 分解为：
  ```
  t0 = b * c
  t1 = a + t0
  ```
]

== IR 指令定义

```rust
// ir.rs
pub enum IrInstr {
    // set result value
    Set {
        result: String,
        value: IrValue,
    },

    // op <opcode> result lhs rhs
    Op {
        opcode: String,
        result: String,
        lhs: IrValue,
        rhs: IrValue,
    },

    // jump label (always)
    Jump {
        label: String,
    },

    // jump label condition lhs rhs
    JumpIf {
        label: String,
        condition: String,  // "eq", "lt", "gt", "not", ...
        lhs: IrValue,
        rhs: IrValue,
    },

    // :label
    Label(String),

    // 特殊指令
    Print(IrValue),
    PrintFlush(String),
    Sensor {
        result: String,
        object: String,
        property: String,
    },
    Control {
        action: String,  // "enabled", "shoot", ...
        block: String,
        value: IrValue,
    },
    Ubind(String),
    // ...
}

pub enum IrValue {
    Number(f64),
    String(String),
    Var(String),       // 已命名的变量
    Temp(usize),       // 临时变量 __tmp_0, __tmp_1...
    Special(String),   // @unit, @time 等
}

// 整个程序的 IR
pub struct IrProgram {
    pub instrs: Vec<IrInstr>,
    pub temp_counter: usize,
}
```

== 将 AST 表达式降级为三地址码

核心挑战：将一棵嵌套的表达式树"拍平"成一条条三地址码指令。

算法思路：
- 每次遇到 `BinaryOp { lhs, op, rhs }`，先递归处理 `lhs` 和 `rhs`，分别得到它们对应的"结果变量"
- 然后分配一个新临时变量，生成一条 `op` 指令
- 返回这个临时变量的值

```rust
impl IrProgram {
    fn lower_expr(&mut self, expr: &Expr) -> IrValue {
        match expr {
            Expr::Number(n) => IrValue::Number(*n),
            Expr::String(s) => IrValue::String(s.clone()),
            Expr::Variable(ident) => IrValue::Var(ident.to_string()),

            Expr::BinaryOp { lhs, op, rhs } => {
                let lhs_val = self.lower_expr(lhs);
                let rhs_val = self.lower_expr(rhs);
                let result = self.new_temp();

                let opcode = match op {
                    BinaryOp::Add => "add",
                    BinaryOp::Sub => "sub",
                    BinaryOp::Mul => "mul",
                    BinaryOp::Div => "div",
                    BinaryOp::Mod => "mod",
                    BinaryOp::Eq => "eq",
                    BinaryOp::Neq => "neq",
                    BinaryOp::Lt => "lt",
                    BinaryOp::Gt => "gt",
                    BinaryOp::Lteq => "lteq",
                    BinaryOp::Gteq => "gteq",
                    BinaryOp::And => "land",
                    BinaryOp::Or => "lor",  // 注意：MLOG 逻辑或用位或
                };

                self.instrs.push(IrInstr::Op {
                    opcode: opcode.to_string(),
                    result: result.clone(),
                    lhs: lhs_val,
                    rhs: rhs_val,
                });

                IrValue::Var(result)
            }

            Expr::UnaryOp { op, expr } => {
                let val = self.lower_expr(expr);
                match op {
                    UnaryOp::Neg => {
                        let result = self.new_temp();
                        // -x = 0 - x
                        self.instrs.push(IrInstr::Op {
                            opcode: "sub".to_string(),
                            result: result.clone(),
                            lhs: IrValue::Number(0.0),
                            rhs: val,
                        });
                        IrValue::Var(result)
                    }
                    UnaryOp::Not => {
                        let result = self.new_temp();
                        // !x = x == false
                        self.instrs.push(IrInstr::Op {
                            opcode: "eq".to_string(),
                            result: result.clone(),
                            lhs: val,
                            rhs: IrValue::Number(0.0),
                        });
                        IrValue::Var(result)
                    }
                }
            }
        }
    }

    fn new_temp(&mut self) -> String {
        let id = self.temp_counter;
        self.temp_counter += 1;
        format!("__tmp_{}", id)
    }
}
```

== 示例：表达式分解

输入 AST（`a + b * c`）：

```
BinaryOp {
    lhs: Variable("a"),
    op: Add,
    rhs: BinaryOp {
        lhs: Variable("b"),
        op: Mul,
        rhs: Variable("c"),
    },
}
```

`lower_expr` 的递归过程：

```
lower_expr(BinaryOp(Add))
  ├─ lower_expr(Variable("a")) → Var("a")
  └─ lower_expr(BinaryOp(Mul))
       ├─ lower_expr(Variable("b")) → Var("b")
       └─ lower_expr(Variable("c")) → Var("c")
       分配临时变量 __tmp_0
       生成: op mul __tmp_0 b c
       返回 Var("__tmp_0")

  分配临时变量 __tmp_1
  生成: op add __tmp_1 a __tmp_0
  返回 Var("__tmp_1")
```

最终 IR：

```
op mul __tmp_0 b c
op add __tmp_1 a __tmp_0
```

== 将语句降级为 IR

```rust
impl IrProgram {
    fn lower_stmt(&mut self, stmt: &Stmt, labels: &mut LabelState) {
        match stmt {
            Stmt::Let { name, init, .. } => {
                let val = self.lower_expr(init);
                self.instrs.push(IrInstr::Set {
                    result: name.to_string(),
                    value: val,
                });
            }

            Stmt::Assign { name, value } => {
                let val = self.lower_expr(value);
                self.instrs.push(IrInstr::Set {
                    result: name.to_string(),
                    value: val,
                });
            }

            Stmt::If { condition, then_branch, else_branch } => {
                let cond_val = self.lower_expr(condition);
                let skip_label = labels.fresh("__skip");
                let else_label = else_branch.as_ref()
                    .map(|_| labels.fresh("__else"));
                let end_label = labels.fresh("__end_if");

                // 条件跳转
                if let Some(ref el) = else_label {
                    self.instrs.push(IrInstr::JumpIf {
                        label: el.clone(),
                        condition: "eq".to_string(),
                        lhs: cond_val,
                        rhs: IrValue::Number(0.0),
                    });
                } else {
                    self.instrs.push(IrInstr::JumpIf {
                        label: skip_label.clone(),
                        condition: "eq".to_string(),
                        lhs: cond_val,
                        rhs: IrValue::Number(0.0),
                    });
                }

                // then 分支
                for s in then_branch {
                    self.lower_stmt(s, labels);
                }

                if let Some(el) = else_branch {
                    self.instrs.push(IrInstr::Jump {
                        label: end_label.clone(),
                    });
                    self.instrs.push(IrInstr::Label(el));
                    for s in el {
                        self.lower_stmt(s, labels);
                    }
                }

                self.instrs.push(IrInstr::Label(
                    else_label.unwrap_or(skip_label)
                ));
            }

            Stmt::While { condition, body } => {
                let loop_label = labels.fresh("__while");
                let end_label = labels.fresh("__end_while");

                self.instrs.push(IrInstr::Label(loop_label.clone()));

                let cond_val = self.lower_expr(condition);
                // if condition == false → jump to end
                self.instrs.push(IrInstr::JumpIf {
                    label: end_label.clone(),
                    condition: "eq".to_string(),
                    lhs: cond_val,
                    rhs: IrValue::Number(0.0),
                });

                for s in body {
                    self.lower_stmt(s, labels);
                }

                self.instrs.push(IrInstr::Jump {
                    label: loop_label,
                });
                self.instrs.push(IrInstr::Label(end_label));
            }

            Stmt::Loop { body } => {
                let loop_label = labels.fresh("__loop");
                let end_label = labels.fresh("__break");

                labels.push_break(end_label.clone());
                self.instrs.push(IrInstr::Label(loop_label.clone()));

                for s in body {
                    self.lower_stmt(s, labels);
                }

                self.instrs.push(IrInstr::Jump {
                    label: loop_label,
                });
                self.instrs.push(IrInstr::Label(end_label));
                labels.pop_break();
            }

            Stmt::Break => {
                let break_label = labels.current_break()
                    .expect("break outside loop");
                self.instrs.push(IrInstr::Jump {
                    label: break_label,
                });
            }

            Stmt::Print(expr) => {
                let val = self.lower_expr(expr);
                self.instrs.push(IrInstr::Print(val));
            }

            Stmt::PrintFlush(block) => {
                self.instrs.push(IrInstr::PrintFlush(block.to_string()));
            }

            Stmt::ExprStmt(expr) => {
                self.lower_expr(expr); // 结果被丢弃
            }

            // ... sensor, enable, disable 等
        }
    }
}
```

== 标签管理

标签在控制流中很重要——每个 `if`/`while`/`loop` 都需要唯一的标签名。

```rust
struct LabelState {
    counter: usize,
    break_stack: Vec<String>,
}

impl LabelState {
    fn fresh(&mut self, prefix: &str) -> String {
        let id = self.counter;
        self.counter += 1;
        format!("{}_{}", prefix, id)
    }

    fn push_break(&mut self, label: String) {
        self.break_stack.push(label);
    }

    fn pop_break(&mut self) {
        self.break_stack.pop();
    }

    fn current_break(&self) -> Option<String> {
        self.break_stack.last().cloned()
    }
}
```

#intuition[
  IR 阶段做了两件事：

  1. *表达式展平*：将 AST 的嵌套表达式树变成三地址码序列
  2. *控制流结构化*：将 if/while/loop 转成标签 + 跳转

  经过 IR 后，指令序列已经非常接近 MLOG——剩下的只是把每个 IR 指令映射到 MLOG 文本。
]

== 小结

- 三地址码是 MLOG 的自然中间表示
- `lower_expr` 递归遍历 AST 表达式树，分配临时变量，生成 op 指令
- `lower_stmt` 处理控制流，生成标签 + jump 指令
- 标签管理器（LabelState）确保标签名唯一，break 知道跳到哪里
- 经过 IR 阶段，编译器已经"说 MLOG 了"
#pagebreak()
