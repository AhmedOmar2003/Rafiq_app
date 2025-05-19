<?php
header('Content-Type: application/json');

// تضمين ملف الاتصال بقاعدة البيانات
include 'db_connection.php';

// جلب جميع المستخدمين من الجدول
$sql = "SELECT id, name, email, created_at FROM users";
$result = $conn->query($sql);

if ($result->num_rows > 0) {
    $users = [];

    while ($row = $result->fetch_assoc()) {
        $users[] = [
            "userId" => $row['id'],
            "name" => $row['name'],
            "email" => $row['email'],
            "created_at" => $row['created_at']
        ];
    }

    echo json_encode([
        "status" => "success",
        "message" => "Users retrieved successfully",
        "users" => $users
    ]);
} else {
    echo json_encode(["status" => "error", "message" => "No users found"]);
}

$conn->close();
?>