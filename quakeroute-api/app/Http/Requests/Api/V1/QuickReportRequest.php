<?php

declare(strict_types=1);

namespace App\Http\Requests\Api\V1;

use Illuminate\Foundation\Http\FormRequest;

class QuickReportRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'type' => ['required', 'string', 'in:DebrisRubble,RoadBlockage,Fire,Flood,ElectricalHazard,VisibleBuildingDamage'],
            'location' => ['required', 'array'],
            'location.lat' => ['required', 'numeric', 'between:-90,90'],
            'location.lng' => ['required', 'numeric', 'between:-180,180'],
        ];
    }
}
