<?php
/**
 * Zooboxi_V2_Events_Controller — the app's capture beacon.
 *
 * Forwards through Zooboxi_Intelligence::forward_event(), the exact validation +
 * forwarding path the website's beacon uses, so the intelligence backend receives one
 * consistent event stream. The Laravel token never leaves the server.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_V2_Events_Controller
{
    private const MAX_BATCH = 50;

    public function register_routes(): void
    {
        Zooboxi_V2_Bootstrap::route('/events', 'POST', [$this, 'track']);
    }

    public function track(\WP_REST_Request $request): \WP_REST_Response
    {
        if (!class_exists('Zooboxi_Intelligence')) {
            return Zooboxi_V2_Bootstrap::fail('events_unavailable', __('التتبّع غير متاح', 'zooboxi'), 'Event capture is unavailable.', 503);
        }

        $batch = $request->get_param('events');
        $items = is_array($batch) ? $batch : [$request->get_params()];
        $items = array_slice(array_values(array_filter($items, 'is_array')), 0, self::MAX_BATCH);

        $anon_id      = Zooboxi_V2_Bootstrap::guest_id($request);
        $user_id      = get_current_user_id();
        $customer_ref = $user_id ? ('wp_' . $user_id) : null;

        $accepted = 0;
        foreach ($items as $event) {
            $input = [
                'event_type' => $event['event_type'] ?? '',
                'anon_id'    => $anon_id !== '' ? $anon_id : ($event['anon_id'] ?? null),
                'item_code'  => $event['item_code'] ?? null,
                'query'      => $event['query'] ?? null,
                'zone'       => $event['zone'] ?? null,
                'ab_variant' => $event['ab_variant'] ?? null,
                'payload'    => is_array($event['payload'] ?? null) ? $event['payload'] : null,
            ];
            if ($customer_ref !== null) {
                $input['customer_ref'] = $customer_ref;
            }

            if (Zooboxi_Intelligence::forward_event($input)) {
                $accepted++;
            }
        }

        $response = Zooboxi_V2_Bootstrap::ok(['accepted' => $accepted, 'received' => count($items)]);
        $response->set_status(202);
        return $response;
    }
}
