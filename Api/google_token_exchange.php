<?php
// Prevent any output before headers
ob_clean();

// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);
error_log("Token exchange request received");

// Log request details
error_log("Request Method: " . $_SERVER['REQUEST_METHOD']);
error_log("Origin: " . ($_SERVER['HTTP_ORIGIN'] ?? 'none'));

// Always set CORS headers
header('Access-Control-Allow-Origin: http://127.0.0.1:5500');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, Accept, Origin');
header('Access-Control-Allow-Credentials: false');
header('Access-Control-Max-Age: 3600');

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit();
}

// Set content type for actual requests
header('Content-Type: application/json; charset=utf-8');

// Get JSON input and log it
$input = file_get_contents('php://input');
error_log('Raw input: ' . $input);

try {
    // Database connection with error handling
    $db_host = 'localhost';
    $db_user = 'root';
    $db_pass = '';
    $db_name = 'new_suggesstions';

    // First, try to create the database if it doesn't exist
    $conn = new mysqli($db_host, $db_user, $db_pass);
    if ($conn->connect_error) {
        error_log("Initial database connection failed: " . $conn->connect_error);
        throw new Exception("Initial database connection failed: " . $conn->connect_error);
    }

    // Create database if it doesn't exist
    $sql = "CREATE DATABASE IF NOT EXISTS `$db_name`";
    if (!$conn->query($sql)) {
        error_log("Failed to create database: " . $conn->error);
        throw new Exception("Failed to create database: " . $conn->error);
    }
    $conn->close();

    // Connect to the specific database
    $conn = new mysqli($db_host, $db_user, $db_pass, $db_name);
    if ($conn->connect_error) {
        error_log("Database connection failed: " . $conn->connect_error);
        throw new Exception("Database connection failed: " . $conn->connect_error);
    }

    // Function to check if column exists
    function columnExists($conn, $table, $column) {
        $result = $conn->query("SHOW COLUMNS FROM `$table` LIKE '$column'");
        return $result && $result->num_rows > 0;
    }

    // Check and add necessary columns
    $required_columns = [
        'google_id' => "ADD COLUMN `google_id` VARCHAR(255) UNIQUE",
        'created_at' => "ADD COLUMN `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP",
        'updated_at' => "ADD COLUMN `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP"
    ];

    foreach ($required_columns as $column => $alter_statement) {
        if (!columnExists($conn, 'users', $column)) {
            $alter_sql = "ALTER TABLE `users` $alter_statement";
            if (!$conn->query($alter_sql)) {
                error_log("Failed to add $column column: " . $conn->error);
                throw new Exception("Failed to add $column column: " . $conn->error);
            }
            error_log("Successfully added $column column");
        }
    }

    // Parse JSON input with error logging
    $data = json_decode($input, true);
    if (json_last_error() !== JSON_ERROR_NONE) {
        error_log('JSON decode error: ' . json_last_error_msg());
        throw new Exception('Invalid JSON input: ' . json_last_error_msg());
    }

    $code = $data['code'] ?? null;
    $redirect_uri = $data['redirect_uri'] ?? 'http://127.0.0.1:5500/auth.html';

    if (!$code) {
        throw new Exception('Authorization code is required');
    }

    // Your OAuth 2.0 client credentials
    $client_id = '1046851663602-tfav0693sqi0smfapqilk1vd8fq90nln.apps.googleusercontent.com';
    $client_secret = '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';

    // Exchange the authorization code for tokens
    $token_url = 'https://oauth2.googleapis.com/token';
    $token_data = [
        'code' => $code,
        'client_id' => $client_id,
        'client_secret' => $client_secret,
        'redirect_uri' => $redirect_uri,
        'grant_type' => 'authorization_code'
    ];

    // Initialize cURL with error handling
    $ch = curl_init($token_url);
    if (!$ch) {
        throw new Exception('Failed to initialize cURL');
    }

    // Set cURL options with SSL verification
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POSTFIELDS => http_build_query($token_data),
        CURLOPT_POST => true,
        CURLOPT_SSL_VERIFYPEER => true,
        CURLOPT_SSL_VERIFYHOST => 2,
        CURLOPT_HTTPHEADER => [
            'Content-Type: application/x-www-form-urlencoded',
            'Accept: application/json'
        ]
    ]);

    // Execute token request with detailed error logging
    $token_response = curl_exec($ch);
    error_log('Token Response: ' . $token_response);
    
    if ($token_response === false) {
        $curl_error = curl_error($ch);
        $curl_errno = curl_errno($ch);
        error_log("cURL Error ($curl_errno): $curl_error");
        throw new Exception("cURL error: $curl_error");
    }

    $token_info = json_decode($token_response, true);
    if (!$token_info || isset($token_info['error'])) {
        throw new Exception($token_info['error_description'] ?? 'Failed to exchange code for tokens');
    }

    // Get user info using the access token
    $userinfo_url = 'https://www.googleapis.com/oauth2/v3/userinfo';
    curl_setopt_array($ch, [
        CURLOPT_URL => $userinfo_url,
        CURLOPT_HTTPGET => true,
        CURLOPT_HTTPHEADER => ['Authorization: Bearer ' . $token_info['access_token']]
    ]);

    $userinfo_response = curl_exec($ch);
    error_log('User Info Response: ' . $userinfo_response);
    
    if ($userinfo_response === false) {
        throw new Exception('Failed to get user information: ' . curl_error($ch));
    }

    $user_info = json_decode($userinfo_response, true);
    if (!$user_info || isset($user_info['error'])) {
        throw new Exception('Failed to parse user information');
    }

    // Check if user exists and create if not
    $email = $user_info['email'];
    $name = $user_info['name'];
    $google_id = $user_info['sub'];

    // First try to find user by google_id or email
    $stmt = $conn->prepare("SELECT id FROM users WHERE email = ? OR google_id = ?");
    if (!$stmt) {
        throw new Exception("Prepare failed: " . $conn->error);
    }
    $stmt->bind_param("ss", $email, $google_id);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows === 0) {
        // User doesn't exist, create new user
        $insert_stmt = $conn->prepare("INSERT INTO users (name, email, google_id) VALUES (?, ?, ?)");
        if (!$insert_stmt) {
            throw new Exception("Prepare insert failed: " . $conn->error);
        }
        $insert_stmt->bind_param("sss", $name, $email, $google_id);
        $insert_stmt->execute();
        $user_id = $insert_stmt->insert_id;
        $insert_stmt->close();
    } else {
        // User exists, update their information
        $row = $result->fetch_assoc();
        $user_id = $row['id'];
        
        // Update user information
        $update_stmt = $conn->prepare("UPDATE users SET name = ?, google_id = ? WHERE id = ?");
        if (!$update_stmt) {
            throw new Exception("Prepare update failed: " . $conn->error);
        }
        $update_stmt->bind_param("ssi", $name, $google_id, $user_id);
        $update_stmt->execute();
        $update_stmt->close();
    }
    $stmt->close();

    // Return success response with user data
    $response = [
        'success' => true,
        'userId' => $user_id,
        'name' => $name,
        'email' => $email,
        'sub' => $google_id
    ];
    
    error_log('Sending response: ' . json_encode($response));
    http_response_code(200); // Explicitly set 200 status code
    echo json_encode($response);
    exit(); // Ensure no further output

} catch (Exception $e) {
    error_log("Error in google_token_exchange.php: " . $e->getMessage());
    error_log("Stack trace: " . $e->getTraceAsString());
    
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
    exit(); // Ensure no further output
} finally {
    if (isset($stmt)) {
        $stmt->close();
    }
    if (isset($conn)) {
        $conn->close();
    }
    if (isset($ch) && is_resource($ch)) {
        curl_close($ch);
    }
    ob_end_flush();
} 