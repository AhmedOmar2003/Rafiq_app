<?php
header('Content-Type: application/json');

// تضمين ملف الاتصال بقاعدة البيانات
include 'db_connection.php';

// التحقق من البيانات المرسلة
if (isset($_POST['email']) && isset($_POST['otp_code'])) {
    $email = $_POST['email'];
    $otp_code = $_POST['otp_code'];

    // البحث عن الكود المرتبط بالبريد الإلكتروني
    $stmt = $conn->prepare("SELECT reset_token, reset_token_expiry FROM users WHERE email = ?");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $stmt->store_result();
    $stmt->bind_result($stored_token, $expiry_time);
    $stmt->fetch();

    if ($stmt->num_rows > 0) {
        // التحقق من صلاحية الكود
        $current_time = date("Y-m-d H:i:s");
        if ($otp_code == $stored_token && $current_time < $expiry_time) {
            echo json_encode(["status" => "success", "message" => "OTP صحيح"]);
        } else {
            echo json_encode(["status" => "error", "message" => "OTP غير صالح أو منتهي"]);
        }
    } else {
        echo json_encode(["status" => "error", "message" => "البريد الإلكتروني غير موجود"]);
    }

    $stmt->close();
} else {
    echo json_encode(["status" => "error", "message" => "بيانات ناقصة"]);
}

$conn->close();
?>