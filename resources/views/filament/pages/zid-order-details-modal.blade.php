<div class="p-4">
    <h3 class="font-bold text-lg mb-4">Order #{{ $order['id'] ?? '' }} Details</h3>
    <div class="grid grid-cols-2 gap-4">
        <div>
            <strong>Customer:</strong> {{ $order['customer']['name'] ?? 'N/A' }} <br>
            <strong>Phone:</strong> {{ $order['customer']['mobile'] ?? 'N/A' }}
        </div>
        <div>
            <strong>Status:</strong> {{ $order['order_status']['name'] ?? 'N/A' }} <br>
            <strong>Date:</strong> {{ $order['created_at'] ?? 'N/A' }}
        </div>
    </div>

    <div class="mt-6">
        <h4 class="font-bold border-b pb-2 mb-2">Items</h4>
        <table class="w-full text-sm text-left">
            <thead>
                <tr>
                    <th>Product</th>
                    <th>SKU</th>
                    <th>Qty</th>
                    <th>Price</th>
                    <th>Total</th>
                </tr>
            </thead>
            <tbody>
                @if(isset($order['products']) && is_array($order['products']))
                    @foreach($order['products'] as $item)
                        <tr class="border-b">
                            <td class="py-2">{{ $item['name'] ?? '-' }}</td>
                            <td>{{ $item['sku'] ?? '-' }}</td>
                            <td>{{ $item['quantity'] ?? 0 }}</td>
                            <td>{{ $item['price'] ?? 0 }}</td>
                            <td>{{ ($item['price'] ?? 0) * ($item['quantity'] ?? 0) }}</td>
                        </tr>
                    @endforeach
                @endif
            </tbody>
        </table>
    </div>
</div>