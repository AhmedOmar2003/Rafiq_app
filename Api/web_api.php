<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST");
header("Access-Control-Allow-Headers: Content-Type");
header('Content-Type: application/json; charset=utf-8');

include 'db_connection.php';

try {
    $response = [];

    $cityName = isset($_GET['cityName']) ? trim($_GET['cityName']) : null;
    $budget = isset($_GET['budget']) ? trim($_GET['budget']) : null;
    $activityName = isset($_GET['activityName']) ? trim($_GET['activityName']) : null;

    $allowedBudgets = ['أقل من 100 جنيه', '100 إلى 500 جنيه', '500 إلى 1000 جنيه'];
    $allowedCities = ['القاهرة', 'الإسكندرية', 'المنصورة'];
    $allowedActivities = ['طعام', 'ترفيه', 'فعاليات'];

    if ($budget && !in_array($budget, $allowedBudgets)) {
        echo json_encode(["error" => "الميزانية غير صحيحة."], JSON_UNESCAPED_UNICODE);
        exit();
    }
    if ($cityName && !in_array($cityName, $allowedCities)) {
        echo json_encode(["error" => "المدينة غير صحيحة."], JSON_UNESCAPED_UNICODE);
        exit();
    }
    if ($activityName && !in_array($activityName, $allowedActivities)) {
        echo json_encode(["error" => "نوع النشاط غير صحيح."], JSON_UNESCAPED_UNICODE);
        exit();
    }

    $query = "SELECT p.PlaceName, p.Description, p.ActivityName, p.Rating, p.PriceRange, CONCAT(p.PlaceAddress, ', ', c.CityName) AS PlaceAddress, p.image_path 
              FROM Places p JOIN Cities c ON p.CityId = c.CityId WHERE 1=1";
    $params = [];
    $types = "";

    if (!empty($cityName)) {
        $query .= " AND c.CityName = ?";
        $params[] = $cityName;
        $types .= "s";
    }
    if (!empty($budget)) {
        $query .= " AND p.PriceRange = ?";
        $params[] = $budget;
        $types .= "s";
    }
    if (!empty($activityName)) {
        $query .= " AND p.ActivityName = ?";
        $params[] = $activityName;
        $types .= "s";
    }

    $stmt = $conn->prepare($query);
    if (!empty($params)) {
        $stmt->bind_param($types, ...$params);
    }
    $stmt->execute();
    $result = $stmt->get_result();

    $places = [];
    if ($result->num_rows > 0) {
        while ($place = $result->fetch_assoc()) {
            $places[] = $place;
        }
        $response = ["places" => $places];
    } else {
        $response = ["message" => "لا توجد أماكن متاحة تتطابق مع معايير البحث."];
    }

    echo json_encode($response, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
} catch (Exception $e) {
    error_log("Error: " . $e->getMessage());
    echo json_encode(["error" => "حدث خطأ أثناء المعالجة، يرجى المحاولة لاحقًا."], JSON_UNESCAPED_UNICODE);
}

$conn->close();
?>