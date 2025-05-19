<?php
// إعداد الاستجابة كـ JSON
header('Content-Type: application/json');

// تعطيل عرض الأخطاء
error_reporting(0);
ini_set('display_errors', 0);

// تضمين ملف الاتصال بقاعدة البيانات
include 'db_connection.php';

// التحقق من البيانات المرسلة وحذف المستخدم
try {
    // التحقق من البيانات المرسلة
    if (!isset($_POST['email']) || empty($_POST['email'])) {
        throw new Exception("Invalid input");
    }

    $email = $_POST['email'];

    // حذف البيانات المرتبطة في جدول feedback
    $deleteFeedbackStmt = $conn->prepare(
        "DELETE FROM feedback WHERE user_id = (SELECT id FROM users WHERE email = ?)"
    );
    if (!$deleteFeedbackStmt) {
        throw new Exception("Failed to prepare feedback deletion statement");
    }

    $deleteFeedbackStmt->bind_param("s", $email);

    if (!$deleteFeedbackStmt->execute()) {
        throw new Exception("Failed to delete related feedback records");
    }
    $deleteFeedbackStmt->close();

    // حذف المستخدم بناءً على الإيميل
    $stmt = $conn->prepare("DELETE FROM users WHERE email = ?");
    if (!$stmt) {
        throw new Exception("Failed to prepare user deletion statement");
    }

    $stmt->bind_param("s", $email);

    if ($stmt->execute()) {
        if ($stmt->affected_rows > 0) {
            echo json_encode(["status" => "success", "message" => "User deleted successfully"]);
        } else {
            echo json_encode(["status" => "error", "message" => "No user found with the given email"]);
        }
    } else {
        throw new Exception("Failed to execute user deletion statement");
    }

    $stmt->close();
    $conn->close();
} catch (Exception $e) {
    echo json_encode(["status" => "error", "message" => $e->getMessage()]);
}
?>