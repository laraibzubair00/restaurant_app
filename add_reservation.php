<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit;
}

include 'db_connect.php';

$data = json_decode(file_get_contents("php://input"), true);

if(!empty($data['customer_name'])) {
    try {
        $sql = "INSERT INTO reservations (customer_name, phone_number, party_size, visit_type, booking_time, tag, status) 
                VALUES (?, ?, ?, ?, ?, ?, 'pending')";
        
        $stmt = $conn->prepare($sql);
        $stmt->execute([
            $data['customer_name'], 
            $data['phone_number'], 
            $data['party_size'], 
            $data['visit_type'], 
            $data['booking_time'] ?? 'NOW', 
            $data['tag'] ?? 'Manager Entry'
        ]);
        
        echo json_encode(["status" => "success"]);
    } catch (PDOException $e) {
        echo json_encode(["status" => "error", "message" => $e->getMessage()]);
    }
} else {
    echo json_encode(["status" => "error", "message" => "Invalid Data"]);
}
?>