<?php

declare(strict_types=1);

namespace App\Http\Requests\Api\V1;

use Illuminate\Foundation\Http\FormRequest;

class ConfirmSuggestionRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'edits' => ['nullable', 'array'],
            'edits.type' => ['nullable', 'string', 'in:DebrisRubble,RoadBlockage,Fire,Flood,ElectricalHazard,VisibleBuildingDamage'],
            'edits.severity' => ['nullable', 'string', 'in:Low,Medium,High'],
            'edits.road_impact' => ['nullable', 'string', 'in:Passable,PartiallyBlocked,Blocked'],
        ];
    }
}
