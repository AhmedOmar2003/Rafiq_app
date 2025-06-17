<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST");
header("Access-Control-Allow-Headers: Content-Type");
header('Content-Type: application/json; charset=utf-8');

include 'db_connection.php';

try {
    // Initialize response array
    $response = array();

    // Get request parameters
    $placeId = isset($_GET['id']) ? trim($_GET['id']) : null;
    $cityName = isset($_GET['cityName']) ? trim($_GET['cityName']) : null;
    $budget = isset($_GET['budget']) ? trim($_GET['budget']) : null;
    $activityName = isset($_GET['activityName']) ? trim($_GET['activityName']) : null;
    $showAll = isset($_GET['showAll']) ? $_GET['showAll'] === 'true' : false;

    // Allowed budget ranges
    $allowedBudgets = [
        'أقل من 100 جنيه',
        '100 إلى 500 جنيه',
        '500 إلى 1000 جنيه',
        '1000 إلى 1500 جنيه',
        'لسه محددتش'
    ];

    // Validate budget if provided
    if ($budget && !in_array($budget, $allowedBudgets)) {
        echo json_encode(['error' => 'الميزانية غير صحيحة']);
        exit();
    }

    if ($placeId) {
        // Details page query
        if (empty($placeId)) {
            throw new Exception('معرف المكان غير صالح');
        }

        // Get main place details
        $query = "SELECT p.*, c.CityName 
                 FROM Places p 
                 JOIN Cities c ON p.CityId = c.CityId 
                 WHERE p.PlaceID = ?";
        
        $stmt = $conn->prepare($query);
        if (!$stmt) {
            throw new Exception('خطأ في تحضير الاستعلام: ' . $conn->error);
        }
        
        $stmt->bind_param('s', $placeId);
        if (!$stmt->execute()) {
            throw new Exception('خطأ في تنفيذ الاستعلام: ' . $stmt->error);
        }
        
        $result = $stmt->get_result();
        
        if ($result->num_rows > 0) {
            $place = $result->fetch_assoc();
            
            // Set default values for empty fields
            $place['image_path'] = !empty($place['image_path']) ? $place['image_path'] : 'images/default.jpg';
            $place['Description'] = !empty($place['Description']) ? $place['Description'] : 'لا يوجد وصف متاح';
            $place['PlaceAddress'] = !empty($place['PlaceAddress']) ? $place['PlaceAddress'] : $place['CityName'];

            // Get similar places query
            $similarQuery = "SELECT p.*, c.CityName 
                           FROM Places p 
                           JOIN Cities c ON p.CityId = c.CityId 
                           WHERE p.PlaceID != ? 
                           AND c.CityName = ?
                           AND p.ActivityName = ? 
                           AND p.budget = ?
                           ORDER BY p.Rating DESC 
                           LIMIT 6";

            $similarStmt = $conn->prepare($similarQuery);
            if (!$similarStmt) {
                throw new Exception('خطأ في تحضير استعلام الأماكن المشابهة: ' . $conn->error);
            }

            $similarStmt->bind_param('ssss', 
                $place['PlaceID'],
                $place['CityName'],
                $place['ActivityName'],
                $place['budget']
            );

            if (!$similarStmt->execute()) {
                throw new Exception('خطأ في تنفيذ استعلام الأماكن المشابهة: ' . $similarStmt->error);
            }

            $similarResult = $similarStmt->get_result();
            $similarPlaces = [];

            while ($similarPlace = $similarResult->fetch_assoc()) {
                $similarPlace['image_path'] = !empty($similarPlace['image_path']) ? $similarPlace['image_path'] : 'images/default.jpg';
                $similarPlace['Description'] = !empty($similarPlace['Description']) ? $similarPlace['Description'] : 'لا يوجد وصف متاح';
                $similarPlace['PlaceAddress'] = !empty($similarPlace['PlaceAddress']) ? $similarPlace['PlaceAddress'] : $similarPlace['CityName'];
                $similarPlaces[] = $similarPlace;
            }

            $response = [
                'places' => [$place],
                'similar_places' => $similarPlaces
            ];

            $similarStmt->close();
        } else {
            throw new Exception('لم يتم العثور على المكان المطلوب');
        }

        $stmt->close();
    } else {
        // Search query (for discover page)
        $query = "SELECT p.*, c.CityName 
                 FROM Places p 
                 JOIN Cities c ON p.CityId = c.CityId 
                 WHERE 1=1";
        $params = [];
        $types = "";

        // Filter by city if not showing all
        if (!$showAll && !empty($cityName)) {
            $query .= " AND c.CityName = ?";
            $params[] = $cityName;
            $types .= "s";
        }

        // Filter by budget if not showing all
        if (!$showAll && !empty($budget)) {
            $query .= " AND p.budget = ?";
            $params[] = $budget;
            $types .= "s";
        }

        // Filter by activity if not showing all
        if (!$showAll && !empty($activityName)) {
            $query .= " AND p.ActivityName = ?";
            $params[] = $activityName;
            $types .= "s";
        }

        // Add rating order
        $query .= " ORDER BY COALESCE(p.Rating, 4.5) DESC";

        $stmt = $conn->prepare($query);
        if (!$stmt) {
            throw new Exception('خطأ في تحضير الاستعلام: ' . $conn->error);
        }

        if (!empty($params)) {
            $stmt->bind_param($types, ...$params);
        }

        if (!$stmt->execute()) {
            throw new Exception('خطأ في تنفيذ الاستعلام: ' . $stmt->error);
        }

        $result = $stmt->get_result();
        $places = [];

        while ($place = $result->fetch_assoc()) {
            $place['image_path'] = !empty($place['image_path']) ? $place['image_path'] : 'images/default.jpg';
            $place['Description'] = !empty($place['Description']) ? $place['Description'] : 'لا يوجد وصف متاح';
            $place['PlaceAddress'] = !empty($place['PlaceAddress']) ? $place['PlaceAddress'] : $place['CityName'];
            $places[] = $place;
        }

        if (count($places) > 0) {
            $response = ['places' => $places];
        } else {
            $response = [
                'places' => [],
                'message' => 'لا توجد أماكن متاحة تتطابق مع معايير البحث'
            ];
        }

        $stmt->close();
    }

    // Output JSON response
    echo json_encode($response, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);

} catch (Exception $e) {
    error_log($e->getMessage());
    http_response_code(500);
    echo json_encode([
        'error' => 'حدث خطأ أثناء المعالجة، يرجى المحاولة لاحقًا',
        'details' => $e->getMessage()
    ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
}

// Close connection
$conn->close(); 