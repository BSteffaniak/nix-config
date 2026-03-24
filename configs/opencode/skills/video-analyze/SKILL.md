---
name: video-analyze
description: Extract and view frames from a video to analyze its visual content. Interactive — finds recordings, adapts frame rate to video length, and supports re-extraction at higher detail.
allowed-tools: Bash(ffmpeg:*), Bash(ffprobe:*), Bash(mkdir:*), Bash(ls:*), Bash(find:*), Bash(stat:*), Bash(python3:*), Question(*), Read(*)
---

## Purpose

Analyze video content by extracting frames and viewing them as images. The skill locates a video file — either from a user-specified path or by finding the most recent screen recording — extracts frames at an adaptive frame rate tuned to the video's duration, and presents them for visual inspection. When more detail is needed for a specific segment, frames can be re-extracted at a higher frame rate or for a narrower time range. Designed to work seamlessly within an existing conversation without unnecessary interruptions.

## Prerequisites

- **ffmpeg** and **ffprobe** must be available on `$PATH`.
- If they are not installed but `nix` is available, use `nix shell` to make them available:
  ```bash
  # Check availability
  command -v ffmpeg || command -v nix
  ```
  If ffmpeg is missing but nix is present, prefix all ffmpeg/ffprobe commands with:
  ```bash
  nix shell nixpkgs#ffmpeg -c <command>
  ```
- The Read tool must support image files (PNG) for displaying extracted frames.

## Steps

### 1. Locate the video

Parse the user's request to determine the video source. There are three modes:

#### Explicit path

If the user provides a file path, use it directly. Verify it exists:

```bash
ls -la "/path/to/video.mp4"
```

#### Tool/source hint

If the user mentions a recording tool or source (e.g., "latest screen recording", "latest obs"), map it to search directories:

| Hint                                        | macOS paths                            | Linux paths             |
| ------------------------------------------- | -------------------------------------- | ----------------------- |
| Default / "screen recording" / "screenshot" | `~/Desktop`, `~/Movies`                | `~/Videos`              |
| "quicktime"                                 | `~/Desktop`, `~/Movies`, `~/Documents` | —                       |
| "obs"                                       | `~/Movies`                             | `~/Videos`              |
| Generic / no hint                           | `~/Desktop`, `~/Movies`, `~/Documents` | `~/Videos`, `~/Desktop` |

Search for the most recent video file in the resolved directories:

```bash
find ~/Desktop ~/Movies -maxdepth 2 \
  \( -name "*.mov" -o -name "*.mp4" -o -name "*.mkv" -o -name "*.webm" -o -name "*.avi" \) \
  -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -5
```

On macOS where `find -printf` is unavailable, use:

```bash
find ~/Desktop ~/Movies -maxdepth 2 \
  \( -name "*.mov" -o -name "*.mp4" -o -name "*.mkv" -o -name "*.webm" -o -name "*.avi" \) \
  -type f -exec stat -f '%m %N' {} + 2>/dev/null | sort -rn | head -5
```

#### Disambiguation

- If exactly **one** candidate is found, use it without asking.
- If **multiple** candidates are found, present the top 5 by modification time using the Question tool and let the user pick.
- If **no** candidates are found, ask the user for an explicit path.

#### Time range parsing

If the user specifies a time range (e.g., "first 10 seconds", "from 1:30 to 2:00", "last 30 seconds"), parse it and store for use in Step 4. Use `python3` for robust parsing:

```bash
python3 -c "
# Parse natural language time ranges into ffmpeg -ss and -t values
# Examples:
#   'first 10 seconds' -> ss=0, t=10
#   'from 1:30 to 2:00' -> ss=90, t=30
#   'last 30 seconds' -> requires video duration, ss=duration-30, t=30
"
```

### 2. Probe video metadata

Get the video's duration, native frame rate, resolution, and codec using `ffprobe`:

```bash
ffprobe -v quiet -print_format json -show_format -show_streams "/path/to/video.mp4"
```

Extract the key values:

```bash
# Duration in seconds (float)
ffprobe -v quiet -show_entries format=duration -of csv=p=0 "/path/to/video.mp4"

# Native FPS (as a fraction, e.g., "30/1")
ffprobe -v quiet -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "/path/to/video.mp4"

# Resolution
ffprobe -v quiet -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "/path/to/video.mp4"
```

Report the metadata to the user concisely:

```
Video: recording-2026-03-24.mov
Duration: 45.2s | FPS: 30 | Resolution: 1920x1080 | Codec: h264
```

If the user specified "last N seconds" in their time range, the duration is needed to compute the start offset — calculate it here.

### 3. Calculate initial frame rate

Choose an extraction frame rate based on the **effective duration** — the time range being extracted (which may be the full video or a user-specified segment):

| Effective duration     | Extraction FPS           |
| ---------------------- | ------------------------ |
| < 1 second             | Native FPS (every frame) |
| 1–5 seconds            | 10 fps                   |
| 5–30 seconds           | 5 fps                    |
| 30 seconds – 2 minutes | 3 fps                    |
| 2–10 minutes           | 2 fps                    |
| > 10 minutes           | 1 fps                    |

**Constraints:**

- **Floor**: Never go below 1 fps.
- **Ceiling**: Never exceed the video's native fps.
- **Frame count sanity check**: If the calculated fps would produce more than 200 frames, reduce fps until the frame count is ≤ 200. This prevents overwhelming the context with too many images on the initial pass.

Use `python3` for the calculation:

```bash
python3 -c "
import math
duration = 45.2  # effective duration in seconds
native_fps = 30

if duration < 1:
    fps = native_fps
elif duration <= 5:
    fps = 10
elif duration <= 30:
    fps = 5
elif duration <= 120:
    fps = 3
elif duration <= 600:
    fps = 2
else:
    fps = 1

fps = min(fps, native_fps)
frame_count = math.ceil(duration * fps)

# Reduce fps if too many frames
while frame_count > 200 and fps > 1:
    fps = max(1, fps - 1)
    frame_count = math.ceil(duration * fps)

print(f'{fps} {frame_count}')
"
```

Report the plan:

```
Extracting at 5 fps → ~226 frames... reducing to 4 fps → ~181 frames
```

### 4. Extract frames

Create a temporary directory for the frames:

```bash
HASH=$(python3 -c "import hashlib; print(hashlib.md5(b'/path/to/video.mp4').hexdigest()[:8])")
mkdir -p "/tmp/video-analyze-$HASH"
```

The directory name format is: `/tmp/video-analyze-<hash>/`

If the directory already exists and contains frames from a previous extraction, note this and offer to reuse them if the video file hasn't changed. Otherwise, clear the directory first.

#### Full video extraction

```bash
ffmpeg -i "/path/to/video.mp4" -vf "fps=5" -q:v 2 /tmp/video-analyze-abcd1234/frame_%04d.png
```

#### Time range extraction

```bash
# Extract from 1:30 for 30 seconds at 5 fps
ffmpeg -ss 90 -i "/path/to/video.mp4" -t 30 -vf "fps=5" -q:v 2 /tmp/video-analyze-abcd1234/frame_%04d.png
```

#### Flags explained

- `-vf "fps=N"` — Extract at N frames per second
- `-q:v 2` — High quality PNG output
- `-ss` — Start time in seconds
- `-t` — Duration in seconds
- `frame_%04d.png` — Sequential numbered output

After extraction, count the frames:

```bash
ls /tmp/video-analyze-abcd1234/frame_*.png | wc -l
```

Report:

```
Extracted 181 frames to /tmp/video-analyze-abcd1234/
Covering 0:00 – 0:45.2 at 4 fps
```

### 5. Present frames

Use the Read tool to display extracted frame images. Adapt the presentation strategy to the number of frames:

#### Few frames (≤ 20)

Show all frames at once. Read each PNG file:

```
Read frame_0001.png through frame_0020.png
```

#### Moderate frames (21–50)

Show in batches of ~15 frames. After each batch, briefly describe what's visible and continue to the next batch. No need to ask — just proceed through all batches.

#### Many frames (> 50)

Show a representative sample to avoid context overload:

1. First ~10 frames (beginning of video)
2. ~10 evenly spaced frames from the middle
3. Last ~10 frames (end of video)

After showing the sample, note which frames were shown and which were skipped:

```
Showed 30 of 181 frames (sampled). Frames cover 0:00–0:45.
To see a specific segment in detail, ask for a time range (e.g., "show me 0:10 to 0:20").
```

#### Presentation format

For each frame or batch, note the approximate timestamp:

```
Frame 15 (~3.0s):
[Read frame_0015.png]
```

Use `python3` to calculate timestamps from frame numbers:

```bash
python3 -c "
frame_num = 15
fps = 5
timestamp = (frame_num - 1) / fps
minutes = int(timestamp // 60)
seconds = timestamp % 60
print(f'{minutes}:{seconds:05.2f}')
"
```

### 6. Analyze and optionally re-extract

After presenting frames, the user can:

#### Ask questions about the video content

Answer based on what's visible in the extracted frames. Reference specific frames and timestamps when describing visual content.

#### Request higher detail for a time range

If the user wants to see a specific segment more closely:

1. Parse the requested time range
2. Recalculate fps using the duration tiers from Step 3, but applied to the **segment duration** (shorter segments get higher fps)
3. Clear the temp directory (or create a subdirectory like `/tmp/video-analyze-<hash>/detail/`)
4. Re-extract frames for just that segment
5. Present all re-extracted frames (the segment is short, so frame count should be manageable)

```bash
# Example: re-extract 0:10 to 0:15 at 10 fps
ffmpeg -ss 10 -i "/path/to/video.mp4" -t 5 -vf "fps=10" -q:v 2 /tmp/video-analyze-abcd1234/detail/frame_%04d.png
```

#### Request full re-extract at higher fps

If the user wants the entire video at higher detail:

1. Warn if this will produce a large number of frames (> 100)
2. Use the Question tool to confirm if > 200 frames would be generated
3. Clear and re-extract at the requested fps
4. Present using the same adaptive strategy from Step 5

#### This step loops

Continue responding to questions and re-extraction requests until the user moves on to other work. The skill does not need an explicit "done" signal — it integrates naturally into the conversation flow.

## Rules

- **Minimize interruptions.** Only use the Question tool when genuinely ambiguous (multiple video candidates, confirmation for large re-extractions). If the user's intent is clear, proceed directly. This skill should integrate into an existing conversation without breaking flow.
- **Never exceed native fps.** Do not extract more frames per second than the video actually has. Cap extraction fps at the native frame rate.
- **Frame count awareness.** Be mindful of how many frames are being sent through the Read tool. More than 200 frames in a single pass will degrade context quality. Use sampling and batching to stay within reasonable limits.
- **Cross-platform commands.** Use `python3` for hashing, date math, and timestamp calculations. Use platform-appropriate `find` and `stat` flags — detect the OS and choose the right variant. Never use macOS-only or GNU-only commands without a fallback.
- **No hardcoded paths.** Derive search directories from the tool/source hint and the OS. Never hardcode user-specific directory paths.
- **Temp directory hygiene.** Always report the temp directory path so the user knows where frames are stored. Do not auto-delete the directory — the user may want to reference the frames later. Reuse existing frames when the video file hasn't changed.
- **Time ranges are natural language.** Accept human-friendly time specifications ("first 10 seconds", "from 1:30 to 2:00", "the part where the error appears around 0:45") and convert them to precise ffmpeg flags. When a description is vague ("around 0:45"), add padding (e.g., ±5 seconds).
- **Nix fallback for ffmpeg.** If ffmpeg/ffprobe are not on `$PATH` but `nix` is available, transparently prefix commands with `nix shell nixpkgs#ffmpeg -c`. Check once at the start and apply consistently.
- **Report what you see.** When describing frame content, be specific and reference frame numbers and timestamps. Do not fabricate details that aren't visible in the frames.
