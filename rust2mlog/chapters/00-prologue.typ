#import "../lib.typ": *
= 序章：为什么需要 Rust → MLOG？

你在 Mindustry 中想实现一个智能仓库管理系统。

需要做的事：
- 扫描所有容器中的物品数量
- 当某种物品低于阈值，触发生产线
- 当存储空间不够，调度运输单位
- 在显示器上实时展示库存状态

MLOG 是一门类汇编语言——没有函数，没有类型，没有变量作用域，没有循环语法。你能用的工具有：

- `set x 5` — 给变量赋值
- `op add result a b` — 算术/逻辑运算
- `jump label condition a b` — 条件/无条件跳转
- `read` / `write` / `sensor` / `control` / `print` / `draw`

用这些写一个仓库管理系统，代码会长得像这样：

```
set copper 0
set lead 0
set threshold 100
:check_copper
sensor copper container1 @copper
op lt need_power copper threshold
jump skip_power equal need_power false
control enabled conveyor1 true
:skip_power
op add index index 1
op lt continue index 4
jump check_copper equal continue true
print "Copper: "
print copper
printflush message1
end
```

当逻辑复杂时——嵌套条件、多状态机、多单位协调——手写 MLOG 很快就变成维护噩梦。

== 三种解决方案

=== 方案一：手写 MLOG

直接编辑文本，粘贴到 Mindustry 处理器。

| 优点 | 缺点 |
|:---|:---|
| 零依赖 | 无可读性 |
| 完全控制 | 无 IDE 支持 |
| | 容易出错 |
| | 没有变量作用域 |
| | 调试靠 print |

=== 方案二：Mindcode

Mindcode 是一个独立的编译器，把高级语言编译成 MLOG。

```
while copper < threshold do
  enabled = true;
end;
```

但它有局限性：
- 独立语言和工具链——和 Rust 项目不集成
- 不能在 Rust 代码中直接生成 MLOG
- 编译结果需要手动复制粘贴

=== 方案三：Rust 过程宏嵌入式 DSL

在 Rust 源码中直接写 MLOG DSL：

```rust
let program = mlog! {
    let mut copper = 0;
    let threshold = 100;

    loop {
        copper = sensor(container1, @copper);
        if copper < threshold {
            enable(conveyor1);
        }
        if index >= 4 { break; }
        index += 1;
    }

    print("Copper: ");
    print(copper);
    print_flush(message1);
};
```

编译时，过程宏把它转换成正确的 MLOG 文本字符串：

```
set threshold 100
set index 0
:__loop_0
sensor copper container1 @copper
op lt __tmp_0 copper threshold
jump __skip_0 equal __tmp_0 false
control enabled conveyor1 true 0 0
:__skip_0
op gteq __tmp_1 index 4
jump __break_0 not __tmp_1 false
op add index index 1
jump __loop_0
:__break_0
print "Copper: "
print copper
printflush message1
```

#intuition[
  这就是本教程要做的事：*在 Rust 中写一个嵌入式编译器*。

  用过程宏把类 Rust 的 DSL 编译成 MLOG 汇编。
  编译器本身在 Rust 编译时运行，产出的 MLOG 文本可以直接粘贴到 Mindustry。
]

== 本教程的结构

这是一次从零开始搭建编译器的旅程。

*第一章*：深入理解目标语言——MLOG 的完整指令集和限制
*第二章*：设计 DSL——MLOG 语义如何映射到 Rust 语法
*第三章*：过程宏架构——选择宏类型，搭项目骨架
*第四章*：解析器——手写一个 TokenStream → AST 的解析器
*第五章*：中间表示——三地址码 IR，表达式分解
*第六章*：代码生成——AST/IR → MLOG 指令序列
*第七章*：控制流——if/while/loop 的 jump 标签策略
*第八章*：变量系统——作用域、临时变量、唯一名称
*第九章*：输出——把 MLOG 指令格式化为文本
*第十章*：错误诊断——如何给用户好的错误信息
*第十一章*：组装完整编译器——从 DSL 到 MLOG 的完整流程
*第十二章*：进阶扩展与总结

准备好从 Rust 走向 MLOG 了吗？
#pagebreak()
