import '../data/quote_models.dart';
import '../data/voucher_models.dart';
import 'checkout_intent.dart';

/// Replaces conflicting choices using current server metadata, without estimating
/// eligibility or savings. The caller validates the candidate and quote first.
List<VoucherSelection> updateVoucherSelection(
  List<VoucherSelection> current, {
  required List<QuoteGroup> groups,
  required String targetShopId,
  required CheckoutVoucher candidate,
  required bool selected,
}) {
  final next = current.where((selection) {
    if (!selected) {
      return selection.voucherId != candidate.id ||
          selection.shopId != targetShopId;
    }
    // An App voucher may move to another explicit target, but never duplicate.
    if (selection.voucherId == candidate.id) return false;
    final group = groups
        .where((g) => g.shop.id == selection.shopId)
        .firstOrNull;
    final applied = group?.applied
        .where((v) => v.id == selection.voucherId)
        .firstOrNull;
    final available = group?.candidates
        .where((v) => v.id == selection.voucherId)
        .firstOrNull;
    final benefit = applied?.benefit ?? available?.benefit;
    final issuer = applied?.issuer ?? available?.issuer;
    if (benefit != candidate.benefit) return true;
    return selection.shopId != targetShopId &&
        !(candidate.issuer == 'app' && issuer == 'app');
  }).toList();
  if (selected) next.add(VoucherSelection(candidate.id, targetShopId));
  return List.unmodifiable(next);
}
