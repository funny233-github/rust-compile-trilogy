#import "../lib.typ": *
= C 控制流 → 汇编
#labnote[ 第三站：cmp + jmp = 一切 ]

C 的 `if`、`while`、`for`、`switch` 在汇编层全部归结为 `cmp` + 条件跳转 + 无条件跳转。这和 MLOG 的 `jump` 模式完全相同。

== if-else

C：

```c
if (x > 0) {
    y = 1;
} else {
    y = -1;
}
```

汇编（伪代码，虚拟寄存器）：

```
    cmp r0, 0         ; x > 0 ?
    jle __else         ; if x <= 0, goto else
    mov r1, 1          ; y = 1
    jmp __end
__else:
    mov r1, -1         ; y = -1
__end:
```

三地址码 IR：

```
    op gt __t0 x 0
    jump __else equal __t0 false     ; x <= 0
    set y 1
    jump __end
:__else
    set y -1
:__end
```

#intuition[
  if-else 的编译模式和 MLOG 完全一致：

  ```
  1. 计算条件 → 临时变量
  2. 条件为假 → 跳转到 else（或跳过 then）
  3. 执行 then 分支
  4. 无条件跳到 end（如果有 else）
  5. else 分支
  6. end 标签
  ```

  x86 用 `cmp + jle`，MLOG 用 `op gt + jump equal false`——语义等价，只是操作码不同。
]

== while 循环

C：

```c
while (n > 0) {
    sum += n;
    n--;
}
```

汇编：

```
__loop:
    cmp r0, 0         ; n > 0 ?
    jle __end          ; if n <= 0, exit loop
    add r1, r0         ; sum += n
    sub r0, 1          ; n--
    jmp __loop
__end:
```

三地址码 IR：

```
:__loop
    op gt __t0 n 0
    jump __end equal __t0 false      ; n <= 0
    op add sum sum n
    op sub n n 1
    jump __loop
:__end
```

x86 的 while 和 MLOG 的 while 在三地址码层面*完全相同*——都是标签 + 条件跳转 + 回跳的组合。

== for 循环

C 的 `for` 是 `while` 的语法糖：

```c
for (int i = 0; i < 10; i++) {
    sum += i;
}
```

等价于：

```c
int i = 0;
while (i < 10) {
    sum += i;
    i++;
}
```

编译器没有"for 循环"这个概念——for 在解析阶段就被展开成 while 的形式，然后按 while 的模式生成代码。

== switch

C：

```c
switch (x) {
    case 0: y = 10; break;
    case 1: y = 20; break;
    case 2: y = 30; break;
    default: y = 0; break;
}
```

有两种编译策略：

=== 策略一：链式比较（case 少时）

```
    cmp x, 0; jne __case1
    mov y, 10; jmp __end
__case1:
    cmp x, 1; jne __case2
    mov y, 20; jmp __end
__case2:
    cmp x, 2; jne __default
    mov y, 30; jmp __end
__default:
    mov y, 0
__end:
```

O(n)——和 if-else 链没区别。

=== 策略二：跳转表（case 密集时）

```asm
    mov rax, x
    cmp rax, 2         ; 边界检查
    ja __default
    jmp [jt + rax*8]   ; 间接跳转
jt: .quad __case0, __case1, __case2
```

O(1)——用 case 值做索引直接跳转。

#concept[
  跳转表是一个编译时常量数组，存储每个 case 的目标地址。

  `jmp [jt + rax*8]` 用 case 值做数组索引，一次跳转完成分发。

  这是 switch 比 if-else 链快的根本原因。
]

== 短路求值

```c
if (a != 0 && b / a > 10) { ... }
```

`&&` 的短路语义：如果 `a == 0`，不能执行 `b / a`（会除零）。

汇编：

```
    cmp a, 0
    je  __skip           ; a == 0 → 整个条件为 false
    mov eax, b
    cdq
    idiv a               ; b / a
    cmp eax, 10
    jle __skip           ; b/a <= 10 → 整个条件为 false
    ; ... then body ...
__skip:
```

#intuition[
  短路求值 = 提前跳转。

  `&&`：第一个操作数为假 → 跳过整个条件，直接到 false 分支
  `||`：第一个操作数为真 → 跳过整个条件，直接到 true 分支

  这和 MLOG 的短路求值逻辑完全一致。
]

== 控制流图 (CFG)

#definition[
  *控制流图*（Control Flow Graph）是把指令序列划分为*基本块*，用箭头连接跳转关系。

  - 基本块：连续执行的指令序列，入口只能是最顶部，出口只能是最底部
  - 边：从 jump 指令指向目标标签
]

```
        [入口]
          |
    [cmp x, 0; jle]
       /      \
  [y=1]     [y=-1]
       \      /
        [出口]
```

CFG 是编译器分析和优化的基础数据结构。数据流分析、死代码消除、循环检测——全部建立在 CFG 上。

== 小结

- if/while/for 全部归结为 cmp + 条件跳转 + 无条件跳转
- for 是 while 的语法糖——展开后没有区别
- switch 有两种编译策略：链式比较 vs 跳转表
- 短路求值 = 提前跳转（&& 遇假则跳，|| 遇真则跳）
- 控制流图是编译优化的基础
- x86 和 MLOG 的控制流编译模式*完全相同*——只是指令名不同
#pagebreak()
