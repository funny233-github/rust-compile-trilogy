// Shared data structures for all exercises.
//
// These types form the compiler IR (three-address code) used
// throughout exercises ch03 through ch11.

/// A value: either a compile-time integer constant or a variable name.
///
/// ```
/// Value::Int(42)       // compile-time constant
/// Value::Var("t0")     // temporary or user variable
/// ```
#[derive(Debug, Clone, PartialEq)]
pub enum Value {
    Int(i64),
    Var(String),
}

/// A binary operator.
///
/// ```
/// BinOp::Add  →  +
/// BinOp::Sub  →  -
/// BinOp::Mul  →  *
/// BinOp::Div  →  /  (integer division)
/// ```
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum BinOp {
    Add,
    Sub,
    Mul,
    Div,
}

/// A three-address code instruction.
///
/// At most three operands: `result = lhs op rhs`.
/// This is the basic unit of all compiler analysis and optimization.
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
/// // label definition
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
    Copy { result: String, value: Value },
    /// `goto label`
    Jump(String),
    /// `if cond == 0 goto label`
    IfGoto { cond: Value, label: String },
    /// A jump target label
    Label(String),
}

/// An expression tree node (used in ch03).
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

/// A live interval for register allocation (used in ch06).
///
/// ```
/// // Variable "a" is defined at instruction 0 and last used at instruction 3
/// LiveInterval { var: "a", start: 0, end: 3 }
/// ```
#[derive(Debug, Clone, PartialEq)]
pub struct LiveInterval {
    /// Variable name
    pub var: String,
    /// Definition point (instruction index)
    pub start: usize,
    /// Last use point (instruction index)
    pub end: usize,
}

pub mod ch03_expr;
pub mod ch04_control;
pub mod ch05_func;
pub mod ch06_regalloc;
pub mod ch07_graph;
pub mod ch10_enum;
pub mod ch11_optimize;
pub mod ch12_mlog;
