# Đề xuất Giai đoạn Dữ liệu Thực

> **Bản dịch tham khảo — bản tiếng Anh là bản chính.** Xem
> `pilot/real_data_phase_proposal.md` để có phiên bản chính thức. Các mục
> `{{...}}` giữ nguyên không dịch — điền theo hướng dẫn tại
> `pilot/tailoring_checklist.md`.

**Chuẩn bị cho:** {{BANK_NAME}}
**Chuẩn bị bởi:** Allotrope VC
**Ngày:** {{DATE}}
**Liên hệ:** {{CONTACT_NAME}} · {{CONTACT_EMAIL}}

## 1. Bối cảnh

{{BANK_NAME}} đã đánh giá nền tảng PACTA + TRISK Việt Nam bằng một trường
hợp ngân hàng tổng hợp (Ngân hàng Thương mại Mekong). Đề xuất này xác định
phạm vi giai đoạn tiếp theo: chạy cùng quy trình mức độ phù hợp PACTA và
kiểm tra sức chịu đựng rủi ro chuyển đổi TRISK trên danh mục cho vay thực
của {{BANK_NAME}}.

## 2. Phạm vi

- **Tiếp nhận dữ liệu:** {{BANK_NAME}} cung cấp trích xuất danh mục cho vay
  theo `loanbook_data_spec.md`. Phương pháp ẩn danh hóa:
  {{ANONYMIZATION_APPROACH}}.
- **Kiểm định:** kiểm định lược đồ tự động và ánh xạ ngành, với báo cáo kiểm
  định gửi lại {{BANK_NAME}} trước khi phân tích được tiến hành.
- **Mức độ phù hợp PACTA:** mức độ phù hợp danh mục so với lộ trình PDP8,
  NDC 2022, và IEA NZE, bao gồm các ngành: {{SECTOR_LIST}}.
- **Kiểm tra sức chịu đựng TRISK:** kiểm tra sức chịu đựng NPV và xác suất
  vỡ nợ cấp độ bên vay/ngành dưới {{SCENARIO_SELECTION}} (mặc định: năm xảy
  ra cú sốc 2030, giả định cơ bản về tỷ lệ chiết khấu/lãi suất phi rủi
  ro/truyền dẫn thị trường — có thể điều chỉnh qua Scenario Builder).
- **Kết quả đầu ra:** chấm điểm ưu tiên tiếp cận, bản thảo thư tiếp cận
  khách hàng, và bộ tài liệu công bố thông tin phù hợp với Quyết định 263 /
  TCFD.
- **Bàn giao:** phiên bản dashboard riêng tư dành cho dữ liệu của
  {{BANK_NAME}}, cùng báo cáo kết quả ({{REPORT_LANGUAGE}}).

## 3. Ngoài phạm vi của giai đoạn này

- Các ngành mới ngoài {{SECTOR_LIST}}.
- Thay đổi phương pháp luận (VD: SDA cấp độ bên vay cho xi măng/thép).
- Tích hợp với hệ thống nội bộ của {{BANK_NAME}} (bàn giao dựa trên file).

## 4. Lộ trình thời gian

| Mốc thời gian | Ngày mục tiêu |
|---|---|
| Nhận danh mục cho vay | {{DATE_1}} |
| Trả báo cáo kiểm định | {{DATE_2}} |
| Bàn giao kết quả PACTA + TRISK | {{DATE_3}} |
| Buổi trình bày kết quả | {{DATE_4}} |

## 5. Xử lý dữ liệu & Bảo mật

- Dữ liệu danh mục cho vay của {{BANK_NAME}} chỉ được sử dụng cho phân tích
  của giai đoạn này và không được lưu giữ quá {{DATA_RETENTION_PERIOD}} nếu
  không có thỏa thuận bằng văn bản.
- Kết quả được bàn giao tới phiên bản dashboard riêng tư, có kiểm soát truy
  cập (không phải bản demo công khai).
- {{ADDITIONAL_CONFIDENTIALITY_TERMS}}

## 6. Điều khoản thương mại

{{PRICING_AND_TERMS_PLACEHOLDER}}

## 7. Bước tiếp theo

Ký xác nhận đề xuất này, sau đó cùng đội ngũ rủi ro/ESG của {{BANK_NAME}}
rà soát đặc tả dữ liệu danh mục cho vay để thống nhất phương pháp ẩn danh
hóa và ánh xạ ngành trước khi chuyển giao dữ liệu.

---
*Đề xuất này được đưa ra sau một giai đoạn thí điểm hoàn toàn trên dữ liệu
tổng hợp; chưa có dữ liệu thực nào của {{BANK_NAME}} được xử lý, xem, hoặc
lưu trữ trước khi có thỏa thuận này.*
