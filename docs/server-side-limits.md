# 服务端限流参考（可选，本仓库不含服务端）

> 本仓库只开源客户端。下面是把"每日次数上限"做在**你自己的 FastAPI 服务端**上的参考实现。
> 客户端无论怎么限制都能被绕过（源码公开，改一行就行），所以任何真正的额度控制都必须在服务端做。

## 一、为什么不在客户端做限制

- 客户端源码完全公开，删掉判断、改掉数字、重新打包，几秒钟就能绕过；
- 客户端拿不到"今天用了多少次"的全量数据，只有自己那一台设备；
- 额度是服务端扣的，账本在服务端，控制点也应该在服务端。

所以开源版能做的只有"劝退"（README 说明、默认关闭最贵的 AI 开关），不能"限流"。

## 二、⚠️ 一个必须知道的坑：`client` 参数是带逻辑的

三个去水印接口里都有这种分支：

```python
if client == "miniprogram" or client == "harmonyos":
    ...
    return JSONResponse(content={"result_url": ...})
return FileResponse(input_path, media_type="video/mp4", ...)
```

也就是说：**客户端的 `client` 字段决定了服务端返回 JSON 还是二进制文件流。**

所以千万不要为了"标记来源"就把客户端里的 `client` 从 `miniprogram` 改成 `github` ——
一旦改了，视频/文档接口会开始返回二进制流，客户端的 `JSONObject(...)` / `JSONDecoder` 直接解析失败，
表现为"处理失败"。如果确实要区分来源，必须先在服务端这三个分支里加上 `or client == "github"`。

## 三、每日次数上限（推荐）

在 `main.py` 里加一个依赖：

```python
DAILY_LIMIT_FREE = 5      # 免费用户每天最多处理次数
DAILY_LIMIT_PRO = 100     # 会员每天上限

def daily_quota(
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db),
):
    is_pro = (current_user.tier or "free").startswith("pro")
    limit = DAILY_LIMIT_PRO if is_pro else DAILY_LIMIT_FREE

    today = datetime.now(BEIJING_TZ).replace(
        hour=0, minute=0, second=0, microsecond=0, tzinfo=None
    )
    used = (
        db.query(models.UsageLog)
        .filter(
            models.UsageLog.user_id == current_user.id,
            models.UsageLog.created_at >= today,
        )
        .count()
    )
    if used >= limit:
        raise HTTPException(
            status_code=429,
            detail=f"今日处理次数已达上限（{limit} 次），请明天再来或联系客服",
        )
    return True
```

然后给每个去水印接口挂上（它们已经写 `UsageLog`，所以 `count()` 是准的）：

```python
@app.post("/api/remove-image-watermark", dependencies=[Depends(daily_quota)])
@app.post("/api/remove-video-watermark", dependencies=[Depends(daily_quota)])
@app.post("/api/remove-pdf-watermark",   dependencies=[Depends(daily_quota)])
@app.post("/api/remove-docx-watermark",  dependencies=[Depends(daily_quota)])
@app.post("/api/remove-pptx-watermark",  dependencies=[Depends(daily_quota)])
```

> 注意：`UsageLog` 是在处理**之前**写入的，所以统计的是"尝试次数"。
> 这对限流是好事（失败也计数），但如果你希望"失败不计次"，需要把写日志挪到成功之后。

## 四、AI 单独限额（花钱最多的那条路）

`use_ai=true` 会调用 SiliconFlow，按张计费，是真实成本。可以单独卡一道：

```python
DAILY_AI_LIMIT_FREE = 1   # 免费用户每天最多 1 次 AI

def ai_daily_quota(
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db),
):
    is_pro = (current_user.tier or "free").startswith("pro")
    if is_pro:
        return True
    today = datetime.now(BEIJING_TZ).replace(
        hour=0, minute=0, second=0, microsecond=0, tzinfo=None
    )
    used = (
        db.query(models.UsageLog)
        .filter(
            models.UsageLog.user_id == current_user.id,
            models.UsageLog.file_type == "image_ai",
            models.UsageLog.created_at >= today,
        )
        .count()
    )
    if used >= DAILY_AI_LIMIT_FREE:
        raise HTTPException(status_code=429, detail="今日 AI 去水印次数已用完，请明天再来")
    return True
```

配套要在 AI 分支里把 `file_type` 记成 `"image_ai"`，否则统计不到。

## 五、上线前的检查清单

- [ ] 新注册赠送次数是否还想给 10 次？开源后建议降到 3～5 次
- [ ] 每日上限是否覆盖了全部 5 个去水印接口
- [ ] AI 是否单独限次
- [ ] 注册的 `auth_limiter`（当前 5 次/分钟/IP）是否够用
- [ ] 是否配了异常用量告警（单账号一天几十次就该看一眼）
