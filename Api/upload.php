<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

// الاتصال بقاعدة البيانات
$servername = "localhost";
$username = "root";
$password = "";
$dbname = "new_suggesstions"; // اسم قاعدة البيانات

$conn = new mysqli($servername, $username, $password, $dbname);

// التحقق من الاتصال
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

// التحقق من وجود رابط للصورة
if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    // التحقق من أن المستخدم قد اختار مكانًا
    if (isset($_POST['place_id']) && !empty($_POST['place_id'])) {
        $place_id = $_POST['place_id']; // مكان الذي اختاره المستخدم
    } else {
        die("لم يتم اختيار مكان.");
    }

    // التحقق من وجود رابط الصورة
    if (isset($_POST['image_url']) && !empty($_POST['image_url'])) {
        $image_url = $_POST['image_url']; // رابط الصورة

        // التحقق من صحة الرابط
        if (filter_var($image_url, FILTER_VALIDATE_URL)) {
            echo "تم إدخال رابط الصورة بنجاح.<br>";

            // تخزين رابط الصورة في قاعدة البيانات
            $stmt = $conn->prepare("UPDATE places SET image_path = ? WHERE PlaceID = ?");
            $stmt->bind_param("si", $image_url, $place_id); // ربط المتغيرات للاستعلام

            if ($stmt->execute()) {
                echo "تم تحديث رابط الصورة في قاعدة البيانات.";
            } else {
                echo "خطأ أثناء تحديث قاعدة البيانات: " . $stmt->error;
            }

            $stmt->close();
        } else {
            die("الرابط الذي تم إدخاله ليس رابط صورة صالح.");
        }
    } else {
        die("لم يتم إدخال رابط صورة.");
    }
}

// استرجاع جميع الأماكن (PlaceIDs)
$places_result = $conn->query("SELECT PlaceID, PlaceName FROM places");
$places = [];
if ($places_result->num_rows > 0) {
    while ($row = $places_result->fetch_assoc()) {
        $places[] = $row;
    }
}

$conn->close();
?>

<!DOCTYPE html>
<html lang="ar">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>إدخال رابط صورة للمكان</title>
</head>
<body>

    <h1>إدخال رابط صورة للمكان</h1>

    <!-- نموذج إدخال رابط الصورة مع اختيار مكان -->
    <form action="" method="POST">
        <label for="place_id">اختر مكان لتحديث الصورة:</label>
        <select name="place_id" id="place_id" required>
            <option value="">اختر مكان</option> <!-- خيار فارغ لمنع المستخدم من تقديم النموذج دون اختيار مكان -->
            <?php foreach ($places as $place): ?>
                <option value="<?= $place['PlaceID']; ?>"><?= $place['PlaceName']; ?></option>
            <?php endforeach; ?>
        </select>
        <br><br>

        <label for="image_url">أدخل رابط الصورة:</label>
        <input type="text" name="image_url" id="image_url" placeholder="http://example.com/image.jpg" required>
        <br><br>

        <button type="submit">تحديث رابط الصورة</button>
    </form>

</body>
</html>
