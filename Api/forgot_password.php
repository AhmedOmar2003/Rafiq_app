<?php
require 'vendor/autoload.php';
use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

header('Content-Type: application/json');

// تضمين ملف الاتصال بقاعدة البيانات
include 'db_connection.php';

if (isset($_POST['email'])) {
    $email = $_POST['email'];

    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        echo json_encode(["status" => "error", "message" => "Invalid email address"]);
        exit();
    }

    // التحقق من وجود البريد الإلكتروني في قاعدة البيانات
    $check_email = $conn->prepare("SELECT id FROM users WHERE email = ?");
    $check_email->bind_param("s", $email);
    $check_email->execute();
    $check_email->store_result();

    if ($check_email->num_rows > 0) {
        // توليد رمز تحقق مكون من 4 أرقام فقط
        $reset_token = rand(1000, 9999);
        $expiry_time = date("Y-m-d H:i:s", strtotime("+2 hours")); // الصلاحية لمدة ساعتين

        // تحديث جدول المستخدمين بالـ reset_token
        $update_token = $conn->prepare("UPDATE users SET reset_token = ?, reset_token_expiry = ? WHERE email = ?");
        $update_token->bind_param("sss", $reset_token, $expiry_time, $email);
        $update_token->execute();

        // إرسال البريد الإلكتروني باستخدام PHPMailer
        $mail = new PHPMailer(true);
        try {
            $mail->isSMTP();
            $mail->Host = 'smtp.gmail.com';
            $mail->SMTPAuth = true;
            $mail->Username = 'ahmedomarahlawy22@gmail.com'; // بريدك الإلكتروني
            $mail->Password = 'tqxw clrs qqdl whmg'; // كلمة مرور التطبيق
            $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
            $mail->Port = 587;

            $mail->setFrom('ahmedomarahlawy22@gmail.com', 'Rafiq App');
            $mail->addAddress($email);
            $mail->Subject = 'Your Verification Code';
            $mail->isHTML(true);
            $mail->Body = "<p>Your OTP Code is: <strong>$reset_token</strong></p>";

            if ($mail->send()) {
                echo json_encode([
                    "status" => "success",
                    "message" => "OTP sent to your email",
                    "otp" => $reset_token
                ]);
            } else {
                echo json_encode(["status" => "error", "message" => "Failed to send email"]);
            }
        } catch (Exception $e) {
            echo json_encode(["status" => "error", "message" => "Error sending email: {$mail->ErrorInfo}"]);
        }
    } else {
        echo json_encode(["status" => "error", "message" => "Email not found"]);
    }

    $check_email->close();
} else {
    echo json_encode(["status" => "error", "message" => "Email is required"]);
}

$conn->close();
?>