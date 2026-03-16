<div style="text-align: center; margin-bottom: 1rem;">
    @php
        $folder = substr($itemCode, 0, 4);
        $url = "https://ppte.sa/img/{$folder}/{$itemCode}.png";
    @endphp
    
    <div style="width: 150px; height: 150px; margin: 0 auto; display: flex; align-items: center; justify-content: center; background-color: #f3f4f6; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);">
        <img 
            src="{{ $url }}" 
            alt="{{ $itemName }}" 
            style="max-width: 100%; max-height: 100%; object-fit: contain;"
            onerror="this.parentElement.innerHTML='<div style=\'text-align: center; color: #9ca3af;\'><svg style=\'width: 48px; height: 48px; margin: 0 auto;\' fill=\'none\' viewBox=\'0 0 24 24\' stroke=\'currentColor\'><path stroke-linecap=\'round\' stroke-linejoin=\'round\' stroke-width=\'2\' d=\'M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z\' /></svg><p style=\'margin-top: 0.5rem; font-size: 0.875rem;\'>No Image</p></div>'"
        />
    </div>
    
    <h3 style="margin-top: 1rem; font-size: 1.125rem; font-weight: 600; color: #111827; dark:color: #f9fafb;">
        {{ $itemName }}
    </h3>
    
    <div style="display: flex; justify-content: center; gap: 1rem; margin-top: 0.5rem; font-size: 0.875rem;">
        <span style="color: #6b7280; dark:color: #9cb3bf;">Item Code: <strong style="color: #374151; dark:color: #d1d5db;">{{ $itemCode }}</strong></span>
        <span style="color: #6b7280; dark:color: #9cb3bf;">Expected Qty: <strong style="color: #374151; dark:color: #d1d5db;">{{ $expectedQty }}</strong></span>
    </div>
</div>
