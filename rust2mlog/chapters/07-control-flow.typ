#import "../lib.typ": *
= 控制流 — jump 的三种形态
#labnote[ 第七站：if / while / loop / break ]

MLOG 只有一种控制流原语——`jump`。所有高级控制结构（分支、循环、break）都必须转化为标签 + 跳转的组合。

这一章深入讲解每种控制结构的 jump 模式。

== if-else 的 jump 模式

=== 只有 if（无 else）

```
if cond {
    // body
}
```

IR 模式：

```
<计算 cond → tmp>
jump __skip equal tmp false    // if cond == false, skip body
<body>
:__skip
```

MLOG：

```
op lt __tmp_0 i 10
jump __skip_0 equal __tmp_0 false
print "less than 10"
:__skip_0
```

=== if-else

```
if cond {
    // then_body
} else {
    // else_body
}
```

IR 模式：

```
<计算 cond → tmp>
jump __else equal tmp false    // if cond == false, goto else
<then_body>
jump __end always
:__else
<else_body>
:__end
```

#concept[
  关键点：*then 分支末尾必须有 `jump __end always`，否则会落到 else 分支中。*

  MLOG 是顺序执行的——没有"自动跳过 else"的机制。每个分支末尾的 jump 都不可或缺。
]

=== else if

```
if a > 0 {
    // a为正
} else if a < 0 {
    // a为负
} else {
    // a为零
}
```

IR 模式：

```
<计算 a > 0 → tmp0>
jump __else_if equal tmp0 false
<正>
jump __end always
:__else_if
<计算 a < 0 → tmp1>
jump __else equal tmp1 false
<负>
jump __end always
:__else
<零>
:__end
```

== while 循环的 jump 模式

```
while cond {
    // body
}
```

IR 模式：

```
:__while_N
<计算 cond → tmp>
jump __end_while_N equal tmp false    // if !cond, exit
<body>
jump __while_N always                 // loop back
:__end_while_N
```

#intuition[
  while 循环的标签布局：

  ```
  :loop_head        ← 每次迭代开始
  condition check
  conditional jump to :loop_end if false
  body
  unconditional jump back to :loop_head
  :loop_end         ← 退出点
  ```

  和汇编/字节码中的 while 结构完全一致。MLOG 是一个比较友好的编译目标——
  jump 指令的条件语法比真正的汇编更接近高级语言。
]

== loop 循环 + break

```
loop {
    if exit_cond { break; }
    // body
}
```

IR 模式：

```
:__loop_N
<计算 exit_cond → tmp>
jump __break_N not equal tmp false    // if exit_cond, goto break
<body>
jump __loop_N always
:__break_N
```

break 的实现最有趣：解析到 `break` 时，我们查看 `break_stack` 找到最近的 break 标签名，直接生成一条 `jump __break_N`。

#concept[
  因为 loop 需要知道 break 跳到哪里，所以：
  - 进入 loop 时，把一个新标签 `__break_N` 压入堆栈
  - 遇到 `break` 时，从堆栈读取当前标签
  - 离开 loop 时，弹出堆栈

  嵌套 loop 中，每个 break 自动跳转到对应的层级。
]

```
loop {           // break → __break_0
    loop {       // break → __break_1
        break;   // 跳到 __break_1
    }
    break;       // 跳到 __break_0
}
```

对应 IR：

```
:__loop_0
  :__loop_1
    jump __break_1 always    // 内层 break
    jump __loop_1 always
  :__break_1
  jump __break_0 always      // 外层 break
  jump __loop_0 always
:__break_0
```

== 短路求值

`&&` 和 `||` 需要短路语义——不计算不需要的操作数。

```
// a && b: 如果 a 是 false，不计算 b
```

IR：

```
<计算 a → tmp_a>
jump __skip_and equal tmp_a false       // a == false? skip
<计算 b → tmp_b>
set __result tmp_b
jump __end_and
:__skip_and
set __result false
:__end_and
```

```
// a || b: 如果 a 是 true，不计算 b
```

IR：

```
<计算 a → tmp_a>
jump __skip_or notEqual tmp_a false     // a == true? skip
<计算 b → tmp_b>
set __result tmp_b
jump __end_or
:__skip_or
set __result true
:__end_or
```

#intuition[
  短路求值就是提前跳转。

  `&&` 在第一个为 false 时跳转到"整体结果为 false"的标签。
  `||` 在第一个为 true 时跳转到"整体结果为 true"的标签。

  注意 MLOG 的 jump 条件：`jump label condition a b` 意思是 "如果 `a condition b` 为真则跳转"。

  - "a == false 时跳转" → `jump label equal a false`
  - "a == true 时跳转" → `jump label notEqual a false`
]

== 条件跳转的条件码速查

| 比较 | MLOG 条件 | 语义 |
|:---|:---|:---|
| `a == b` | `equal` | a 等于 b |
| `a != b` | `notEqual` | a 不等于 b |
| `a < b` | `lessThan` | a 小于 b |
| `a <= b` | `lessThanEq` | a 小于等于 b |
| `a > b` | `greaterThan` | a 大于 b |
| `a >= b` | `greaterThanEq` | a 大于等于 b |
| 无条件 | `always` | 永远跳转 |

条件码与 `op` 的运算码使用了不同的名称——代码生成时需要注意转换。

== 小结

- MLOG 只有 jump 一种控制流——所有结构化控制流必须转化
- if 无 else：`jump skip equal cond false`
- if-else：`jump else equal cond false` + `jump end always`
- while：`label loop` + `jump end equal cond false` + `jump loop always`
- loop/break：`break_stack` 管理标签层级
- 短路求值 = 提前跳转到结果标签
- 每个分支末尾的 `jump always` 不能少——MLOG 没有「跳过 else」
#pagebreak()
