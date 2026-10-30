# 素材记录

当前应用名：晴空物语。系统毛玻璃使用 SwiftUI Material，功能图标使用本机 SF Symbols。

## 少女头像与奇幻天空

2026-10-28 经用户指定的 ViseAPI 服务生成，调用模型标识为 `gpt-image-2.5`。通过 imagegen 技能附带 CLI，API 地址为 `https://www.viseapi.com/v1`；服务返回 URL 后下载图像。模型标识来自服务请求参数，不据此确认服务背后的实际模型版本。

- `AnimeAvatar.png`：原创校园少女大头照，用于 App 图标及侧栏品牌。
- `Sky.jpg`：奇幻二次元云海、浮空岛与月光天空，来自生成图的优化 JPEG；原始 PNG 保存在项目 `output/imagegen/fantasy-sky.png`。
- 头像原图：`output/imagegen/anime-girl.png`。
- 完整提示词：`output/imagegen/icon-prompt.txt`、`output/imagegen/sky-prompt.txt`。
- macOS 图标由 `scripts/make-icon.swift` 从头像裁成圆角方形并生成各档尺寸，不重新绘制人物。

生成请求只发送美术提示词，不含课程、训练或其他个人记录。图片随 App 本地打包，运行时不调用 API。

## 历史版本

旧版晴屿的 CC0 天空照片与原创几何图标保存在 `docs/branding-before/`。旧背景来源为 W.carter 的 Quill-shaped cirrus cloud：
https://commons.wikimedia.org/wiki/File:Quill-shaped_cirrus_cloud.jpg
许可：https://creativecommons.org/publicdomain/zero/1.0/
