# =============================================
# ProGuard / R8 Rules — 精简版
# =============================================

# --- dontwarn: 缺失的optional依赖（仅抑制警告，不禁用裁剪） ---

# Flutter deferred components (Play Core) — 未使用
-dontwarn com.google.android.play.core.**

# --- keepattributes: 保留调试信息 ---
-keepattributes SourceFile,LineNumberTable
-keepattributes *Annotation*
-keepattributes EnclosingMethod

# --- keep: 仅保留R8裁剪时必须的入口点 ---

# Flutter embedding entry points
-keep class io.flutter.embedding.android.FlutterActivity
-keep class io.flutter.embedding.android.FlutterFragmentActivity
-keep class io.flutter.embedding.engine.FlutterEngine
-keep class io.flutter.plugin.common.MethodChannel { *; }
-keep class io.flutter.plugin.common.EventChannel { *; }
-keep class io.flutter.plugin.common.PluginRegistry { *; }
