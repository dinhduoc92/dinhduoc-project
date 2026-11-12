Bản cập nhật tùy chỉnh cho **VoiceStudio 0.5.8 Windows x64**, bổ sung ngay trong màn hình **Nhân bản giọng nói**:

- Nút **Lưu âm thanh + SRT** lưu WAV hoặc MP3 cùng file SRT bằng một hộp thoại.
- Tên file lấy từ TXT: `Bai_01.txt` → `Bai_01.wav` + `Bai_01.srt`.
- Mỗi dòng TXT không trống là một mục SRT; thời gian tính theo số mẫu âm thanh của chính đoạn đó, không cần đưa sang Transcriptions.
- Chọn nhiều TXT, chọn WAV/MP3 + SRT và thư mục một lần; app tạo lần lượt rồi tự lưu từng cặp.
- Sao lưu trước khi cập nhật; không ghi đè các bản xuất trùng tên; có bộ khôi phục.

### Cài đặt

1. Tải **VoiceStudio-0.5.8-TXT-Audio-SRT-win-x64-update.zip** ở Assets.
2. Giải nén toàn bộ ZIP, thoát VoiceStudio hoàn toàn, kể cả biểu tượng khay hệ thống.
3. Nhấp đúp **UPDATE.cmd**. Nếu được hỏi, chọn thư mục chứa `VoiceStudio.exe`.
4. Mở lại app → Nhân bản giọng nói → Nhập kịch bản TXT → Tổng hợp âm thanh → Lưu âm thanh + SRT.

Tải riêng `SOURCE.zip` nếu cần mã nguồn. Không cần tải mã nguồn để cài bản cập nhật. Hướng dẫn tiếng Việt đầy đủ và checksum cũng có trong Assets. Muốn khôi phục, thoát app rồi chạy **RESTORE.cmd** trong thư mục đã giải nén.

### Phạm vi kiểm tra

Đã build từ nền mã nguồn 0.5.8, kiểm tra TypeScript và 22 bản dịch, chạy 147 kiểm tra renderer/main cùng 15 kiểm tra Python/PowerShell và kiểm tra giao diện tiếng Việt trong Chromium với backend/bridge giả lập. Đã kiểm tra checksum và tính toàn vẹn ZIP.

**Chưa chạy bản cập nhật trên Windows thật hoặc kiểm tra suy luận bằng RTX 5060.** Đây là bản thử tùy chỉnh, không phải bản phát hành chính thức của tác giả VoiceStudio. Bộ cập nhật chỉ nhận đúng bản gốc 0.5.8 Windows x64 và sẽ từ chối phiên bản khác trước khi sửa file.

Audio tạo trước khi bật thời gian theo dòng cần được tổng hợp lại từ TXT để xuất SRT theo dòng. Cách tổng hợp từng câu có thể đổi nhịp đọc; cần nghe kiểm tra kết quả. Không bao gồm mô hình mới; giấy phép mô hình và quyền sử dụng giọng mẫu vẫn áp dụng.

### Mã nguồn

Nền [VoiceStudio v0.5.8](https://github.com/debpalash/VoiceStudio/tree/v0.5.8), AGPL-3.0. `SOURCE.zip` chứa mã nguồn tương ứng đã sửa; `source.patch`, LICENSE và LICENSE-NOTICE.md đi kèm gói cập nhật. Giọng clone, mô hình tải về, dự án và dữ liệu cá nhân không nằm trong gói phân phối.
