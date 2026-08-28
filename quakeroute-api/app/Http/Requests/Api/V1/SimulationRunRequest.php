<?php

declare(strict_types=1);

namespace App\Http\Requests\Api\V1;

use Illuminate\Foundation\Http\FormRequest;

class SimulationRunRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'origin' => ['required', 'array'],
            'origin.lat' => ['required', 'numeric', 'between:-90,90'],
            'origin.lng' => ['required', 'numeric', 'between:-180,180'],
            // Synthetic mode (center present) generates destinations on-the-fly,
            // so destination_id may be a synthetic UUID not yet in DB.
            // Allow any string/uuid here; existence is validated in service for non-synthetic mode.
            'destination_id' => ['required', 'string', 'max:36'],
            'center' => ['nullable', 'array'],
            'center.lat' => ['required_with:center', 'numeric', 'between:-90,90'],
            'center.lng' => ['required_with:center', 'numeric', 'between:-180,180'],
            'seed' => ['nullable', 'integer', 'between:0,2147483647'],
            'radius_m' => ['nullable', 'integer', 'between:500,5000'],
        ];
    }
}
