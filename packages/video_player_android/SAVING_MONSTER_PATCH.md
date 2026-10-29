# Android playback compatibility patch

Vendored from Flutter video_player_android 2.9.5 (BSD license in LICENSE).
Only Android/lib runtime sources and upstream Android tests are retained.

Both ExoPlayer factories prefer MediaCodecSelector.PREFER_SOFTWARE and enable
decoder initialization fallback. This avoids the connected Huawei Android 10
phone's failing OMX.hisi.video.decoder.avc, which could not allocate buffers even
with a single player. Android's software AVC decoder can play the original
720x1280 clips without using that vendor hardware decoder. Available hardware
decoders remain fallback candidates if software initialization fails.

The Dart video_player API, assets, timing, looping and completion events are
unchanged. The app starts the loading loop first, then prepares the paused intro
in the background for immediate egg-tap playback. Only one video plays at a time.
This patch applies
only on Android; Web and iOS use their existing upstream implementations.

When updating video_player_android, retain these two ExoPlayer builder changes
and validate both videos on the affected phone before removing this override.
