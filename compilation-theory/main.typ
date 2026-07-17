// ============================================================
//  代码生成论：从 C 到 Rust 到 MLOG
//  Code Generation Theory: From C to Rust to MLOG
//
//  入口文件
// ============================================================

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

#import "lib.typ": *

#show raw.where(block: true): set block(
  fill: rgb("#f8f9fa"),
  inset: 10pt,
  radius: 4pt,
  stroke: 0.5pt + rgb("#d1d5db"),
)
#show raw.where(block: true): set text(size: 9pt, font: "Noto Sans Mono")
#show raw.where(block: false): set text(font: "Noto Sans Mono", size: 9pt)

// ============================================================
#align(center)[
  #block(text(size: 26pt, weight: "bold")[代码生成论])
  #block(text(size: 17pt, weight: "bold", fill: rgb("#4b5563"))[从 C 到 Rust 到 MLOG])
  #v(0.3em)
  #text(size: 10pt, fill: gray)[
    Typst 编译 — #datetime.today().display("[year]-[month]-[day]")
  ]
]

#v(2em)

#align(center)[
  #text(size: 11pt, fill: rgb("#6b7280"))[
    所有编译器都是翻译器。

    从 C 到 x86，从 Rust 到 LLVM IR，从 DSL 到 MLOG——

    每条翻译链背后都是同一套方法论。
  ]
]

#pagebreak()
#outline(title: "目录", depth: 2)
#pagebreak()

// ============================================================
#include "chapters/00-prologue.typ"
#include "chapters/01-cpu-view.typ"
#include "chapters/02-c-expr.typ"
#include "chapters/03-c-control.typ"
#include "chapters/04-c-func.typ"
#include "chapters/05-regalloc.typ"
#include "chapters/06-graph-color.typ"
#include "chapters/07-tac.typ"
#include "chapters/08-c-to-rust.typ"
#include "chapters/09-rust-specific.typ"
#include "chapters/10-optimization.typ"
#include "chapters/11-back-to-mlog.typ"
#include "chapters/12-proc-macro-theory.typ"
#include "chapters/13-conclusion.typ"
