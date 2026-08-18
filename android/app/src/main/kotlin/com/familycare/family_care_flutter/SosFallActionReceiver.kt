package com.familycare.family_care

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/// Nhận action bấm trên notification đếm ngược té ngã ("Tôi ổn" / "Gửi SOS
/// ngay"). CHỈ chuyển tiếp action cho [SosEmergencyFlowService] xử lý — không
/// mở `MainActivity`, không cần Flutter engine sống. Đây là điểm mấu chốt để
/// notification không phải là điều kiện phải "mở app" mới countdown tiếp.
class SosFallActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val serviceIntent = Intent(context, SosEmergencyFlowService::class.java).apply {
            this.action = action
        }
        context.startService(serviceIntent)
    }
}
