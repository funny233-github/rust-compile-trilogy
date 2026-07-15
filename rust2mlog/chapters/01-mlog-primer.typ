#import "../lib.typ": *
= MLOG 汇编速览
#labnote[ 第一站：目标语言 ]

在写编译器之前，必须彻底理解目标语言。这一章覆盖 MLOG 的完整指令集和关键限制。

== 什么是 MLOG

MLOG 是 Mindustry 内置处理器（processor）执行的汇编式语言。

- 每个处理器有独立的指令序列，编号从 0 开始
- 每条指令占一行，无嵌套
- 执行模型：顺序执行，jump 改变执行流
- 每个 tick 执行若干条指令（取决于处理器类型）
- 变量是动态类型的——只有 `number` 和 `null`
- 没有调用栈——没有真正的函数

== 处理器类型

| 处理器 | 指令上限 | 特点 |
|:---|:---:|:---|
| Micro Processor | ~128 | 最小，够简单逻辑 |
| Logic Processor | ~500 | 标准 |
| Hyper Processor | ~1000 | 最强大 |
| World Processor | ~1000 | 全局控制（地图规则、天气等） |

#warning[
  1000 条指令看起来不少，但每条高级语言语句通常对应 2-5 条 MLOG 指令。
  一个中等复杂的 while 循环轻松吃掉 10+ 条指令。
]

== 核心指令族

=== set：赋值

```
set x 5          // x = 5
set y x          // y = x
set name "hello" // name = "hello"
```

变量在首次 `set` 出现时自动创建。没有类型声明，任何变量可以保存数字或字符串引用。

=== op：运算

```
op add result a b   // result = a + b
op sub result a b   // result = a - b
op mul result a b   // result = a * b
op div result a b   // result = a / b (浮点)
op idiv result a b  // result = a // b (整数除法)
op mod result a b   // result = a % b
op pow result a b   // result = a ^ b
op eq result a b    // result = a == b (比较用，不是严格相等)
op neq result a b   // result = a != b
op lt result a b    // result = a < b
op gt result a b    // result = a > b
op lteq result a b  // result = a <= b
op gteq result a b  // result = a >= b
op land result a b  // result = a && b (逻辑与)
op and result a b   // result = a & b (位与)
op or result a b    // result = a | b (位或)
op xor result a b   // result = a ^ b (位异或)
op shl result a b   // result = a << b
op shr result a b   // result = a >> b
op not result a 0   // result = !a (位非)
op max result a b   // result = max(a, b)
op min result a b   // result = min(a, b)
op abs result a 0   // result = |a|
op sin result a 0   // result = sin(a) 弧度
op cos result a 0   // result = cos(a)
op sqrt result a 0  // result = sqrt(a)
op rand result a 0  // result = 0..a 范围的随机整数
```

#concept[
  MLOG 的运算指令是 *三地址码*（three-address code）：
  ```
  op <操作符> <结果> <操作数1> <操作数2>
  ```
  这是一种接近编译器中层的表示形式——后面我们会大量使用这种形式。
]

=== jump：控制流

```
jump label always              // 无条件跳转
jump label condition a b       // 条件跳转
```

条件可以是：`==` `!=` `<` `<=` `>` `>=` `not`（布尔假时跳转）`always`。

```
jump end_loop gteq counter 10  // if counter >= 10 goto end_loop
jump skip equal x null        // if x == null goto skip
jump loop always              // goto loop
```

=== read / write：内存操作

```
read result memoryCell index    // result = memoryCell[index]
write value memoryCell index    // memoryCell[index] = value
```

必须链接内存单元（Memory Cell）才能使用。index 从 0 开始。

=== sensor：读取方块/单位属性

```
sensor result object property   // result = object.property
```

`sensor result @unit @x` — 读取当前绑定单位的 x 坐标。
`sensor result turret1 @ammo` — 读取炮塔的弹药量。

=== control：控制方块

```
control enabled block value 0 0 0   // 启用/禁用方块
control shoot block x y shoot 0     // 控制炮塔射击
```

== 输出指令

```
print "hello"             // 添加到打印缓冲区
print counter             // 添加变量的值
printflush message1       // 刷新缓冲区到消息方块

draw clear r g b          // 清屏
draw color r g b a 0 0   // 设置颜色
draw rect x y w h 0 0    // 绘制矩形
drawflush display1        // 刷新到显示器
```

== 单位指令

```
ubind @poly              // 绑定下一个 Poly 单位到 @unit
ucontrol move x y 0 0 0 // 移动当前单位
uradar ...               // 单位雷达
```

== 特殊变量

| 变量 | 含义 |
|:---|:---|
| `@counter` | 当前指令编号 |
| `@time` | 游戏时间（秒） |
| `@tick` | 当前 tick |
| `@unit` | 当前绑定的单位 |
| `@this` | 当前处理器 |
| `null` | 空值 |

== 硬限制

#warning[
  作为编译器作者，这些限制直接影响你的设计：

  1. *无调用栈*：不能 push/pop 返回地址，必须用 jump 模拟子程序
  2. *无类型系统*：编译时无法做类型检查，只能靠命名惯例
  3. *指令上限*：Micro ~128, Logic ~500, Hyper ~1000
  4. *变量是全局的*：DSL 中的"局部变量"需要编译器做名称转换
  5. *条件跳转只能是二元比较*：不能 `if x` 只能 `jump label eq x true`
  6. *单线程*：所有逻辑在一个指令流中
]

== 一个完整的 MLOG 程序

我们以最简单的例子结束：

```
// 打印 1 到 5
set counter 1
set limit 5
:loop
print counter
op add counter counter 1
op lteq continue counter limit
jump loop not continue false
printflush message1
```

输出：

```
1
2
3
4
5
```

MLOG 的语法很简单——但用这些原语组装复杂逻辑，就是编译器的工作了。

== 小结

- MLOG 是类汇编语言：set / op / jump 三大家族
- op 指令是三地址码：`op <opcode> <dest> <a> <b>`
- jump 是唯一控制流手段：条件/无条件跳转到标签
- 无调用栈、无类型、无作用域
- 输出靠 print/draw 缓冲区 + flush
- 处理器有严格指令上限
- 这些限制 *正是编译器要帮助开发者管理的*
#pagebreak()
