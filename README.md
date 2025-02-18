# nexus-run (Nexus Prover 管理工具)

一个便捷的 Nexus Prover 节点管理工具，提供简单的安装、运行和管理功能。

## 特性

- 自动检测并安装依赖
- 支持 Linux 和 macOS
- 一键安装并启动 Nexus Prover
- Prover ID 管理
- 运行状态监控
- tmux 会话管理

## 快速开始

```bash
curl -O https://raw.githubusercontent.com/qzz0518/nexus-run/refs/heads/main/nexus-manager.sh && chmod +x nexus-manager.sh && ./nexus-manager.sh
```

## 系统要求

- 2022年以后的 Linux 发行版(老版本系统请重装新系统) 或 macOS
- 支持 APT 或 YUM 的包管理器（Linux）
- Homebrew（macOS）

## 功能选项

1. 安装并启动 Nexus
2. 查看当前运行状态
3. 查看 Prover ID
4. 设置 Prover ID
5. 停止 Nexus
6. 退出

## 注意事项

- 首次运行时会提示输入 Prover ID，如果没有可以直接回车自动生成 (建议使用网页上的 ID)
- 查看运行状态时请使用关闭终端或者 Ctrl+B 再按 D 的方式退出，不要使用 Ctrl+C
- 程序会自动在后台运行，无需保持终端开启
- 服务器内存至少要有 2G RAM，不然会闪退
- 请确认你的服务器已经安装 openssl3 及以上版本，不然会启动失败

## 关于 Prover ID 的说明
如果你想在网页上的看到自己的 POINTS ,点击左下角 My Profile 如下图显示的话，你需要使用网页接口的形式获取并使用你的 localId 才能够显示（这里可能有个坑，如果你在CLI跑可能真的需要这个完整的ID才有效，你使用网页版截取的前8位的可能是无效的）。
<img width="1326" alt="image" src="https://github.com/user-attachments/assets/a2107b55-7f8a-4bc6-bbaa-eb17f0ea927c">

网页浏览器进入 https://beta.nexus.xyz/ ，点击F12，按照下图画红圈的地方进行点击，找最后找到 localId，并复制绿色的部分（复制id不要带双引号），使用并设置为 Prover ID
<img width="1137" alt="image" src="https://github.com/user-attachments/assets/e7d038dd-a940-4681-bd8d-aacd1816b2f3">


或者在F12控制台中，输入如下使用命令,则会显示你的id

```js
console.log(localStorage.getItem('flutter.proverId'));
```
<img width="500" alt="image" src="https://github.com/user-attachments/assets/76b99f8f-bcb4-4a70-bf3d-ff346bf8ccb2">



当前使用CLI随机生成id的形式运行并不代表你跑的积分无效，请保存和备份好你随机生成的id，项目方后续应该会出绑定的步骤。


## 我已经运行过了，我想使用网页上的 ID 重新跑需要怎么做？

如果你已经运行过 Nexus Prover，但想使用网页上的 ID 重新运行，请按照以下步骤操作：

1.	打开浏览器，进入 - [Nexus Beta](https://beta.nexus.xyz/) 页面。
2.	按下 F12 打开开发者工具，切换到控制台 (Console)。
3.	在控制台中输入以下命令：console.log(localStorage.getItem('flutter.proverId'));
4.	复制输出的 ID（绿色部分，不要包含双引号）。注意: 如果之前使用的是随机生成的 ID，请备份该 ID，以防丢失后无法查看之前的积分。
5.	回到终端，运行脚本并按照以下步骤操作：

```bash
./nexus-manager.sh
```

	•	按下 5 停止当前进程。
	•	按下 4 设置新的 Prover ID，并粘贴从网页复制的一长串 ID。
	•	按下 1 启动 Nexus。

完成上述步骤后，Prover 会使用新的 ID 运行，等几分钟后你可以在网页中查看积分和其他信息。

## 关于作者

- Twitter: [@zerah_eth](https://x.com/zerah_eth)
- Github: [qzz0518/nexus-run](https://github.com/qzz0518/nexus-run)

## 推荐工具

- SOL 回收工具: [SOLBack](https://solback.app/)

## 相关链接

- [Nexus Network](https://nexus.xyz/)
- [Nexus Beta](https://beta.nexus.xyz/)
- [Nexus Client](https://github.com/nexus-xyz/network-api)
