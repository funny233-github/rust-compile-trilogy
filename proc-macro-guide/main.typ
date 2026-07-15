// ============================================================
//  Rust 过程宏：从零开始的探索之旅
//  Procedural Macros: A Hands-On Introduction
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

// ---- 内联代码样式 ----
#show raw.where(block: false): set text(font: "Noto Sans Mono", size: 9pt)

// ============================================================
//  封面
// ============================================================
#align(center)[
  #block(text(size: 28pt, weight: "bold")[Rust 过程宏])
  #block(text(size: 20pt, weight: "bold", fill: rgb("#4b5563"))[从零开始的探索之旅])
  #v(0.3em)
  #text(size: 10pt, fill: gray)[
    Typst 编译 — #datetime.today().display("[year]-[month]-[day]")
  ]
]

#v(2em)

#align(center)[
  #text(size: 11pt, fill: rgb("#6b7280"))[
    这不是一本 API 手册。

    这是一个开发者发现过程宏的全程记录——

    从第一个重复的代码开始，到最后一个自定义 derive 结束。
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
#include "chapters/01-from-macro-rules.typ"
#include "chapters/02-tokenstream.typ"
#include "chapters/03-parsing.typ"
#include "chapters/04-codegen.typ"
#include "chapters/05-derive-macro.typ"
#include "chapters/06-attribute-macro.typ"
#include "chapters/07-function-like.typ"
#include "chapters/08-error-handling.typ"
#include "chapters/09-testing.typ"
#include "chapters/10-case-study.typ"
#include "chapters/11-advanced.typ"
#include "chapters/12-conclusion.typ"
