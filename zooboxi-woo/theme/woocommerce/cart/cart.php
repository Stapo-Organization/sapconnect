<?php
/**
 * Cart Page — Zooboxi override.
 *
 * GROUPED VIEW (Smart Shipments on + customer location set): abandons WooCommerce's wide
 * shop_table and renders each delivery tier as a real "shipment card" (a bordered container
 * whose coloured header strip OWNS the compact item rows inside it) — noon-style.
 * FALLBACK VIEW (otherwise): the standard WooCommerce cart table, untouched.
 *
 * Based on WooCommerce core templates/cart/cart.php @version 10.8.0.
 *
 * @package WooCommerce\Templates
 */

defined( 'ABSPATH' ) || exit;

/**
 * Decide layout: grouped shipment cards vs default table.
 */
$zb_on    = class_exists( 'Zooboxi_Smart_Shipments' ) && Zooboxi_Smart_Shipments::enabled() && class_exists( 'Zooboxi_Fulfillment' );
$zb_loc   = $zb_on ? Zooboxi_Fulfillment::customer_location() : array( 0, 0 );
$zb_lat   = (float) $zb_loc[0];
$zb_lng   = (float) $zb_loc[1];
$zb_group = $zb_on && $zb_lat && $zb_lng;

// Build ordered tier groups (express → next-day → shipping).
$zb_groups = array();
if ( $zb_group ) {
	$zb_order = array( 'express' => 1, 'same_day' => 2, 'shipping' => 3 );
	foreach ( WC()->cart->get_cart() as $cart_item_key => $cart_item ) {
		$_p = isset( $cart_item['data'] ) ? $cart_item['data'] : null;
		if ( ! ( $_p instanceof WC_Product ) || ! $_p->exists() || $cart_item['quantity'] <= 0 ) {
			continue;
		}
		if ( ! apply_filters( 'woocommerce_cart_item_visible', true, $cart_item, $cart_item_key ) ) {
			continue;
		}
		$tier = Zooboxi_Fulfillment::line_tier( (int) $cart_item['product_id'], (int) $cart_item['quantity'], $zb_lat, $zb_lng );
		$zb_groups[ $tier ][ $cart_item_key ] = $cart_item;
	}
	uksort(
		$zb_groups,
		function ( $a, $b ) use ( $zb_order ) {
			$ra = isset( $zb_order[ $a ] ) ? $zb_order[ $a ] : 9;
			$rb = isset( $zb_order[ $b ] ) ? $zb_order[ $b ] : 9;
			return $ra <=> $rb;
		}
	);
	if ( count( $zb_groups ) < 1 ) {
		$zb_group = false;
	}
}

do_action( 'woocommerce_before_cart' ); ?>

<form class="woocommerce-cart-form<?php echo $zb_group ? ' zb-cart-form--grouped' : ''; ?>" action="<?php echo esc_url( wc_get_cart_url() ); ?>" method="post">
	<?php do_action( 'woocommerce_before_cart_table' ); ?>

	<?php if ( $zb_group ) : ?>

		<?php // ─────────────  GROUPED SHIPMENT CARDS  ───────────── ?>
		<div class="zb-cart-groups">
			<?php
			$zb_qualifies = ( WC()->cart->get_subtotal() >= (float) apply_filters( 'zooboxi_free_shipping_min', (float) get_option( 'zooboxi_free_shipping_min', 200 ) ) );

			foreach ( $zb_groups as $zb_tier => $zb_items ) :
				$zb_pr  = Zooboxi_Fulfillment::tier_presentation( $zb_tier );
				$zb_cnt = count( $zb_items );
				$zb_cw  = ( 1 === $zb_cnt ) ? 'صنف' : 'أصناف';
				?>
				<div class="zb-scard zb-scard--<?php echo esc_attr( $zb_tier ); ?>" style="--zb-c:<?php echo esc_attr( $zb_pr['color'] ); ?>;--zb-bg:<?php echo esc_attr( $zb_pr['bg'] ); ?>;">
					<div class="zb-scard-head">
						<div class="zb-scard-row">
							<span class="zb-scard-name"><?php echo esc_html( $zb_pr['icon'] . ' ' . $zb_pr['name'] ); ?></span>
							<span class="zb-scard-count"><?php echo esc_html( $zb_cnt . ' ' . $zb_cw ); ?></span>
						</div>
						<div class="zb-scard-promise"><?php echo esc_html( sprintf( __( 'احصل عليها %1$s · %2$s', 'zooboxi' ), $zb_pr['date'], $zb_pr['relative'] ) ); ?></div>
						<?php if ( $zb_qualifies ) : ?>
							<div class="zb-scard-free"><?php esc_html_e( '🚚 توصيل مجاني', 'zooboxi' ); ?></div>
						<?php endif; ?>
					</div>

					<div class="zb-scard-items">
						<?php
						foreach ( $zb_items as $cart_item_key => $cart_item ) :
							$_product          = apply_filters( 'woocommerce_cart_item_product', $cart_item['data'], $cart_item, $cart_item_key );
							$product_id        = apply_filters( 'woocommerce_cart_item_product_id', $cart_item['product_id'], $cart_item, $cart_item_key );
							$product_name      = apply_filters( 'woocommerce_cart_item_name', $_product->get_name(), $cart_item, $cart_item_key );
							$product_permalink = apply_filters( 'woocommerce_cart_item_permalink', $_product->is_visible() ? $_product->get_permalink( $cart_item ) : '', $cart_item, $cart_item_key );
							$thumbnail         = apply_filters( 'woocommerce_cart_item_thumbnail', $_product->get_image(), $cart_item, $cart_item_key );

							if ( $_product->is_sold_individually() ) {
								$min_quantity = 1;
								$max_quantity = 1;
							} else {
								$min_quantity = 0;
								$max_quantity = $_product->get_max_purchase_quantity();
							}
							$qty_input = woocommerce_quantity_input(
								array(
									'input_name'   => "cart[{$cart_item_key}][qty]",
									'input_value'  => $cart_item['quantity'],
									'max_value'    => $max_quantity,
									'min_value'    => $min_quantity,
									'product_name' => $product_name,
								),
								$_product,
								false
							);
							?>
							<div class="zb-line">
								<div class="zb-line-thumb">
									<?php
									if ( ! $product_permalink ) {
										echo $thumbnail; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
									} else {
										printf( '<a href="%s">%s</a>', esc_url( $product_permalink ), $thumbnail ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
									}
									?>
								</div>

								<div class="zb-line-info">
									<?php
									if ( ! $product_permalink ) {
										echo '<span class="zb-line-name">' . wp_kses_post( $product_name ) . '</span>';
									} else {
										printf( '<a class="zb-line-name" href="%s">%s</a>', esc_url( $product_permalink ), wp_kses_post( $product_name ) );
									}
									do_action( 'woocommerce_after_cart_item_name', $cart_item, $cart_item_key );
									echo wc_get_formatted_cart_item_data( $cart_item ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
									?>
									<div class="zb-line-price"><?php echo apply_filters( 'woocommerce_cart_item_subtotal', WC()->cart->get_product_subtotal( $_product, $cart_item['quantity'] ), $cart_item, $cart_item_key ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></div>
								</div>

								<div class="zb-line-actions">
									<div class="zb-line-qty"><?php echo apply_filters( 'woocommerce_cart_item_quantity', $qty_input, $cart_item_key, $cart_item ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></div>
									<a class="zb-line-remove" href="<?php echo esc_url( wc_get_cart_remove_url( $cart_item_key ) ); ?>" aria-label="<?php echo esc_attr( sprintf( __( 'Remove %s from cart', 'woocommerce' ), wp_strip_all_tags( $product_name ) ) ); ?>">🗑 <?php esc_html_e( 'حذف', 'zooboxi' ); ?></a>
								</div>
							</div>
						<?php endforeach; ?>
					</div>
				</div>
			<?php endforeach; ?>
		</div>

		<?php // Update-cart button kept in the DOM (off-screen via CSS) — the qty stepper triggers its
		      // click to apply quantity changes. Coupon lives in the left summary now. ?>
		<div class="zb-cart-actions">
			<button type="submit" class="button" name="update_cart" value="<?php esc_attr_e( 'Update cart', 'woocommerce' ); ?>"><?php esc_html_e( 'Update cart', 'woocommerce' ); ?></button>
			<?php do_action( 'woocommerce_cart_actions' ); ?>
			<?php wp_nonce_field( 'woocommerce-cart', 'woocommerce-cart-nonce' ); ?>
		</div>

	<?php else : ?>

		<?php // ─────────────  DEFAULT TABLE (no location / feature off)  ───────────── ?>
		<table class="shop_table shop_table_responsive cart woocommerce-cart-form__contents" cellspacing="0">
			<thead>
				<tr>
					<th class="product-remove"><span class="screen-reader-text"><?php esc_html_e( 'Remove item', 'woocommerce' ); ?></span></th>
					<th class="product-thumbnail"><span class="screen-reader-text"><?php esc_html_e( 'Thumbnail image', 'woocommerce' ); ?></span></th>
					<th scope="col" class="product-name"><?php esc_html_e( 'Product', 'woocommerce' ); ?></th>
					<th scope="col" class="product-price"><?php esc_html_e( 'Price', 'woocommerce' ); ?></th>
					<th scope="col" class="product-quantity"><?php esc_html_e( 'Quantity', 'woocommerce' ); ?></th>
					<th scope="col" class="product-subtotal"><?php esc_html_e( 'Subtotal', 'woocommerce' ); ?></th>
				</tr>
			</thead>
			<tbody>
				<?php do_action( 'woocommerce_before_cart_contents' ); ?>

				<?php
				foreach ( WC()->cart->get_cart() as $cart_item_key => $cart_item ) {
					$_product   = apply_filters( 'woocommerce_cart_item_product', $cart_item['data'], $cart_item, $cart_item_key );
					$product_id = apply_filters( 'woocommerce_cart_item_product_id', $cart_item['product_id'], $cart_item, $cart_item_key );
					$visible    = apply_filters( 'woocommerce_cart_item_visible', true, $cart_item, $cart_item_key );

					if ( $_product instanceof WC_Product && $_product->exists() && $cart_item['quantity'] > 0 && $visible ) {
						$product_name      = apply_filters( 'woocommerce_cart_item_name', $_product->get_name(), $cart_item, $cart_item_key );
						$product_permalink = apply_filters( 'woocommerce_cart_item_permalink', $_product->is_visible() ? $_product->get_permalink( $cart_item ) : '', $cart_item, $cart_item_key );
						?>
						<tr class="woocommerce-cart-form__cart-item <?php echo esc_attr( apply_filters( 'woocommerce_cart_item_class', 'cart_item', $cart_item, $cart_item_key ) ); ?>">
							<td class="product-remove">
								<?php
									echo apply_filters( // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
										'woocommerce_cart_item_remove_link',
										sprintf(
											'<a role="button" href="%s" class="remove" aria-label="%s" data-product_id="%s" data-product_sku="%s">&times;</a>',
											esc_url( wc_get_cart_remove_url( $cart_item_key ) ),
											esc_attr( sprintf( __( 'Remove %s from cart', 'woocommerce' ), wp_strip_all_tags( $product_name ) ) ),
											esc_attr( $product_id ),
											esc_attr( $_product->get_sku() )
										),
										$cart_item_key
									);
								?>
							</td>
							<td class="product-thumbnail">
							<?php
							$thumbnail = apply_filters( 'woocommerce_cart_item_thumbnail', $_product->get_image(), $cart_item, $cart_item_key );
							if ( ! $product_permalink ) {
								echo $thumbnail; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
							} else {
								printf( '<a href="%s">%s</a>', esc_url( $product_permalink ), $thumbnail ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
							}
							?>
							</td>
							<td scope="row" role="rowheader" class="product-name" data-title="<?php esc_attr_e( 'Product', 'woocommerce' ); ?>">
							<?php
							if ( ! $product_permalink ) {
								echo wp_kses_post( $product_name . '&nbsp;' );
							} else {
								echo wp_kses_post( apply_filters( 'woocommerce_cart_item_name', sprintf( '<a href="%s">%s</a>', esc_url( $product_permalink ), $_product->get_name() ), $cart_item, $cart_item_key ) );
							}
							do_action( 'woocommerce_after_cart_item_name', $cart_item, $cart_item_key );
							echo wc_get_formatted_cart_item_data( $cart_item ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
							if ( $_product->backorders_require_notification() && $_product->is_on_backorder( $cart_item['quantity'] ) ) {
								echo wp_kses_post( apply_filters( 'woocommerce_cart_item_backorder_notification', '<p class="backorder_notification">' . esc_html__( 'Available on backorder', 'woocommerce' ) . '</p>', $product_id ) );
							}
							?>
							</td>
							<td class="product-price" data-title="<?php esc_attr_e( 'Price', 'woocommerce' ); ?>">
								<?php echo apply_filters( 'woocommerce_cart_item_price', WC()->cart->get_product_price( $_product ), $cart_item, $cart_item_key ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
							</td>
							<td class="product-quantity" data-title="<?php esc_attr_e( 'Quantity', 'woocommerce' ); ?>">
							<?php
							if ( $_product->is_sold_individually() ) {
								$min_quantity = 1;
								$max_quantity = 1;
							} else {
								$min_quantity = 0;
								$max_quantity = $_product->get_max_purchase_quantity();
							}
							$product_quantity = woocommerce_quantity_input(
								array(
									'input_name'   => "cart[{$cart_item_key}][qty]",
									'input_value'  => $cart_item['quantity'],
									'max_value'    => $max_quantity,
									'min_value'    => $min_quantity,
									'product_name' => $product_name,
								),
								$_product,
								false
							);
							echo apply_filters( 'woocommerce_cart_item_quantity', $product_quantity, $cart_item_key, $cart_item ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
							?>
							</td>
							<td class="product-subtotal" data-title="<?php esc_attr_e( 'Subtotal', 'woocommerce' ); ?>">
								<?php echo apply_filters( 'woocommerce_cart_item_subtotal', WC()->cart->get_product_subtotal( $_product, $cart_item['quantity'] ), $cart_item, $cart_item_key ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
							</td>
						</tr>
						<?php
					}
				}
				?>

				<?php do_action( 'woocommerce_cart_contents' ); ?>

				<tr>
					<td colspan="6" class="actions">
						<?php if ( wc_coupons_enabled() ) { ?>
							<div class="coupon">
								<label for="coupon_code" class="screen-reader-text"><?php esc_html_e( 'Coupon:', 'woocommerce' ); ?></label> <input type="text" name="coupon_code" class="input-text" id="coupon_code" value="" placeholder="<?php esc_attr_e( 'Coupon code', 'woocommerce' ); ?>" /> <button type="submit" class="button<?php echo esc_attr( wc_wp_theme_get_element_class_name( 'button' ) ? ' ' . wc_wp_theme_get_element_class_name( 'button' ) : '' ); ?>" name="apply_coupon" value="<?php esc_attr_e( 'Apply coupon', 'woocommerce' ); ?>"><?php esc_html_e( 'Apply coupon', 'woocommerce' ); ?></button>
								<?php do_action( 'woocommerce_cart_coupon' ); ?>
							</div>
						<?php } ?>
						<button type="submit" class="button<?php echo esc_attr( wc_wp_theme_get_element_class_name( 'button' ) ? ' ' . wc_wp_theme_get_element_class_name( 'button' ) : '' ); ?>" name="update_cart" value="<?php esc_attr_e( 'Update cart', 'woocommerce' ); ?>"><?php esc_html_e( 'Update cart', 'woocommerce' ); ?></button>
						<?php do_action( 'woocommerce_cart_actions' ); ?>
						<?php wp_nonce_field( 'woocommerce-cart', 'woocommerce-cart-nonce' ); ?>
					</td>
				</tr>

				<?php do_action( 'woocommerce_after_cart_contents' ); ?>
			</tbody>
		</table>

	<?php endif; ?>

	<?php do_action( 'woocommerce_after_cart_table' ); ?>
</form>

<?php do_action( 'woocommerce_before_cart_collaterals' ); ?>

<div class="cart-collaterals">
	<?php do_action( 'woocommerce_cart_collaterals' ); ?>
</div>

<?php do_action( 'woocommerce_after_cart' ); ?>
