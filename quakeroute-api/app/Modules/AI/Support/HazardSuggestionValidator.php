<?php

declare(strict_types=1);

namespace App\Modules\AI\Support;

use App\Modules\AI\DTOs\StructuredHazardDTO;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\ValidationException;

final class HazardSuggestionValidator
{
    public const ALLOWED_TYPES = [
        'DebrisRubble',
        'RoadBlockage',
        'Fire',
        'Flood',
        'ElectricalHazard',
        'VisibleBuildingDamage',
    ];

    public const ALLOWED_SEVERITIES = ['Low', 'Medium', 'High'];

    public const ALLOWED_ROAD_IMPACTS = ['Passable', 'PartiallyBlocked', 'Blocked'];

    /**
     * Validate raw AI output and return DTO. Throws ValidationException on failure.
     *
     * @param  array<string, mixed>  $data
     */
    public function validate(array $data): StructuredHazardDTO
    {
        $validator = Validator::make($data, [
            'type' => ['required', 'string', 'in:'.implode(',', self::ALLOWED_TYPES)],
            'severity' => ['required', 'string', 'in:'.implode(',', self::ALLOWED_SEVERITIES)],
            'roadImpact' => ['required', 'string', 'in:'.implode(',', self::ALLOWED_ROAD_IMPACTS)],
            'confidence' => ['required', 'numeric', 'between:0,1'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'evidence' => ['nullable', 'string', 'max:2000'],
        ]);

        // Require both lat/lng together or both null
        $validator->after(function ($v) use ($data) {
            $hasLat = array_key_exists('latitude', $data) && $data['latitude'] !== null && $data['latitude'] !== '';
            $hasLng = array_key_exists('longitude', $data) && $data['longitude'] !== null && $data['longitude'] !== '';
            if ($hasLat xor $hasLng) {
                $v->errors()->add('latitude', 'Latitude and longitude must both be provided or both be null.');
                $v->errors()->add('longitude', 'Latitude and longitude must both be provided or both be null.');
            }
        });

        if ($validator->fails()) {
            throw new ValidationException($validator);
        }

        $validated = $validator->validated();

        return new StructuredHazardDTO(
            type: $validated['type'],
            severity: $validated['severity'],
            roadImpact: $validated['roadImpact'],
            confidence: (float) $validated['confidence'],
            latitude: isset($validated['latitude']) ? (float) $validated['latitude'] : null,
            longitude: isset($validated['longitude']) ? (float) $validated['longitude'] : null,
            evidence: $validated['evidence'] ?? null,
        );
    }
}
