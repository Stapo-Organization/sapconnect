import 'package:zooboxi_app/features/cart/data/cart_models.dart';
import 'package:zooboxi_app/features/cart/data/cart_repository.dart';

/// A cart that answers from memory.
///
/// The two shop signs wear what each storefront's basket holds, so anything
/// that pumps `ShelfTabs` — the home header, the home screen — now reads the
/// cart. Without this a widget test reaches for the network, which under
/// `TestWidgetsFlutterBinding` answers 400 and leaves a timer pending.
class StubCartRepository implements CartRepository {
  StubCartRepository([this.cart = const CartData(basket: CartBasket.none)]);

  final CartData cart;

  @override
  Future<CartData> fetch() async => cart;

  @override
  Future<({CartData cart, BasketMove? move})> alignBasket() async =>
      (cart: cart, move: null);

  @override
  Future<CartData> addItem({
    required int productId,
    int? variationId,
    int quantity = 1,
    Map<String, String>? attributes,
  }) async => cart;

  @override
  Future<CartData> switchBasket(String shelf) async => cart;

  @override
  Future<CartData> setQuantity(String key, int quantity) async => cart;

  @override
  Future<CartData> removeItem(String key) async => cart;

  @override
  Future<CartData> applyCoupon(String code) async => cart;

  @override
  Future<CartData> removeCoupon(String code) async => cart;
}
