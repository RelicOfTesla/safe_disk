# Safe Disk 重构任务列表

> 本文档记录所有重构相关的待办任务

**相关文档**：
- [archive/ARCHITECTURE_REFACTOR_PLAN_V2.md](archive/ARCHITECTURE_REFACTOR_PLAN_V2.md) - V2 架构设计（历史参考）
- [ARCHITECTURE.md](ARCHITECTURE.md) - 当前架构文档
- [TODO.md](TODO.md) - 功能任务列表

---

## 📊 优先级说明

- **P0（紧急）**：必须立即处理，影响架构稳定性
- **P1（高）**：尽快处理，影响代码质量
- **P2（中）**：后续改进，架构优化
- **P3（低）**：锦上添花，可选重构

---

## 🔴 P0 - 紧急任务

### 1. TaskManager 持久化实现

**优先级**：1（最高）

**背景**：taskManager 需要支持断电恢复和多任务管理

**设计方案**：
- `_pending_task_list.json` - 维护处理一半的 import/export 任务列表
- `_progress_task_<task_id>.json` - 每个任务的进度文件（原 `_progress_list.json`）

**实现要点**：
```
taskManager 内部结构：
- taskList: map[taskID]*ActionTaskInfo
- pendingTaskListFile: _pending_task_list.json（持久化）

ActionTaskInfo 内部结构：
- taskID: string
- taskType: TransferType（export/import）
- status: TaskStatus（pending/running/paused/complete/failed/rolled_back）
- progressFile: _progress_task_<task_id>.json（持久化）
- progress: ProgressStatus（内存）
```

**持久化流程**：
1. 任务创建时：
   - 生成 taskID
   - 写入 `_pending_task_list.json`
   - 创建 `_progress_task_<task_id>.json`

2. 任务更新时：
   - 更新内存中的 progress
   - 写入 `_progress_task_<task_id>.json`

3. 任务完成/失败时：
   - 从 `_pending_task_list.json` 中移除
   - 保留 `_progress_task_<task_id>.json`（用于回滚）

**验收标准**：
- [ ] taskManager 创建时加载 `_pending_task_list.json`
- [ ] 任务创建/更新/完成时持久化
- [ ] 断电恢复测试通过

---

### 2. 原子化导入导出实现（安全 + 异步 + 原子化 + 持久队列）

**优先级**：2

**背景**：TransferService 需要支持断电恢复、幂等性、数据安全

**核心设计**（详见 V2 文档）：
- 进度持久化：`_progress_task_<task_id>.json`
- 原子化文件替换：`rename -> rename -> update progress -> remove temp`
- 断电恢复：启动时检查进度文件，清理临时文件

**流程**（Import/Export 统一）：
```
Step 1: 扫描所有文件，保存 -> _progress_task_<task_id>.json
Step 2: 加密/解密文件
Step 3: 安全替换（原子操作）：rename(a.txt -> a.txt.raw), rename(a.txt.enc -> a.txt)
Step 4: 保存进度（更新 _progress_task_<task_id>.json）← 先更新进度
Step 5: 清理临时文件：remove(a.txt.raw) ← 后删除临时文件
Step 6: 返回 Step 2 处理下一个文件
```

**验收标准**：
- [ ] ImportDirectoryAsync 实现原子化流程
- [ ] ExportDirectoryAsync 实现原子化流程
- [ ] 断电恢复测试通过
- [ ] 幂等性测试通过

---

### 3. ActionTask 任务管理接口

**优先级**：3

**背景**：ExportDirectoryAsync/ImportDirectoryAsync 需要返回任务管理对象，支持暂停、继续、回滚等操作。

**依赖**：
- TaskManager 持久化实现
- 原子化导入导出实现（回滚功能依赖持久化进度文件）

**接口设计**：
```go
type ActionTask interface {
    GetProgress() *TaskProgress
    AsyncPause() error
    AsyncContinue() error
    AsyncRollback() error  // 仅能回滚导入/导出一回
    Close() error
}
```

**FFI 导出函数**：
```c
// 任务进度查询
char* action_task_get_progress(const char* action_task_id);

// 任务控制
char* action_task_async_pause(const char* action_task_id);
char* action_task_async_continue(const char* action_task_id);
char* action_task_async_rollback(const char* action_task_id);

// 任务关闭
char* action_task_close(const char* action_task_id);
```

**实现要点**：
- ActionTask 内部维护任务状态（pending/running/paused/complete/failed/rolled_back）
- AsyncRollback 记录已完成的操作，按逆序撤销
- 导入回滚：删除已导入的文件
- 导出回滚：删除已导出的文件
- FFI 返回 JSON 格式的结果

**验收标准**：
- [ ] ActionTask 接口定义
- [ ] TransferService 返回 ActionTask 对象
- [ ] FFI 导出函数实现
- [ ] Dart 端测试通过

---

## 🟡 P1 - 高优先级任务

### 重构 stream 设计

**背景**：允许重构掉原来 V2 的 stream 设计，允许不兼容

**验收标准**：
- [ ] 评估现有 stream 设计的问题
- [ ] 设计新的 stream 方案
- [ ] 实现并测试

---

## 🟢 P2 - 中优先级任务

### 架构文档

**验收标准**：
- [ ] 更新 ARCHITECTURE.md（V2 架构设计已合并至当前文档）
- [ ] 添加设计决策记录
- [ ] 添加接口文档

---

## ✅ 已完成任务

- [x] **架构重构：统一配置传递** ✅ 2026-04-06
- [x] **架构重构：路径类型安全强制** ✅ 2026-04-06
- [x] **架构重构：修复过度设计** ✅ 2026-04-06
- [x] **架构重构：移动 sec_transfer 到 sec_fs** ✅ 2026-04-06
- [x] **架构重构：TaskManager 封装化** ✅ 2026-04-06
- [x] **架构重构：删除 TransferResult 和同步方法** ✅ 2026-04-06

---

_Last updated: 2026-04-06_
