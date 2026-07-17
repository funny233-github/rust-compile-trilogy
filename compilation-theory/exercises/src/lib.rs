// 共享数据结构 — 所有练习共用
//
// 这些类型是编译器 IR（三地址码）的核心数据结构，
// 贯穿 ch03 到 ch11 的所有练习。

/// 值：整数常量或变量名。
///
/// ```
/// Value::Int(42)       // 编译期常量
/// Value::Var("t0")     // 临时变量 / 用户变量
/// ```
#[derive(Debug, Clone, PartialEq)]
pub enum Value {
    Int(i64),
    Var(String),
}

/// 二元运算。
///
/// ```
/// BinOp::Add  →  +
/// BinOp::Sub  →  -
/// BinOp::Mul  →  *
/// BinOp::Div  →  /  (整数除法)
/// ```
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum BinOp {
    Add,
    Sub,
    Mul,
    Div,
}

/// 三地址码指令。
///
/// 每条指令最多三个操作数：result = lhs op rhs。
/// 这是编译器中所有分析和优化的基本单位。
///
/// ```
/// // t0 = a + b
/// Tac::BinOp { result: "t0", op: BinOp::Add, lhs: Value::Var("a"), rhs: Value::Var("b") }
///
/// // y = 42
/// Tac::Copy { result: "y", value: Value::Int(42) }
///
/// // goto loop
/// Tac::Jump("loop")
///
/// // if x == 0 goto done
/// Tac::IfGoto { cond: Value::Var("x"), label: "done" }
///
/// // 标签
/// Tac::Label("done")
/// ```
#[derive(Debug, Clone, PartialEq)]
pub enum Tac {
    /// `result = lhs op rhs`
    BinOp {
        result: String,
        op: BinOp,
        lhs: Value,
        rhs: Value,
    },
    /// `result = value`
    Copy {
        result: String,
        value: Value,
    },
    /// `goto label`
    Jump(String),
    /// `if cond == 0 goto label`
    IfGoto {
        cond: Value,
        label: String,
    },
    /// 跳转目标标签
    Label(String),
}

/// 表达式树节点（ch03 用）。
///
/// ```
/// // 1 + 2
/// Expr::BinOp(Box::new(Expr::Int(1)), BinOp::Add, Box::new(Expr::Int(2)))
///
/// // a * b
/// Expr::BinOp(Box::new(Expr::Var("a")), BinOp::Mul, Box::new(Expr::Var("b")))
/// ```
#[derive(Debug, Clone, PartialEq)]
pub enum Expr {
    Int(i64),
    Var(String),
    BinOp(Box<Expr>, BinOp, Box<Expr>),
}

/// 活跃区间（ch06 寄存器分配用）。
///
/// ```
/// // 变量 a 在指令 0 处定义，最后在指令 3 处被使用
/// LiveInterval { var: "a", start: 0, end: 3 }
/// ```
#[derive(Debug, Clone, PartialEq)]
pub struct LiveInterval {
    /// 变量名
    pub var: String,
    /// 定义点（指令索引）
    pub start: usize,
    /// 最后使用点（指令索引）
    pub end: usize,
}

pub mod ch03_expr;
pub mod ch04_control;
pub mod ch05_func;
pub mod ch06_regalloc;
pub mod ch09_enum;
pub mod ch10_optimize;
pub mod ch11_mlog;
