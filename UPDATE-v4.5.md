# OpenClaw Remote Deploy v4.5 更新说明

## 更新日期
2026-02-09

## 更新内容

### 新增问题 11: Windows Gateway 安装权限不足

**问题描述**:
- `openclaw gateway install` 在 Windows 上需要管理员权限
- 错误信息：`schtasks create failed: 错误: 拒绝访问`

**解决方案**:
1. **直接启动**（推荐，无需管理员权限）
   - 使用 `gateway.cmd` 直接启动
   - 使用 PowerShell 在新窗口启动

2. **以管理员权限安装服务**
   - 右键 PowerShell → 以管理员身份运行
   - 执行 `openclaw gateway install`

**对比**:
| 方式 | 优点 | 缺点 |
|------|------|------|
| 直接启动 | 无需管理员权限，立即可用 | 关闭窗口后停止，不会开机自启 |
| 安装为服务 | 开机自启动，后台运行 | 需要管理员权限 |

---

### 新增问题 12: OpenClaw Rescue Dashboard Windows 部署

**项目**: https://github.com/iamcheyan/openclaw-rescue-dashboard

**用途**: Web 紧急控制面板，用于快速恢复 AI agent 故障

**Windows 部署遇到的问题**:

#### 12.1 SSH 克隆失败
- **症状**: `Connection closed by 198.18.0.11 port 22`
- **解决**: 改用 HTTPS 克隆

#### 12.2 Windows 编码错误
- **症状**: `UnicodeEncodeError: 'gbk' codec can't encode character '\U0001f680'`
- **原因**: Python 代码中有 emoji，Windows 控制台默认 GBK 编码
- **解决**: 在 `app.py` 开头添加 UTF-8 编码设置

#### 12.3 Windows 兼容性问题
- **症状**: `lsof: command not found`, `systemctl: command not found`
- **原因**: 代码使用了 Linux 专用命令
- **解决**:
  - 修改 `kill_process_on_port` 函数（netstat 替代 lsof）
  - 修改 `restart_service` 函数（提示手动重启）

**部署步骤**:
1. 使用 HTTPS 克隆仓库
2. 应用 Windows 兼容性修复
3. 创建启动脚本 `start.bat`
4. 启动并访问 http://localhost:8080

**功能**:
- ⚡ 紧急模型切换
- 🔓 会话管理
- 📊 提供商概览
- ⚠️ Windows 上无法自动重启服务

---

## 文件修改

### REFERENCE.md
- 新增"问题 11: Windows Gateway 安装权限不足"
- 新增"问题 12: OpenClaw Rescue Dashboard Windows 部署"
- 更新版本号到 v4.5.0

### SKILL.md
- 更新版本号到 v4.5
- 更新描述中的版本号

---

## 部署经验总结

### Windows 特有问题
1. **权限管理**: Windows 任务计划程序需要管理员权限
2. **编码问题**: 默认 GBK 编码，需要显式设置 UTF-8
3. **命令兼容性**: Linux 命令（lsof, systemctl）需要替换为 Windows 等价命令（netstat, taskkill）
4. **SSH 连接**: 可能不稳定，建议使用 HTTPS

### 最佳实践
1. **Gateway 启动**: 优先使用直接启动方式，避免权限问题
2. **仓库克隆**: Windows 上优先使用 HTTPS
3. **跨平台代码**: 使用 `sys.platform` 检测并适配不同操作系统
4. **编码处理**: Python 脚本开头添加编码声明和 UTF-8 设置

---

## 测试验证

### 测试环境
- OS: Windows 10/11
- Python: 3.13.11
- OpenClaw: 2026.2.6-3

### 测试结果
- ✅ Gateway 直接启动成功（端口 18789）
- ✅ Rescue Dashboard 启动成功（端口 8080）
- ✅ 所有 Windows 兼容性修复生效
- ✅ 编码问题已解决

---

## 下一步计划

1. 考虑为 Windows 创建专门的安装脚本
2. 添加更多 Windows 特定的故障排查案例
3. 完善 Rescue Dashboard 的 Windows 部署文档
4. 考虑创建 Windows 服务安装的详细指南

---

## 参考资源

- [OpenClaw Rescue Dashboard](https://github.com/iamcheyan/openclaw-rescue-dashboard)
- [Windows 任务计划程序文档](https://docs.microsoft.com/en-us/windows/win32/taskschd/task-scheduler-start-page)
- [Python Windows 编码问题](https://docs.python.org/3/library/sys.html#sys.stdout)
