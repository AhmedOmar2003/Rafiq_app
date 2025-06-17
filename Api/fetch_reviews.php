<?php
// إضافة رأسيات CORS للسماح بطلبات من أي مصدر
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST");
header("Access-Control-Allow-Headers: Content-Type");
header('Content-Type: application/json');

// إعدادات تسجيل الأخطاء للمساعدة في التصحيح
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

// تضمين ملف الاتصال بقاعدة البيانات
include 'db_connection.php';

// التحقق من وجود place_id في الطلب
if (!isset($_POST['place_id']) || empty($_POST['place_id'])) {
    echo json_encode(["status" => "error", "message" => "place_id is required"]);
    $conn->close();
    exit();
}

$place_id = intval($_POST['place_id']);

// استعلام لجلب التقييمات بناءً على place_id
$sql = "SELECT id, place_id, user_id, name, review_text, created_at FROM feedback WHERE place_id = ? ORDER BY id DESC";
$stmt = $conn->prepare($sql);

if (!$stmt) {
    error_log("Prepare failed: " . $conn->error);
    echo json_encode(["status" => "error", "message" => "Prepare failed: " . $conn->error]);
    $conn->close();
    exit();
}

$stmt->bind_param("i", $place_id);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows > 0) {
    $reviews = [];

    while ($row = $result->fetch_assoc()) {
        $reviews[] = [
            "id" => $row['id'],
            "place_id" => $row['place_id'],
            "user_id" => $row['user_id'],
            "name" => $row['name'],
            "review_text" => $row['review_text'],
            "created_at" => $row['created_at']
        ];
    }

    // إرجاع البيانات كـ JSON
    echo json_encode(["status" => "success", "data" => $reviews]);
} else {
    echo json_encode(["status" => "success", "data" => [], "message" => "No reviews found for this place."]);
}

$stmt->close();
$conn->close();
?>