# 大目录 cursor 与 UI 增量加载设计

> 状态：2026-07-18，native cursor ABI 已实现并有 FFI 回归；Dart session、浏览器增量加载、全局排序与全 root 搜索仍未实现。

## 现状与问题

- Flutter 的 `SliverList` 与 `SliverGrid` 只虚拟构建可见条目，但 `HomeShell` 在创建浏览器前已拿到完整 `items` 列表。
- `ReadDir_FFI` 会把 walker 全部结果编码为一个 JSON 响应；目录很宽时，Go、C 字符串、Dart JSON 和 `FileSystemNode` 会同时持有整表。
- `FileService.listCurrentDirectory(offset/limit)` 与目录树的“加载更多”是在完整响应之后做 `skip/take`，不能降低内存、首屏延迟或 FFI 传输量。
- 当前 UI 排序和筛选默认面对完整目录。若直接改为追加页面再沿用这些操作，会错误地把局部排序或局部筛选说成全量结果。

## 目标与非目标

第一阶段目标：当前目录可按固定大小增量读取、列表/网格仅持有已读取条目、导航或 root 关闭可立即取消并释放 native walker。

第一阶段不做：递归 walker 搜索、全 root 搜索、任意宽目录的全局排序、目录快照隔离、跨进程续传 cursor，或把一次性读取改名为“分页”。

## FFI 协议

新增三个 C ABI 导出，均返回现有成功/失败 JSON 包装：

- `sec_dir_cursor_open(root_id, relative_path)`：创建非递归 `IDirWalker`，返回 `cursor_id`。不预读目录，避免 open 时把首屏和生命周期耦合。
- `sec_dir_cursor_read_page(cursor_id, limit)`：读取最多 `limit` 个可见条目，返回 `entries` 与 `done`。只有实际读到 `io.EOF` 才令 `done=true`；不能使用 `HasNext()`。最后一个恰好填满的页面可暂时 `done=false`，下一次读取返回空数组与 `done=true`，调用方不得把这视为错误。
- `sec_dir_cursor_close(cursor_id)`：幂等关闭 walker 并移除 cursor。`root` 关闭时必须同步关闭属于该 root 的所有 cursor；未知或已关闭 cursor 返回稳定错误。

每个 cursor 绑定一个 root id 和逻辑相对目录。它不可并发读取；Dart 同一 `DirectoryPageSession` 串行化 `readPage`。读取、名称解密、metadata、路径转换或 walker work-limit 错误必须让本次页请求失败并自动关闭 cursor。此前已完成页面在 UI 中可保留，但必须显示“目录未完整加载”和重试/刷新入口，不能显示完整数量。

cursor 只保存一个 native walker，不保存 JSON 页或整目录。应用端在页面离开、刷新、root 锁定、widget dispose 或错误后关闭它。native 端还应有 root 关闭兜底，不能依赖 Dart `dispose`。

## UI 状态机

`DirectoryPageSession` 为每个当前目录持有：已加载条目、cursor id、`isLoading`、`done`、错误和 generation。导航、刷新或 root id 变化递增 generation；迟到结果不得写入新目录。

- 初次打开读取一个固定 page（建议 200 条）。
- list/grid 共享一个 scroll controller；距离底部约两个 viewport 时读取下一页。加载时在 sliver 尾部显示进度，失败显示重试，完成显示无更多条目。
- 筛选在未完成加载时必须明确标注“仅已加载条目”，继续滚动可扩大范围；不得称为当前目录完整筛选。
- 未完成加载时禁用全局排序菜单并说明原因。完整加载后才允许现有内存排序。名称/时间/大小的真正全量排序需要后续外部索引或后端排序设计，不能在本阶段伪造。
- 文件选择使用稳定逻辑路径；页面追加和重新构建不得丢失已选项。涉及变更当前目录内容的操作完成后，关闭 cursor 并从第一页刷新。
- tree 是单独的 direct-child cursor 消费者，不得递归预载；其“加载更多”只能建立在真实 cursor 上。

## 并发与一致性

目录枚举不提供快照隔离。枚举期间新增、删除、重命名的条目可能不出现、重复或在后续页报底层错误；UI 在刷新前不承诺一致目录快照。对会改变当前目录的应用内操作，先取消 session、执行操作、再从头刷新，避免与旧 cursor 混合。

## 验收

- sec：目录 cursor 分页顺序、EOF、错误传播、关闭幂等、root 关闭级联、名称加密与内部 marker ignore。
- FFI：C ABI cursor 打开/多页/错误/关闭，失败不被转换为空页。
- Dart：generation 防止迟到结果覆盖、取消/刷新/错误重试、逻辑路径映射和草稿过滤。
- Widget：list/grid 首屏、滚动加载、加载/完成/失败状态、筛选与排序边界、导航后不混页。
- 性能：真实 name-encrypted root 生成至少 10 万 direct entries，记录首屏条数、峰值内存和分页响应；没有该证据不得宣称大目录任务完成。

## 当前实施证据

- `OpenDirCursor_FFI`、`ReadDirCursorPage_FFI`、`CloseDirCursor_FFI` 已实现；页读取只以 `io.EOF` 作为完成条件，walker 错误会销毁 cursor 并返回失败。
- root 关闭前会关闭并移除其 cursor；FFI 测试覆盖多页、EOF、无效 page size、幂等 close 与 root 关闭级联。
- Dart bindings、`DirectoryPageSession`、list/grid/tree 接入和 10 万条性能基线仍为未完成项。
