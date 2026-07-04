# Đặc tả Dữ liệu Danh mục Cho vay

> **Bản dịch tham khảo — bản tiếng Anh là bản chính.** Xem
> `pilot/loanbook_data_spec.md` để có phiên bản chính thức.

*Dành cho các ngân hàng đối tác tiềm năng đang xem xét giai đoạn dữ liệu
thực PACTA + TRISK.*

> **Đây là bản đặc tả, không phải yêu cầu cung cấp dữ liệu.** Trong giai
> đoạn thí điểm, không có dữ liệu danh mục cho vay thực nào được thu thập.
> Tài liệu này mô tả chính xác những gì một giai đoạn dữ liệu thực trong
> tương lai sẽ cần, để đội ngũ của quý ngân hàng có thể đánh giá tính khả
> thi và yêu cầu ẩn danh hóa trước khi cam kết.

## Dữ liệu này phục vụ mục đích gì

Danh mục cho vay của quý ngân hàng sẽ đi qua đúng quy trình đã tạo ra bản
demo mà quý vị đã xem: phân loại ngành → mức độ phù hợp danh mục PACTA (so
với PDP8 / NDC 2022 / IEA NZE) → kiểm tra sức chịu đựng rủi ro chuyển đổi
TRISK → bộ tài liệu tiếp cận khách hàng và công bố thông tin (phù hợp với
Quyết định 263 / TCFD).

## Các cột bắt buộc

| Cột | Kiểu dữ liệu | Mô tả | Phục vụ cho |
|---|---|---|---|
| `counterparty_name` | văn bản | Tên bên vay | Ghi nhãn báo cáo, bộ tài liệu công bố |
| `exposure_vnd` | số, ≥ 0 | Dư nợ (VND) | Trọng số danh mục, mức độ kiểm tra sức chịu đựng NPV |
| `sector_code` | văn bản | Mã ngành kinh tế | Ánh xạ ngành (xem bên dưới) |
| `sector_code_system` | `VSIC` hoặc `ISIC` | Hệ thống mã của `sector_code` | Ánh xạ ngành |
| `credit_limit_vnd` | số, ≥ 0 | Hạn mức tín dụng (VND) | Bối cảnh dư nợ tại thời điểm vỡ nợ |

## Các cột không bắt buộc (khuyến nghị)

| Cột | Kiểu dữ liệu | Mô tả | Phục vụ cho |
|---|---|---|---|
| `lei` | văn bản | Mã định danh pháp nhân | Đối chiếu ABCD với độ tin cậy cao hơn |
| `tax_id` | văn bản | Mã số thuế | Gán ID bên vay, loại trùng lặp |
| `parent_name` | văn bản | Tên công ty mẹ | Tổng hợp theo tập đoàn (VD: EVN, THACO, VICEM) |
| `parent_id` | văn bản | Mã định danh công ty mẹ | Tổng hợp theo tập đoàn |
| `currency` | văn bản | Mã tiền tệ (mặc định `VND`) | Chuẩn hóa tiền tệ |

## Các ngành PACTA hiện đang được hỗ trợ

| Mã ISIC | Ngành | Mức độ hỗ trợ PACTA/TRISK |
|---|---|---|
| 3511 | Điện lực | TRISK thị phần cấp độ bên vay đầy đủ |
| 2394 | Xi măng | TRISK SDA cấp độ ngành |
| 2410 | Thép | TRISK SDA cấp độ ngành (tỷ lệ đối chiếu ~4% trong bản demo — danh mục thực có LEI/mã số thuế sẽ cải thiện đáng kể) |
| 2910 | Ô tô | Chỉ mức độ phù hợp PACTA (chưa có kiểm tra TRISK) |
| 0510 | Khai thác than | Một phần (không nằm trong kiểm tra TRISK) |
| 0610 | Dầu khí | Một phần (không nằm trong kiểm tra TRISK) |

## Định dạng và gửi dữ liệu

- **Định dạng file:** CSV (UTF-8 hoặc Latin-1), mỗi dòng là một khoản vay.
- **File mẫu:** xem `intake/templates/loanbook_template.csv` và hướng dẫn
  tiếng Việt `intake/templates/README_vi.md`.
- **Ẩn danh hóa:** `counterparty_name` có thể được thay bằng mã số (VD:
  `"Ben_vay_0042"`) miễn là nhất quán trong nội bộ — quy trình không yêu
  cầu tên pháp nhân thực để chạy PACTA/TRISK, chỉ cần cho bước hiển thị bộ
  tài liệu công bố cuối cùng. Mã số thuế / LEI có thể bỏ trống hoặc mã hóa
  nếu sự hiện diện của chúng gây nhạy cảm — việc bỏ trống chỉ làm giảm chất
  lượng tỷ lệ đối chiếu, không cản trở phân tích.
- **Kiểm định:** mọi file gửi lên đều được kiểm định tự động qua cùng một
  công cụ dùng trong bản demo (`scripts/intake_validate_and_map.R`), tạo ra
  báo cáo kiểm định (`validation_summary.txt`) trước khi bất kỳ phân tích
  nào chạy — đội ngũ của quý ngân hàng sẽ thấy chính xác điều gì đã qua,
  điều gì không, và lý do, trước khi có kết quả.

## Quý ngân hàng sẽ nhận được gì

1. Danh mục cho vay đã chuẩn hóa và đối chiếu (ánh xạ ngành, loại trùng lặp
   theo tập đoàn).
2. Kết quả mức độ phù hợp danh mục PACTA so với PDP8 / NDC 2022 / IEA NZE.
3. Kết quả kiểm tra sức chịu đựng rủi ro chuyển đổi TRISK (biến động NPV và
   PD) cho các ngành được hỗ trợ.
4. Bộ tài liệu tiếp cận khách hàng và công bố thông tin (chấm điểm ưu tiên,
   thư tiếp cận khách hàng, bộ tài liệu công bố phù hợp Quyết định 263).

---
*Mọi con số do quy trình này tạo ra chỉ mang tính minh họa cho mục đích sàng
lọc rủi ro chuyển đổi danh mục, không phải kết quả rủi ro tín dụng sản xuất
hoặc vốn quy định.*
