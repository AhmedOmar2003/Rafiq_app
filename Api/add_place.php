<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type");
header('Content-Type: application/json; charset=utf-8');

// تضمين الاتصال بقاعدة البيانات
include 'db_connection.php';

// فتح ملف لتسجيل الأخطاء (لأغراض التصحيح)
$logFile = 'debug_log.txt';
file_put_contents($logFile, "----- Start of Request -----\n", FILE_APPEND);

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        $errorMsg = "الطلب يجب أن يكون من نوع POST.";
        file_put_contents($logFile, "Error: $errorMsg\n", FILE_APPEND);
        echo json_encode(["error" => $errorMsg]);
        exit();
    }

    $data = json_decode(file_get_contents("php://input"), true);
    file_put_contents($logFile, "Received Data: " . json_encode($data, JSON_UNESCAPED_UNICODE) . "\n", FILE_APPEND);

    $placeName = isset($data['placeName']) ? trim($data['placeName']) : null;
    $activityId = isset($data['activityId']) ? (int)$data['activityId'] : null;
    $budget = isset($data['budget']) ? trim($data['budget']) : null;
    $priceRange = isset($data['priceRange']) ? trim($data['priceRange']) : null;
    $placeAddress = isset($data['address']) ? trim($data['address']) : null;
    $cityName = isset($data['cityName']) ? trim($data['cityName']) : null;
    $description = isset($data['description']) ? trim($data['description']) : null;

    // تعيين رابط الصورة الافتراضي مباشرة (رابط صالح من Unsplash)
    $imagePath = "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4";

    if (empty($placeName) || empty($activityId) || empty($budget) || empty($priceRange) || empty($placeAddress) || empty($cityName) || empty($description)) {
        $errorMsg = "جميع الحقول مطلوبة.";
        file_put_contents($logFile, "Error: $errorMsg\n", FILE_APPEND);
        echo json_encode(["error" => $errorMsg]);
        exit();
    }

    $allowedBudgets = ['أقل من 100 جنيه', '100 إلى 500 جنيه', '500 إلى 1000 جنيه', '1000 إلى 1500 جنيه', 'لسه محددتش'];
    if (!in_array($budget, $allowedBudgets)) {
        $errorMsg = "الميزانية غير صحيحة.";
        file_put_contents($logFile, "Error: $errorMsg\n", FILE_APPEND);
        echo json_encode(["error" => $errorMsg]);
        exit();
    }

    // جلب CityID
    $cityQuery = "SELECT CityID FROM Cities WHERE CityName = ?";
    $cityStmt = $conn->prepare($cityQuery);
    $cityStmt->bind_param("s", $cityName);
    $cityStmt->execute();
    $cityResult = $cityStmt->get_result();

    if ($cityResult->num_rows == 0) {
        $errorMsg = "المدينة غير موجودة.";
        file_put_contents($logFile, "Error: $errorMsg\n", FILE_APPEND);
        echo json_encode(["error" => $errorMsg]);
        $cityStmt->close();
        exit();
    }

    $cityRow = $cityResult->fetch_assoc();
    $cityID = $cityRow['CityID'];
    file_put_contents($logFile, "CityID: $cityID\n", FILE_APPEND);
    $cityStmt->close();

    // جلب ActivityName
    $activityQuery = "SELECT ActivityName FROM activities WHERE ActivityID = ?";
    $activityStmt = $conn->prepare($activityQuery);
    $activityStmt->bind_param("i", $activityId);
    $activityStmt->execute();
    $activityResult = $activityStmt->get_result();

    if ($activityResult->num_rows == 0) {
        $errorMsg = "نوع النشاط غير موجود.";
        file_put_contents($logFile, "Error: $errorMsg\n", FILE_APPEND);
        echo json_encode(["error" => $errorMsg]);
        $activityStmt->close();
        exit();
    }

    $activityRow = $activityResult->fetch_assoc();
    $activityName = $activityRow['ActivityName'];
    file_put_contents($logFile, "ActivityName: $activityName\n", FILE_APPEND);
    $activityStmt->close();

    // إدراج البيانات مع تقييم افتراضي ورابط الصورة الافتراضي
    $defaultRating = 3.8;
    $query = "INSERT INTO places (PlaceName, ActivityID, ActivityName, budget, PriceRange, PlaceAddress, CityID, Description, image_path, Rating) 
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
    $stmt = $conn->prepare($query);
    $stmt->bind_param("sissssissd", $placeName, $activityId, $activityName, $budget, $priceRange, $placeAddress, $cityID, $description, $imagePath, $defaultRating);

    if ($stmt->execute()) {
        if ($stmt->affected_rows > 0) {
            $successMsg = "تم إضافة المكان بنجاح.";
            file_put_contents($logFile, "Success: $successMsg\n", FILE_APPEND);
            echo json_encode(["success" => $successMsg]);
        } else {
            $errorMsg = "لم يتم إدراج المكان (لا توجد صفوف متأثرة).";
            file_put_contents($logFile, "Error: $errorMsg\n", FILE_APPEND);
            echo json_encode(["error" => $errorMsg]);
        }
    } else {
        $errorMsg = "فشل في إضافة المكان: " . $stmt->error;
        file_put_contents($logFile, "Error: $errorMsg\n", FILE_APPEND);
        echo json_encode(["error" => $errorMsg]);
    }

    $stmt->close();
} catch (Exception $e) {
    $errorMsg = "حدث خطأ: " . $e->getMessage();
    file_put_contents($logFile, "Exception: $errorMsg\n", FILE_APPEND);
    echo json_encode(["error" => $errorMsg]);
}

$conn->close();
file_put_contents($logFile, "----- End of Request -----\n\n", FILE_APPEND);
?>