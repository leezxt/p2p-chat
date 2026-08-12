import '../../../core/events/app_event.dart';
import '../domain/desktop_link.dart';

enum DesktopLinkChangeKind { authorized, revoked }

/// Desktop Link 狀態變更事件。
///
/// 未來傳輸／桌面 UI 模組可訂閱此事件收斂連線或清除暫存，避免直接依賴
/// Desktop Link 的內部 service。
class DesktopLinkChanged extends AppEvent {
  const DesktopLinkChanged({required this.link, required this.kind});

  final DesktopLink link;
  final DesktopLinkChangeKind kind;
}
