FROM alpine:latest

# Metadata
LABEL maintainer="s33g <dev@charlie.fyi>"
LABEL description="Automated audio file converter - watches directories and converts on the fly"
LABEL version="1.0.0"

# Install dependencies
RUN apk add --no-cache \
    ffmpeg \
    inotify-tools \
    bash \
    coreutils \
    findutils \
    && rm -rf /var/cache/apk/*

# Create app directory
WORKDIR /app

# Copy watcher script
COPY watcher.sh /app/watcher.sh
RUN chmod +x /app/watcher.sh

# Environment variables with sensible defaults
ENV WATCH_DIR=/watch \
    OUTPUT_DIR=/watch \
    INPUT_FORMAT=flac \
    OUTPUT_FORMAT=aiff \
    AUDIO_CODEC=pcm_s16le \
    SAMPLE_RATE=44100 \
    BIT_DEPTH=16 \
    RECURSIVE=true \
    PRESERVE_METADATA=true \
    DELETE_SOURCE=false \
    LOG_LEVEL=info \
    PROCESS_EXISTING=true \
    FILE_STABLE_TIME=2

# Health check - verify watcher script is running
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pgrep -f "watcher.sh" > /dev/null || exit 1

# Run the watcher
CMD ["/app/watcher.sh"]
