<?php
header('Content-Type: application/json');

// تضمين ملف الاتصال بقاعدة البيانات
include 'db_connection.php';

// التحقق من البيانات المطلوبة
if (isset($_POST['email'], $_POST['new_password'], $_POST['otp_code'])) {
    $email = $_POST['email'];
    $new_password = $_POST['new_password'];
    $otp_code = $_POST['otp_code'];

    // التحقق من القيم الفارغة
    if (empty($email) || empty($new_password) || empty($otp_code)) {
        echo json_encode(["status" => "error", "message" => "البيانات غير مكتملة."]);
        exit;
    }

    // تشفير كلمة المرور
    $hashed_password = password_hash($new_password, PASSWORD_DEFAULT);

    // التحقق من صلاحية الرمز ووجود المستخدم
    $query = "SELECT * FROM users WHERE email = ? AND reset_token = ? AND reset_token_expiry > NOW()";
    $stmt = $conn->prepare($query);
    $stmt->bind_param("ss", $email, $otp_code);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        // المستخدم موجود والرمز صالح
        $update_query = "UPDATE users SET password = ?, reset_token = NULL, reset_token_expiry = NULL WHERE email = ?";
        $update_stmt = $conn->prepare($update_query);
        $update_stmt->bind_param("ss", $hashed_password, $email);

        if ($update_stmt->execute()) {
            echo json_encode(["status" => "success", "message" => "تم تغيير كلمة المرور بنجاح."]);
        } else {
            echo json_encode(["status" => "error", "message" => "فشل في تحديث كلمة المرور."]);
        }
    } else {
        echo json_encode(["status" => "error", "message" => "رمز OTP غير صالح أو منتهي الصلاحية."]);
    }

    $stmt->close();
} else {
    echo json_encode(["status" => "error", "message" => "المدخلات غير مكتملة."]);
}

$conn->close();
?>