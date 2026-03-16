<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class UserResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'mobile_number' => $this->mobile_number,
            'warehouse_code' => $this->warehouse_code,
            'avatar_url' => $this->avatar_url,
            'roles' => $this->getRoleNames(),
            // 'permissions' => $this->getAllPermissions()->pluck('name'), // heavy query, enable if needed
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
