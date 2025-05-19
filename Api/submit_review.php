<?php
// تعيين رأس الاستجابة كـ JSON
header('Content-Type: application/json');

// تضمين ملف الاتصال بقاعدة البيانات
include 'db_connection.php';

// قراءة البيانات القادمة من الطلب
$place_id = $_POST['place_id'] ?? null;
$user_id = $_POST['user_id'] ?? null;
$name = $_POST['name'] ?? null;
$review_text = $_POST['review_text'] ?? null;
$rating = $_POST['rating'] ?? null;

// التحقق من وجود البيانات المطلوبة
if (!$place_id || !$user_id || !$name || !$review_text || !$rating) {
    echo json_encode(["status" => "error", "message" => "جميع الحقول مطلوبة."]);
    exit;
}

// إدخال التقييم في قاعدة البيانات
$stmt = $conn->prepare("INSERT INTO feedback (place_id, user_id, name, review_text, rating) VALUES (?, ?, ?, ?, ?)");
$stmt->bind_param("iissi", $place_id, $user_id, $name, $review_text, $rating);

if ($stmt->execute()) {
    echo json_encode(["status" => "success", "message" => "تم إضافة التقييم بنجاح."]);
} else {
    echo json_encode(["status" => "error", "message" => "فشل في إضافة التقييم: " . $stmt->error]);
}

$stmt->close();
$conn->close();
?>