# JHenTai

English | [简体中文](https://github.com/jiangtian616/JHenTai/blob/master/README_cn.md)

## Description

An E-Hentai app for mobile.

Still in starting stage, welcome to submit issues.

## Download & Install

[Download](https://github.com/jiangtian616/JHenTai/releases)

Install for Android: download .apk according to your device architecture and install.

Install for ios: download .ipa, then use  [AltStore](https://altstore.io) or SideLoadly to sign。

## Help With Translation

Please submit a PR if you want to help with translation.

[steps](https://github.com/jiangtian616/JHenTai#Translation)

## Develop Motivation

My first project With Flutter. I aim at getting familiar with Flutter during development. Devices I use include Android phone and
Ipad, E-hentai apps I used before have several bugs, and I don't understand source code because I have no development experience
with Android or ios, so I choose JHenTai to become my first Flutter Project.

## References

Layout and style references:

- [FEhviewer](https://github.com/honjow/FEhViewer) :Mainly
- [EHPanda](https://github.com/tatsuz0u/EhPanda)
- [EHViewer](https://gitlab.com/NekoInverter/EhViewer)

Tag translation:

- [EhTagTranslation](https://github.com/EhTagTranslation/Database)

mush thanks to these projects🙇‍

## screenshot

<img width="250" style="margin-right:10px" src="screenshot/1.jpg"/> <img width="250" style="margin-right:10px" src="screenshot/2.jpg"/> <img width="250" src="screenshot/3.jpg"/>

<img width="770" src="screenshot/4.png"/>

## Main Features

- [x] GalleryPage, Popular, Favorite, Watched, History, support multiple gallery list style
- [x] search, search suggestion, tap tag to search, file search, jump to a certain page
- [x] online reading and download, support restore download task
- [x] favorite, rating, torrent, archive, share
- [x] password login, Cookie login, web login
- [x] support EX site
- [x] vote for Tag
- [x] comment, vote for comment
- [x] domain fronting
- [x] Fingerprint unlock

## Feature Todo

- [ ] support My Tags
- [ ] customize Archive Page, support automatic unzip and read directly
- [ ] customize Statistic Page
- [ ] support sharing favorite

## Improvement & Todo

- [ ] use isolate to download

## Translation

1. Copy `/lib/src/l18n/en_US.dart ` and rename to `{your_languageCode}_{your_countryCode}.dart`
2. Rename classname in new file(optional)
3. Modify k-v pairs in method `keys` ,translate values to your language
4. Enter `/lib/src/l18n/locale_text.dart ` ,add a new k-v pair in method `keys`
   => `{your_languageCode}_{your_countryCode} : {your_className}.keys()`

## Bug

## Main Dart Dependencies

- dependency management, state management, l18n, NoSQL: get
- network: dio
- image: extendedImage
- database: drift

