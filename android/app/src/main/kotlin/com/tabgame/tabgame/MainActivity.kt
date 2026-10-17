package com.tabgame.tabgame

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** 앱 안에서 내려받은 업데이트 APK를 설치 화면에 넘길 때 쓰는 파일 공급자. */
class UpdateFileProvider : FileProvider()

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tabgame/updater")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "version" -> {
                        val info = packageManager.getPackageInfo(packageName, 0)
                        result.success(info.versionName)
                    }
                    "install" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("bad_args", "path 가 없어요", null)
                        } else {
                            result.success(installApk(File(path)))
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        // Wi‑Fi 방을 열어 두거나 다른 기기와 이어져 있는 동안 화면이 꺼지지 않게 한다 (권한이 필요 없다)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tabgame/awake")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "keepOn" -> {
                        val on = call.argument<Boolean>("on") ?: false
                        runOnUiThread {
                            if (on) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** "started": 설치 화면을 열었다 / "needPermission": '이 앱에서 설치 허용' 설정을 먼저 켜야 한다. */
    private fun installApk(file: File): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !packageManager.canRequestPackageInstalls()) {
            startActivity(
                Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            return "needPermission"
        }
        val uri = FileProvider.getUriForFile(this, "$packageName.updater", file)
        startActivity(
            Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        )
        return "started"
    }
}
