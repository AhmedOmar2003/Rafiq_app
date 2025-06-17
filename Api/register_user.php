<?php
// Basic error reporting
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Simple CORS headers
header("Access-Control-Allow-Origin: http://127.0.0.1:5500");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

// Handle preflight
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

// تضمين ملف الاتصال بقاعدة البيانات
try {
    include 'db_connection.php';
} catch (Exception $e) {
    error_log("Database connection error: " . $e->getMessage());
    echo json_encode([
        "status" => "error",
        "message" => "Database connection failed"
    ]);
    exit();
}

// التحقق من البيانات المدخلة
if (isset($_POST['name']) && isset($_POST['email']) && isset($_POST['password'])) {
    $name = trim($_POST['name']);
    $email = trim($_POST['email']);
    $password = $_POST['password'];

    // تسجيل البيانات المستلمة (مع إخفاء كلمة المرور)
    error_log("Received data: " . json_encode([
        'name' => $name,
        'email' => $email,
        'password_length' => strlen($password)
    ]));

    // التحقق من صحة البريد الإلكتروني
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        echo json_encode(["status" => "error", "message" => "Invalid email address"]);
        exit();
    }

    // التحقق من كلمة المرور
    if (strlen($password) < 6) {
        echo json_encode(["status" => "error", "message" => "Password must be at least 6 characters long"]);
        exit();
    }

    try {
        // التحقق من وجود البريد الإلكتروني مسبقاً
        $check_email = $conn->prepare("SELECT id FROM users WHERE email = ?");
        $check_email->bind_param("s", $email);
        $check_email->execute();
        $check_email->store_result();

        if ($check_email->num_rows > 0) {
            echo json_encode(["status" => "error", "message" => "Email already exists"]);
            $check_email->close();
            exit();
        }
        $check_email->close();

        // تشفير كلمة المرور
        $hashed_password = password_hash($password, PASSWORD_BCRYPT);

        // إدخال البيانات
        $stmt = $conn->prepare("INSERT INTO users (name, email, password) VALUES (?, ?, ?)");
        $stmt->bind_param("sss", $name, $email, $hashed_password);

        if ($stmt->execute()) {
            // جلب جميع المستخدمين بعد التسجيل
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
                    "message" => "User registered successfully",
                    "users" => $users
                ]);
            }
        } else {
            throw new Exception("Registration failed");
        }

        $stmt->close();
    } catch (Exception $e) {
        error_log("Database error: " . $e->getMessage());
        echo json_encode([
            "status" => "error",
            "message" => "Registration failed: " . $e->getMessage()
        ]);
    }
} else {
    error_log("Missing required fields: " . json_encode($_POST));
    echo json_encode([
        "status" => "error",
        "message" => "Missing required fields"
    ]);
}

$conn->close();
?> 