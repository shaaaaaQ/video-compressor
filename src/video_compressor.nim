import uirelays
import std/[atomics, json, math, os, osproc, streams, strformat, strutils, unicode]

const
  AppTitle = "video-compressor"
  UiFontPath = when defined(windows): "segoeui.ttf" else: ""
  MinWindowWidth = 820
  MinWindowHeight = 580
  Bg = color(246, 247, 245)
  Paper = color(255, 255, 255)
  Soft = color(239, 241, 244)
  Border = color(215, 218, 221)
  Ink = color(30, 32, 35)
  Muted = color(104, 108, 113)
  Accent = color(43, 82, 211)
  AccentHover = color(34, 68, 181)
  Success = color(35, 127, 83)
  Danger = color(181, 59, 54)

type
  Job = object
    inputPath: string
    outputPath: string
    duration: float
    targetMb: int
    audioEnabled: bool
    targetFps: float

  UpdateKind = enum
    ProgressUpdate, CompletedUpdate, FailedUpdate, CancelledUpdate

  WorkerUpdate = object
    kind: UpdateKind
    progress: float
    message: string
    outputPath: string
    outputBytes: int64

  AppState = object
    inputPath: string
    outputPath: string
    inputBytes: int64
    duration: float
    sourceFps: float
    targetFps: float
    targetMb: int
    audioEnabled: bool
    progress: float
    status: string
    busy: bool
    completed: bool
    ffmpegReady: bool
    ffmpegVersion: string
    mouseX: int
    mouseY: int

  DragTarget = enum
    NoDrag, TargetSizeDrag, FrameRateDrag

  UiRects = object
    selectFile, openOutput, compress, cancel: Rect
    targetSlider, fpsSlider, audioToggle: Rect
    preset20, preset50: Rect

var
  updates: Channel[WorkerUpdate]
  cancelRequested: Atomic[bool]

when defined(windows):
  proc getAsyncKeyState(vKey: int32): int16
    {.stdcall, dynlib: "user32", importc: "GetAsyncKeyState".}

proc leftMouseIsDown(): bool =
  when defined(windows):
    (getAsyncKeyState(1) and cast[int16](0x8000'u16)) != 0
  else:
    true

proc clampFloat(value, low, high: float): float =
  if high < low: return low
  max(low, min(value, high))

proc formatTime(seconds: float): string =
  let safe = max(0.0, seconds)
  let hours = int(safe) div 3600
  let minutes = (int(safe) mod 3600) div 60
  let secs = int(safe) mod 60
  if hours > 0: &"{hours:02}:{minutes:02}:{secs:02}"
  else: &"{minutes:02}:{secs:02}"

proc formatBytes(bytes: int64): string =
  if bytes < 1024 * 1024:
    &"{float(bytes) / 1024.0:.1f} KB"
  else:
    &"{float(bytes) / 1024.0 / 1024.0:.2f} MB"

proc truncateMiddle(value: string; maxChars: int): string =
  let charCount = value.runeLen
  if charCount <= maxChars: return value
  let side = max(4, (maxChars - 3) div 2)
  value.runeSubStr(0, side) & "..." & value.runeSubStr(charCount - side, side)

proc fitMiddle(font: Font; value: string; maxWidth: int): string =
  if measureText(font, value).w <= maxWidth: return value
  var maxChars = max(8, value.runeLen - 1)
  while maxChars > 8:
    result = truncateMiddle(value, maxChars)
    if measureText(font, result).w <= maxWidth: return
    dec maxChars
  result = "..."

proc detectFfmpegVersion(): string =
  try:
    let raw = execProcess("ffmpeg", args = ["-version"],
      options = {poUsePath, poStdErrToStdOut, poDaemon})
    let lines = raw.splitLines()
    if lines.len > 0:
      const prefix = "ffmpeg version "
      if lines[0].startsWith(prefix):
        let fields = strutils.splitWhitespace(lines[0][prefix.len .. ^1])
        if fields.len > 0: return "FFmpeg " & fields[0]
  except CatchableError:
    discard
  "FFmpegが見つかりません"

proc drawBorder(r: Rect; c: Color) =
  if r.w <= 0 or r.h <= 0: return
  drawLine(r.x, r.y, r.x + r.w - 1, r.y, c)
  drawLine(r.x, r.y, r.x, r.y + r.h - 1, c)
  drawLine(r.x + r.w - 1, r.y, r.x + r.w - 1, r.y + r.h - 1, c)
  drawLine(r.x, r.y + r.h - 1, r.x + r.w - 1, r.y + r.h - 1, c)

proc drawLabel(font: Font; fm: FontMetrics; r: Rect; label: string;
               fg, bg: Color) =
  let size = measureText(font, label)
  let x = r.x + max(0, (r.w - size.w) div 2)
  let y = r.y + max(0, (r.h - fm.lineHeight) div 2)
  discard drawText(font, x, y, label, fg, bg)

proc drawButton(font: Font; fm: FontMetrics; r: Rect; label: string;
                mouseX, mouseY: int; enabled = true; primary = false;
                selected = false) =
  let hovered = enabled and r.contains(point(mouseX, mouseY))
  let bg =
    if not enabled: Soft
    elif primary and hovered: AccentHover
    elif primary: Accent
    elif selected: color(232, 237, 255)
    elif hovered: color(245, 247, 252)
    else: Paper
  let fg =
    if not enabled: color(157, 160, 165)
    elif primary: Paper
    elif selected: Accent
    else: Ink
  fillRect(r, bg)
  drawBorder(r, if selected or primary: Accent else: Border)
  drawLabel(font, fm, r, label, fg, bg)

proc sliderValue(x: int; r: Rect; low, high, step: int): int =
  let ratio = clampFloat(float(x - r.x) / float(max(1, r.w)), 0.0, 1.0)
  let raw = float(low) + ratio * float(high - low)
  clamp(int(round(raw / float(step))) * step, low, high)

proc drawSlider(r: Rect; value, low, high: int; enabled: bool) =
  let track = rect(r.x, r.y + (r.h - 6) div 2, r.w, 6)
  let ratio = float(value - low) / float(high - low)
  let knobX = r.x + int(ratio * float(r.w))
  fillRect(track, if enabled: color(224, 227, 232) else: Soft)
  if enabled:
    fillRect(rect(track.x, track.y, max(0, knobX - track.x), track.h), Accent)
  let knob = rect(knobX - 7, r.y + (r.h - 18) div 2, 14, 18)
  fillRect(knob, if enabled: Accent else: color(170, 173, 178))
  drawBorder(knob, if enabled: AccentHover else: Border)

proc fpsFromSlider(x: int; r: Rect; sourceFps: float): float =
  if sourceFps <= 1: return max(1.0, sourceFps)
  let ratio = clampFloat(float(x - r.x) / float(max(1, r.w)), 0.0, 1.0)
  if ratio >= 0.995: return sourceFps
  min(sourceFps, max(1.0, round(1.0 + ratio * (sourceFps - 1.0))))

proc drawFpsSlider(r: Rect; value, sourceFps: float; enabled: bool) =
  let high = max(1.0, sourceFps)
  let track = rect(r.x, r.y + (r.h - 6) div 2, r.w, 6)
  let ratio = if high <= 1: 1.0 else: (value - 1.0) / (high - 1.0)
  let knobX = r.x + int(clampFloat(ratio, 0, 1) * float(r.w))
  fillRect(track, if enabled: color(224, 227, 232) else: Soft)
  if enabled:
    fillRect(rect(track.x, track.y, max(0, knobX - track.x), track.h), Accent)
  let knob = rect(knobX - 7, r.y + (r.h - 18) div 2, 14, 18)
  fillRect(knob, if enabled: Accent else: color(170, 173, 178))
  drawBorder(knob, if enabled: AccentHover else: Border)

proc formatFps(fps: float): string =
  if abs(fps - round(fps)) < 0.01: $(int(round(fps)))
  else: &"{fps:.2f}"

proc outputPathFor(inputPath: string): string =
  let parts = splitFile(inputPath)
  var candidate = parts.dir / (parts.name & "-compressed.mp4")
  var suffix = 2
  while fileExists(candidate):
    candidate = parts.dir / (parts.name & "-compressed-" & $suffix & ".mp4")
    inc suffix
  candidate

proc parseFrameRate(value: string): float =
  let parts = value.split('/')
  if parts.len == 2:
    let denominator = parseFloat(parts[1])
    if denominator != 0: return parseFloat(parts[0]) / denominator
  parseFloat(value)

proc probeVideo(path: string): tuple[duration, fps: float, error: string] =
  try:
    let raw = execProcess("ffprobe", args = ["-v", "error", "-show_entries",
      "format=duration:stream=codec_type,avg_frame_rate", "-of", "json", path],
      options = {poUsePath, poStdErrToStdOut, poDaemon})
    let doc = parseJson(raw)
    if not doc.hasKey("format") or not doc["format"].hasKey("duration"):
      return (0.0, 0.0, "動画の長さを取得できませんでした。")
    let duration = parseFloat(doc["format"]["duration"].getStr())
    if duration <= 0: return (0.0, 0.0, "動画の長さが不正です。")
    var fps = 30.0
    if doc.hasKey("streams"):
      for stream in doc["streams"]:
        if stream.hasKey("codec_type") and stream["codec_type"].getStr() == "video" and
           stream.hasKey("avg_frame_rate"):
          fps = parseFrameRate(stream["avg_frame_rate"].getStr())
          break
    if fps <= 0 or fps > 1000: fps = 30.0
    (duration, fps, "")
  except CatchableError as error:
    (0.0, 0.0, "ffprobeエラー: " & error.msg)

proc chooseVideoFile(): string =
  when defined(windows):
    const script = "Add-Type -AssemblyName System.Windows.Forms; " &
      "$d=New-Object System.Windows.Forms.OpenFileDialog; " &
      "$d.Title='動画を選択'; " &
      "$d.Filter='Video files|*.mp4;*.mov;*.mkv;*.webm;*.avi;*.m4v;*.wmv|All files|*.*'; " &
      "if($d.ShowDialog() -eq 'OK'){[Console]::OutputEncoding=[Text.Encoding]::UTF8;$d.FileName}"
    try:
      result = execProcess("powershell.exe", args = ["-NoProfile", "-STA", "-Command", script],
        options = {poUsePath, poStdErrToStdOut, poDaemon}).strip()
    except CatchableError:
      result = ""
  elif defined(macosx):
    try:
      result = execProcess("osascript", args = ["-e", "POSIX path of (choose file with prompt \"動画を選択\")"],
        options = {poUsePath, poStdErrToStdOut}).strip()
    except CatchableError:
      result = ""
  else:
    try:
      result = execProcess("zenity", args = ["--file-selection", "--title=動画を選択",
        "--file-filter=Video | *.mp4 *.mov *.mkv *.webm *.avi *.m4v *.wmv"],
        options = {poUsePath, poStdErrToStdOut}).strip()
    except CatchableError:
      result = ""

proc revealInFileManager(path: string) =
  if path.len == 0: return
  try:
    when defined(windows):
      discard startProcess("explorer.exe", args = ["/select,", path], options = {poUsePath, poDaemon})
    elif defined(macosx):
      discard startProcess("open", args = ["-R", path], options = {poUsePath, poDaemon})
    else:
      discard startProcess("xdg-open", args = [parentDir(path)], options = {poUsePath, poDaemon})
  except CatchableError:
    discard

proc sendUpdate(kind: UpdateKind; progress: float; message: string;
                outputPath = ""; outputBytes: int64 = 0) =
  updates.send WorkerUpdate(kind: kind, progress: progress, message: message,
    outputPath: outputPath, outputBytes: outputBytes)

proc encodingSettings(duration: float; targetMb: int; audioEnabled: bool;
                      factor: float):
    tuple[videoKbps, audioKbps, maxHeight: int] =
  let totalKbps = (float(targetMb) * 1024.0 * 1024.0 * 8.0 / duration / 1000.0) * 0.94 * factor
  result.audioKbps =
    if not audioEnabled: 0
    elif totalKbps >= 900: 128
    elif totalKbps >= 500: 96
    else: 64
  result.videoKbps = int(floor(totalKbps - float(result.audioKbps)))
  result.maxHeight =
    if result.videoKbps < 350: 360
    elif result.videoKbps < 750: 480
    elif result.videoKbps < 1600: 720
    else: 1080

proc runFfmpeg(job: Job; factor: float): tuple[exitCode: int, cancelled: bool] =
  let settings = encodingSettings(job.duration, job.targetMb, job.audioEnabled, factor)
  if settings.videoKbps < 120: return (-2, false)
  let maxWidth = settings.maxHeight * 16 div 9
  let scale = &"scale=w='min(iw,{maxWidth})':h='min(ih,{settings.maxHeight})':force_original_aspect_ratio=decrease:force_divisible_by=2"
  let filters = &"fps={job.targetFps:.3f}," & scale
  var args = @["-y", "-nostdin", "-i", job.inputPath, "-map", "0:v:0"]
  if job.audioEnabled:
    args.add ["-map", "0:a:0?"]
  else:
    args.add "-an"
  args.add ["-vf", filters, "-c:v", "libx264", "-preset", "medium",
    "-b:v", $settings.videoKbps & "k", "-maxrate", $settings.videoKbps & "k",
    "-bufsize", $(settings.videoKbps * 2) & "k", "-pix_fmt", "yuv420p"]
  if job.audioEnabled:
    args.add ["-c:a", "aac", "-b:a", $settings.audioKbps & "k"]
  args.add ["-movflags", "+faststart", "-progress", "pipe:1", "-nostats", job.outputPath]
  var process: Process
  try:
    process = startProcess("ffmpeg", args = args,
      options = {poUsePath, poStdErrToStdOut, poDaemon})
    let output = process.outputStream
    var line = ""
    while output.readLine(line):
      if cancelRequested.load():
        process.terminate()
        discard process.waitForExit()
        process.close()
        return (-1, true)
      if line.startsWith("out_time_us=") or line.startsWith("out_time_ms="):
        try:
          let micros = parseFloat(line.split('=', 1)[1])
          sendUpdate(ProgressUpdate, clampFloat(micros / 1_000_000.0 / job.duration, 0.0, 0.98),
            "動画を圧縮しています")
        except ValueError:
          discard
    result.exitCode = process.waitForExit()
    process.close()
  except CatchableError:
    if process != nil:
      try: process.close()
      except CatchableError: discard
    result.exitCode = -1

proc compressWorker(job: Job) {.thread.} =
  let limitBytes = int64(job.targetMb) * 1024'i64 * 1024'i64
  var factor = 1.0
  for attempt in 0 .. 2:
    if cancelRequested.load():
      sendUpdate(CancelledUpdate, 0, "キャンセルしました")
      return
    if attempt > 0:
      sendUpdate(ProgressUpdate, 0.02, &"サイズを再調整しています ({attempt + 1}/3)")
    let run = runFfmpeg(job, factor)
    if run.cancelled:
      if fileExists(job.outputPath): removeFile(job.outputPath)
      sendUpdate(CancelledUpdate, 0, "キャンセルしました")
      return
    if run.exitCode == -2:
      sendUpdate(FailedUpdate, 0, "この長さに対して目標サイズが小さすぎます")
      return
    if run.exitCode != 0 or not fileExists(job.outputPath):
      sendUpdate(FailedUpdate, 0, "ffmpegでの圧縮に失敗しました")
      return
    let actualBytes = getFileSize(job.outputPath)
    if actualBytes <= limitBytes:
      sendUpdate(CompletedUpdate, 1, "圧縮が完了しました", job.outputPath, actualBytes)
      return
    factor *= max(0.4, (float(limitBytes) / float(actualBytes)) * 0.94)
  if fileExists(job.outputPath): removeFile(job.outputPath)
  sendUpdate(FailedUpdate, 0, "指定サイズ以下にできませんでした。目標MBを増やしてください")

proc computeRects(width, height: int): UiRects =
  let contentW = min(930, width - 64)
  let left = (width - contentW) div 2
  let right = left + contentW
  result.selectFile = rect(left + 24, 92, 150, 42)
  result.openOutput = rect(right - 172, 92, 148, 42)
  result.targetSlider = rect(left + 24, 239, contentW - 230, 28)
  result.fpsSlider = rect(left + 24, 321, contentW - 210, 28)
  result.audioToggle = rect(right - 150, 371, 126, 38)
  let presetX = right - 172
  result.preset20 = rect(presetX, 229, 70, 36)
  result.preset50 = rect(presetX + 78, 229, 70, 36)
  result.compress = rect(left + 24, height - 72, contentW - 48, 50)
  result.cancel = rect(right - 144, 523, 120, 34)

proc startJob(state: var AppState; worker: var Thread[Job]) =
  if state.inputPath.len == 0 or state.busy: return
  let settings = encodingSettings(state.duration, state.targetMb, state.audioEnabled, 1.0)
  if settings.videoKbps < 120:
    state.status = "目標サイズが小さすぎます"
    return
  state.outputPath = outputPathFor(state.inputPath)
  state.busy = true
  state.completed = false
  state.progress = 0
  state.status = "ffmpegを開始しています"
  cancelRequested.store(false)
  createThread(worker, compressWorker, Job(inputPath: state.inputPath,
    outputPath: state.outputPath, duration: state.duration, targetMb: state.targetMb,
    audioEnabled: state.audioEnabled, targetFps: state.targetFps))

proc loadVideo(state: var AppState; path: string) =
  if path.len == 0: return
  if not fileExists(path):
    state.status = "ファイルを開けませんでした"
    return
  let probe = probeVideo(path)
  if probe.error.len > 0:
    state.status = probe.error
    return
  state.inputPath = path
  state.outputPath = ""
  state.inputBytes = getFileSize(path)
  state.duration = probe.duration
  state.sourceFps = probe.fps
  state.targetFps = probe.fps
  state.completed = false
  state.progress = 0
  state.status = "目標サイズを設定してください"

proc selectFile(state: var AppState) =
  let path = chooseVideoFile()
  if path.len > 0:
    state.loadVideo(path)

proc handleClick(state: var AppState; ui: UiRects; x, y: int;
                 worker: var Thread[Job]; drag: var DragTarget) =
  let p = point(x, y)
  if ui.selectFile.contains(p) and not state.busy:
    state.selectFile()
  elif ui.openOutput.contains(p) and state.completed:
    revealInFileManager(state.outputPath)
  elif ui.compress.contains(p) and state.inputPath.len > 0 and not state.busy:
    state.startJob(worker)
  elif ui.cancel.contains(p) and state.busy:
    cancelRequested.store(true)
    state.status = "キャンセルしています"
  elif not state.busy:
    if ui.targetSlider.contains(p):
      state.targetMb = sliderValue(x, ui.targetSlider, 1, 500, 1)
      drag = TargetSizeDrag
    elif ui.fpsSlider.contains(p) and state.inputPath.len > 0:
      state.targetFps = fpsFromSlider(x, ui.fpsSlider, state.sourceFps)
      drag = FrameRateDrag
    elif ui.audioToggle.contains(p): state.audioEnabled = not state.audioEnabled
    elif ui.preset20.contains(p): state.targetMb = 20
    elif ui.preset50.contains(p): state.targetMb = 50
    state.targetMb = clamp(state.targetMb, 1, 500)
    state.completed = false

proc handleDrag(state: var AppState; ui: UiRects; x: int; drag: DragTarget) =
  if state.busy: return
  if drag == TargetSizeDrag:
    state.targetMb = sliderValue(x, ui.targetSlider, 1, 500, 1)
    state.completed = false
  elif drag == FrameRateDrag and state.inputPath.len > 0:
    state.targetFps = fpsFromSlider(x, ui.fpsSlider, state.sourceFps)
    state.completed = false

proc drawUi(state: AppState; ui: UiRects; width, height: int;
            font, titleFont: Font; fm, titleFm: FontMetrics) =
  let contentW = min(930, width - 64)
  let left = (width - contentW) div 2
  fillRect(rect(0, 0, width, height), Bg)
  fillRect(rect(0, 0, width, 52), Paper)
  drawLine(0, 51, width, 51, Border)
  discard drawText(titleFont, left, (52 - titleFm.lineHeight) div 2,
    AppTitle, Ink, Paper)
  let readyText = state.ffmpegVersion
  let readyColor = if state.ffmpegReady: Success else: Danger
  let readyWidth = measureText(font, readyText).w
  discard drawText(font, left + contentW - readyWidth,
    (52 - fm.lineHeight) div 2, readyText, readyColor, Paper)

  let fileCard = rect(left, 72, contentW, 82)
  fillRect(fileCard, Paper)
  drawBorder(fileCard, Border)
  drawButton(font, fm, ui.selectFile, "動画を選択", state.mouseX, state.mouseY,
    enabled = not state.busy, primary = true)
  drawButton(font, fm, ui.openOutput, "出力場所を開く", state.mouseX, state.mouseY,
    enabled = state.completed)
  if state.inputPath.len > 0:
    let infoLeft = left + 190
    let infoWidth = contentW - 380
    let filename = fitMiddle(font, extractFilename(state.inputPath), infoWidth)
    discard drawText(font, infoLeft, 87, filename, Ink, Paper)
    discard drawText(font, infoLeft, 115,
      "元サイズ " & formatBytes(state.inputBytes) & "  ・  長さ " & formatTime(state.duration),
      Muted, Paper)
  else:
    discard drawText(font, left + 190, 103, "MP4 / MOV / MKV / WebM など", Muted, Paper)

  let sizeCard = rect(left, 174, contentW, 250)
  fillRect(sizeCard, Paper)
  drawBorder(sizeCard, Border)
  discard drawText(titleFont, left + 24, 190, "目標サイズ", Ink, Paper)
  let sizeLabelWidth = measureText(titleFont, "目標サイズ").w
  discard drawText(titleFont, left + 24 + sizeLabelWidth + 18, 190,
    $state.targetMb & " MB 以下", Accent, Paper)
  drawSlider(ui.targetSlider, state.targetMb, 1, 500, not state.busy)
  for item in [(ui.preset20, 20), (ui.preset50, 50)]:
    drawButton(font, fm, item[0], $item[1] & " MB", state.mouseX, state.mouseY,
      not state.busy, selected = state.targetMb == item[1])
  let fpsText =
    if state.inputPath.len > 0:
      formatFps(state.targetFps) & " fps（元: " & formatFps(state.sourceFps) & "）"
    else: "動画選択後に設定できます"
  discard drawText(font, left + 24, 291, "フレームレート  " & fpsText, Ink, Paper)
  drawFpsSlider(ui.fpsSlider, state.targetFps, state.sourceFps,
    state.inputPath.len > 0 and not state.busy)
  discard drawText(font, left + 24, 375, "音声を含める", Ink, Paper)
  discard drawText(font, left + 24, 398,
    "オフにすると映像だけのMP4を作成します", Muted, Paper)
  drawButton(font, fm, ui.audioToggle,
    if state.audioEnabled: "音声あり" else: "音声なし",
    state.mouseX, state.mouseY, not state.busy, selected = state.audioEnabled)

  discard drawText(font, left + 2, 447, state.status, if state.completed: Success else: Muted, Bg)
  if state.busy:
    let progressBg = rect(left, 477, contentW, 8)
    fillRect(progressBg, Border)
    fillRect(rect(progressBg.x, progressBg.y, int(float(progressBg.w) * state.progress), progressBg.h), Accent)
    discard drawText(font, left + contentW - 42, 493, $(int(state.progress * 100)) & "%", Muted, Bg)
    drawButton(font, fm, ui.cancel, "キャンセル", state.mouseX, state.mouseY)
  else:
    let label = if state.completed: "もう一度圧縮する" else: "この設定で圧縮する"
    drawButton(titleFont, titleFm, ui.compress, label, state.mouseX, state.mouseY,
      enabled = state.inputPath.len > 0 and state.ffmpegReady, primary = true)

proc main =
  let win = createWindow(920, 620)
  var width = max(MinWindowWidth, win.width)
  var height = max(MinWindowHeight, win.height)
  var fm, titleFm: FontMetrics
  let font = openFont(UiFontPath, win.scaled(14), fm)
  let titleFont = openFont(UiFontPath, win.scaled(20), titleFm, {FontStyle.bold})
  setWindowTitle(AppTitle)
  updates.open()
  cancelRequested.store(false)

  let ffmpegReady = findExe("ffmpeg").len > 0 and findExe("ffprobe").len > 0
  var state = AppState(targetMb: 20, audioEnabled: true,
    ffmpegReady: ffmpegReady, ffmpegVersion: detectFfmpegVersion(),
    status: "動画を選択してください")
  if not state.ffmpegReady:
    state.status = "ffmpeg と ffprobe をPATHに追加してください"
  else:
    let args = commandLineParams()
    if args.len > 0:
      state.loadVideo(absolutePath(args[0]))
  var worker: Thread[Job]
  var workerStarted = false
  var drag = NoDrag
  var running = true

  while running:
    var received = updates.tryRecv()
    while received.dataAvailable:
      let update = received.msg
      state.progress = update.progress
      state.status = update.message
      case update.kind
      of ProgressUpdate: discard
      of CompletedUpdate:
        state.busy = false
        state.completed = true
        state.outputPath = update.outputPath
        state.status = "完了: " & formatBytes(update.outputBytes) & "  →  " & extractFilename(update.outputPath)
      of FailedUpdate, CancelledUpdate:
        state.busy = false
        state.completed = false
      if update.kind != ProgressUpdate and workerStarted:
        joinThread(worker)
        workerStarted = false
      received = updates.tryRecv()

    let ui = computeRects(width, height)
    if drag != NoDrag and not leftMouseIsDown():
      drag = NoDrag
    var event = default Event
    while pollEvent(event):
      case event.kind
      of QuitEvent, WindowCloseEvent:
        running = false
      of WindowResizeEvent, WindowMetricsEvent:
        width = max(MinWindowWidth, event.x)
        height = max(MinWindowHeight, event.y)
      of MouseMoveEvent:
        state.mouseX = event.x
        state.mouseY = event.y
        state.handleDrag(ui, event.x, drag)
      of MouseDownEvent:
        state.mouseX = event.x
        state.mouseY = event.y
        let wasBusy = state.busy
        state.handleClick(ui, event.x, event.y, worker, drag)
        if not wasBusy and state.busy: workerStarted = true
      of MouseUpEvent:
        drag = NoDrag
      of WindowFocusLostEvent:
        drag = NoDrag
      of KeyDownEvent:
        if event.key == KeyEsc:
          if state.busy: cancelRequested.store(true)
          else: running = false
        elif event.key == KeyO and CtrlPressed in event.mods and not state.busy:
          state.selectFile()
      else:
        discard

    let pointer = point(state.mouseX, state.mouseY)
    if ui.selectFile.contains(pointer) or ui.openOutput.contains(pointer) or
       ui.compress.contains(pointer) or ui.cancel.contains(pointer) or
       ui.targetSlider.contains(pointer) or ui.fpsSlider.contains(pointer) or
       ui.audioToggle.contains(pointer) or ui.preset20.contains(pointer) or
       ui.preset50.contains(pointer):
      setCursor(curHand)
    else:
      setCursor(curArrow)
    drawUi(state, ui, width, height, font, titleFont, fm, titleFm)
    refresh()
    os.sleep(16)

  if state.busy:
    cancelRequested.store(true)
  if workerStarted:
    joinThread(worker)
  updates.close()
  closeFont(titleFont)
  closeFont(font)
  shutdown()

main()
