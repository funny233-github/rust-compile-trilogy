// ============================================================
//  lib.typ — 共享样式、自定义环境、辅助函数
//  proc-macro-tutorial
// ============================================================

// ---- 调色板 ----
#let concept-color    = rgb("#2563eb")
#let definition-color = rgb("#059669")
#let example-color    = rgb("#d97706")
#let note-color       = rgb("#7c3aed")
#let intuition-color  = rgb("#0891b2")
#let story-color      = rgb("#be185d")
#let derivation-color = rgb("#8b5cf6")
#let warning-color    = rgb("#dc2626")
#let code-color       = rgb("#1e293b")

// ---- 自定义环境 ----
#let env(title, color, body) = {
  block(
    inset: 8pt,
    fill: color.lighten(90%),
    stroke: (left: 3pt + color),
    radius: 3pt,
    [#text(weight: "bold", fill: color)[#title] \
     #body],
  )
}

#let concept(body)     = env("🔬 概念", concept-color, body)
#let definition(body)  = env("定义", definition-color, body)
#let example(body)     = env("示例", example-color, body)
#let note(body)        = env(text(fill: note-color)[💡 注], note-color, body)
#let intuition(body)   = env(text(fill: intuition-color)[🔍 核心直觉], intuition-color, body)
#let story(body)       = env(text(fill: story-color)[📖 故事], story-color, body)
#let derivation(body)  = env(text(fill: derivation-color)[✏️ 推导], derivation-color, body)
#let dialogue(body)    = env(text(fill: rgb("#1e293b"))[🎭 对话], rgb("#1e293b"), body)
#let warning(body)     = env(text(fill: warning-color)[⚠️ 注意], warning-color, body)

// ---- 辅助 ----
#let labnote(body) = text(weight: "bold", size: 9pt, fill: rgb("#64748b"))[🧪 实验记录：#body]
