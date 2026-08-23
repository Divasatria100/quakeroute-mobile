<?php

declare(strict_types=1);

namespace App\Http\Requests\Api\V1;

use Illuminate\Foundation\Http\FormRequest;

class PhotoReportRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'photo' => ['required', 'file', 'image', 'max:5120'],
            'location' => ['required', 'array'],
            'location.lat' => ['required', 'numeric', 'between:-90,90'],
            'location.lng' => ['required', 'numeric', 'between:-180,180'],
            'note' => ['nullable', 'string', 'max:2000'],
        ];
    }

    protected function prepareForValidation(): void
    {
        if (is_string($this->input('location'))) {
            $decoded = json_decode($this->input('location'), true);
            if (json_last_error() === JSON_ERROR_NONE) {
                $this->merge(['location' => $decoded]);
            }
        }
    }
}
