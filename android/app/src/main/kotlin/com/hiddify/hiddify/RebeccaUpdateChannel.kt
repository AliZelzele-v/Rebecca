package com.hiddify.hiddify

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

/** Self-distributed updates still use Android's installer and its user approval. */
class RebeccaUpdateChannel(private val activity: MainActivity) {
    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "app.rebecca.vpn/updates")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "installedApk" -> result.success(mapOf(
                            "path" to activity.applicationInfo.sourceDir,
                            "abis" to Build.SUPPORTED_ABIS.toList(),
                            "cache" to File(activity.cacheDir, "updates").apply { mkdirs() }.path
                        ))
                        "install" -> {
                            val root = File(activity.cacheDir, "updates").canonicalFile
                            val file = File(call.argument<String>("path") ?: "").canonicalFile
                            require(file.parentFile == root && file.isFile && file.extension == "apk") { "Invalid update file" }
                            @Suppress("DEPRECATION")
                            val flag = if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES
                            val update = activity.packageManager.getPackageArchiveInfo(file.path, flag)
                                ?: error("Invalid APK")
                            val installed = activity.packageManager.getPackageInfo(activity.packageName, flag)
                            require(update.packageName == activity.packageName) { "Wrong package" }
                            @Suppress("DEPRECATION")
                            val updateCode = if (Build.VERSION.SDK_INT >= 28) update.longVersionCode else update.versionCode.toLong()
                            @Suppress("DEPRECATION")
                            val installedCode = if (Build.VERSION.SDK_INT >= 28) installed.longVersionCode else installed.versionCode.toLong()
                            require(updateCode > installedCode) { "Update is not newer" }
                            @Suppress("DEPRECATION")
                            val oldSigners = if (Build.VERSION.SDK_INT >= 28) installed.signingInfo?.apkContentsSigners else installed.signatures
                            @Suppress("DEPRECATION")
                            val newSigners = if (Build.VERSION.SDK_INT >= 28) update.signingInfo?.apkContentsSigners else update.signatures
                            fun fingerprints(signers: Array<android.content.pm.Signature>?) = signers?.map {
                                MessageDigest.getInstance("SHA-256").digest(it.toByteArray()).joinToString("") { b -> "%02x".format(b) }
                            }?.toSet()
                            require(!fingerprints(oldSigners).isNullOrEmpty() && fingerprints(oldSigners) == fingerprints(newSigners)) { "SIGNATURE_MISMATCH" }
                            if (Build.VERSION.SDK_INT >= 26 && !activity.packageManager.canRequestPackageInstalls()) {
                                activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${activity.packageName}")))
                                result.success(false)
                            } else {
                                val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.updates", file)
                                activity.startActivity(Intent(Intent.ACTION_VIEW).apply {
                                    setDataAndType(uri, "application/vnd.android.package-archive")
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                })
                                result.success(true)
                            }
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) { result.error("UPDATE_ERROR", error.message, null) }
            }
    }
}
