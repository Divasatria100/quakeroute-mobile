<?php

declare(strict_types=1);

namespace App\Modules\AI\Services;

use App\Modules\AI\Contracts\AIProviderInterface;
use App\Modules\AI\DTOs\StructuredHazardDTO;
use App\Modules\AI\Support\AIProviderException;
use App\Modules\AI\Support\HazardSuggestionValidator;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

final class HazardUnderstandingService
{
    public function __construct(
        private readonly AIProviderInterface $provider,
        private readonly HazardSuggestionValidator $validator,
    ) {}

    /**
     * Process a hazard_report into a hazard_suggestion.
     *
     * @param  string  $hazardReportId  UUID of hazard_reports.id
     * @return array{success: bool, suggestionId: ?string, dto: ?StructuredHazardDTO, error: ?string}
     */
    public function processReport(string $hazardReportId): array
    {
        $report = DB::table('hazard_reports')->where('id', $hazardReportId)->first();

        if ($report === null) {
            return ['success' => false, 'suggestionId' => null, 'dto' => null, 'error' => 'hazard_report not found'];
        }

        $reportText = (string) ($report->raw_text ?? $report->note ?? '');
        if (trim($reportText) === '') {
            $reportText = (string) ($report->mode ?? '');
        }

        try {
            $raw = $this->provider->extractHazard($reportText, [
                'mode' => $report->mode,
                'hazard_report_id' => $hazardReportId,
            ]);
        } catch (\Throwable $e) {
            Log::warning('AI extraction failed', ['report_id' => $hazardReportId, 'error' => $e->getMessage(), 'category' => $e instanceof AIProviderException ? $e->category : null]);

            return ['success' => false, 'suggestionId' => null, 'dto' => null, 'error' => $e->getMessage()];
        }

        try {
            $dto = $this->validator->validate($raw);
        } catch (ValidationException $e) {
            Log::warning('AI output validation failed', ['report_id' => $hazardReportId, 'errors' => $e->errors(), 'raw' => $raw]);

            return ['success' => false, 'suggestionId' => null, 'dto' => null, 'error' => 'validation failed: '.json_encode($e->errors())];
        }

        // Persist as hazard_suggestions (never hazards). Location handling: DTO lat/lng validated but NOT stored as separate column
        // because schema has no location on hazard_suggestions; original report location remains authoritative.
        $suggestionId = (string) Str::uuid();

        DB::table('hazard_suggestions')->insert([
            'id' => $suggestionId,
            'hazard_report_id' => $hazardReportId,
            'status' => 'PendingConfirmation',
            'proposed_type' => $dto->type,
            'proposed_severity' => $dto->severity,
            'proposed_confidence' => $dto->confidence,
            'proposed_road_impact' => $dto->roadImpact,
            'resulting_hazard_id' => null,
            'created_at' => now(),
            'resolved_at' => null,
        ]);

        return ['success' => true, 'suggestionId' => $suggestionId, 'dto' => $dto, 'error' => null];
    }
}
