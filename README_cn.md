# JHenTai

[English](https://github.com/jiangtian616/JHenTai/blob/master/README.md) | 简体中文

## 定位

E-hentai 的一个移动端app。

仍在起步阶段，欢迎提交issue。
## 下载&安装

[下载](https://github.com/jiangtian616/JHenTai/releases)

安卓安装： 下载对应自己设置架构的apk文件，直接安装即可。

苹果安装： 下载ipa文件后，使用[AltStore](https://altstore.io)、SideLoadly、爱思助手等任一工具进行自签名。

## 开发动机

学习flutter的第一个练手项目，用来熟悉flutter的开发流程。

我自己平时主要使用安卓手机和Ipad，之前用的E站其他移动端App Bug较多，没接触过原生开发也改不动源码，就刚好选JHenTai来作为第一个项目。

## 参考与借鉴

布局样式参考：

- [FEhviewer](https://github.com/honjow/FEhViewer) ：主要
- [EHPanda](https://github.com/tatsuz0u/EhPanda)
- [EHViewer](https://gitlab.com/NekoInverter/EhViewer)

标签翻译数据库：

- [EhTagTranslation](https://github.com/EhTagTranslation/Database)

十分感谢以上项目🙇‍

## 截图

<img width="250" style="margin-right:10px" src="screenshot/1.jpg"/> <img width="250" style="margin-right:10px" src="screenshot/2.jpg"/> <img width="250" src="screenshot/3.jpg"/>

<img width="770" src="screenshot/4.png"/>

## 主要功能

- [x] 主页、热门、收藏、关注、历史，支持多种画廊样式
- [x] 搜索、搜索Tag提示、点击Tag快捷搜索、以图搜图、跳页
- [x] 在线阅读与下载，支持恢复下载记录
- [x] 收藏、评分、磁力、归档、分享
- [x] 账号密码登录、Cookie登录、Web登录
- [x] 支持里站
- [x] Tag翻译、Tag投票
- [x] 评论、评论投票
- [x] 域名前置实现直连
- [x] 指纹解锁

## 功能Todo

- [ ] 自动打开剪切板中的画廊链接
- [ ] 接入E站本身的My Tags
- [ ] 自定义归档视图，支持下载完后自动解压、阅读
- [ ] 自定义统计视图
- [ ] 支持收藏夹分享

## 优化Todo

- [ ] 另起isolate，专门负责下载

## 国际化步骤

1. 复制 `/lib/src/l18n/en_US.dart ` 一份并重命名为`{your_languageCode}_{your_countryCode}.dart`
2. 更改新文件的主类名字(可选)
3. 修改keys方法返回的所有键值对，将value翻译为你的语言
4. 在 `/lib/src/l18n/locale_text.dart ` 的keys方法中增加一条键值对`{your_languageCode}_{your_countryCode} : {your_className}.keys()`

## 已知bug

## 主要dart依赖

- 依赖管理、状态管理、国际化、NoSQL：get
- 网络：dio
- 图片：extendedImage
- 数据库：drift

