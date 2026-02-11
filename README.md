# Training Management System

ระบบจัดการการอบรมสำหรับคลาสสาธารณะ (Public Training Classes) ที่พัฒนาด้วย Ruby on Rails เพื่อทดแทนการจัดการด้วย Excel ด้วยเว็บอินเทอร์เฟซที่ทันสมัย

## Features

### 🎯 Core Features
- **Training Class Management**: สร้าง แก้ไข และลบคลาสการอบรม
- **Attendee Management**: จัดการรายชื่อผู้เข้าร่วม (เพิ่ม แก้ไข ลบ)
- **Payment Slip Upload**: อัปโหลดสลิปการชำระเงิน (รองรับ PNG, JPG, GIF, PDF)
- **CSV Export**: ส่งออกรายชื่อผู้เข้าร่วมเป็นไฟล์ CSV (รองรับ Excel)
- **CSV Data Import**: นำเข้าข้อมูลจากไฟล์ CSV หลายไฟล์ (attendees, payments, quotations)
- **Modern UI**: ใช้ Bootstrap 5 สำหรับอินเทอร์เฟซที่สวยงามและ responsive

### 📊 Dashboards

#### 1. Admin Dashboard (Operation / Sales / Class Management)
มุ่งเน้นการจัดการคลาส การลงทะเบียน และงานประสานงาน

**KPIs:**
- Total Upcoming Classes
- Total Attendees (เดือนนี้)
- New Leads (สัปดาห์นี้)
- Repeat Learners

**Sections:**
- **Action Required**: รายการที่ต้องดำเนินการ (QT รอส่ง, INV ยังไม่ confirm, คลาสใกล้เต็ม)
- **Upcoming Classes**: คลาสที่กำลังจะมาถึง พร้อมข้อมูลที่นั่ง Paid/Pending และ Revenue
- **Leads by Channel**: สถิติผู้สมัครตามช่องทาง (Line, Facebook, Web, Referral)
- **Recent Activity**: กิจกรรมล่าสุด

#### 2. Finance Dashboard (Financial Management)
มุ่งเน้นการจัดการรายรับ เอกสาร และ Cash Flow

**KPIs:**
- Revenue This Month
- Paid This Month
- Outstanding Invoice
- Overdue Payments

**Sections:**
- **Invoice Summary**: สรุปใบแจ้งหนี้ (INV issued, unpaid, overdue, receipt not issued)
- **Revenue Breakdown**: แบ่งตาม Course, Corp/Individual, VAT Summary
- **Payment Status List**: รายการสถานะการชำระเงิน (ชื่อ, คลาส, Invoice No., Amount, Due Date, Status)
- **Corporate Billing Overview**: สรุปการเรียกเก็บเงินจากบริษัท

### 📋 Class Detail Page (3 Tabs)

#### Tab 1: Participants (รายชื่อผู้เรียน)
ตารางแสดงรายชื่อผู้เข้าร่วมทั้งหมด พร้อมคอลัมน์:
- ลำดับ (Order)
- ชื่อ-นามสกุล (Full Name)
- บริษัท (Company) - แสดงเฉพาะ Corporate
- ประเภท (Type) - Indi / Corp
- ช่องทางที่มา (Source Channel)
- สถานะชำระเงิน (Payment Status) - Pending / Paid
- สถานะเอกสาร (Document Status) - QT / INV / Receipt
- Attendance - มาเรียน / No-show
- จำนวนคลาสที่เคยเรียนแล้ว (Total Classes)
- Slip - ลิงก์ดูสลิปการชำระเงิน

#### Tab 2: Documents (เอกสาร)
สรุปสถานะเอกสาร:
- สรุปจำนวนผู้ที่ส่ง QT/INV/Receipt แล้ว
- ตารางแสดงรายละเอียดตาม Document Status

#### Tab 3: Finance (การเงิน)
สรุปการเงินของคลาส:
- Total Revenue
- Paid
- Pending
- VAT Summary
- Class Cost

## Setup Instructions

### Prerequisites

- Ruby (version 3.0 or higher)
- Rails 8.1.2
- SQLite3
- Bundler gem

### Installation

1. **Install dependencies:**
   ```bash
   bundle install
   ```

2. **Set up the database:**
   ```bash
   rails db:create
   rails db:migrate
   ```

3. **Import existing data (optional):**
   ```bash
   rails data:import
   ```
   หมายเหตุ: วางไฟล์ CSV ใน `db/Data/`:
   - `attendees_import.csv`
   - `payments_import.csv`
   - `quotations_company_import.csv`
   - `quotations_indi_import.csv`

4. **Start the Rails server:**
   ```bash
   rails server
   ```

5. **Access the application:**
   - เปิดเบราว์เซอร์และไปที่ `http://localhost:3000`
   - ระบบจะแสดง Admin Dashboard โดยไม่ต้องล็อกอิน

## Usage

### Managing Training Classes

1. คลิก "Training Classes" ในแถบนำทาง
2. คลิก "New Training Class" เพื่อสร้างคลาสใหม่
3. กรอกข้อมูลคลาส (title, date, location, price, cost)
4. บันทึกคลาส

### Managing Attendees

1. ไปที่หน้า Training Class ที่ต้องการ
2. คลิก "Add Attendee" หรือไปที่ Tab "Participants"
3. กรอกข้อมูลผู้เข้าร่วม:
   - ข้อมูลพื้นฐาน (name, email, phone)
   - Company (แสดงเฉพาะเมื่อเลือกประเภท Corporate)
   - Participant Type (Indi / Corp)
   - Source Channel
   - Payment Status (Pending / Paid)
   - Document Status (QT / INV / Receipt)
   - Attendance Status (มาเรียน / No-show)
   - Total Classes (จำนวนคลาสที่เคยเรียน)
   - Price
   - Invoice No. และ Due Date
   - Payment Slip (อัปโหลดไฟล์)
4. บันทึกข้อมูล

### Viewing Class Details

1. คลิกที่ชื่อคลาสจากรายการ Training Classes
2. ดูข้อมูลใน 3 Tabs:
   - **Participants**: รายชื่อผู้เข้าร่วมทั้งหมด
   - **Documents**: สรุปสถานะเอกสาร
   - **Finance**: สรุปการเงิน

### Exporting Attendee Lists

1. ไปที่หน้า Training Class
2. คลิก "Export to CSV" ใน Tab Participants
3. ไฟล์ CSV จะถูกดาวน์โหลดพร้อมข้อมูลผู้เข้าร่วมทั้งหมด
4. เปิดไฟล์ CSV ใน Excel หรือโปรแกรม spreadsheet อื่น

### Uploading Payment Slips

1. เมื่อเพิ่มหรือแก้ไข Attendee
2. เลือกไฟล์ในช่อง "Payment Slip"
3. รองรับไฟล์: PNG, JPG, GIF, PDF (ขนาดไม่เกิน 10MB)
4. บันทึกข้อมูล
5. ดูสลิปได้จากคอลัมน์ "Slip" ในตาราง Participants

### Importing Data from CSV

1. วางไฟล์ CSV ใน `db/Data/`:
   - `attendees_import.csv` - ข้อมูลผู้เข้าร่วม
   - `payments_import.csv` - ข้อมูลการชำระเงิน
   - `quotations_company_import.csv` - ใบเสนอราคาบริษัท
   - `quotations_indi_import.csv` - ใบเสนอราคาบุคคล

2. รันคำสั่ง:
   ```bash
   rails data:import
   ```

3. ระบบจะ:
   - สร้าง Training Classes อัตโนมัติจากข้อมูล
   - นำเข้าข้อมูล Attendees
   - อัปเดต Payment Status และ Document Status
   - คำนวณราคาต่อคนสำหรับ Corporate Quotations

## Project Structure

```
app/
  controllers/
    admin/
      dashboard_controller.rb      # Admin Dashboard
      finance_controller.rb        # Finance Dashboard
      training_classes_controller.rb  # Training Class CRUD
      attendees_controller.rb      # Attendee Management
  models/
    training_class.rb              # Training Class model
    attendee.rb                    # Attendee model
  views/
    admin/                        # Admin interface views
      dashboard/                  # Admin Dashboard views
      finance/                    # Finance Dashboard views
      training_classes/           # Training Class views
      attendees/                  # Attendee views
  helpers/
    application_helper.rb         # Helper methods
db/
  migrate/                        # Database migrations
  Data/                           # CSV import files directory
  seeds.rb                        # Seed data
lib/
  tasks/
    import_data.rake              # Rake task for CSV import
```

## Database Schema

### TrainingClass
- `id` (integer, primary key)
- `title` (string, required)
- `description` (text)
- `date` (date, required)
- `start_time` (time)
- `end_time` (time)
- `location` (string, required)
- `instructor` (string)
- `max_attendees` (integer)
- `price` (decimal, precision: 10, scale: 2) - ราคาคลาส
- `cost` (decimal, precision: 10, scale: 2) - ต้นทุนคลาส
- `created_at` (datetime)
- `updated_at` (datetime)

### Attendee
- `id` (integer, primary key)
- `training_class_id` (foreign key, required)
- `name` (string, required)
- `email` (string, required, unique per class)
- `phone` (string)
- `company` (string) - สำหรับ Corporate
- `notes` (text)
- `participant_type` (string) - "Indi" หรือ "Corp"
- `source_channel` (string) - ช่องทางที่มา (Line, Facebook, Web, etc.)
- `payment_status` (string) - "Pending" หรือ "Paid"
- `document_status` (string) - "QT", "INV", หรือ "Receipt"
- `attendance_status` (string) - "มาเรียน" หรือ "No-show"
- `total_classes` (integer, default: 0) - จำนวนคลาสที่เคยเรียน
- `price` (decimal, precision: 10, scale: 2) - ราคาที่ชำระ
- `invoice_no` (string) - หมายเลขใบแจ้งหนี้
- `due_date` (date) - วันครบกำหนดชำระ
- `created_at` (datetime)
- `updated_at` (datetime)

### Active Storage
- `active_storage_blobs` - เก็บข้อมูลไฟล์ที่อัปโหลด
- `active_storage_attachments` - เชื่อมโยงไฟล์กับ records

## Development

### Running Tests

```bash
rails test
```

### Database Console

```bash
rails console
```

### Creating Migrations

```bash
rails generate migration MigrationName
```

### Running Rake Tasks

```bash
# Import data from CSV files
rails data:import
```

## Technical Details

### Gems Used
- **Rails 8.1.2**: Web framework
- **SQLite3**: Database
- **Bootstrap 5**: UI framework (via CDN)
- **Active Storage**: File uploads
- **Turbo Rails**: SPA-like navigation
- **Stimulus**: JavaScript framework
- **CSV**: CSV parsing for data import

### Data Import Logic

ระบบ import ข้อมูลจะ:
1. **Normalize Data**: ทำความสะอาดข้อมูล (ลบ whitespace, แปลงค่า null)
2. **Find or Create**: หา Training Class ที่มีอยู่หรือสร้างใหม่
3. **Match Attendees**: จับคู่ Attendee ด้วย email, name, หรือ phone
4. **Update Status**: อัปเดต Payment Status และ Document Status จากข้อมูล Payments และ Quotations
5. **Calculate Prices**: คำนวณราคาต่อคนสำหรับ Corporate Quotations

### File Upload Validation

- **Content Types**: PNG, JPG, JPEG, GIF, PDF
- **File Size**: สูงสุด 10MB
- **Storage**: ใช้ Active Storage (local storage by default)

## License

This project is open source and available for use.
