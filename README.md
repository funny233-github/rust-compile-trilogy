# 代码生成论

三本教程，一个主题：**代码生成**。

从 Rust 过程宏的 API，到 MLOG 编译器的实现，到编译理论的底层原理——
覆盖从「怎么用」到「怎么做」到「为什么」的完整链条。

## 目录

| 目录 | 内容 | 形式 |
|---|---|---|
| `compilation-theory/` | 编译理论 — C → x86 → Rust → MLOG | Typst 书籍 + Rust 练习 |
| `rust2mlog/` | MLOG 编译器实战 | Rust proc macro 项目 |
| `proc-macro-guide/` | 过程宏指南 | Rust 教程 |

## 快速开始

### 编译理论

```bash
cd compilation-theory
typst compile main.typ          # 生成 PDF
```

### 编程练习

```bash
cd compilation-theory/exercises
cargo test                      # 全部 stub，0 passed
cargo test ch03                 # 做完一个测一个
```

答案在 `exercises/answers/`，但建议先自己做。

## 练习列表

| 章节 | 练习 | 内容 |
|---|---|---|
| 第 3 章 | `ch03_expr` | 表达式树 → 三地址码 |
| 第 4 章 | `ch04_control` | if-else → 跳转指令 |
| 第 5 章 | `ch05_func` | 栈帧偏移计算 |
| 第 6 章 | `ch06_regalloc` | 线性扫描寄存器分配 |
| 第 7 章 | `ch07_graph` | 干涉图构建 |
| 第 10 章 | `ch10_enum` | Fat pointer + vtable 分发 |
| 第 11 章 | `ch11_optimize` | 常量折叠 |
| 第 12 章 | `ch12_mlog` | TAC → MLOG 文本 |

## 许可证

MIT
