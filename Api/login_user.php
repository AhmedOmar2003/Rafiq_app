<?php
// Prevent any output before headers
ob_clean();

// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);
error_log("Login request received");

// Log request details
error_log("Request Method: " . $_SERVER['REQUEST_METHOD']);
error_log("Origin: " . ($_SERVER['HTTP_ORIGIN'] ?? 'none'));

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    header("Access-Control-Allow-Origin: http://127.0.0.1:5500");
    header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
    header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
    header("Access-Control-Allow-Credentials: true");
    header("Access-Control-Max-Age: 3600");
    header("Content-Length: 0");
    header("Content-Type: text/plain");
    exit();
}

// Set CORS headers for actual request
header("Access-Control-Allow-Origin: http://127.0.0.1:5500");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Access-Control-Allow-Credentials: true");
header('Content-Type: application/json; charset=utf-8');

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

// Get JSON input
$input = file_get_contents('php://input');
$data = json_decode($input, true);

// Check if it's JSON data
if ($input && json_last_error() === JSON_ERROR_NONE) {
    $email = $data['email'] ?? null;
    $password = $data['password'] ?? null;
} else {
    // Fall back to POST data
    $email = $_POST['email'] ?? null;
    $password = $_POST['password'] ?? null;
}

// تحقق من البيانات المرسلة
if ($email && $password) {
    // تحقق من صحة البريد الإلكتروني
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        echo json_encode([
            "status" => "error",
            "message" => "Invalid email address"
        ]);
        $conn->close();
        exit();
    }

    try {
        // التحقق من وجود البريد الإلكتروني في قاعدة البيانات
        $check_email = $conn->prepare("SELECT id, password FROM users WHERE email = ?");
        if (!$check_email) {
            throw new Exception("Prepare failed: " . $conn->error);
        }

        $check_email->bind_param("s", $email);
        $check_email->execute();
        $check_email->store_result();

        if ($check_email->num_rows > 0) {
            // إذا تم العثور على البريد الإلكتروني، نتحقق من كلمة المرور
            $check_email->bind_result($userId, $hashedPassword);
            $check_email->fetch();

            // التحقق من صحة كلمة المرور
            if (password_verify($password, $hashedPassword)) {
                echo json_encode([
                    "status" => "success",
                    "message" => "Login successful",
                    "userId" => $userId
                ]);
            } else {
                echo json_encode([
                    "status" => "error",
                    "message" => "Incorrect password"
                ]);
            }
        } else {
            echo json_encode([
                "status" => "error",
                "message" => "Email not found"
            ]);
        }

        $check_email->close();
    } catch (Exception $e) {
        error_log("Login error: " . $e->getMessage());
        echo json_encode([
            "status" => "error",
            "message" => "An error occurred during login"
        ]);
    }
} else {
    echo json_encode([
        "status" => "error",
        "message" => "Email and password are required"
    ]);
}

// Clean up
if (isset($conn)) {
    $conn->close();
}
?> 