/// مفاتيح صلاحيات خصائص التطبيق — مرآة لكتالوج الباكند config/app_features.php.
///
/// تُستخدم مع [User.can] و[User.hasFeature] لإظهار/إخفاء الخصائص والإجراءات.
/// عند إضافة خاصية/إجراء جديد في الباكند، أضِف مفتاحه هنا للاستخدام في الواجهة.
class Ability {
  Ability._();

  // ─── تحويلات المخزون (النموذج المرجعي) ───
  static const stockTransferView = 'stock_transfer.view';
  static const stockTransferSend = 'stock_transfer.send';
  static const stockTransferConfirmReceive = 'stock_transfer.confirm_receive';

  // ─── الجرد ───
  static const inventoryCountingView = 'inventory_counting.view';
  static const inventoryCountingCreate = 'inventory_counting.create';
  static const inventoryCountingComplete = 'inventory_counting.complete';

  // ─── مهام الجودة ───
  static const qualityControlView = 'quality_control.view';
  static const qualityControlSubmit = 'quality_control.submit';

  // ─── طلبات زوبوكسي العاجلة ───
  static const zooboxiOrdersView = 'zooboxi_orders.view';
  static const zooboxiOrdersPrepare = 'zooboxi_orders.prepare';

  // ─── الإنجازات والنقاط ───
  static const gamificationView = 'gamification.view';

  // ─── الإعلانات والعروض ───
  static const promotionsView = 'promotions.view';
  static const promotionsApprove = 'promotions.approve';

  // ─── نبض المعرض ───
  static const showroomPulseView = 'showroom_pulse.view';
  static const showroomPulseRequestTransfer = 'showroom_pulse.request_transfer';
  static const showroomPulseSuggestDiscount = 'showroom_pulse.suggest_discount';

  // ─── خصائص المالك (Super Admin) ───
  static const retailDashboardView = 'retail_dashboard.view';
  static const qualityAdminView = 'quality_admin.view';
  static const qualityAdminManage = 'quality_admin.manage';
  static const stockDistributionView = 'stock_distribution.view';
  static const stockDistributionRun = 'stock_distribution.run';
  static const containerTrackingView = 'container_tracking.view';
}

/// مفاتيح الخصائص (الجذر) — تُستخدم مع [User.hasFeature].
class Feature {
  Feature._();

  static const stockTransfer = 'stock_transfer';
  static const inventoryCounting = 'inventory_counting';
  static const qualityControl = 'quality_control';
  static const zooboxiOrders = 'zooboxi_orders';
  static const gamification = 'gamification';
  static const promotions = 'promotions';
  static const showroomPulse = 'showroom_pulse';

  // ─── خصائص المالك (Super Admin) ───
  static const retailDashboard = 'retail_dashboard';
  static const qualityAdmin = 'quality_admin';
  static const stockDistribution = 'stock_distribution';
  static const containerTracking = 'container_tracking';
}
