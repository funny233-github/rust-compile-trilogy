// ============================================================
//  Rust → MLOG：用过程宏打造 Mindustry 汇编编译器
//  Rust → MLOG: Compiling to Mindustry Assembly via Proc Macros
//
//  入口文件 — 导入 lib.typ，设置页面样式，include 所有章节
// ============================================================

// ---- 页面设置 ----
#set page(
  paper: "a4",
  margin: (x: 2.5cm, y: 2.5cm),
  numbering: "1",
  number-align: center,
)

#set text(
  font: ("Noto Sans Mono", "Noto Serif CJK SC"),
  size: 10pt,
)

#set par(justify: true, leading: 0.65em)

#set heading(numbering: "1.1")

// ---- 导入共享样式和自定义环境 ----
#import "lib.typ": *

// ---- 代码块样式 ----
#show raw.where(block: true): set block(
  fill: rgb("#f8f9fa"),
  inset: 10pt,
  radius: 4pt,
  stroke: 0.5pt + rgb("#d1d5db"),
)

#show raw.where(block: true): set text(size: 9pt, font: "Noto Sans Mono")

#show raw.where(block: false): set text(font: "Noto Sans Mono", size: 9pt)

// ============================================================
//  封面
// ============================================================
#align(center)[
  #block(text(size: 26pt, weight: "bold")[Rust → MLOG])
  #block(text(size: 18pt, weight: "bold", fill: rgb("#4b5563"))[用过程宏打造 Mindustry 汇编编译器])
  #v(0.3em)
  #text(size: 10pt, fill: gray)[
    Typst 编译 — #datetime.today().display("[year]-[month]-[day]")
  ]
]

#v(2em)

#align(center)[
  #text(size: 11pt, fill: rgb("#6b7280"))[
    这不是一门新语言。

    这是一个嵌入在 Rust 中的 MLOG 编译器——

    从第一行 DSL 开始，到最后一条 jump 指令结束。
  ]
]

#pagebreak()

// ============================================================
//  目录
// ============================================================
#outline(
  title: "目录",
  depth: 2,
)

#pagebreak()

// ============================================================
//  章节
// ============================================================
#include "chapters/00-prologue.typ"
#include "chapters/01-mlog-primer.typ"
#include "chapters/02-dsl-design.typ"
#include "chapters/03-architecture.typ"
#include "chapters/04-parser.typ"
#include "chapters/05-ir.typ"
#include "chapters/06-codegen.typ"
#include "chapters/07-control-flow.typ"
#include "chapters/08-variables.typ"
#include "chapters/09-output.typ"
#include "chapters/10-error-diagnostics.typ"
#include "chapters/11-full-compiler.typ"
#include "chapters/12-conclusion.typ"
