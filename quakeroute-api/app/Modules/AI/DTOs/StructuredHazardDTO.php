<?php

declare(strict_types=1);

namespace App\Modules\AI\DTOs;

final readonly class StructuredHazardDTO
{
    public function __construct(
        public string $type,
        public string $severity,
        public string $roadImpact,
        public float $confidence,
        public ?float $latitude = null,
        public ?float $longitude = null,
        public ?string $evidence = null,
    ) {}

    /**
     * @return array<string, mixed>
     */
    public function toArray(): array
    {
        return [
            'type' => $this->type,
            'severity' => $this->severity,
            'roadImpact' => $this->roadImpact,
            'confidence' => $this->confidence,
            'latitude' => $this->latitude,
            'longitude' => $this->longitude,
            'evidence' => $this->evidence,
        ];
    }
}
