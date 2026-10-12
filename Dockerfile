# Hardened build: the base image is pinned by digest (music-assistant/server 2.10.6),
# and the provider's Python dependencies are pinned and hash-checked
# (requirements.lock, compiled from requirements.in against the base image's own
# packages so nothing of upstream gets upgraded). The provider installs nothing at
# runtime. To update, bump the digest and/or requirements.in, recompile the lock
# with --generate-hashes and rebuild.
FROM ghcr.io/music-assistant/server@sha256:45fdb050e06962097a07feeb092606ad119fac17965c8228a57146448d5fa772 AS runtime

LABEL org.opencontainers.image.description="Hardened local build of the upstream server image with the ytmusic_free provider."

COPY requirements.lock /tmp/requirements.lock
RUN uv pip install --python /app/venv/bin/python --no-deps --require-hashes \
        -r /tmp/requirements.lock && \
    rm /tmp/requirements.lock

COPY ytmusic_free/ /tmp/ytmusic_free
# Resolve the site-packages path via Python itself (no globbing, no
# hard-coded version fallback): if the venv Python is broken, the build
# fails here instead of silently installing to the wrong location.
RUN DST_DIR="$( /app/venv/bin/python -c 'import sysconfig; print(sysconfig.get_path("purelib"))' )/music_assistant/providers/ytmusic_free" && \
    rm -rf "$DST_DIR" && \
    mv /tmp/ytmusic_free "$DST_DIR"

# Smart Fades analyses only tracks up to 5 minutes (upstream: 30). Longer tracks
# (mixes, live sets) get a standard crossfade and cost no analysis CPU. The grep
# fails the build if upstream changes the line, so the cap never silently lapses.
RUN F="$( /app/venv/bin/python -c 'import sysconfig; print(sysconfig.get_path("purelib"))' )/music_assistant/providers/smart_fades/provider.py" && \
    sed -i 's/^    max_analysis_duration = ACCUMULATING_ANALYSIS_MAX_DURATION_SECONDS$/    max_analysis_duration = 300.0/' "$F" && \
    grep -q '^    max_analysis_duration = 300.0$' "$F"
