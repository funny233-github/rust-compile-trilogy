// 共享数据结构 — 所有练习共用

/// 值：整数常量或变量名
#[derive(Debug, Clone, PartialEq)]
pub enum Value {
    Int(i64),
    Var(String),
}

/// 二元运算
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum BinOp {
    Add,
    Sub,
    Mul,
    Div,
}

/// 三地址码指令
#[derive(Debug, Clone, PartialEq)]
pub enum Tac {
    /// result = lhs op rhs
    BinOp {
        result: String,
        op: BinOp,
        lhs: Value,
        rhs: Value,
    },
    /// result = value
    Copy {
        result: String,
        value: Value,
    },
    /// goto label
    Jump(String),
    /// if cond goto label
    IfGoto {
        cond: Value,
        label: String,
    },
    /// 标签（跳转目标）
    Label(String),
}

/// 表达式树节点
#[derive(Debug, Clone, PartialEq)]
pub enum Expr {
    Int(i64),
    Var(String),
    BinOp(Box<Expr>, BinOp, Box<Expr>),
}

/// 活跃区间（用于寄存器分配）
#[derive(Debug, Clone, PartialEq)]
pub struct LiveInterval {
    pub var: String,
    pub start: usize, // 定义点的指令索引
    pub end: usize,   // 最后使用的指令索引
}

pub mod ch02_expr;
pub mod ch03_control;
pub mod ch04_func;
pub mod ch05_regalloc;
pub mod ch08_enum;
pub mod ch09_optimize;
pub mod ch10_mlog;
