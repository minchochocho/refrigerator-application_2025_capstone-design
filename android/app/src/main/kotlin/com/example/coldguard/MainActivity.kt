package com.example.coldguard

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.coldguard/image_crop"
    private val CROP_REQUEST_CODE = 1001
    private var pendingResult: MethodChannel.Result? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "cropImage" -> {
                    val imagePath = call.argument<String>("imagePath")
                    val outputPath = call.argument<String>("outputPath")
                    if (imagePath != null && outputPath != null) {
                        cropImage(imagePath, outputPath, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Image path or output path is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun cropImage(imagePath: String, outputPath: String, result: MethodChannel.Result) {
        try {
            pendingResult = result
            
            val imageUri = Uri.fromFile(File(imagePath))
            val outputUri = Uri.fromFile(File(outputPath))
            
            // 1순위: 삼성 갤러리 편집 기능
            val samsungGalleryIntent = Intent().apply {
                action = Intent.ACTION_EDIT
                setDataAndType(imageUri, "image/*")
                setPackage("com.sec.android.gallery3d") // 삼성 갤러리 패키지명
                putExtra("output", outputUri)
                putExtra("outputFormat", "JPEG")
                putExtra("return-data", false)
                flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            }
            
            if (samsungGalleryIntent.resolveActivity(packageManager) != null) {
                startActivityForResult(samsungGalleryIntent, CROP_REQUEST_CODE)
                return
            }
            
            // 2순위: 구글 포토 편집 기능
            val googlePhotosIntent = Intent().apply {
                action = Intent.ACTION_EDIT
                setDataAndType(imageUri, "image/*")
                setPackage("com.google.android.apps.photos") // 구글 포토 패키지명
                putExtra("output", outputUri)
                putExtra("outputFormat", "JPEG")
                putExtra("return-data", false)
                flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            }
            
            if (googlePhotosIntent.resolveActivity(packageManager) != null) {
                startActivityForResult(googlePhotosIntent, CROP_REQUEST_CODE)
                return
            }
            
            // 3순위: 기본 크롭 인텐트
            val cropIntent = Intent("com.android.camera.action.CROP").apply {
                setDataAndType(imageUri, "image/*")
                putExtra("crop", "true")
                putExtra("aspectX", 1)
                putExtra("aspectY", 1)
                putExtra("outputX", 512)
                putExtra("outputY", 512)
                putExtra("scale", true)
                putExtra("return-data", false)
                putExtra("output", outputUri)
                putExtra("outputFormat", "JPEG")
            }
            
            if (cropIntent.resolveActivity(packageManager) != null) {
                startActivityForResult(cropIntent, CROP_REQUEST_CODE)
                return
            }
            
            // 4순위: 일반 편집 인텐트
            val editIntent = Intent(Intent.ACTION_EDIT).apply {
                setDataAndType(imageUri, "image/*")
                putExtra("output", outputUri)
                flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            }
            
            if (editIntent.resolveActivity(packageManager) != null) {
                startActivityForResult(editIntent, CROP_REQUEST_CODE)
                return
            }
            
            // 모든 방법이 실패한 경우
            result.error("NO_CROP_APP", "No image editing application available", null)
            
        } catch (e: Exception) {
            result.error("CROP_ERROR", "Failed to start edit activity: ${e.message}", null)
        }
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == CROP_REQUEST_CODE) {
            pendingResult?.let { result ->
                if (resultCode == Activity.RESULT_OK) {
                    result.success("success")
                } else {
                    result.error("CROP_CANCELLED", "Image crop was cancelled", null)
                }
                pendingResult = null
            }
        }
    }
}