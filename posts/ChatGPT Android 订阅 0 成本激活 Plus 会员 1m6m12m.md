# ChatGPT Android 订阅 0 成本激活 Plus 会员 1m/6m/12m

<font color="red">对爬虫 & 逆向 & 算法模型感兴趣的同学可以查看历史文章，私信作者一对一小班教学，学习详细案例和兼职接单渠道</font>

<font color="red">相关代码和软件视频购买地址：http://219.151.187.96:3000/product/prod_56cfc1171e9b</font>

------

****

> 适用平台：Android x86_64 模拟器（推荐 Android 12） 工具：Frida 17.x · ADB

------

## 一、原理简介

ChatGPT Android 端使用 **RevenueCat** 管理订阅，通过 **Google Play Billing** 完成支付。

核心思路：用 Frida 在运行时将 Google Play 的 `offerToken`（优惠凭证）替换为目标优惠档位的 token，Google Play 会以该优惠价格处理订阅，完成后 RevenueCat 自动同步激活 Plus 会员。

整个过程**不会产生实际费用**（免费试用期内）。

### 关键障碍：libpairipcore.so

ChatGPT 集成了 Appdome 反篡改 SDK，核心模块 `libpairipcore.so` 会在运行时检测注入行为并强制退出。需要在注入后立即将其所有可执行段用 `0xC3`（RET 指令）填充，使所有检测函数直接返回。

```javascript
var mod = Process.findModuleByName("libpairipcore.so");

Process.enumerateRanges("r-x").forEach(function(r) {

    if (r.base.compare(mod.base) < 0 ||

        r.base.compare(mod.base.add(mod.size)) >= 0) return;

    Memory.protect(r.base, r.size, "rwx");

    var buf = new Uint8Array(r.size);

    buf.fill(0xC3); // RET — 所有函数立即返回，检测逻辑失效

    Memory.writeByteArray(r.base, buf.buffer);

});
```

同时还需绕过 Java 层的 `VMRunner` 以及系统 SSL 证书校验，确保脚本可以正常 hook 网络请求。

------

## 二、订阅套餐 offerId

Google Play 后台为每个优惠档位分配了唯一的 `offerId`，脚本通过替换对应的 `offerToken` 来激活指定优惠。

### ChatGPT Plus（$19.99/月）

|          offerId          |          优惠内容          |
| :-----------------------: | :------------------------: |
|      `2ispxs5mtgz35`      |  免费 1 年 → 后 $19.99/月  |
|      `2wqkodfx51z2x`      | 免费 6 个月 → 后 $19.99/月 |
| `plus-1-month-free-trial` | 免费 1 个月 → 后 $19.99/月 |
|    `3-day-free-trial`     |  免费 3 天 → 后 $19.99/月  |
|   `1-month-10-dollars`    |  首月 $10 → 后 $19.99/月   |
|      （无 offerId）       |  直接 $19.99/月（无优惠）  |
|         （年付）          |          $200/年           |

![图片[4]-如何在Android模拟器上使用Frida破解ChatGPT订阅优惠](https://web.archive.org/web/20260420143138im_/https://www.azx.us/wp-content/uploads/2026/04/52c52a47a220260420150928.jpg)

![图片[1]-如何在Android模拟器上使用Frida破解ChatGPT订阅优惠](https://web.archive.org/web/20260420143138im_/https://www.azx.us/wp-content/uploads/2026/04/4ab1a29e6e20260420150923.jpg)

![图片[2]-如何在Android模拟器上使用Frida破解ChatGPT订阅优惠](https://web.archive.org/web/20260420143138im_/https://www.azx.us/wp-content/uploads/2026/04/a140b8436b20260420150925.jpg)

![图片[3]-如何在Android模拟器上使用Frida破解ChatGPT订阅优惠](https://web.archive.org/web/20260420143138im_/https://www.azx.us/wp-content/uploads/2026/04/9529d1992920260420150926.jpg)

![图片[4]-如何在Android模拟器上使用Frida破解ChatGPT订阅优惠](https://web.archive.org/web/20260420143138im_/https://www.azx.us/wp-content/uploads/2026/04/52c52a47a220260420150928.jpg)

![图片[1]-如何在Android模拟器上使用Frida破解ChatGPT订阅优惠](https://web.archive.org/web/20260420143138im_/https://www.azx.us/wp-content/uploads/2026/04/4ab1a29e6e20260420150923.jpg)



### ChatGPT Go（$8/月）

|       offerId        |        优惠内容        |
| :------------------: | :--------------------: |
| `1-month-free-trial` | 免费 1 个月 → 后 $8/月 |
|   `16ei8n9du5wh6`    | 免费 3 个月 → 后 $8/月 |
|   `1r5t7n9qz0y1u`    |  免费 1 年 → 后 $8/月  |
|    （无 offerId）    |       直接 $8/月       |

> 本项目提供 **1 个月免费试用**的测试脚本（`hook_1m.js`）。 6 个月、12 个月等其他档位的 `offerToken` 获取与适配请自行研究。

------

## 三、环境准备

**PC 端：**

```python
pip install frida frida-tools
```

**模拟器要求：**

- Android x86_64（推荐 AVD Android 12）
- 已 root
- 已安装 ChatGPT APK
- 已登录 Google Play 账号（建议使用有试用资格的新账号）

**启动 frida-server（每次重启模拟器后执行一次）：**

```python
adb push frida-server /data/local/tmp/

adb shell chmod 755 /data/local/tmp/frida-server

adb shell su -c '/data/local/tmp/frida-server &'
```

------

## 四、使用步骤

**第一步：注入脚本**

先在模拟器里打开 ChatGPT，等主界面加载完毕后执行：

```python
frida -U -n ChatGPT -l hook_1m.js
```

看到 `就绪。请在 ChatGPT 中点击订阅按钮` 后继续。

**第二步：完成购买**

在 ChatGPT 里点击升级订阅 → 在 Google Play 弹窗里**点确认**。

![图片[5]-如何在Android模拟器上使用Frida破解ChatGPT订阅优惠](https://web.archive.org/web/20260420143138im_/https://www.azx.us/wp-content/uploads/2026/04/d2b5ca33bd20260420150655.png)

购买完成后，当前账号即可获得 1 个月 Plus 会员。

## 五、常见问题

|            现象             |                 原因 / 解决                 |
| :-------------------------: | :-----------------------------------------: |
| 弹窗显示 $19.99，无免费试用 |     Google 账号无试用资格，换新账号重试     |
|    Frida 报错找不到进程     | 确认 ChatGPT 已打开且 frida-server 正在运行 |
|      App 内未显示会员       |   退出账号重新登录，或强制停止 App 后重开   |
