<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\PhotoReportRequest;
use App\Http\Requests\Api\V1\QuickReportRequest;
use App\Http\Requests\Api\V1\TextReportRequest;
use App\Modules\AI\Support\AIProviderException;
use App\Modules\Hazard\Services\HazardReportService;
use Illuminate\Http\JsonResponse;

class HazardReportController extends Controller
{
    public function __construct(
        private readonly HazardReportService $hazardReportService,
    ) {}

    public function photo(PhotoReportRequest $request): JsonResponse
    {
        try {
            $file = $request->file('photo');
            $photoUrl = $file->store('hazards', 'local');
            $location = $request->input('location');
            $note = $request->input('note');

            $result = $this->hazardReportService->createPhotoReport($request, $photoUrl, $location, $note);

            return response()->json($result, 201);
        } catch (AIProviderException $e) {
            return response()->json([
                'error' => ['code' => 'AI_PROVIDER_UNAVAILABLE', 'message' => $e->getMessage(), 'details' => []],
            ], 503);
        } catch (\Throwable $e) {
            if ($e->getMessage() === 'AI failed' || str_contains($e->getMessage(), 'AI')) {
                return response()->json([
                    'error' => ['code' => 'AI_PROVIDER_UNAVAILABLE', 'message' => $e->getMessage(), 'details' => []],
                ], 503);
            }
            throw $e;
        }
    }

    public function text(TextReportRequest $request): JsonResponse
    {
        try {
            $result = $this->hazardReportService->createTextReport($request, $request->input('text'), $request->input('location'));

            return response()->json($result, 201);
        } catch (AIProviderException $e) {
            return response()->json([
                'error' => ['code' => 'AI_PROVIDER_UNAVAILABLE', 'message' => $e->getMessage(), 'details' => []],
                'hazards' => [],
            ], 503);
        }
    }

    public function quick(QuickReportRequest $request): JsonResponse
    {
        $result = $this->hazardReportService->createQuickReport($request, $request->input('type'), $request->input('location'));

        return response()->json($result, 201);
    }

    public function voice(): JsonResponse
    {
        return response()->json([
            'error' => ['code' => 'NOT_IMPLEMENTED', 'message' => 'Voice reporting not implemented', 'details' => []],
        ], 501);
    }
}
