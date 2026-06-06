# auto-convert 🎧

**Automated audio file converter.** Drop files in a folder, get converted audio back automatically. Zero configuration needed, infinitely customizable.

[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![Alpine Linux](https://img.shields.io/badge/Alpine_Linux-%230D597F.svg?style=for-the-badge&logo=alpine-linux&logoColor=white)](https://alpinelinux.org/)

## 🚀 Quick Start

```bash
# Clone the repo
git clone https://github.com/s33g/auto-convert.git
cd auto-convert

# Create your music directory
mkdir -p music

# Start the converter
docker compose up -d

# Drop FLAC files into ./music, get AIFF files back automatically!
```

That's it. The container watches `./music` and converts FLAC → AIFF by default.

## 📋 What It Does

- **Watches** directories for new audio files
- **Converts** to DJ-friendly formats automatically
- **Preserves** all metadata (tags, album art, BPM, key, cue points)
- **Processes** existing files on startup (optional)
- **Handles** large files safely (waits for complete write)
- **Logs** everything or nothing (your choice)

Perfect for:
- 🎛️ Preparing music for DJ equipment (Pioneer CDJs, Denon, controllers)
- 💿 Batch converting your music library overnight
- 📁 Automatically processing downloads folder
- 🔄 Converting any audio format to any other format
- 🎵 Maintaining multiple format libraries simultaneously

## 🎯 Default: FLAC → AIFF

The default configuration converts **FLAC → AIFF** (44.1kHz, 16-bit) because:
- Pioneer CDJs and many DJ controllers prefer AIFF for instant loading
- Uncompressed formats eliminate playback delays on performance hardware
- Maximum compatibility with Rekordbox, Serato, Traktor

**But you can convert anything to anything!** See [Custom Formats](#-custom-formats) below.

## 📖 Full Setup

### Prerequisites

- Docker & Docker Compose
- A directory with audio files

### Installation

1. **Clone this repository:**
   ```bash
   git clone https://github.com/s33g/auto-convert.git
   cd auto-convert
   ```

2. **Create configuration (optional):**
   ```bash
   cp .env.example .env
   # Edit .env to customize behavior
   ```

3. **Set your music directory:**

   Edit `docker-compose.yml`:
   ```yaml
   volumes:
     - /path/to/your/music:/watch
   ```

   Or use `.env`:
   ```bash
   MUSIC_DIR=/path/to/your/music
   ```

4. **Build and run:**
   ```bash
   docker compose up -d
   ```

5. **Check logs:**
   ```bash
   docker compose logs -f
   ```

## ⚙️ Configuration

All settings are configured via environment variables. Either:
- Edit `docker-compose.yml` directly
- Create `.env` from `.env.example`

### Directory Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `MUSIC_DIR` | `./music` | Local directory containing your music (host path) |
| `OUTPUT_DIR` | `./music` | Where to write converted files (host path) |
| `WATCH_DIR` | `/watch` | Internal container path (usually don't change) |

**Examples:**

```bash
# Convert in-place (AIFF files next to FLACs)
MUSIC_DIR=./music
OUTPUT_DIR=./music

# Separate output directory
MUSIC_DIR=./flac-library
OUTPUT_DIR=./aiff-library

# Watch network share (macOS)
MUSIC_DIR=/Volumes/NAS/Music
OUTPUT_DIR=/Volumes/NAS/Music-Converted
```

### Conversion Settings

| Variable | Default | Options | Description |
|----------|---------|---------|-------------|
| `INPUT_FORMAT` | `flac` | `flac`, `mp3`, `wav`, `m4a`, `ogg`, `opus`, etc. | File type to watch for |
| `OUTPUT_FORMAT` | `aiff` | `aiff`, `wav`, `flac`, `mp3`, etc. | Output format |
| `AUDIO_CODEC` | `pcm_s16le` | `pcm_s16le`, `pcm_s24le`, `pcm_s32le` | Audio codec |
| `SAMPLE_RATE` | `44100` | `44100`, `48000`, `96000`, `192000` | Sample rate (Hz) |
| `BIT_DEPTH` | `16` | `16`, `24`, `32` | Bit depth |

**CDJ-Optimized Defaults:**
- ✅ 44.1kHz sample rate (CD quality)
- ✅ 16-bit depth (maximum compatibility)
- ✅ Uncompressed PCM (instant loading)

### Behavior Settings

| Variable | Default | Options | Description |
|----------|---------|---------|-------------|
| `RECURSIVE` | `true` | `true`, `false` | Watch subdirectories |
| `PRESERVE_METADATA` | `true` | `true`, `false` | Keep tags, art, BPM, key |
| `DELETE_SOURCE` | `false` | `true`, `false` | Delete original after conversion ⚠️ |
| `PROCESS_EXISTING` | `true` | `true`, `false` | Convert existing files on startup |
| `FILE_STABLE_TIME` | `2` | seconds | Wait time to ensure file is complete |
| `LOG_LEVEL` | `info` | `debug`, `info`, `error` | Logging verbosity |

## 🎨 Custom Formats

### Convert MP3 → WAV
```bash
INPUT_FORMAT=mp3
OUTPUT_FORMAT=wav
AUDIO_CODEC=pcm_s16le
```

### Convert anything → High-Res FLAC
```bash
OUTPUT_FORMAT=flac
SAMPLE_RATE=96000
BIT_DEPTH=24
```

### Convert M4A → MP3
```bash
INPUT_FORMAT=m4a
OUTPUT_FORMAT=mp3
AUDIO_CODEC=libmp3lame
```

### Professional 24-bit AIFF
```bash
OUTPUT_FORMAT=aiff
AUDIO_CODEC=pcm_s24le
BIT_DEPTH=24
SAMPLE_RATE=48000
```

## 📊 Usage Examples

### Basic: Watch and Convert
```bash
docker compose up -d
# Drop FLACs in ./music
# Get AIFFs automatically
```

### Advanced: Separate Directories
```yaml
# docker-compose.yml
volumes:
  - /Volumes/Downloads:/watch
  - /Volumes/CDJ-Ready:/output

environment:
  WATCH_DIR: /watch
  OUTPUT_DIR: /output
```

### Batch Convert Existing Library
```bash
# Copy your library into ./music
cp -r ~/Music/FLAC-Library/* ./music/

# Start converter (processes existing files immediately)
docker compose up -d

# Watch progress
docker compose logs -f
```

### Dangerous: Auto-Delete Source Files
```bash
# .env
DELETE_SOURCE=true  # ⚠️ Deletes FLACs after conversion!
```

Only enable if:
- ✅ You have backups
- ✅ You're 100% certain about conversion settings
- ✅ You've tested without deletion first

### Debug Mode
```bash
LOG_LEVEL=debug
docker compose up
# See every file operation
```

## 🔍 Monitoring

### View Logs
```bash
# Follow logs in real-time
docker compose logs -f

# Last 100 lines
docker compose logs --tail=100

# Errors only
docker compose logs | grep ERROR
```

### Check Health
```bash
docker compose ps
# Shows health status
```

### Stop Converter
```bash
docker compose down
# Gracefully shuts down (waits for current conversion)
```

## 🐛 Troubleshooting

### Files Aren't Converting

**Check the container is running:**
```bash
docker compose ps
```

**Check logs for errors:**
```bash
docker compose logs --tail=50
```

**Verify file format matches:**
```bash
# If INPUT_FORMAT=flac, but you're dropping MP3s → won't convert
# Change INPUT_FORMAT or rename files
```

**Check permissions:**
```bash
ls -la music/
# Ensure Docker can read/write the directory
```

### Conversions Are Incomplete

**Increase stability wait time:**
```bash
FILE_STABLE_TIME=5  # Wait 5 seconds instead of 2
```

This helps with:
- Large files (>100MB)
- Network shares
- Slow disks

### Metadata Not Preserved

**Ensure preserve flag is enabled:**
```bash
PRESERVE_METADATA=true
```

**Check source file has metadata:**
```bash
ffprobe input.flac
# Should show tags, artwork, etc.
```

### Container Keeps Restarting

**Check disk space:**
```bash
df -h
```

**Check directory exists:**
```bash
ls ./music  # or your MUSIC_DIR path
```

**View crash logs:**
```bash
docker compose logs
```

### Performance Issues

**Reduce concurrent conversions:**
The script processes one file at a time by design (ensures stability). For faster batch processing:

```bash
# Process existing files disabled, manual batch instead
PROCESS_EXISTING=false

# Run multiple containers on different folders (advanced)
docker compose -f compose-folder1.yml up -d
docker compose -f compose-folder2.yml up -d
```

## 🔧 Advanced Usage

### Multiple Converters

Run different converters for different formats:

**compose-flac.yml:**
```yaml
services:
  flac-converter:
    extends:
      file: docker-compose.yml
      service: cdj-prepare
    container_name: flac-converter
    volumes:
      - ./flac:/watch
    environment:
      INPUT_FORMAT: flac
```

**compose-mp3.yml:**
```yaml
services:
  mp3-converter:
    extends:
      file: docker-compose.yml
      service: cdj-prepare
    container_name: mp3-converter
    volumes:
      - ./mp3:/watch
    environment:
      INPUT_FORMAT: mp3
```

Run both:
```bash
docker compose -f compose-flac.yml up -d
docker compose -f compose-mp3.yml up -d
```

### Network Shares

**macOS:**
```yaml
volumes:
  - /Volumes/NAS/Music:/watch
```

**Linux (NFS):**
```yaml
volumes:
  - /mnt/nfs/music:/watch
```

**Windows (WSL2):**
```yaml
volumes:
  - /mnt/c/Users/YourName/Music:/watch
```

### Custom FFmpeg Flags

Edit `watcher.sh` and modify the `ffmpeg` command around line 90:

```bash
ffmpeg -y -i "$input_file" \
    -acodec "$AUDIO_CODEC" \
    -ar "$SAMPLE_RATE" \
    -sample_fmt "s${BIT_DEPTH}" \
    -your-custom-flag value \
    $metadata_flags \
    "$temp_output"
```

Then rebuild:
```bash
docker compose build
docker compose up -d
```

## 🤝 Contributing

Contributions welcome! This is designed to be simple and foolproof. Please:

- Keep dependencies minimal (Alpine base)
- Maintain broad compatibility
- Test with various audio formats
- Update README for new features

## 📄 License

MIT License - use it however you want!

---

**Questions?** Open an issue!  
**Working well?** Star the repo! ⭐
