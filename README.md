# video-compressor

ローカルのFFmpegを使って動画を指定サイズ以下に圧縮する、Windows向けアプリです。

## 必要なもの

`ffmpeg`と`ffprobe`をPATHから実行できるようにしてください。インストーラーには同梱されていません。

## ビルド

```powershell
nimble install -y uirelays@0.8.0
nimble buildRelease
```

インストーラーの作成には[Inno Setup 6](https://jrsoftware.org/isinfo.php)が必要です。

```powershell
nimble buildInstaller
```
