# Rust → MLOG 编译器教程 — 大纲草案

## 核心概念

通过 Rust 过程宏，在编译时将类 Rust 的 DSL 代码编译成 Mindustry MLOG 汇编。

使用场景：你在 Rust 中写：

```rust
let program = mlog! {
    let mut counter = 0;
    loop {
        counter += 1;
        if counter >= 100 { break; }
    }
    print("Done: ");
    print(counter);
    print_flush(message1);
};
```

编译时宏将其展开为 MLOG 文本：

```
set counter 0
:__loop_1
op add counter counter 1
op gteq __tmp_0 counter 100
jump __end_1 not __tmp_0
jump __loop_1
:__end_1
print "Done: "
print counter
printflush message1
```

## 目标

- 读起来像 Rust，输出是 MLOG 文本
- 编译时完成所有代码生成（零运行时开销）
- 类型安全的 DSL（变量作用域、语义检查）
- 最终产出的 MLOG 是格式良好的，可以直接粘贴到 Mindustry

---

## 章节大纲

### 序章：为什么需要 Rust → MLOG？
- 问题场景：在 Mindustry 中写复杂逻辑，MLOG 表达能力差
- 方案一：直接手写 MLOG — 容易出错，没有 IDE 支持
- 方案二：用 Mindcode — 独立语言，不集成 Rust 工具链
- 方案三：Rust proc macro 嵌入式 DSL — 编译时生成，零运行时
- 本教程的结构

### 第一章：MLOG 汇编速览
- MLOG 是什么：类似汇编的单指令语言
- 变量模型：无类型，set 创建，动态类型
- 核心指令族：set / op / jump
- I/O 指令：read / write / sensor / control
- 输出指令：print / printflush / draw / drawflush
- 单位指令：ubind / ucontrol / uradar
- 特殊变量：@counter @time @unit 等
- 硬限制：无调用栈，~1000 指令上限，单处理器单线程

### 第二章：设计 DSL — 从 MLOG 到 Rust 语法
- DSL 设计目标：看起来像 Rust，编译成 MLOG
- 语法映射表：Rust 语法 → MLOG 指令
- let 绑定 → set
- 二元运算 → op
- if/while/loop → jump + 条件
- print!() → print + printflush
- 函数调用 → 内联展开（无栈约束）
- 一个完整示例：从 DSL 到 MLOG 的对照

### 第三章：过程宏架构设计
- 为什么用 proc macro：编译时计算，零运行时
- crate 结构：mlog-macro（proc-macro crate + facade crate）
- 三种设计选择：
  - 方案 A：函数式宏 `mlog! { ... }`
  - 方案 B：属性宏 `#[mlog] fn ...`
  - 方案 C：函数式宏 + 增量解析
- 为什么选方案 A：最直观，最灵活

### 第四章：解析 DSL — 自己写一个简单的解析器
- 不用 syn 的 DeriveInput——我们解析的是 DSL，不是 Rust 结构体
- 从 TokenStream 到 AST：定义自己的语法树节点
- AST 节点类型：Program, Stmt (Let/Assign/If/While/Loop/Print/Break), Expr
- 逐 token 解析：peek / parse / error 模式
- 表达式解析：二元运算、括号、字面量、变量引用

### 第五章：中间表示 — 三地址码
- 为什么需要中间表示：MLOG 的 op 指令是三地址码
- 三地址码定义：`dest = src1 op src2`
- 表达式 SSA 化：复杂表达式拆成三地址码序列
- 临时变量生成：`__tmp_0`, `__tmp_1`...
- 示例：`a + b * c` → `tmp0 = b * c; tmp1 = a + tmp0`

### 第六章：代码生成 — AST → MLOG
- 从 AST 节点到 MLOG 指令的映射
- Let 语句 → set 指令
- Assign 语句 → set 指令
- If 语句 → jump + 标签
- While 语句 → jump + 标签（循环头 + 出口）
- Loop 语句 → 无条件跳转 + break 标签
- 表达式 → op 指令链
- Print 语句 → print + printflush
- 标签分配：统一的标签命名策略

### 第七章：控制流 — jump 的三种形态
- MLOG 的条件跳转机制：jump label condition a b
- 条件码：== != < <= > >= always not
- 三种跳转模式：
  - 条件分支：if/else
  - 条件循环：while
  - 无条件：loop（break 用 if + jump）
- 嵌套控制流的标签管理：栈式标签分配
- 短路求值：&& 和 || 的分解

### 第八章：变量系统
- MLOG 的变量是全局的——需要自己管作用域
- 变量名映射：用户变量 → 唯一 MLOG 标识符
- 自动生成临时变量：`__tmp_N`
- let 变量的生命周期
- 不可变 vs 可变变量
- 变量名冲突检测和错误报告

### 第九章：输出生成 — 最后的 MLOG 文本
- 指令列表 → 格式化的 MLOG 文本
- `quote!` 宏生成 TokenStream vs 直接生成 String
- 这里选择直接生成 String（MLOG 不是 Rust 代码）
- 格式：缩进、标签格式、注释
- 集成到 Rust：`mlog!` 展开为 `&'static str`
- 在 Rust 中使用：打印到文件、嵌入二进制

### 第十章：错误处理与诊断
- DSL 中的语义错误：未定义变量、break 在非循环中
- 利用 Span 指向 DSL 代码中的错误位置
- 友好的错误信息：不是 "token parse error" 而是 "variable 'x' not defined"
- 编译时panic vs 友好的 compile_error!
- 调试技巧：打印中间表示

### 第十一章：实战 — 完整编译器
- 组合所有模块
- 从 DSL 输入到 MLOG 输出
- 完整示例：仓库管理机器人
- 完整示例：自动炮塔控制
- 测试策略：单元测试 IR，集成测试 MLOG 输出

### 第十二章：进阶扩展
- 内存操作 (read/write) 支持
- Sensor 和控制指令
- 单位控制 (ubind/ucontrol)
- 常量和内建变量
- 寄存器分配优化（减少临时变量）
- 与其他 MLOG 工具链对比

### 终章：总结与展望
- 我们做了什么：一个嵌入在 Rust 中的 MLOG 编译器
- Rust proc macro 做编译器的优势和局限
- 未来方向：优化器、更多语言特性、VS Code 插件
- 推荐阅读

---

## 风格说明

与 proc-macro-tutorial 保持一致：
- 直接技术讲解（无角色叙事）
- 相同的环境框（concept, definition, example, intuition, note, warning）
- 相同的排版（Typst, 相同字体/颜色主题）
- 🧪 实验记录标签（改为"第X站"等编号）
- 每章从实际问题出发，逐步构建
- 大量代码示例，每章要点总结
