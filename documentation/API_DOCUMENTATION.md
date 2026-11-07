# SHREEJI IMAGING AND DIAGNOSTICS CENTER PRIVATE LIMITED
## CLIENT ORDER MANAGEMENT SYSTEM — API SPECIFICATION

- **API Base URL**: `https://YOUR-N8N-DOMAIN/webhook` (e.g. `https://finisher-pajamas-dipping.ngrok-free.dev/webhook`)
- **Format**: JSON (`Content-Type: application/json`)
- **Authentication**: Bearer Token in `Authorization` header (`Authorization: Bearer <TOKEN>`)

---

### 1. Authentication Endpoints

#### `POST /shreeji/auth/login`
Authenticates a hospital client or system administrator.

- **Request Body**:
```json
{
  "username": "apex_pet",
  "password": "Apex@2026"
}
```

- **Success Response (200 OK)**:
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Login successful",
  "token": "eyJ1c2VySWQiOjIsInJvbGUiOiJDTElFTlQiLCJjbGllbnRJZCI6MX0...",
  "user": {
    "id": 2,
    "clientId": 1,
    "clientCode": "HOSP-APEX",
    "username": "apex_pet",
    "email": "pet@apexhospital.org",
    "fullName": "Apex Hospital PET Team",
    "role": "CLIENT",
    "hospitalName": "Apex Cancer Hospital & Research Center",
    "destinationName": "Nuclear Medicine Dept, 1st Floor"
  }
}
```

- **Error Response (401 Unauthorized)**:
```json
{
  "success": false,
  "statusCode": 401,
  "message": "Invalid credentials or inactive account."
}
```

---

#### `POST /shreeji/auth/logout`
Invalidates client session.

- **Request Headers**: `Authorization: Bearer <TOKEN>`
- **Response**:
```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

---

### 2. Client Order Endpoints

#### `POST /shreeji/order/create`
Submits a new order containing one or multiple lots.

- **Request Headers**: `Authorization: Bearer <TOKEN>`
- **Request Body**:
```json
{
  "orderDate": "2026-11-08",
  "productId": 1,
  "destination": "Nuclear Medicine Dept, 1st Floor",
  "notes": "Patient scheduled for 08:30 AM whole-body scan",
  "lots": [
    {
      "quantity": 100,
      "unit": "mCi",
      "calibrationDate": "2026-11-08",
      "calibrationTime": "08:00"
    },
    {
      "quantity": 150,
      "unit": "mCi",
      "calibrationDate": "2026-11-08",
      "calibrationTime": "10:30"
    }
  ]
}
```

- **Success Response (201 Created)**:
```json
{
  "success": true,
  "statusCode": 201,
  "message": "Order submitted successfully",
  "orderId": "SHR-2026-000001",
  "totalLots": 2,
  "totalQuantity": 250.00,
  "status": "Order Submitted",
  "submissionTimestamp": "2026-11-08T02:15:00.000Z"
}
```

- **Validation Rules**:
  1. `orderDate`: Mandatory date string (YYYY-MM-DD).
  2. `productId`: Positive integer referencing active product.
  3. `destination`: Mandatory string.
  4. `lots`: Array of objects with minimum 1 lot.
  5. `lot.quantity`: Numeric value strictly greater than 0.
  6. `lot.unit`: Strictly either `"mCi"` or `"Dose"`.
  7. `lot.calibrationDate` & `lot.calibrationTime`: Mandatory.

---

#### `GET /shreeji/orders`
Retrieves paginated orders. If authenticated as `CLIENT`, strictly returns orders belonging to that client. If `ADMIN`, allows viewing all clients.

- **Request Headers**: `Authorization: Bearer <TOKEN>`
- **Query Parameters**:
  - `fromDate` (optional, YYYY-MM-DD)
  - `toDate` (optional, YYYY-MM-DD)
  - `status` (optional)
  - `productId` (optional, int)
  - `orderId` (optional, string search)
  - `page` (optional, default: 1)
  - `limit` (optional, default: 50, max: 100)

- **Success Response (200 OK)**:
```json
{
  "success": true,
  "count": 1,
  "orders": [
    {
      "id": 1001,
      "order_id": "SHR-2026-000001",
      "client_id": 1,
      "hospital_name": "Apex Cancer Hospital & Research Center",
      "client_code": "HOSP-APEX",
      "order_date": "2026-11-08",
      "submission_timestamp": "2026-11-08T02:15:00.000Z",
      "product_name": "F-18 FDG",
      "destination": "Nuclear Medicine Dept, 1st Floor",
      "status": "Production Planned",
      "total_lots": 2,
      "total_quantity": 250.00
    }
  ]
}
```

---

#### `GET /shreeji/dashboard`
Returns live PostgreSQL aggregate cards and recent order data for the authenticated client.

- **Request Headers**: `Authorization: Bearer <TOKEN>`
- **Success Response (200 OK)**:
```json
{
  "success": true,
  "hospital": "Apex Cancer Hospital & Research Center",
  "role": "CLIENT",
  "metrics": {
    "total_orders": 14,
    "pending_orders": 3,
    "today_orders": 2,
    "delivered_orders": 10,
    "cancelled_orders": 1,
    "total_lots": 29,
    "production_planned": 1,
    "dispatched_orders": 1
  },
  "products": [
    { "product_name": "F-18 FDG", "order_count": 10, "total_qty": 1450.00 },
    { "product_name": "F-18 PSMA", "order_count": 4, "total_qty": 320.00 }
  ],
  "recentOrders": [ ... ]
}
```

---

### 3. Administrator Endpoints

#### `POST /shreeji/admin/order/status`
Updates order status across the operational workflow.

- **Request Headers**: `Authorization: Bearer <TOKEN>` (Role must be `ADMIN`)
- **Request Body**:
```json
{
  "orderId": "SHR-2026-000001",
  "newStatus": "Dispatched",
  "remarks": "Driver dispatched in refrigerated vehicle GJ-01-AB-1234"
}
```

- **Allowed Status Values**:
  1. `Order Submitted`
  2. `Production Planned`
  3. `Production Completed`
  4. `Invoice Generated`
  5. `Dispatched`
  6. `Out for Delivery`
  7. `Delivered`
  8. `Cancelled`

- **Success Response (200 OK)**:
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Order status updated successfully",
  "orderId": "SHR-2026-000001",
  "previousStatus": "Invoice Generated",
  "currentStatus": "Dispatched"
}
```

---

#### `GET /shreeji/admin/reports`
Aggregated enterprise reports grouped by client and product.
