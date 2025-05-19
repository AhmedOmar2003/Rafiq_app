<?php
// تعيين رأس الاستجابة كـ JSON
header('Content-Type: application/json');

// تضمين ملف الاتصال بقاعدة البيانات
include 'db_connection.php';

if (isset($_POST['reset_token'], $_POST['new_password'])) {
    $reset_token = $_POST['reset_token'];
    $new_password = password_hash($_POST['new_password'], PASSWORD_DEFAULT);  // استخدام PASSWORD_DEFAULT بدلاً من PASSWORD_BCRYPT

    // التحقق من وجود الـ reset_token وصلاحيته
    $query = "SELECT reset_token_expiry FROM users WHERE reset_token = ? AND reset_token_expiry > NOW()";
    $stmt = $conn->prepare($query);
    $stmt->bind_param("s", $reset_token);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        // تم العثور على الرمز وصلاحيته، نكمل تحديث كلمة المرور
        $update_query = "UPDATE users SET password = ?, reset_token = NULL, reset_token_expiry = NULL WHERE reset_token = ?";
        $update_stmt = $conn->prepare($update_query);
        $update_stmt->bind_param("ss", $new_password, $reset_token);

        if ($update_stmt->execute()) {
            echo json_encode(["status" => "success", "message" => "تم تحديث كلمة المرور بنجاح."]);
        } else {
            echo json_encode(["status" => "error", "message" => "حدث خطأ أثناء تحديث كلمة المرور."]);
        }
    } else {
        echo json_encode(["status" => "error", "message" => "الرمز غير صالح أو انتهت صلاحيته."]);
    }
} else {
    echo json_encode(["status" => "error", "message" => "البيانات مفقودة."]);
}

$conn->close();
?>