# Hướng dẫn Chuẩn bị Dữ liệu Danh mục Cho vay

## Mục đích

Tài liệu này hướng dẫn ngân hàng chuẩn bị file dữ liệu danh mục cho vay (loanbook) để đưa vào hệ thống phân tích PACTA và TRISK của chúng tôi.

## Các bước thực hiện

### Bước 1: Tải file mẫu

Sử dụng file `loanbook_template.xlsx` hoặc `loanbook_template.csv` làm khuôn mẫu.

### Bước 2: Điền thông tin

Điền các thông tin sau cho mỗi khoản vay:

| Cột | Bắt buộc? | Mô tả | Ví dụ |
|-----|-----------|-------|-------|
| `counterparty_name` | Bắt buộc | Tên pháp nhân của bên vay | Cong ty CP Nhiet Dien Vinh Tan |
| `exposure_vnd` | Bắt buộc | Dư nợ (số tiền gốc) bằng VND | 800000000000 |
| `sector_code` | Bắt buộc | Mã ngành kinh tế (VSIC hoặc ISIC) | D3511 |
| `sector_code_system` | Bắt buộc | Hệ thống mã: chọn `VSIC` hoặc `ISIC` | VSIC |
| `credit_limit_vnd` | Bắt buộc | Hạn mức tín dụng bằng VND | 960000000000 |
| `lei` | Không bắt buộc | Mã định danh pháp nhân (20 ký tự) | 5493000IBP32UQZ0KL24 |
| `tax_id` | Không bắt buộc | Mã số thuế | 0301452948 |
| `parent_name` | Không bắt buộc | Tên công ty mẹ / tập đoàn | Tap doan Dien luc Viet Nam (EVN) |
| `parent_id` | Không bắt buộc | Mã định danh công ty mẹ | EVN_001 |
| `currency` | Không bắt buộc | Loại tiền tệ (`VND` hoặc `USD`) | VND |

### Bước 3: Lưu và gửi

- Lưu file dưới dạng `.xlsx` hoặc `.csv`
- Gửi file qua kênh bảo mật cho đội ngũ vận hành

## Lưu ý về Mã VSIC

- VSIC 2018 là hệ thống phân loại ngành kinh tế Việt Nam
- Cấu trúc: một chữ cái + 4 chữ số (ví dụ: `D3511` - Sản xuất điện)
- Hệ thống tự động chuyển đổi VSIC sang mã ISIC
- Nếu không có mã VSIC, có thể sử dụng mã ISIC trực tiếp

## Tùy chọn Ẩn danh hóa

Ngân hàng có thể thay thế tên bên vay bằng mã số (ví dụ: "KH_001", "KH_002") trước khi gửi để tăng cường bảo mật. Việc này là hoàn toàn tự nguyện.

## Dữ liệu ABCD (Asset-Based Company Data)

Ngoài danh mục cho vay, hệ thống còn cần file ABCD để ánh xạ công ty với tài sản vật lý. Xem `intake/SCHEMA.md` phần "ABCD (Asset-Based Company Data) Schema" và file mẫu `abcd_template.csv`.

## Hỗ trợ

Liên hệ đội ngũ vận hành nếu cần hỗ trợ thêm về định dạng dữ liệu.
