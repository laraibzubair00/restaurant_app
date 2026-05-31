<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

// Browser check ke liye
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit;
}

include 'db_connect.php';

// Flutter se JSON data lena
$data = json_decode(file_get_contents("php://input"), true);

if(isset($data['id']) && isset($data['status'])) {
    try {
        $id = $data['id'];
        $status = $data['status'];

        $sql = "UPDATE reservations SET status = ? WHERE id = ?";
        $stmt = $conn->prepare($sql);
        $success = $stmt->execute([$status, $id]);

        if($success) {
            echo json_encode(["status" => "success"]);
        } else {
            echo json_encode(["status" => "error"]);
        }
    } catch (PDOException $e) {
        echo json_encode(["status" => "error", "message" => $e->getMessage()]);
    }
} else {
    echo json_encode(["status" => "error", "message" => "Data not received"]);
}
?>